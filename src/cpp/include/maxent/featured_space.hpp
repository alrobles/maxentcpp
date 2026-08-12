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

#ifndef MAXENT_FEATURED_SPACE_HPP
#define MAXENT_FEATURED_SPACE_HPP

#include "feature.hpp"
#include "background_provider.hpp"

#include <Eigen/Dense>
#include <vector>
#include <memory>
#include <string>
#include <cmath>
#include <algorithm>
#include <numeric>
#include <limits>
#include <stdexcept>
#include <fstream>
#include <sstream>
#include <iomanip>

namespace maxent {

// ============================================================================
// Helper structs
// ============================================================================

/**
 * @brief Summary statistics over a set of sample values.
 * Ported from the inner class FeaturedSpace.SampleInfo in Java Maxent.
 */
struct SampleInfo {
    double avg;        ///< Mean value
    double std;        ///< Standard deviation
    double min;        ///< Minimum value
    double max;        ///< Maximum value
    int    sample_cnt; ///< Number of samples

    SampleInfo() : avg(0), std(0), min(0), max(0), sample_cnt(0) {}
    SampleInfo(double avg, double std, double min, double max, int cnt)
        : avg(avg), std(std), min(min), max(max), sample_cnt(cnt) {}
};

/**
 * @brief Confidence interval [low, high] for a feature value.
 * Ported from the inner class FeaturedSpace.Interval in Java Maxent.
 */
struct Interval {
    double low;   ///< Lower bound
    double high;  ///< Upper bound

    Interval() : low(0), high(0) {}
    Interval(double low, double high) : low(low), high(high) {}

    /** Construct interval from SampleInfo and beta multiplier. */
    Interval(const SampleInfo& f, double beta) {
        if (f.sample_cnt == 0) {
            low  = f.min;
            high = f.max;
        } else {
            double spread = beta / std::sqrt(static_cast<double>(f.sample_cnt)) * f.std;
            low  = f.avg - spread;
            high = f.avg + spread;
        }
    }

    /** Construct interval as the ratio of two intervals (for bias correction). */
    Interval(const Interval& a, const Interval& b) {
        if (b.low < 0.0) {
            low  =  std::numeric_limits<double>::infinity();
            high = -std::numeric_limits<double>::infinity();
        } else {
            low  = a.low  / (b.high > 0.0 ? b.high : 1.0);
            high = a.high / (b.low  > 0.0 ? b.low  : 1.0);
        }
    }

    /// Mid-point of the interval
    double mid() const { return 0.5 * (low + high); }
    /// Half-width of the interval
    double dev() const { return 0.5 * (high - low); }
};

/**
 * @brief Closure that builds feature objects from concatenated tile data.
 *
 * The argument is the full background data matrix of shape
 * (num_points × num_layers), assembled by draining a BackgroundProvider
 * tile by tile. The closure is responsible for constructing all feature
 * objects (LinearFeature, QuadraticFeature, ProductFeature, …) and
 * wiring them to the column(s) of `background` they depend on.
 *
 * This is the interface specified in docs/ARCHITECTURE_terra_raster.md §3.2.
 * See test_background_provider.cpp::StreamingFactoryConstructor_* for
 * a concrete example.
 */
using FeatureFactory = std::function<
    std::vector<std::shared_ptr<Feature>>(const Eigen::MatrixXd& /*background*/)>;

/**
 * @brief Result returned by FeaturedSpace::train()
 */
struct TrainResult {
    double loss;          ///< Final regularized loss
    double entropy;       ///< Shannon entropy of the distribution
    int    iterations;    ///< Number of iterations completed
    bool   converged;     ///< Whether convergence threshold was reached
    std::vector<double> lambdas; ///< Final lambda values for all features
};

// ============================================================================
// FeaturedSpace class
// ============================================================================

/**
 * @brief Core MaxEnt featured space: manages the Gibbs distribution over
 *        background points and drives model training.
 *
 * Terminology (following the original Java code):
 *   density[i]         = exp(linearPredictor[i] - linearPredictorNormalizer)
 *   normalized prob    = density[i] / densityNormalizer
 *   linearPredictor[i] = sum_j lambda_j * feature_j.eval(i)
 *
 * Ported from density/FeaturedSpace.java and density/Sequential.java.
 */
class FeaturedSpace {
public:
    // -----------------------------------------------------------------------
    // Construction
    // -----------------------------------------------------------------------

    /**
     * @brief Construct a FeaturedSpace.
     * @param num_points     Number of background points.
     * @param sample_indices 0-based indices of occurrence samples in background.
     * @param features       Feature objects (shared ownership).
     * @param bias_weights   Optional per-point bias weights (length num_points).
     *                       When non-empty, density is computed as
     *                       bias[i] * exp(lp[i] - lpn) instead of exp(lp[i] - lpn).
     *                       Values need not be normalized — the density normalizer
     *                       handles that.  An empty vector (default) means uniform
     *                       bias (all 1.0), which reproduces the standard behavior.
     */
    FeaturedSpace(int                                    num_points,
                  std::vector<int>                       sample_indices,
                  std::vector<std::shared_ptr<Feature>>  features,
                  std::vector<double>                    bias_weights = {})
        : num_points_(num_points)
        , num_samples_(static_cast<int>(sample_indices.size()))
        , sample_indices_(std::move(sample_indices))
        , features_(std::move(features))
        , density_(Eigen::VectorXd::Zero(num_points))
        , linear_predictor_(Eigen::VectorXd::Zero(num_points))
    {
        init_bias_weights(bias_weights);
        for (int idx : sample_indices_) {
            if (idx < 0 || idx >= num_points_)
                throw std::out_of_range("FeaturedSpace: sample index out of range");
        }
        build_feature_matrix();
        set_linear_predictor();
        set_density();
    }

