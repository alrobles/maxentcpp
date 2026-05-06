#include <Rcpp.h>
#include <algorithm>
#include <numeric>

// Enable C++17
// [[Rcpp::plugins(cpp17)]]

// Link to Eigen
// [[Rcpp::depends(RcppEigen)]]


#include "cpp/include/maxent/feature.hpp"
#include "cpp/include/maxent/featured_space.hpp"
#include "cpp/include/maxent/caching_background_provider.hpp"
#include "cpp/include/maxent/sequential.hpp"
#include "rcpp_streaming_provider.h"


using namespace Rcpp;
using namespace maxent;

// -------------------------------------------------------------------------
// Helper: extract a vector of Feature* from a list of XPtr<Feature>
// -------------------------------------------------------------------------
static std::vector<std::shared_ptr<Feature>> extract_features(List feature_ptrs) {
    std::vector<std::shared_ptr<Feature>> features;
    features.reserve(feature_ptrs.size());
    for (int i = 0; i < feature_ptrs.size(); ++i) {
        XPtr<Feature> xp(feature_ptrs[i]);
        // Wrap the raw pointer in a non-owning shared_ptr
        // (the XPtr still manages lifetime from R)
        features.push_back(std::shared_ptr<Feature>(xp.get(), [](Feature*) {}));
    }
    return features;
}

//' Create a FeaturedSpace object
//'
//' Constructs a MaxEnt FeaturedSpace from background point count,
//' occurrence sample indices, and a list of Feature objects.
//'
//' @param num_points     Integer: number of background points.
//' @param sample_indices Integer vector: 0-based indices of occurrence samples
//'   in the background array.
//' @param feature_ptrs   List of external pointers to Feature objects
//'   (from \code{create_linear_feature()} etc.).
//' @param bias_weights   Optional numeric vector of per-point bias weights
//'   (length \code{num_points}).  When supplied, background density is
//'   computed as \code{bias[i] * exp(lp[i] - lpn)} instead of the standard
//'   \code{exp(lp[i] - lpn)}.  Pass an empty vector (default) for uniform
//'   (unbiased) background.
//' @return External pointer to a FeaturedSpace object.
//' @export
// [[Rcpp::export]]
SEXP maxent_featured_space_create(int num_points,
                                  IntegerVector sample_indices,
                                  List feature_ptrs,
                                  NumericVector bias_weights = NumericVector(0)) {
    std::vector<int> idx(sample_indices.begin(), sample_indices.end());
    auto features = extract_features(feature_ptrs);

    std::vector<double> bw;
    if (bias_weights.size() > 0) {
        bw.assign(bias_weights.begin(), bias_weights.end());
    }

    FeaturedSpace* fs = new FeaturedSpace(num_points, idx, features, bw);
    XPtr<FeaturedSpace> ptr(fs, true);
    ptr.attr("feature_ptrs") = feature_ptrs;
    return ptr;
}

//' Train a FeaturedSpace model
//'
//' Runs the sequential coordinate-ascent MaxEnt optimization.
//'
//' @param fs_ptr            External pointer to a FeaturedSpace object.
//' @param max_iter          Maximum number of training iterations (default 500).
//' @param convergence       Convergence threshold (default 1e-5).
//' @param beta_multiplier   Regularization multiplier (default 1.0).
//' @param min_deviation     Minimum sample deviation floor (default 0.001).
//' @return Named list with elements: \code{loss}, \code{entropy},
//'   \code{iterations}, \code{converged}, \code{lambdas}.
//' @export
// [[Rcpp::export]]
List maxent_train(SEXP fs_ptr,
                  int    max_iter        = 500,
                  double convergence     = 1e-5,
                  double beta_multiplier = 1.0,
                  double min_deviation   = 0.001) {
    XPtr<FeaturedSpace> fs(fs_ptr);
    TrainResult r = fs->train(max_iter, convergence, beta_multiplier, min_deviation);

    return List::create(
        Named("loss")       = r.loss,
        Named("entropy")    = r.entropy,
        Named("iterations") = r.iterations,
        Named("converged")  = r.converged,
        Named("lambdas")    = NumericVector(r.lambdas.begin(), r.lambdas.end())
    );
}

