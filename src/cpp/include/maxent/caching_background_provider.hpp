/*
Copyright (c) 2025 Maxent Contributors

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#ifndef MAXENT_CACHING_BACKGROUND_PROVIDER_HPP
#define MAXENT_CACHING_BACKGROUND_PROVIDER_HPP

#include <cstdint>
#include <memory>
#include <stdexcept>
#include <utility>
#include <vector>

#include <Eigen/Dense>

#include "maxent/background_provider.hpp"

namespace maxent {

// =============================================================================
// CachingBackgroundProvider — in-memory tile cache on top of any provider.
//
// See docs/ARCHITECTURE_terra_raster.md §4.2 (Design B, in-memory variant).
//
// Purpose
// -------
// `BackgroundProvider` implementations like `RcppCallbackBackgroundProvider`
// (Phase E.2) read their tiles from an expensive source — a `terra::SpatRaster`
// block loop, a network volume, an `mmap`'d scratch file.  `FeaturedSpace`'s
// streaming constructor drains the provider exactly once during construction,
// but future work (per-iteration streaming in `Sequential`, multi-fit workflows
// on the same raster) needs the ability to iterate the same stream multiple
// times without re-paying the source cost.
//
// `CachingBackgroundProvider` is an adapter that solves this: it wraps an
// inner provider, records every tile the inner provider emits during the
// first full drain, and serves subsequent drains from the in-memory cache.
// Once the cache is fully populated the inner provider is released, so the
// caching wrapper owns the only live reference to the background data.
//
// Semantics
// ---------
// * Before the cache is fully populated, `next_tile()` forwards to the inner
//   provider and records each tile into `cache_`.  `reset()` rewinds both
//   the inner provider and the cache cursor.
// * The first call to `next_tile()` that receives an empty tile from the
//   inner provider marks the cache as **fully populated**, destroys the
//   inner provider, and returns the empty sentinel to the caller.
// * After full population, `next_tile()` serves directly from `cache_` and
//   is guaranteed not to touch the inner provider (which no longer exists).
// * `fork()` on a fully populated cache returns a cursor-only clone that
//   shares the underlying tile storage via a `std::shared_ptr`, so parallel
//   consumers do not duplicate the cache in memory.  `fork()` on a
//   partially populated cache delegates to the inner provider's `fork()`;
//   the forked cursor maintains its own independent cache.
// * Tile equality across passes is exact: each cached tile is an
//   `Eigen::MatrixXd` copied from the inner provider at first read, and
//   subsequent passes return const references to the same bytes.
//
// Thread safety
// -------------
// A single `CachingBackgroundProvider` instance is single-threaded — the
// same `reset`/`next_tile` contract as the base class.  `fork()` produces
// independent cursors which may be consumed concurrently after the cache
// is fully populated (shared read-only storage).
// =============================================================================

class CachingBackgroundProvider : public BackgroundProvider {
public:
    /// Construct from an inner provider.  Ownership of `inner` transfers
    /// to the caching wrapper; after full population the wrapper releases
    /// the inner provider.
    ///
    /// \throws std::invalid_argument if `inner` is nullptr.
    explicit CachingBackgroundProvider(std::unique_ptr<BackgroundProvider> inner)
        : inner_(std::move(inner))
        , tiles_(std::make_shared<std::vector<TileMatrix>>())
        , cursor_(0)
        , fully_populated_(false)
        , num_points_(0)
        , num_layers_(0)
    {
        if (!inner_) {
            throw std::invalid_argument(
                "CachingBackgroundProvider: inner provider must be non-null");
        }
        num_points_ = inner_->num_points();
        num_layers_ = inner_->num_layers();
    }

    int num_points() const override { return num_points_; }
    int num_layers() const override { return num_layers_; }

    /// Read the next tile.  On first pass, reads from the inner provider
    /// and records into `cache_`.  On subsequent passes, returns the
    /// matching cached tile by value (copy-on-return; the caller owns its
    /// copy, as with any other BackgroundProvider).
    TileMatrix next_tile() override {
        if (fully_populated_) {
            if (cursor_ >= tiles_->size()) return TileMatrix();
            return (*tiles_)[cursor_++];
        }

        // Populating path: forward to inner, snapshot into cache.
        TileMatrix tile = inner_->next_tile();
        if (tile.rows() == 0) {
            // End of stream — cache is now complete; release the inner
            // provider since we no longer need it.
            fully_populated_ = true;
            inner_.reset();
            return TileMatrix();
        }
        tiles_->push_back(tile);
        ++cursor_;
        return tile;
    }

    /// Rewind the cursor to the beginning of the stream.  On a populating
    /// pass this also rewinds the inner provider so the next `next_tile()`
    /// call continues filling the cache from tile 0; on a fully populated
    /// cache it only resets the cursor.
    void reset() override {
        cursor_ = 0;
        if (!fully_populated_ && inner_) {
            inner_->reset();
            tiles_->clear();
        }
    }

    /// Clone for parallel consumption.  After the cache is fully
    /// populated, the forked cursor shares the underlying tile storage
    /// (no copy).  Before full population, forks the inner provider and
    /// returns a fresh caching wrapper around the fork, so each parallel
    /// consumer owns its own cache.
    std::unique_ptr<BackgroundProvider> fork() const override {
        if (fully_populated_) {
            return std::unique_ptr<BackgroundProvider>(
                new CachingBackgroundProvider(tiles_, num_points_, num_layers_));
        }
        if (!inner_) {
            // Should be unreachable: only way `inner_` is null is after
            // full population, which is handled above.  Defensive guard.
            throw std::runtime_error(
                "CachingBackgroundProvider::fork: inner provider is null "
                "but cache is not fully populated");
        }
        return std::make_unique<CachingBackgroundProvider>(inner_->fork());
    }

    /// Returns true once the full stream has been drained at least once
    /// and the cache is stable.  Useful for test assertions and for
    /// deciding whether to call `fork()` cheaply.
    bool fully_populated() const { return fully_populated_; }

    /// Number of tiles held in the cache (0 until the stream is first
    /// drained).  Primarily for tests and diagnostics.
    std::size_t cached_tile_count() const { return tiles_->size(); }

    /// Total number of rows currently held in the cache.  On a fully
    /// populated cache this equals `num_points()`.
    std::int64_t cached_row_count() const {
        std::int64_t total = 0;
        for (const auto& t : *tiles_) total += t.rows();
        return total;
    }

private:
    // Private constructor used by `fork()` to create a cursor-only clone
    // that shares the underlying tile storage.
    CachingBackgroundProvider(std::shared_ptr<std::vector<TileMatrix>> tiles,
                              int num_points,
                              int num_layers)
        : inner_(nullptr)
        , tiles_(std::move(tiles))
        , cursor_(0)
        , fully_populated_(true)
        , num_points_(num_points)
        , num_layers_(num_layers)
    {}

    std::unique_ptr<BackgroundProvider>       inner_;
    std::shared_ptr<std::vector<TileMatrix>>  tiles_;
    std::size_t                                cursor_;
    bool                                       fully_populated_;
    int                                        num_points_;
    int                                        num_layers_;
};

} // namespace maxent

#endif // MAXENT_CACHING_BACKGROUND_PROVIDER_HPP