    /**
     * @brief Streaming constructor: build from a BackgroundProvider.
     *
     * Accepts a BackgroundProvider and a pre-built vector of features
     * whose eval(i) data has already been populated from the same
     * background source.  The provider is stored for potential future
     * streaming passes; the features are used exactly as in the dense
     * constructor.
     *
     * This preserves full API and numerical equivalence with the dense
     * constructor when the features are built from the same data that
     * the provider wraps.
     *
     * @param provider       Streaming background data source (ownership transferred).
     * @param sample_indices 0-based indices of occurrence samples.
     * @param features       Feature objects built from the provider's data.
     * @param bias_weights   Optional per-point bias weights (see dense ctor).
     */
    FeaturedSpace(std::unique_ptr<BackgroundProvider>    provider,
                  std::vector<int>                       sample_indices,
                  std::vector<std::shared_ptr<Feature>>  features,
                  std::vector<double>                    bias_weights = {})
        : num_points_(provider ? provider->num_points() : 0)
        , num_samples_(static_cast<int>(sample_indices.size()))
        , sample_indices_(std::move(sample_indices))
        , features_(std::move(features))
        , density_(Eigen::VectorXd::Zero(num_points_))
        , linear_predictor_(Eigen::VectorXd::Zero(num_points_))
        , provider_(std::move(provider))
    {
        init_bias_weights(bias_weights);
        for (int idx : sample_indices_) {
            if (idx < 0 || idx >= num_points_)
                throw std::out_of_range("FeaturedSpace: sample index out of range");
        }
        build_feature_matrix();
        set_linear_predictor();
        set_density();
    }

    /**
     * @brief Streaming constructor with a feature factory.
     *
     * This is the spec'd Phase E.1 constructor from
     * docs/ARCHITECTURE_terra_raster.md §3.2. Unlike the pre-built
     * `vector<shared_ptr<Feature>>` overload above, this overload
     * actually *drains* the provider (reset → next_tile loop → empty
     * tile sentinel) and then hands the concatenated background matrix
     * to `feature_factory`, which produces the feature objects wired
     * to whichever column(s) of `background` they need.
     *
     * Provider iteration contract enforced here:
     *   - provider->reset() is called exactly once.
     *   - provider->next_tile() is called in a loop until it returns
     *     an empty (0-row) tile.
     *   - The concatenated row count must equal provider->num_points().
     *   - Every tile must have exactly provider->num_layers() columns.
     *   - Violations throw std::runtime_error.
     *
     * @param provider         Streaming background data source (ownership transferred).
     * @param sample_indices   0-based indices of occurrence samples.
     * @param feature_factory  Closure that builds features from the
     *                         drained (num_points × num_layers) matrix.
     * @param bias_weights     Optional per-point bias weights (see dense ctor).
     * @throws std::invalid_argument if provider or feature_factory is null.
     * @throws std::out_of_range     if a sample index is out of range.
     * @throws std::runtime_error    if the provider's tile stream is
     *                               inconsistent with its declared
     *                               num_points() / num_layers(), or if
     *                               the factory returns no features.
     */
    FeaturedSpace(std::unique_ptr<BackgroundProvider>  provider,
                  std::vector<int>                     sample_indices,
                  FeatureFactory                       feature_factory,
                  std::vector<double>                  bias_weights = {})
        : num_points_(provider ? provider->num_points() : 0)
        , num_samples_(static_cast<int>(sample_indices.size()))
        , sample_indices_(std::move(sample_indices))
        , density_(Eigen::VectorXd::Zero(num_points_))
        , linear_predictor_(Eigen::VectorXd::Zero(num_points_))
        , provider_(std::move(provider))
    {
        if (!provider_)
            throw std::invalid_argument(
                "FeaturedSpace: BackgroundProvider must not be null");
        if (!feature_factory)
            throw std::invalid_argument(
                "FeaturedSpace: FeatureFactory must not be null");
        init_bias_weights(bias_weights);
        for (int idx : sample_indices_) {
            if (idx < 0 || idx >= num_points_)
                throw std::out_of_range(
                    "FeaturedSpace: sample index out of range");
        }

        const int expected_layers = provider_->num_layers();
        Eigen::MatrixXd background(num_points_, expected_layers);
        provider_->reset();
        int row = 0;
        while (true) {
            TileMatrix tile = provider_->next_tile();
            if (tile.rows() == 0) break;
            if (tile.cols() != expected_layers) {
                throw std::runtime_error(
                    "FeaturedSpace: BackgroundProvider emitted tile with "
                    "inconsistent num_layers");
            }
            if (row + static_cast<int>(tile.rows()) > num_points_) {
                throw std::runtime_error(
                    "FeaturedSpace: BackgroundProvider emitted more rows "
                    "than declared by num_points()");
            }
            background.middleRows(row, tile.rows()) = tile;
            row += static_cast<int>(tile.rows());
        }
        if (row != num_points_) {
            throw std::runtime_error(
                "FeaturedSpace: BackgroundProvider emitted fewer rows "
                "than declared by num_points()");
        }

        features_ = feature_factory(background);
        if (features_.empty()) {
            throw std::runtime_error(
                "FeaturedSpace: FeatureFactory returned no features");
        }

        build_feature_matrix();
        set_linear_predictor();
        set_density();
    }

    // -----------------------------------------------------------------------
    // Core distribution methods
    // -----------------------------------------------------------------------

    /** Recompute linearPredictor[i] = sum_j lambda_j * feature_j.eval(i). */
    void set_linear_predictor() {
        if (streaming_eval_) { set_linear_predictor_streaming(); return; }
        const int nf = static_cast<int>(features_.size());
        linear_predictor_.setZero();
        if (nf > 0 && feature_matrix_.size() > 0) {
            // Per-column Eigen accumulation: preserves feature-outer order,
            // eliminates virtual dispatch, and enables SIMD for element-wise ops.
            for (int j = 0; j < nf; ++j) {
                double lam = features_[j]->lambda();
                if (lam == 0.0) continue;
                linear_predictor_.noalias() += lam * feature_matrix_.col(j);
            }
        } else {
            for (const auto& f : features_) {
                double lam = f->lambda();
                if (lam == 0.0) continue;
                for (int i = 0; i < num_points_; ++i)
                    linear_predictor_(i) += lam * f->eval(i);
            }
        }
        set_linear_predictor_normalizer();
    }

    /** Set linearPredictorNormalizer = max(linearPredictor). */
    void set_linear_predictor_normalizer() {
        if (num_points_ == 0) { linear_predictor_normalizer_ = 0.0; return; }
        linear_predictor_normalizer_ = linear_predictor_.maxCoeff();
    }