//' Predict with a trained FeaturedSpace model
//'
//' Computes raw Gibbs distribution scores for new environmental data.
//'
//' @param fs_ptr    External pointer to a trained FeaturedSpace object.
//' @param new_data  Numeric matrix with one row per new point and one column
//'   per feature (values must be pre-evaluated, i.e., the feature
//'   transformation already applied).
//' @return Numeric vector of raw scores (unnormalized).
//' @export
// [[Rcpp::export]]
NumericVector maxent_predict(SEXP fs_ptr, NumericMatrix new_data) {
    XPtr<FeaturedSpace> fs(fs_ptr);

    int n_pts = new_data.nrow();
    int n_feat = new_data.ncol();

    std::vector<std::vector<double>> mat(n_pts, std::vector<double>(n_feat));
    for (int i = 0; i < n_pts; ++i) {
        for (int j = 0; j < n_feat; ++j) {
            mat[i][j] = new_data(i, j);
        }
    }

    auto scores = fs->predict(mat);
    return NumericVector(scores.begin(), scores.end());
}

//' Get current distribution weights from a FeaturedSpace
//'
//' @param fs_ptr External pointer to a FeaturedSpace object.
//' @return Numeric vector of normalized weights (sums to 1).
//' @export
// [[Rcpp::export]]
NumericVector maxent_get_weights(SEXP fs_ptr) {
    XPtr<FeaturedSpace> fs(fs_ptr);
    auto w = fs->get_weights();
    return NumericVector(w.begin(), w.end());
}

//' Get entropy of a FeaturedSpace distribution
//'
//' @param fs_ptr External pointer to a FeaturedSpace object.
//' @return Shannon entropy (non-negative scalar).
//' @export
// [[Rcpp::export]]
double maxent_get_entropy(SEXP fs_ptr) {
    XPtr<FeaturedSpace> fs(fs_ptr);
    return fs->get_entropy();
}

//' Get current loss of a FeaturedSpace
//'
//' @param fs_ptr External pointer to a FeaturedSpace object.
//' @return Scalar loss value (negative log-likelihood).
//' @export
// [[Rcpp::export]]
double maxent_get_loss(SEXP fs_ptr) {
    XPtr<FeaturedSpace> fs(fs_ptr);
    return fs->get_loss();
}

//' Write feature lambdas to a file
//'
//' Saves the trained model coefficients in CSV format compatible with
//' the original Java Maxent .lambdas file format.
//'
//' @param fs_ptr   External pointer to a trained FeaturedSpace object.
//' @param filename Character: path to the output file.
//' @return Called for side effects; returns invisibly.
//' @export
// [[Rcpp::export]]
void maxent_write_lambdas(SEXP fs_ptr, std::string filename) {
    XPtr<FeaturedSpace> fs(fs_ptr);
    fs->write_lambdas(filename);
}

//' Read feature lambdas from a file
//'
//' Restores model coefficients from a .lambdas file.  The FeaturedSpace
//' must have been created with the same features (same names and order).
//'
//' @param fs_ptr   External pointer to a FeaturedSpace object.
//' @param filename Character: path to the lambdas file.
//' @return Called for side effects; returns invisibly.
//' @export
// [[Rcpp::export]]
void maxent_read_lambdas(SEXP fs_ptr, std::string filename) {
    XPtr<FeaturedSpace> fs(fs_ptr);
    fs->read_lambdas(filename);
}

