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

#ifndef MAXENT_BACKGROUND_PROVIDER_HPP
#define MAXENT_BACKGROUND_PROVIDER_HPP

#include <Eigen/Dense>
#include <memory>

namespace maxent {

/// Tile matrix type: (rows × cols) dense matrix of doubles.
/// Each row is one background point; each column is one environmental layer.
using TileMatrix = Eigen::MatrixXd;

// =============================================================================
// BackgroundProvider — abstract interface for streaming background data.
//
// See docs/ARCHITECTURE_terra_raster.md §3.1 for the full specification.
//
// A BackgroundProvider is an iterator over *tiles* of a background raster.
// Each tile is a dense (n_rows, n_layers) matrix.  The provider does NOT
// own the underlying data storage — for `DenseMatrixBackgroundProvider` the
// matrix is copied in; for `SpatRasterBackgroundProvider` (Phase E.2) the
// raster lives R-side and is held alive via `R_PreserveObject`.
//
// Usage pattern:
//   provider->reset();
//   while (true) {
//       TileMatrix tile = provider->next_tile();
//       if (tile.rows() == 0) break;   // end of iteration
//       process(tile);
//   }
// =============================================================================

class BackgroundProvider {
public:
    virtual ~BackgroundProvider() = default;

    /// Total number of finite-valued cells in the background raster
    /// (after NA masking).  Must be callable cheaply (cached).
    virtual int num_points() const = 0;

    /// Number of raster layers / environmental variables.
    virtual int num_layers() const = 0;

    /// Read the next tile.  Returns an (n_rows_in_tile, n_layers)
    /// dense matrix.  An empty matrix (rows() == 0) signals
    /// end-of-iteration.
    virtual TileMatrix next_tile() = 0;

    /// Rewind the iterator to the beginning.
    virtual void reset() = 0;

    /// Clone for parallel consumption.  Thread-safe, returns a fresh
    /// iterator starting from the same underlying data.
    virtual std::unique_ptr<BackgroundProvider> fork() const = 0;
};

// =============================================================================
// DenseMatrixBackgroundProvider — wraps an Eigen::MatrixXd in memory.
//
// This is the "today's fixtures" implementation: it preserves the existing
// API exactly by returning the entire matrix as a single tile.  All
// existing tests and the current R interface continue to work unmodified.
//
// See docs/ARCHITECTURE_terra_raster.md §3.1, table row 1.
// =============================================================================

class DenseMatrixBackgroundProvider : public BackgroundProvider {
public:
    /// Construct from a (num_points × num_layers) matrix.
    /// The matrix is *copied* into the provider.
    explicit DenseMatrixBackgroundProvider(Eigen::MatrixXd data)
        : data_(std::move(data))
        , exhausted_(false)
    {}

    int num_points() const override {
        return static_cast<int>(data_.rows());
    }

    int num_layers() const override {
        return static_cast<int>(data_.cols());
    }

    /// Returns the full matrix as a single tile on the first call after
    /// construction / reset.  Subsequent calls return an empty matrix.
    TileMatrix next_tile() override {
        if (exhausted_) return TileMatrix();
        exhausted_ = true;
        return data_;
    }

    void reset() override {
        exhausted_ = false;
    }

    std::unique_ptr<BackgroundProvider> fork() const override {
        return std::make_unique<DenseMatrixBackgroundProvider>(data_);
    }

private:
    Eigen::MatrixXd data_;
    bool exhausted_;
};

} // namespace maxent

#endif // MAXENT_BACKGROUND_PROVIDER_HPP