    /**
     * @brief Recompute density array and all feature model expectations.
     *
     * When bias weights are present:
     *   density[i] = bias[i] * exp(linearPredictor[i] - linearPredictorNormalizer)
     * Otherwise:
     *   density[i] = exp(linearPredictor[i] - linearPredictorNormalizer)
     *
     * densityNormalizer = sum(density)
     * feature_j.expectation = sum_i density[i]*feature_j(i) / densityNormalizer
     */
    void set_density() {
        // Default: refresh expectations for every feature (matches Java's
        // no-arg FeaturedSpace.setDensity() which builds a toUpdate list of
        // all active+non-generated features).  Used at init/load time.
        std::vector<int> all(features_.size());
        for (int j = 0; j < static_cast<int>(features_.size()); ++j) all[j] = j;
        set_density(all);
    }

    /**
     * @brief Density refresh that only recomputes expectations for the
     *        listed features (matches Java's setDensity(Feature[] toUpdate)).
     *
     * density[] and density_normalizer_ are always fully refreshed; only the
     * per-feature expectation step is restricted to `to_update`.
     */
    void set_density(const std::vector<int>& to_update) {
        // Eigen-vectorised exp() (SIMD, element-wise, no reduction order issue)
        density_ = (linear_predictor_.array() - linear_predictor_normalizer_).exp();
        // Apply bias weights if present
        if (bias_weights_.size() > 0)
            density_.array() *= bias_weights_.array();
        density_normalizer_ = density_.sum();
        if (density_normalizer_ > 0.0 && !to_update.empty()) {
            if (streaming_eval_) {
                set_expectations_streaming(to_update);
            } else if (feature_matrix_.size() > 0) {
                // BLAS-accelerated dot products for each updated feature.
                for (int j : to_update) {
                    const double sum = density_.dot(feature_matrix_.col(j));
                    features_[j]->set_expectation(sum / density_normalizer_);
                }
            } else {
                for (int j : to_update) {
                    auto& f = features_[j];
                    double sum = 0.0;
                    for (int i = 0; i < num_points_; ++i)
                        sum += density_(i) * f->eval(i);
                    f->set_expectation(sum / density_normalizer_);
                }
            }
        }
        entropy_ = -1.0;
    }

    /**
     * @brief Incrementally increase feature j's lambda by alpha.
     * Updates linearPredictor, linearPredictorNormalizer, and density.
     * Refreshes expectations for ALL features (used by external callers
     * that don't track a selective refresh set).
     */
    void increase_lambda(int feature_index, double alpha) {
        std::vector<int> all(features_.size());
        for (int j = 0; j < static_cast<int>(features_.size()); ++j) all[j] = j;
        increase_lambda(feature_index, alpha, all);
    }

    /**
     * @brief Selective-refresh variant matching Java's
     *        increaseLambda(h, alpha, updateFeatures).  Only the features
     *        listed in `to_update` get fresh expectations after the lp
     *        update; all others keep their stale values.
     */
    void increase_lambda(int feature_index, double alpha,
                         const std::vector<int>& to_update) {
        if (alpha == 0.0) return;
        auto& f = features_[feature_index];
        f->increase_lambda(alpha);
        if (streaming_eval_) {
            stream_update_lp_single(feature_index, alpha);
        } else if (feature_matrix_.size() > 0) {
            // Eigen-vectorised per-column LP update (element-wise, no reduction).
            linear_predictor_.noalias() += alpha * feature_matrix_.col(feature_index);
            // Preserve "only increase" normalizer semantics with sequential max.
            if (num_points_ > 0)
                linear_predictor_normalizer_ = std::max(linear_predictor_normalizer_,
                                                         linear_predictor_.maxCoeff());
        } else {
            for (int i = 0; i < num_points_; ++i) {
                linear_predictor_(i) += alpha * f->eval(i);
                if (linear_predictor_(i) > linear_predictor_normalizer_)
                    linear_predictor_normalizer_ = linear_predictor_(i);
            }
        }
        set_density(to_update);
    }

    /**
     * @brief Batch-update all lambdas simultaneously (refreshes ALL
     * expectations).
     */
    void increase_lambda(const std::vector<double>& alphas) {
        std::vector<int> all(features_.size());
        for (int j = 0; j < static_cast<int>(features_.size()); ++j) all[j] = j;
        increase_lambda(alphas, all);
    }

    /**
     * @brief Selective-refresh batch lambda update matching Java's
     *        increaseLambda(double[] alpha, Feature[] toUpdate).
     */
    void increase_lambda(const std::vector<double>& alphas,
                         const std::vector<int>& to_update) {
        if (alphas.size() != features_.size())
            throw std::invalid_argument("increase_lambda: alphas size mismatch");
        for (std::size_t j = 0; j < features_.size(); ++j) {
            if (alphas[j] == 0.0) continue;
            features_[j]->increase_lambda(alphas[j]);
        }
        if (streaming_eval_) {
            stream_update_lp_batch(alphas);
        } else if (feature_matrix_.size() > 0) {
            // Per-column Eigen accumulation preserves feature-by-feature order.
            for (std::size_t j = 0; j < features_.size(); ++j) {
                if (alphas[j] == 0.0) continue;
                linear_predictor_.noalias() += alphas[j] * feature_matrix_.col(static_cast<int>(j));
            }
            if (num_points_ > 0)
                linear_predictor_normalizer_ = linear_predictor_.maxCoeff();
        } else {
            for (std::size_t j = 0; j < features_.size(); ++j) {
                if (alphas[j] == 0.0) continue;
                for (int i = 0; i < num_points_; ++i)
                    linear_predictor_(i) += alphas[j] * features_[j]->eval(i);
            }
        }
        set_linear_predictor_normalizer();
        set_density(to_update);
    }

    // -----------------------------------------------------------------------
    // Accessors
    // -----------------------------------------------------------------------

    double get_density(int i) const { return density_(i); }
    double get_density_normalizer() const { return density_normalizer_; }
    double get_linear_predictor_normalizer() const { return linear_predictor_normalizer_; }
    int num_points() const { return num_points_; }
    int num_samples() const { return num_samples_; }
    int num_features() const { return static_cast<int>(features_.size()); }
    const std::vector<std::shared_ptr<Feature>>& features() const { return features_; }