//' Set sample expectations for a FeaturedSpace
//'
//' Computes sample expectations and regularization deviations for each feature.
//' Called automatically by \code{maxent_train()}, but exposed for advanced use.
//'
//' @param fs_ptr          External pointer to a FeaturedSpace object.
//' @param beta_multiplier Regularization multiplier (default 1.0).
//' @param min_deviation   Minimum sample deviation (default 0.001).
//' @return Called for side effects; returns invisibly.
//' @export
// [[Rcpp::export]]
void maxent_set_sample_expectations(SEXP fs_ptr,
                                    double beta_multiplier = 1.0,
                                    double min_deviation   = 0.001) {
    XPtr<FeaturedSpace> fs(fs_ptr);
    fs->set_sample_expectations(beta_multiplier, min_deviation);
}

//' Train a FeaturedSpace with the Sequential optimizer (trajectory-capable)
//'
//' Runs the full \code{density.Sequential} optimizer ported from the original
//' Java Maxent, with optional per-iteration trajectory snapshots.  Unlike
//' \code{maxent_train()} which uses a \code{goodAlpha}-only loop, this trainer
//' reproduces the real Java optimizer's feature-selection (\code{deltaLossBound}),
//' Newton step, 1-D line search, and every-10-iter \code{doParallelUpdate}
//' with undo on loss-violating batch steps.
//'
//' @param fs_ptr                   External pointer to a FeaturedSpace object.
//' @param max_iter                 Maximum number of iterations (default 500).
//' @param convergence              Convergence threshold on \code{newLoss - oldLoss}
//'   (default \code{1e-5}).  Ignored when \code{disable_convergence_test=TRUE}.
//' @param beta_multiplier          Regularization multiplier (default 1.0).
//' @param min_deviation            Minimum sample deviation floor (default 0.001).
//' @param parallel_update_frequency Iteration frequency at which
//'   \code{doParallelUpdate} runs (default 10, matching Java).
//' @param disable_convergence_test When \code{TRUE}, the loop runs a fixed
//'   \code{max_iter} iterations with no early stop.  Needed for deterministic
//'   per-iteration trajectory comparisons against the Java oracle.
//' @param trajectory_iterations    Integer vector of 1-based iteration indices
//'   at which to capture \code{(loss, entropy, lambdas)} snapshots.  May be
//'   empty.  Snapshots outside \code{[1, max_iter]} are silently dropped.
//' @return Named list with elements:
//'   \code{loss}, \code{entropy}, \code{iterations}, \code{converged},
//'   \code{lambdas}, and \code{trajectory} — a data.frame with columns
//'   \code{iteration, loss, entropy, lambda_0, ..., lambda_{J-1}} holding
//'   one row per requested checkpoint that was actually reached.
//' @keywords internal
// [[Rcpp::export]]
List maxent_sequential_train(SEXP fs_ptr,
                             int    max_iter                  = 500,
                             double convergence               = 1e-5,
                             double beta_multiplier           = 1.0,
                             double min_deviation             = 0.001,
                             int    parallel_update_frequency = 10,
                             bool   disable_convergence_test  = false,
                             Rcpp::IntegerVector trajectory_iterations =
                                 Rcpp::IntegerVector::create()) {
    XPtr<FeaturedSpace> fs(fs_ptr);

    SequentialParams params;
    params.max_iter                  = max_iter;
    params.convergence_threshold     = convergence;
    params.beta_multiplier           = beta_multiplier;
    params.min_deviation             = min_deviation;
    params.parallel_update_frequency = parallel_update_frequency;
    params.disable_convergence_test  = disable_convergence_test;

    Sequential opt(*fs, params);

    // Sort the requested checkpoint iterations and capture matching snapshots.
    std::vector<int> checkpoints(trajectory_iterations.begin(),
                                 trajectory_iterations.end());
    std::sort(checkpoints.begin(), checkpoints.end());

    std::vector<SequentialSnapshot> snaps;
    std::size_t cp_idx = 0;
    opt.set_observer([&](const SequentialSnapshot& s) {
        while (cp_idx < checkpoints.size() && checkpoints[cp_idx] < s.iteration)
            ++cp_idx;
        if (cp_idx < checkpoints.size() && checkpoints[cp_idx] == s.iteration) {
            snaps.push_back(s);
            ++cp_idx;
        }
    });

    opt.run();
    TrainResult r = opt.result();

    const int nfeat = fs->num_features();
    const int nrows = static_cast<int>(snaps.size());
    IntegerVector traj_iter(nrows);
    NumericVector traj_loss(nrows);
    NumericVector traj_entropy(nrows);
    List traj = List::create(
        Named("iteration") = traj_iter,
        Named("loss")      = traj_loss,
        Named("entropy")   = traj_entropy);
    for (int j = 0; j < nfeat; ++j) {
        NumericVector col(nrows);
        for (int i = 0; i < nrows; ++i) col[i] = snaps[i].lambdas[j];
        std::string nm = "lambda_" + std::to_string(j);
        traj.push_back(col, nm);
    }
    for (int i = 0; i < nrows; ++i) {
        traj_iter[i]    = snaps[i].iteration;
        traj_loss[i]    = snaps[i].loss;
        traj_entropy[i] = snaps[i].entropy;
    }
    // Turn the list into a data.frame so R users get familiar semantics.
    traj.attr("class")     = "data.frame";
    traj.attr("row.names") = IntegerVector::create(NA_INTEGER, -nrows);

    return List::create(
        Named("loss")       = r.loss,
        Named("entropy")    = r.entropy,
        Named("iterations") = r.iterations,
        Named("converged")  = r.converged,
        Named("lambdas")    = NumericVector(r.lambdas.begin(), r.lambdas.end()),
        Named("trajectory") = traj
    );
}

