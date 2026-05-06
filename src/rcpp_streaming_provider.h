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

#ifndef MAXENT_RCPP_STREAMING_PROVIDER_HPP
#define MAXENT_RCPP_STREAMING_PROVIDER_HPP

#include <Rcpp.h>
#include <Eigen/Dense>
#include <memory>
#include <stdexcept>

#include "cpp/include/maxent/background_provider.hpp"

namespace maxent {

// =============================================================================
// RcppCallbackBackgroundProvider — BackgroundProvider backed by two R closures.
//
// This is the bridge for Phase E.2 `SpatRaster` streaming: the R side owns
// the terra SpatRaster (via `terra::readStart` / `readValues` / `readStop`),
// and supplies two closures:
//
//   next_tile_fn()  -> NumericMatrix with (n_rows_in_tile, num_layers).
//                      Returns a 0-row matrix to signal end-of-iteration.
//                      The closure is expected to filter NA rows internally,
//                      so that the concatenated tile stream matches
//                      num_points and never contains NAs.
//   reset_fn()      -> NULL. Closes any open streaming session and re-opens it
//                      at the beginning of the raster.
//
// Because this provider re-enters R for every tile, it is NOT thread-safe:
// `fork()` throws. This matches the current usage pattern in
// `FeaturedSpace(provider, sample_indices, FeatureFactory)`, which drains
// the provider exactly once on the R main thread before any parallel work.
// =============================================================================

class RcppCallbackBackgroundProvider : public BackgroundProvider {
public:
    RcppCallbackBackgroundProvider(int               num_points,
                                   int               num_layers,
                                   Rcpp::Function    next_tile_fn,
                                   Rcpp::Function    reset_fn)
        : num_points_(num_points)
        , num_layers_(num_layers)
        , next_tile_fn_(next_tile_fn)
        , reset_fn_(reset_fn)
    {
        if (num_points_ < 0)
            throw std::invalid_argument(
                "RcppCallbackBackgroundProvider: num_points must be non-negative");
        if (num_layers_ <= 0)
            throw std::invalid_argument(
                "RcppCallbackBackgroundProvider: num_layers must be positive");
    }

    int num_points() const override { return num_points_; }
    int num_layers() const override { return num_layers_; }

    TileMatrix next_tile() override {
        SEXP res = next_tile_fn_();
        // An end-of-iteration sentinel: NULL, an empty vector, or a 0-row matrix.
        if (Rf_isNull(res)) return TileMatrix();

        Rcpp::NumericMatrix m(res);
        if (m.nrow() == 0) return TileMatrix();
        if (m.ncol() != num_layers_) {
            Rcpp::stop(
                "RcppCallbackBackgroundProvider: next_tile_fn returned a "
                "matrix with %d columns, expected %d",
                m.ncol(), num_layers_);
        }
        // Eigen is column-major; NumericMatrix storage is also column-major,
        // so Eigen::Map lets us avoid a transpose.
        Eigen::Map<const Eigen::MatrixXd> view(
            REAL(res), m.nrow(), m.ncol());
        return TileMatrix(view);
    }

    void reset() override {
        reset_fn_();
    }

    std::unique_ptr<BackgroundProvider> fork() const override {
        Rcpp::stop(
            "RcppCallbackBackgroundProvider::fork is not supported "
            "(R callbacks must run on the main thread)");
    }

private:
    int            num_points_;
    int            num_layers_;
    Rcpp::Function next_tile_fn_;
    Rcpp::Function reset_fn_;
};

// =============================================================================
// SpatRasterBackgroundProvider — callback provider + preserved SpatRaster.
//
// The provider itself is still driven by callback tiles (so it can be used
// with either terra C++ or terra R block readers), but it additionally owns
// an R_PreserveObject/R_ReleaseObject guard on the source SpatRaster S4
// object for the lifetime of the provider. This prevents the underlying
// external pointer from being garbage collected while C++ iterates tiles.
// =============================================================================
class SpatRasterBackgroundProvider : public BackgroundProvider {
public:
    SpatRasterBackgroundProvider(int               num_points,
                                 int               num_layers,
                                 Rcpp::Function    next_tile_fn,
                                 Rcpp::Function    reset_fn,
                                 SEXP              preserved_rast)
        : callback_(num_points, num_layers, next_tile_fn, reset_fn)
        , preserved_rast_(preserved_rast)
    {
        if (!Rf_isNull(preserved_rast_)) {
            R_PreserveObject(preserved_rast_);
            preserved_ = true;
        }
    }

    ~SpatRasterBackgroundProvider() override {
        if (preserved_) {
            R_ReleaseObject(preserved_rast_);
            preserved_ = false;
        }
    }

    int num_points() const override { return callback_.num_points(); }
    int num_layers() const override { return callback_.num_layers(); }
    TileMatrix next_tile() override { return callback_.next_tile(); }
    void reset() override { callback_.reset(); }

    std::unique_ptr<BackgroundProvider> fork() const override {
        Rcpp::stop(
            "SpatRasterBackgroundProvider::fork is not supported "
            "(R callbacks must run on the main thread)");
    }

private:
    RcppCallbackBackgroundProvider callback_;
    SEXP preserved_rast_ = R_NilValue;
    bool preserved_ = false;
};

} // namespace maxent

#endif // MAXENT_RCPP_STREAMING_PROVIDER_HPP