    /// Whether bias weights are active (non-uniform background prior).
    bool has_bias() const { return bias_weights_.size() > 0; }

    /// Access the pre-materialised feature-value matrix (N×J).
    /// Returns a reference to the internal Eigen matrix used for vectorised
    /// hot-loop computation.  May be empty (0×0) if the FeaturedSpace was
    /// constructed with zero features or zero points.
    const Eigen::MatrixXd& feature_matrix() const { return feature_matrix_; }

    /// Access the density vector (length N) as an Eigen vector.
    const Eigen::VectorXd& density_vector() const { return density_; }

    /// Access the background provider (may be null if built via dense ctor).
    const BackgroundProvider* provider() const { return provider_.get(); }

    /**
     * @brief Enable streaming-evaluation mode for the hot loops.
     *
     * In streaming mode, set_linear_predictor(), set_density()'s expectation
     * step, and the two increase_lambda() overloads re-iterate `provider_`
     * via reset()+next_tile() and evaluate features through
     * Feature::eval_from_env(env) instead of Feature::eval(i).  This means
     * the provider is walked end-to-end on every hot-loop call (1–2 walks
     * per Sequential iteration), which is the runtime consumer the Phase
     * E.3 CachingBackgroundProvider is designed to amortise.
     *
     * The feature-values cache is NOT torn down — Sequential's direct
     * h.eval(i) call sites (newton_step_*, new_loss_change,
     * refresh_expectations_for, set_feature_expectation) keep working as
     * before.  Streaming therefore costs extra provider traffic but does
     * not reduce per-feature RAM yet; that is a later enhancement.
     *
     * Preconditions:
     *   - A non-null BackgroundProvider must have been supplied at
     *     construction time.
     *   - Every feature must have a valid var_index() (and var_index2()
     *     for ProductFeature), i.e. the features must have been built via
     *     a FeatureFactory or a wiring step that sets var indices.
     *
     * @throws std::runtime_error if either precondition is violated.
     */
    void set_streaming_eval(bool enabled) {
        if (enabled == streaming_eval_) return;
        if (enabled) {
            if (!provider_) {
                throw std::runtime_error(
                    "FeaturedSpace::set_streaming_eval: no BackgroundProvider");
            }
            for (std::size_t j = 0; j < features_.size(); ++j) {
                if (features_[j]->var_index() < 0) {
                    throw std::runtime_error(
                        "FeaturedSpace::set_streaming_eval: feature lacks "
                        "var_index (required for eval_from_env)");
                }
                if (const auto* prod =
                        dynamic_cast<const ProductFeature*>(features_[j].get())) {
                    if (prod->var_index2() < 0) {
                        throw std::runtime_error(
                            "FeaturedSpace::set_streaming_eval: ProductFeature "
                            "lacks var_index2 (required for eval_from_env)");
                    }
                }
            }
        }
        streaming_eval_ = enabled;
        if (enabled) {
            // Refresh lp/density through the streaming path so that the
            // initial state exactly matches what subsequent iterations will
            // see.  Eager vs streaming produce bit-identical lp/density
            // on in-range training data, so this is a no-op numerically;
            // we do it defensively to make any drift immediately visible.
            set_linear_predictor();
            set_density();
        }
    }

    /// Is streaming-eval mode active?  See set_streaming_eval().
    bool streaming_eval() const { return streaming_eval_; }

    /**
     * @brief Infer the number of raw environmental variables from the
     *        features' var_index() values.
     *
     * Returns max(var_index) + 1 across all features. Returns 0 if no
     * features have a var_index set (all -1), which indicates manually
     * created features that were not produced by FeatureGenerator.
     * In that case, the env-variable-count validation in projection
     * and response curves is skipped.
     */
    int num_env_variables() const {
        int max_idx = -1;
        for (const auto& f : features_) {
            max_idx = std::max(max_idx, f->var_index());
            if (const auto* product = dynamic_cast<const ProductFeature*>(f.get())) {
                max_idx = std::max(max_idx, product->var_index2());
            }
        }
        // -1 means no var_index was set → return 0 to skip validation
        return (max_idx >= 0) ? max_idx + 1 : 0;
    }

    /**
     * @brief Predict from a matrix of raw environmental variable values.
     *
     * Each row of env_matrix contains one value per environmental variable
     * (not one per feature).  Features are evaluated internally via
     * Feature::eval_from_env().
     *
     * Returns the "raw unnormalized" score:
     *   raw_unnormalized = exp(linearPredictor - linearPredictorNormalizer)
     *
     * Note: this is NOT the same as Java Maxent's "raw" output.
     * See predict_raw_java_from_env() for the Java-compatible raw score.
     *
     * @param env_matrix  [n_points × n_env_vars] matrix.
     * @return Vector of raw unnormalized prediction scores (one per point).
     */
    std::vector<double> predict_from_env(
            const std::vector<std::vector<double>>& env_matrix) const {
        if (env_matrix.empty()) return {};
        int n_env = num_env_variables();
        if (n_env > 0) {
            for (std::size_t i = 0; i < env_matrix.size(); ++i) {
                if (static_cast<int>(env_matrix[i].size()) != n_env) {
                    throw std::invalid_argument(
                        "predict_from_env: row " + std::to_string(i) +
                        " has " + std::to_string(env_matrix[i].size()) +
                        " columns, expected " + std::to_string(n_env));
                }
            }
        }
        int n_new = static_cast<int>(env_matrix.size());
        std::vector<double> scores(n_new, 0.0);
        for (int i = 0; i < n_new; ++i) {
            double lp = 0.0;
            for (int j = 0; j < num_features(); ++j)
                lp += features_[j]->lambda() * features_[j]->eval_from_env(env_matrix[i]);
            scores[i] = std::exp(lp - linear_predictor_normalizer_);
        }
        return scores;
    }