//' Get FeaturedSpace metadata
//'
//' @param fs_ptr External pointer to a FeaturedSpace object.
//' @return Named list with num_points, num_samples, num_features,
//'   density_normalizer, linear_predictor_normalizer, has_bias.
//' @export
// [[Rcpp::export]]
List maxent_featured_space_info(SEXP fs_ptr) {
    XPtr<FeaturedSpace> fs(fs_ptr);
    return List::create(
        Named("num_points")   = fs->num_points(),
        Named("num_samples")  = fs->num_samples(),
        Named("num_features") = fs->num_features(),
        Named("density_normalizer") = fs->get_density_normalizer(),
        Named("linear_predictor_normalizer") = fs->get_linear_predictor_normalizer(),
        Named("has_bias") = fs->has_bias()
    );
}

//' Enable or disable streaming-eval mode on a FeaturedSpace
//'
//' @param fs_ptr External pointer to a FeaturedSpace object.
//' @param enabled Logical flag.
//' @return Called for side effects; returns invisibly.
//' @keywords internal
// [[Rcpp::export]]
void maxent_set_streaming_eval(SEXP fs_ptr, bool enabled = true) {
    XPtr<FeaturedSpace> fs(fs_ptr);
    fs->set_streaming_eval(enabled);
}

// -------------------------------------------------------------------------
// Phase E.2: Streaming FeaturedSpace from an R-driven callback provider.
//
// The R side owns the streaming session (e.g. a `terra::SpatRaster` opened
// via `readStart()`) and supplies two closures:
//
//   next_tile_fn() -> NumericMatrix (nrow x num_layers) or 0-row matrix/NULL
//                     at end of stream. Closure is expected to filter out
//                     NA rows so the concatenated stream matches num_points.
//   reset_fn()     -> NULL. Re-opens the stream at the beginning.
//
// See docs/ARCHITECTURE_terra_raster.md §3.1 / §3.2.
// -------------------------------------------------------------------------
//' Create a FeaturedSpace from a streaming background provider
//'
//' Builds a \code{FeaturedSpace} by draining a callback-style background
//' provider (typically backed by a \code{terra::SpatRaster} block loop)
//' one tile at a time, then constructing features from the concatenated
//' \code{(num_points x num_layers)} matrix via \code{\link{generate_features}}.
//'
//' This is the C++ entry point used by
//' \code{\link{maxent_featured_space_from_rast}}; end users should prefer
//' that R-level wrapper.
//'
//' @param num_points      Integer: total number of finite background points
//'   the provider will emit (sum of \code{nrow()} across tiles).
//' @param num_layers      Integer: number of environmental variables / raster
//'   layers per tile row.
//' @param layer_names     Character vector of length \code{num_layers}
//'   giving the name for each layer / column (used when generating feature
//'   names such as \code{bio1^2}, \code{bio1*bio2}).
//' @param sample_indices  Integer vector: 0-based indices of occurrence
//'   samples in the concatenated background stream.
//' @param feature_types   Character vector of feature types to generate.
//'   See \code{\link{maxent_generate_features}}.
//' @param n_thresholds    Number of threshold knots per variable.
//' @param n_hinges        Number of hinge knots per variable.
//' @param next_tile_fn    R function returning the next tile as a numeric
//'   matrix (nrow x num_layers), or a 0-row matrix / \code{NULL} when the
//'   stream is exhausted. The function is responsible for filtering out
//'   rows containing NAs.
//' @param reset_fn        R function (no arguments) that rewinds the
//'   underlying stream to the beginning.
//' @param use_cache Logical; wrap the callback stream in
//'   \code{CachingBackgroundProvider}.
//' @return External pointer to a \code{FeaturedSpace} object.
//' @export
// [[Rcpp::export]]
SEXP maxent_featured_space_from_callback(int               num_points,
                                         int               num_layers,
                                         CharacterVector   layer_names,
                                         IntegerVector     sample_indices,
                                         CharacterVector   feature_types,
                                         int               n_thresholds,
                                         int               n_hinges,
                                         Function          next_tile_fn,
                                         Function          reset_fn,
                                         bool              use_cache = true) {
    if (layer_names.size() != num_layers) {
        Rcpp::stop(
            "maxent_featured_space_from_callback: layer_names has %d "
            "entries but num_layers is %d",
            layer_names.size(), num_layers);
    }

    std::vector<std::string> names_cpp(num_layers);
    for (int j = 0; j < num_layers; ++j) {
        names_cpp[j] = as<std::string>(layer_names[j]);
    }

    FeatureConfig cfg;
    cfg.linear    = false;
    cfg.quadratic = false;
    cfg.product   = false;
    cfg.threshold = false;
    cfg.hinge     = false;
    cfg.n_thresholds = n_thresholds;
    cfg.n_hinges     = n_hinges;
    for (int i = 0; i < feature_types.size(); ++i) {
        std::string t = as<std::string>(feature_types[i]);
        if (t == "linear")    cfg.linear    = true;
        else if (t == "quadratic") cfg.quadratic = true;
        else if (t == "product")   cfg.product   = true;
        else if (t == "threshold") cfg.threshold = true;
        else if (t == "hinge")     cfg.hinge     = true;
        else Rcpp::stop(
            "maxent_featured_space_from_callback: unknown feature type '%s'", t);
    }

    std::unique_ptr<BackgroundProvider> provider(
        new RcppCallbackBackgroundProvider(
            num_points, num_layers, next_tile_fn, reset_fn));
    if (use_cache) {
        provider = std::unique_ptr<BackgroundProvider>(
            new CachingBackgroundProvider(std::move(provider)));
    }

    // FeatureFactory: consumes the drained (num_points x num_layers) matrix
    // and produces all configured features. Keeps features alive by
    // handing back `shared_ptr` (FeatureGenerator::generate returns
    // unique_ptr; we release+wrap).
    auto factory = [cfg, names_cpp](const Eigen::MatrixXd& bg)
        -> std::vector<std::shared_ptr<Feature>>
    {
        std::vector<std::pair<std::string, std::vector<double>>> data;
        data.reserve(names_cpp.size());
        for (std::size_t j = 0; j < names_cpp.size(); ++j) {
            std::vector<double> col(bg.rows());
            for (int i = 0; i < bg.rows(); ++i) col[i] = bg(i, static_cast<int>(j));
            data.emplace_back(names_cpp[j], std::move(col));
        }
        auto unique_features = FeatureGenerator::generate(data, cfg);
        std::vector<std::shared_ptr<Feature>> shared_features;
        shared_features.reserve(unique_features.size());
        for (auto& up : unique_features) {
            shared_features.emplace_back(up.release());
        }
        return shared_features;
    };

    std::vector<int> idx(sample_indices.begin(), sample_indices.end());
    FeaturedSpace* fs = new FeaturedSpace(std::move(provider), idx, factory);
    XPtr<FeaturedSpace> ptr(fs, true);
    return ptr;
}

//' Create a FeaturedSpace from a terra SpatRaster callback stream
//'
//' Same as \code{maxent_featured_space_from_callback()}, but also preserves
//' the source \code{SpatRaster} S4 object for provider lifetime safety and
//' can enable streaming-eval mode immediately.
//'
//' @param preserved_rast A terra \code{SpatRaster} S4 object to preserve.
//' @param rast_xptr External pointer extracted from the raster object
//'   (used for contract validation).
//' @param num_points Integer; total number of finite background points.
//' @param num_layers Integer; number of environmental variables per row.
//' @param layer_names Character vector of layer names (length num_layers).
//' @param sample_indices Integer vector; 0-based indices of presence samples.
//' @param feature_types Character vector of feature types to generate.
//' @param n_thresholds Integer; number of threshold knots per variable.
//' @param n_hinges Integer; number of hinge knots per variable.
//' @param next_tile_fn R function returning the next tile or NULL/0-row matrix.
//' @param reset_fn R function (no args) that rewinds the underlying stream.
//' @param enable_streaming_eval Logical; whether to enable streaming eval mode.
//' @param use_cache Logical; wrap the stream in \code{CachingBackgroundProvider}.
//' @return External pointer to a FeaturedSpace object.
//' @keywords internal
// [[Rcpp::export]]
SEXP maxent_featured_space_from_spatraster_callback(SEXP              preserved_rast,
                                                    SEXP              rast_xptr,
                                                    int               num_points,
                                                    int               num_layers,
                                                    CharacterVector   layer_names,
                                                    IntegerVector     sample_indices,
                                                    CharacterVector   feature_types,
                                                    int               n_thresholds,
                                                    int               n_hinges,
                                                    Function          next_tile_fn,
                                                    Function          reset_fn,
                                                    bool              enable_streaming_eval = true,
                                                    bool              use_cache = true) {
    if (TYPEOF(rast_xptr) != EXTPTRSXP) {
        Rcpp::stop(
            "maxent_featured_space_from_spatraster_callback: rast_xptr must "
            "be an external pointer (XPtr<SpatRaster>)");
    }
    if (layer_names.size() != num_layers) {
        Rcpp::stop(
            "maxent_featured_space_from_spatraster_callback: layer_names has %d "
            "entries but num_layers is %d",
            layer_names.size(), num_layers);
    }

    std::vector<std::string> names_cpp(num_layers);
    for (int j = 0; j < num_layers; ++j) {
        names_cpp[j] = as<std::string>(layer_names[j]);
    }

    FeatureConfig cfg;
    cfg.linear    = false;
    cfg.quadratic = false;
    cfg.product   = false;
    cfg.threshold = false;
    cfg.hinge     = false;
    cfg.n_thresholds = n_thresholds;
    cfg.n_hinges     = n_hinges;
    for (int i = 0; i < feature_types.size(); ++i) {
        std::string t = as<std::string>(feature_types[i]);
        if (t == "linear")    cfg.linear    = true;
        else if (t == "quadratic") cfg.quadratic = true;
        else if (t == "product")   cfg.product   = true;
        else if (t == "threshold") cfg.threshold = true;
        else if (t == "hinge")     cfg.hinge     = true;
        else Rcpp::stop(
            "maxent_featured_space_from_spatraster_callback: unknown feature type '%s'", t);
    }

    std::unique_ptr<BackgroundProvider> provider(
        new SpatRasterBackgroundProvider(
            num_points, num_layers, next_tile_fn, reset_fn, preserved_rast));
    if (use_cache) {
        provider = std::unique_ptr<BackgroundProvider>(
            new CachingBackgroundProvider(std::move(provider)));
    }

    auto factory = [cfg, names_cpp](const Eigen::MatrixXd& bg)
        -> std::vector<std::shared_ptr<Feature>>
    {
        std::vector<std::pair<std::string, std::vector<double>>> data;
        data.reserve(names_cpp.size());
        for (std::size_t j = 0; j < names_cpp.size(); ++j) {
            std::vector<double> col(bg.rows());
            for (int i = 0; i < bg.rows(); ++i) col[i] = bg(i, static_cast<int>(j));
            data.emplace_back(names_cpp[j], std::move(col));
        }
        auto unique_features = FeatureGenerator::generate(data, cfg);
        std::vector<std::shared_ptr<Feature>> shared_features;
        shared_features.reserve(unique_features.size());
        for (auto& up : unique_features) {
            shared_features.emplace_back(up.release());
        }
        return shared_features;
    };

    std::vector<int> idx(sample_indices.begin(), sample_indices.end());
    FeaturedSpace* fs = new FeaturedSpace(std::move(provider), idx, factory);
    if (enable_streaming_eval) {
        fs->set_streaming_eval(true);
    }
    XPtr<FeaturedSpace> ptr(fs, true);
    return ptr;
}