    /**
     * @brief Predict Java Maxent "raw" scores from raw environmental values.
     *
     * Java Maxent's "raw" output is the normalized probability:
     *   raw_java = exp(linearPredictor - linearPredictorNormalizer)
     *              / densityNormalizer
     *
     * This is identical to predict_from_env() divided by densityNormalizer,
     * and matches the output of the Java Maxent software and the dismo R
     * package.
     *
     * Following the Java implementation (Project.java, pred()), the result
     * is clamped to [0, 1]: values above 1.0 (which can occur in novel
     * environments outside the training range) are set to 1.0.
     *
     * @param env_matrix  [n_points × n_env_vars] matrix.
     * @return Vector of Java-compatible raw scores clamped to [0, 1].
     */
    std::vector<double> predict_raw_java_from_env(
            const std::vector<std::vector<double>>& env_matrix) const {
        auto scores = predict_from_env(env_matrix);
        if (density_normalizer_ > 0.0) {
            for (auto& s : scores) {
                s /= density_normalizer_;
                if (s > 1.0) s = 1.0;
            }
        }
        return scores;
    }

    // -----------------------------------------------------------------------
    // Loss / entropy / weights
    // -----------------------------------------------------------------------

    /**
     * @brief Negative log-likelihood loss.
     * loss = getN1() + log(densityNormalizer)
     * getN1() = -sum_j lambda_j * sampleExpectation_j + linearPredictorNormalizer
     */
    double get_loss() const {
        double n1 = linear_predictor_normalizer_;
        for (const auto& f : features_)
            n1 -= f->lambda() * f->sample_expectation();
        return n1 + std::log(density_normalizer_);
    }

    /** Sum of L1 regularization terms. */
    double get_l1_reg() const {
        double result = 0.0;
        for (const auto& f : features_)
            result += std::abs(f->lambda()) * f->sample_deviation();
        return result;
    }

    /** Shannon entropy H = -sum_i p_i * log(p_i), cached. */
    double get_entropy() const {
        if (entropy_ >= 0.0) return entropy_;
        entropy_ = 0.0;
        for (int i = 0; i < num_points_; ++i) {
            double p = density_(i) / density_normalizer_;
            if (p > 0.0) entropy_ += -p * std::log(p);
        }
        return entropy_;
    }

    /** Return normalized distribution weights (sum to 1). */
    std::vector<double> get_weights() const {
        std::vector<double> w(num_points_);
        for (int i = 0; i < num_points_; ++i)
            w[i] = density_(i) / density_normalizer_;
        return w;
    }

    // -----------------------------------------------------------------------
    // Sample expectations
    // -----------------------------------------------------------------------

    /**
     * @brief Compute sample_expectation and sample_deviation for each feature.
     *
     * sample_expectation = mean of feature over occurrence samples
     * sample_deviation   = beta * std / sqrt(n), clipped to an effective
     *                      minimum of `min_deviation * beta_multiplier`
     *                      (matches Java's `minDeviation *= betaMultiplier`
     *                      in FeaturedSpace.setSampleExpectations()).
     *
     * Ported from FeaturedSpace.setSampleExpectations() in Java
     * (density/FeaturedSpace.java:296..299, 469..490).
     */
    void set_sample_expectations(double beta_multiplier = 1.0,
                                 double min_deviation   = 0.001) {
        // Mirror Java FeaturedSpace.java:296..299:
        //     minDeviation = 0.001;
        //     if (params != null) minDeviation *= params.getBetamultiplier();
        // The caller passes the *unscaled* base floor (default 0.001); we
        // scale it here so the floor tracks beta_multiplier exactly.
        const double effective_min_deviation = min_deviation * beta_multiplier;
        for (auto& f : features_) {
            SampleInfo fi = get_sample_info(*f);
            Interval fi_interval(fi, beta_multiplier);

            const double mid = fi_interval.mid();
            f->set_sample_expectation(mid);

            double dev = fi_interval.dev();
            if (dev < effective_min_deviation) {
                // Java setSampleExpectations special case
                // (density/FeaturedSpace.java:480-486): a binary feature
                // saturated at sampleExpectation==1 falls back to a
                // sample-count-derived deviation rather than the floor.
                const int m = fi.sample_cnt;
                if (f->is_binary() && mid == 1.0 && m > 0) {
                    dev = 1.0 / (2.0 * static_cast<double>(m));
                } else {
                    dev = effective_min_deviation;
                }
            }
            f->set_sample_deviation(dev);
        }
    }

    // -----------------------------------------------------------------------
    // Training
    // -----------------------------------------------------------------------

    /**
     * @brief Run sequential coordinate-ascent MaxEnt optimization.
     *
     * Ported from density/Sequential.java (run(), doSequentialUpdate(),
     * goodAlpha(), reduceAlpha()).
     *
     * @param max_iter             Maximum iterations (default 500).
     * @param convergence_threshold  Stop when 20-iter loss drop < threshold.
     * @param beta_multiplier      Regularization multiplier (default 1.0).
     * @param min_deviation        Sample deviation floor (default 0.001).
     * @return TrainResult with loss, entropy, iterations, converged, lambdas.
     */
    TrainResult train(int    max_iter             = 500,
                      double convergence_threshold = 1e-5,
                      double beta_multiplier       = 1.0,
                      double min_deviation         = 0.001) {
        set_sample_expectations(beta_multiplier, min_deviation);
        entropy_ = -1.0;

        double prev_loss = std::numeric_limits<double>::infinity();
        bool   converged = false;
        int    iter      = 0;

        static constexpr int kConvergenceFreq = 20;

        for (iter = 0; iter < max_iter; ++iter) {
            for (int j = 0; j < static_cast<int>(features_.size()); ++j) {
                double alpha = good_alpha(*features_[j]);
                alpha = reduce_alpha(alpha, iter);
                if (alpha == 0.0) continue;
                increase_lambda(j, alpha);
            }

            if (iter % kConvergenceFreq == 0) {
                double loss = get_loss();
                if (prev_loss - loss < convergence_threshold) {
                    converged = true;
                    ++iter;
                    break;
                }
                prev_loss = loss;
            }
        }

        TrainResult result;
        result.loss       = get_loss();
        result.entropy    = get_entropy();
        result.iterations = iter;
        result.converged  = converged;
        result.lambdas.reserve(features_.size());
        for (const auto& f : features_)
            result.lambdas.push_back(f->lambda());
        return result;
    }

    // -----------------------------------------------------------------------
    // Prediction
    // -----------------------------------------------------------------------

    /**
     * @brief Predict raw Gibbs scores for new feature data.
     * @param feature_matrix  [n_pts x n_features] matrix of pre-evaluated values.
     * @return Exp(sum_j lambda_j * val_j - lpNormalizer) for each new point.
     */
    std::vector<double> predict(
            const std::vector<std::vector<double>>& feature_matrix) const {
        if (feature_matrix.empty()) return {};
        int n_new = static_cast<int>(feature_matrix.size());
        std::vector<double> scores(n_new, 0.0);
        for (int i = 0; i < n_new; ++i) {
            if (static_cast<int>(feature_matrix[i].size()) != num_features())
                throw std::invalid_argument(
                    "predict: feature_matrix row width does not match num_features");
            double lp = 0.0;
            for (int j = 0; j < num_features(); ++j)
                lp += features_[j]->lambda() * feature_matrix[i][j];
            scores[i] = std::exp(lp - linear_predictor_normalizer_);
        }
        return scores;
    }

    // -----------------------------------------------------------------------
    // Lambda file I/O
    // -----------------------------------------------------------------------

    /**
     * @brief Write trained lambdas to a CSV file.
     * Format: featureName, lambda, min, max  (then normalizer metadata lines).
     */
    void write_lambdas(const std::string& filename) const {
        std::ofstream out(filename);
        if (!out)
            throw std::runtime_error("write_lambdas: cannot open: " + filename);

        out << std::setprecision(17);
        for (const auto& f : features_) {
            out << f->name() << ", " << f->lambda() << ", "
                << f->min_val() << ", " << f->max_val() << "\n";
        }
        out << "linearPredictorNormalizer, " << linear_predictor_normalizer_ << "\n";
        out << "densityNormalizer, "          << density_normalizer_          << "\n";
        out << "numBackgroundPoints, "        << num_points_                  << "\n";
        out << "entropy, "                    << get_entropy() << "\n";
    }

    /**
     * @brief Read lambdas from a file and apply them to features by name.
     * Also restores linearPredictorNormalizer, densityNormalizer, and entropy.
     */
    void read_lambdas(const std::string& filename) {
        std::ifstream in(filename);
        if (!in)
            throw std::runtime_error("read_lambdas: cannot open: " + filename);

        std::string line;
        while (std::getline(in, line)) {
            if (line.empty()) continue;
            std::istringstream ss(line);
            std::string name;
            std::getline(ss, name, ',');
            while (!name.empty() && (name.front() == ' ' || name.front() == '\t'))
                name.erase(name.begin());
            while (!name.empty() && (name.back()  == ' ' || name.back()  == '\t'))
                name.pop_back();

            std::string val_str;
            std::getline(ss, val_str, ',');
            double val = std::stod(val_str);

            if      (name == "linearPredictorNormalizer") linear_predictor_normalizer_ = val;
            else if (name == "densityNormalizer")         density_normalizer_ = val;
            else if (name == "numBackgroundPoints")       { /* informational */ }
            else if (name == "entropy")                   entropy_ = val;
            else {
                for (auto& f : features_) {
                    if (f->name() == name) { f->set_lambda(val); break; }
                }
            }
        }

        // Save normalizer values loaded from the file before set_linear_predictor()
        // and set_density() overwrite them.  When the model is loaded from a
        // lambdas file without any background points in memory (num_points_ == 0),
        // set_density() would reset density_normalizer_ to 0 and entropy_ to -1.
        double saved_lpn     = linear_predictor_normalizer_;
        double saved_dn      = density_normalizer_;
        double saved_entropy = entropy_;

        set_linear_predictor();
        set_density();

        // Restore file-loaded values when there are no in-memory background
        // points; otherwise the in-memory computation is preferred.
        if (num_points_ == 0) {
            linear_predictor_normalizer_ = saved_lpn;
            density_normalizer_          = saved_dn;
        }
        // entropy_ is always restored: set_density() resets it to -1 (to be
        // lazily recomputed), but the value from the file is authoritative when
        // no density array is available, and matches what the file writer stored.
        entropy_ = saved_entropy;
    }

private:
    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    /**
     * @brief Validate and store bias weights.
     *
     * If the input vector is empty, bias_weights_ is left empty (size 0),
     * and set_density() will skip the bias multiplication (uniform prior).
     * If non-empty, the vector must have exactly num_points_ elements, and
     * all values must be non-negative.
     */
    void init_bias_weights(const std::vector<double>& bw) {
        if (bw.empty()) return;          // uniform (default)
        if (static_cast<int>(bw.size()) != num_points_)
            throw std::invalid_argument(
                "FeaturedSpace: bias_weights length ("
                + std::to_string(bw.size()) + ") != num_points ("
                + std::to_string(num_points_) + ")");
        for (std::size_t i = 0; i < bw.size(); ++i) {
            if (bw[i] < 0.0)
                throw std::invalid_argument(
                    "FeaturedSpace: bias_weights[" + std::to_string(i)
                    + "] is negative");
        }
        bias_weights_ = Eigen::Map<const Eigen::VectorXd>(bw.data(),
                                                           static_cast<int>(bw.size()));
    }

    /** Compute SampleInfo for a feature over the occurrence sample indices. */
    SampleInfo get_sample_info(const Feature& feat) const {
        double vmin =  std::numeric_limits<double>::infinity();
        double vmax = -std::numeric_limits<double>::infinity();
        for (int i = 0; i < num_points_; ++i) {
            double v = feat.eval(i);
            if (v < vmin) vmin = v;
            if (v > vmax) vmax = v;
        }

        double avg = 0.0, std_val = 0.0;
        int cnt = static_cast<int>(sample_indices_.size());
        for (int idx : sample_indices_) {
            double v = feat.eval(idx);
            avg     += v;
            std_val += v * v;
        }

        if (cnt == 0) {
            avg     = (vmin + vmax) / 2.0;
            std_val = 0.5 * (vmax - vmin);
        } else if (cnt == 1) {
            avg     /= cnt;
            std_val  = 0.5 * (vmax - vmin);
        } else {
            avg /= cnt;
            double var = std_val / cnt - avg * avg;
            if (var < 0.0) var = 0.0;
            std_val = std::sqrt(var * cnt / (cnt - 1));
            double half_range = 0.5 * (vmax - vmin);
            if (std_val > half_range) std_val = half_range;
        }

        return SampleInfo(avg, std_val, vmin, vmax, cnt);
    }