//' Extract occurrence environmental values from a callback stream
//'
//' Drains a callback background stream once and returns the rows at the
//' requested 0-based finite-stream indices.
//'
//' @param num_points Integer; total finite background rows in stream.
//' @param num_layers Integer; number of environmental variables per row.
//' @param occurrence_indices Integer vector of 0-based finite-stream indices.
//' @param next_tile_fn R function returning the next tile or NULL/0-row matrix.
//' @param reset_fn R function (no args) that rewinds the underlying stream.
//' @param preserved_rast Optional SpatRaster object to preserve during read.
//' @return Numeric matrix with one row per requested occurrence index.
//' @keywords internal
// [[Rcpp::export]]
NumericMatrix maxent_extract_occurrence_from_callback(int            num_points,
                                                      int            num_layers,
                                                      IntegerVector  occurrence_indices,
                                                      Function       next_tile_fn,
                                                      Function       reset_fn,
                                                      SEXP           preserved_rast = R_NilValue) {
    std::vector<int> idx(occurrence_indices.begin(), occurrence_indices.end());
    for (int i : idx) {
        if (i < 0 || i >= num_points) {
            Rcpp::stop(
                "maxent_extract_occurrence_from_callback: occurrence index %d "
                "out of range [0, %d)", i, num_points);
        }
    }

    auto provider = std::unique_ptr<BackgroundProvider>(
        new SpatRasterBackgroundProvider(
            num_points, num_layers, next_tile_fn, reset_fn, preserved_rast));
    provider->reset();

    NumericMatrix out(idx.size(), num_layers);
    std::vector<int> order(idx.size());
    std::iota(order.begin(), order.end(), 0);
    std::sort(order.begin(), order.end(),
              [&](int a, int b) { return idx[a] < idx[b]; });

    std::size_t next_pick = 0;
    int global_row = 0;
    while (true) {
        TileMatrix tile = provider->next_tile();
        if (tile.rows() == 0) break;
        const int tile_rows = static_cast<int>(tile.rows());
        const int tile_end = global_row + tile_rows;

        while (next_pick < order.size()) {
            const int out_row = order[next_pick];
            const int wanted = idx[out_row];
            if (wanted >= tile_end) break;
            if (wanted >= global_row) {
                const int local = wanted - global_row;
                for (int j = 0; j < num_layers; ++j) {
                    out(out_row, j) = tile(local, j);
                }
            }
            ++next_pick;
        }
        global_row = tile_end;
    }

    if (global_row != num_points) {
        Rcpp::stop(
            "maxent_extract_occurrence_from_callback: stream row count (%d) "
            "did not match declared num_points (%d)", global_row, num_points);
    }
    return out;
}