    /**
     * @brief Pre-materialise all feature evaluations into a dense matrix.
     *
     * Populates feature_matrix_ (num_points × num_features) by calling
     * Feature::eval(i) once for every (point, feature) pair.  Subsequent
     * hot-loop operations use the matrix directly, eliminating virtual
     * dispatch and enabling Eigen SIMD vectorisation.
     *
     * Cost: O(N × J) time and memory.  For N = 10 000 and J = 800 this
     * is ~61 MB — manageable.  See OPTIMIZATION_ANALYSIS.md §1.2.
     */
    void build_feature_matrix() {
        const int nf = static_cast<int>(features_.size());
        if (nf == 0 || num_points_ == 0) {
            feature_matrix_.resize(0, 0);
            return;
        }
        feature_matrix_.resize(num_points_, nf);
        for (int j = 0; j < nf; ++j)
            for (int i = 0; i < num_points_; ++i)
                feature_matrix_(i, j) = features_[j]->eval(i);
    }

    /**
     * @brief Compute the "good alpha" coordinate-ascent step for feature feat.
     * Ported from Sequential.goodAlpha() in the Java code.
     *
     * Uses sample expectation (N1), model expectation (W1), and regularization
     * penalty (beta1 = sample_deviation) to find the optimal lambda increment.
     */
    double good_alpha(const Feature& feat) const {
        double N1 = feat.sample_expectation();
        double W1 = feat.expectation();
        double W0 = 1.0 - W1;
        double N0 = 1.0 - N1;

        if (W0 < kEps || W1 < kEps) return 0.0;

        double lambda = feat.lambda();
        double beta1  = feat.sample_deviation();

        // Try positive direction
        if (N1 - beta1 > kEps) {
            double cand = std::log((N1 - beta1) * W0 / ((N0 + beta1) * W1));
            if (std::isfinite(cand) && cand + lambda > 0.0) return cand;
        }

        // Try negative direction
        if (N0 - beta1 > kEps) {
            double cand = std::log((N1 + beta1) * W0 / ((N0 - beta1) * W1));
            if (std::isfinite(cand) && cand + lambda < 0.0) return cand;
        }

        // Default: zero out lambda
        return -lambda;
    }

    /**
     * @brief Scale down alpha in early iterations for numerical stability.
     * Ported from Sequential.reduceAlpha() in the Java code.
     */
    static double reduce_alpha(double alpha, int iteration) {
        if (iteration < 10) return alpha / 50.0;
        if (iteration < 20) return alpha / 10.0;
        if (iteration < 50) return alpha /  3.0;
        return alpha;
    }

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------
    int num_points_;   ///< Number of background points
    int num_samples_;  ///< Number of occurrence samples

    std::vector<int>                      sample_indices_; ///< 0-based sample locations
    std::vector<std::shared_ptr<Feature>> features_;       ///< Feature objects

    Eigen::VectorXd density_;          ///< Unnormalized Gibbs density per point
    Eigen::VectorXd linear_predictor_; ///< Lambda-weighted feature sum per point

    /// Optional per-point bias weights for non-uniform background prior.
    /// Empty (size 0) means uniform bias (standard MaxEnt).
    /// When present, density_[i] = bias_weights_[i] * exp(lp[i] - lpn).
    Eigen::VectorXd bias_weights_;

    /// Pre-materialised feature-value matrix (num_points × num_features).
    /// Eliminates virtual Feature::eval(i) calls in the hot loops and enables
    /// Eigen SIMD vectorisation.  Built once at construction time.
    Eigen::MatrixXd feature_matrix_;

    double linear_predictor_normalizer_ = 0.0; ///< max(linearPredictor)
    double density_normalizer_          = 0.0; ///< sum(density) – Z
    mutable double entropy_                     = -1.0; ///< Cached entropy (-1 = invalid)

    /// Streaming background provider (null when built via the dense ctor).
    std::unique_ptr<BackgroundProvider> provider_;

    /// When true, hot loops re-iterate provider_ via reset()+next_tile()
    /// and evaluate features through eval_from_env(env) instead of eval(i).
    /// See set_streaming_eval().
    bool streaming_eval_ = false;

    // -----------------------------------------------------------------------
    // Streaming-eval helpers (require provider_ != nullptr and every feature
    // to have a valid var_index(); guarded by set_streaming_eval()).
    //
    // All four helpers share the identical per-tile iteration pattern used
    // by the streaming ctor: reset() → loop next_tile() → break on empty
    // sentinel. They differ only in what they accumulate per row.
    // -----------------------------------------------------------------------

    /**
     * @brief Evaluate every feature on a single row of tile data.
     *
     * @param tile     Current tile (rows × num_layers).
     * @param r        Row index within tile.
     * @param env_buf  Scratch vector of size num_layers reused across calls.
     * @param out      Output vector of size num_features, filled in place.
     */
    void eval_row_features(const TileMatrix& tile,
                           int r,
                           std::vector<double>& env_buf,
                           std::vector<double>& out) const {
        for (int c = 0; c < tile.cols(); ++c)
            env_buf[c] = tile(r, c);
        for (std::size_t j = 0; j < features_.size(); ++j)
            out[j] = features_[j]->eval_from_env(env_buf);
    }

    /**
     * @brief Streaming variant of set_linear_predictor().
     *
     * Contract: provider_ must be non-null (guarded by set_streaming_eval()).
     * Produces bit-identical lp[] to the eager path on in-range training
     * data because the per-point feature-contribution summation order
     * (features 0..n-1) is preserved.
     */
    void set_linear_predictor_streaming() {
        linear_predictor_.setZero();
        const int nf = static_cast<int>(features_.size());
        std::vector<double> lambdas(nf);
        for (int j = 0; j < nf; ++j) lambdas[j] = features_[j]->lambda();

        std::vector<double> env_buf(provider_->num_layers(), 0.0);
        std::vector<double> fvals(nf, 0.0);

        provider_->reset();
        int offset = 0;
        while (true) {
            TileMatrix tile = provider_->next_tile();
            if (tile.rows() == 0) break;
            validate_tile(tile, offset);
            for (int r = 0; r < tile.rows(); ++r) {
                eval_row_features(tile, r, env_buf, fvals);
                double lp = 0.0;
                for (int j = 0; j < nf; ++j)
                    lp += lambdas[j] * fvals[j];
                linear_predictor_(offset + r) = lp;
            }
            offset += static_cast<int>(tile.rows());
        }
        if (offset != num_points_) {
            throw std::runtime_error(
                "FeaturedSpace (streaming): provider emitted fewer rows "
                "than declared by num_points()");
        }
        set_linear_predictor_normalizer();
    }

    /**
     * @brief Streaming variant of set_density()'s expectation step.
     *
     * density[] and density_normalizer_ are already populated by the
     * eager density compute (which needs no feature eval).  Here we
     * only recompute per-feature expectation values by streaming tiles.
     */
    void set_expectations_streaming() {
        const int nf = static_cast<int>(features_.size());
        std::vector<int> all(nf);
        for (int j = 0; j < nf; ++j) all[j] = j;
        set_expectations_streaming(all);
    }

    /**
     * @brief Selective-refresh streaming variant.  Same per-tile pass as
     *        the all-features version, but only writes back expectations
     *        for the features listed in `to_update`.
     */
    void set_expectations_streaming(const std::vector<int>& to_update) {
        if (to_update.empty()) return;
        const int nf = static_cast<int>(features_.size());
        std::vector<double> sums(nf, 0.0);
        std::vector<double> env_buf(provider_->num_layers(), 0.0);
        std::vector<double> fvals(nf, 0.0);

        provider_->reset();
        int offset = 0;
        while (true) {
            TileMatrix tile = provider_->next_tile();
            if (tile.rows() == 0) break;
            validate_tile(tile, offset);
            for (int r = 0; r < tile.rows(); ++r) {
                eval_row_features(tile, r, env_buf, fvals);
                const double d = density_(offset + r);
                for (int j : to_update)
                    sums[j] += d * fvals[j];
            }
            offset += static_cast<int>(tile.rows());
        }
        if (offset != num_points_) {
            throw std::runtime_error(
                "FeaturedSpace (streaming): provider emitted fewer rows "
                "than declared by num_points()");
        }
        for (int j : to_update)
            features_[j]->set_expectation(sums[j] / density_normalizer_);
    }

    /**
     * @brief Streaming variant of the per-feature lp-update loop in
     *        increase_lambda(int, double).
     */
    void stream_update_lp_single(int feature_index, double alpha) {
        std::vector<double> env_buf(provider_->num_layers(), 0.0);
        provider_->reset();
        int offset = 0;
        while (true) {
            TileMatrix tile = provider_->next_tile();
            if (tile.rows() == 0) break;
            validate_tile(tile, offset);
            for (int r = 0; r < tile.rows(); ++r) {
                for (int c = 0; c < tile.cols(); ++c)
                    env_buf[c] = tile(r, c);
                const double v =
                    features_[feature_index]->eval_from_env(env_buf);
                linear_predictor_(offset + r) += alpha * v;
                if (linear_predictor_(offset + r) > linear_predictor_normalizer_)
                    linear_predictor_normalizer_ = linear_predictor_(offset + r);
            }
            offset += static_cast<int>(tile.rows());
        }
        if (offset != num_points_) {
            throw std::runtime_error(
                "FeaturedSpace (streaming): provider emitted fewer rows "
                "than declared by num_points()");
        }
    }

    /**
     * @brief Streaming variant of the per-feature lp-update loop in
     *        increase_lambda(const std::vector<double>&).
     *
     * Iterates feature-outer / point-inner (one provider pass per active
     * feature) so that per-point addition order exactly matches the eager
     * path's feature-by-feature accumulation.  This is what preserves
     * bit-identity with the eager path: summing `alpha_0 * v_0 + alpha_1
     * * v_1 + ...` in a row-local accumulator would reassociate and drift.
     * The redundant provider passes are what the Phase E.3 cache amortises.
     */
    void stream_update_lp_batch(const std::vector<double>& alphas) {
        const int nf = static_cast<int>(features_.size());
        for (int j = 0; j < nf; ++j) {
            if (alphas[j] == 0.0) continue;
            stream_update_lp_single_no_norm(j, alphas[j]);
        }
    }

    /// Streaming lp-update for feature j without touching lp_normalizer_.
    /// Used by stream_update_lp_batch(); the caller is responsible for
    /// refreshing lp_normalizer_ via set_linear_predictor_normalizer().
    void stream_update_lp_single_no_norm(int feature_index, double alpha) {
        std::vector<double> env_buf(provider_->num_layers(), 0.0);
        provider_->reset();
        int offset = 0;
        while (true) {
            TileMatrix tile = provider_->next_tile();
            if (tile.rows() == 0) break;
            validate_tile(tile, offset);
            for (int r = 0; r < tile.rows(); ++r) {
                for (int c = 0; c < tile.cols(); ++c)
                    env_buf[c] = tile(r, c);
                const double v =
                    features_[feature_index]->eval_from_env(env_buf);
                linear_predictor_(offset + r) += alpha * v;
            }
            offset += static_cast<int>(tile.rows());
        }
        if (offset != num_points_) {
            throw std::runtime_error(
                "FeaturedSpace (streaming): provider emitted fewer rows "
                "than declared by num_points()");
        }
    }

    /// Shared tile-shape validation for all streaming helpers.
    void validate_tile(const TileMatrix& tile, int offset) const {
        if (tile.cols() != provider_->num_layers()) {
            throw std::runtime_error(
                "FeaturedSpace (streaming): tile col count "
                "disagrees with provider->num_layers()");
        }
        if (offset + static_cast<int>(tile.rows()) > num_points_) {
            throw std::runtime_error(
                "FeaturedSpace (streaming): provider emitted more rows "
                "than declared by num_points()");
        }
    }

    static constexpr double kEps = 1e-6;
};

} // namespace maxent

#endif // MAXENT_FEATURED_SPACE_HPP
