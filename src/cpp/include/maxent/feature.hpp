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

#ifndef MAXENT_FEATURE_HPP
#define MAXENT_FEATURE_HPP

#include <string>
#include <vector>
#include <memory>
#include <stdexcept>
#include <algorithm>
#include <cmath>

namespace maxent {

/**
 * @brief Abstract base class for Maxent feature functions
 *
 * Features transform raw environmental variable values into predictors
 * used by the Maxent model. All features share a common interface for
 * evaluation, naming, and model parameters.
 *
 * Ported from density/Feature.java in the original Java Maxent code.
 */
class Feature {
public:
    /**
     * @brief Evaluate the feature at a given sample index
     * @param i Index into the underlying data vector (0-based)
     * @return Feature value at that index
     */
    virtual double eval(int i) const = 0;

    /**
     * @brief Get the feature type name (e.g., "linear", "hinge")
     * @return Type string
     */
    virtual std::string type() const = 0;

    /**
     * @brief Is this feature a binary (0/1-valued) indicator?
     *
     * Mirrors density/Feature.java:96 isBinary() — default false.
     * Overridden to true by ThresholdFeature (mirrors
     * density/ThresholdFeature.java:41) and by any other 0/1 indicator.
     *
     * Sequential uses this flag to (a) route through goodAlpha instead of
     * the newton step in doSequentialUpdate (Sequential.java:427) and
     * (b) skip the feature entirely in the parallel update direction
     * (Sequential.java:250).
     */
    virtual bool is_binary() const { return false; }

    /**
     * @brief Virtual destructor
     */
    virtual ~Feature() = default;

    /**
     * @brief Get feature name
     * @return Feature name
     */
    const std::string& name() const { return name_; }

    /**
     * @brief Get regularization weight (lambda)
     * @return Lambda value
     */
    double lambda() const { return lambda_; }

    /**
     * @brief Set regularization weight (lambda)
     * @param l New lambda value
     */
    void set_lambda(double l) { lambda_ = l; }

    /**
     * @brief Get minimum value
     * @return Minimum of the underlying data
     */
    double min_val() const { return min_; }

    /**
     * @brief Get maximum value
     * @return Maximum of the underlying data
     */
    double max_val() const { return max_; }

    /**
     * @brief Get number of data points
     * @return Size of the underlying data vector
     */
    int size() const {
        return values_ ? static_cast<int>(values_->size()) : 0;
    }

    /**
     * @brief Get the index of the primary source environmental variable.
     *
     * Set by FeatureGenerator during feature generation.  Used by
     * projection and response-curve code to map features back to the
     * raw environmental-variable grids.
     *
     * @return 0-based variable index, or -1 if not set.
     */
    int var_index() const { return var_index_; }

    /**
     * @brief Set the primary source variable index.
     * @param idx 0-based index into the environmental-variable list.
     */
    void set_var_index(int idx) { var_index_ = idx; }

    /**
     * @brief Evaluate the feature from a vector of raw environmental
     *        variable values (one per variable, **not** one per feature).
     *
     * This is used during projection / response-curve generation where
     * the caller has a vector of raw env values for a single cell and
     * needs the transformed feature value.
     *
     * Subclasses override this to compute the same transformation as
     * eval(int i), but using raw values instead of an index into the
     * stored data vector.
     *
     * @param env_values  Raw environmental variable values, indexed by
     *                    var_index().
     * @return The transformed feature value.
     * @throws std::runtime_error if var_index() has not been set (-1).
     */
    virtual double eval_from_env(const std::vector<double>& env_values) const = 0;

    /**
     * @brief Get model expectation (weighted mean under current distribution)
     * @return Model expectation
     */
    double expectation() const { return expectation_; }

    /**
     * @brief Set model expectation
     * @param e New expectation value
     */
    void set_expectation(double e) { expectation_ = e; }

    /**
     * @brief Get sample expectation (mean over occurrence samples)
     * @return Sample expectation
     */
    double sample_expectation() const { return sample_expectation_; }

    /**
     * @brief Set sample expectation
     * @param e New value
     */
    void set_sample_expectation(double e) { sample_expectation_ = e; }

    /**
     * @brief Get sample deviation (regularization coefficient)
     * @return Sample deviation
     */
    double sample_deviation() const { return sample_deviation_; }

    /**
     * @brief Set sample deviation
     * @param d New value
     */
    void set_sample_deviation(double d) { sample_deviation_ = d; }

    /**
     * @brief Increase lambda by delta
     * @param delta Amount to add to lambda
     */
    void increase_lambda(double delta) { lambda_ += delta; }

protected:
    std::string name_;                             ///< Feature name/identifier
    double lambda_ = 0.0;                          ///< Regularization weight
    double min_ = 0.0;                             ///< Data minimum
    double max_ = 0.0;                             ///< Data maximum
    std::shared_ptr<std::vector<double>> values_;  ///< Underlying sample values
    int var_index_ = -1;                           ///< Primary source variable index

    double expectation_ = 0.0;        ///< Model expectation (current distribution)
    double sample_expectation_ = 0.0; ///< Sample expectation (occurrence points)
    double sample_deviation_ = 0.0;   ///< Regularization term
};

/**
 * @brief Linear (normalized) feature
 *
 * Evaluates to (values[i] - min) / (max - min).
 * Returns 0 when min == max to handle the degenerate case.
 *
 * Ported from density/LinearFeature.java.
 */
class LinearFeature : public Feature {
public:
    /**
     * @brief Construct a LinearFeature
     * @param values Shared pointer to data vector
     * @param name Feature name
     * @param min_val Minimum value for normalization
     * @param max_val Maximum value for normalization
     */
    LinearFeature(std::shared_ptr<std::vector<double>> values,
                  const std::string& name,
                  double min_val,
                  double max_val)
    {
        values_ = values;
        name_   = name;
        min_    = min_val;
        max_    = max_val;
    }

    double eval(int i) const override {
        if (min_ == max_) return 0.0;
        return ((*values_)[i] - min_) / (max_ - min_);
    }

    double eval_from_env(const std::vector<double>& env_values) const override {
        if (var_index_ < 0)
            throw std::runtime_error("LinearFeature::eval_from_env: var_index not set");
        if (min_ == max_) return 0.0;
        double v = (env_values[var_index_] - min_) / (max_ - min_);
        if (v < 0.0) v = 0.0;
        if (v > 1.0) v = 1.0;
        return v;
    }

    std::string type() const override { return "linear"; }
};

/**
 * @brief Quadratic feature
 *
 * Evaluates to linear_val^2 where linear_val = (values[i] - min) / (max - min).
 *
 * Ported from density/SquareFeature.java.
 */
class QuadraticFeature : public Feature {
public:
    /**
     * @brief Construct a QuadraticFeature
     * @param values Shared pointer to data vector
     * @param name Feature name
     * @param min_val Minimum value for normalization
     * @param max_val Maximum value for normalization
     */
    QuadraticFeature(std::shared_ptr<std::vector<double>> values,
                     const std::string& name,
                     double min_val,
                     double max_val)
    {
        values_ = values;
        name_   = name;
        min_    = min_val;
        max_    = max_val;
    }

    double eval(int i) const override {
        if (min_ == max_) return 0.0;
        double linear_val = ((*values_)[i] - min_) / (max_ - min_);
        return linear_val * linear_val;
    }

    double eval_from_env(const std::vector<double>& env_values) const override {
        if (var_index_ < 0)
            throw std::runtime_error("QuadraticFeature::eval_from_env: var_index not set");
        if (min_ == max_) return 0.0;
        double linear_val = (env_values[var_index_] - min_) / (max_ - min_);
        if (linear_val < 0.0) linear_val = 0.0;
        if (linear_val > 1.0) linear_val = 1.0;
        return linear_val * linear_val;
    }

    std::string type() const override { return "quadratic"; }
};

/**
 * @brief Product (interaction) feature between two environmental variables
 *
 * Evaluates to values1[i] * values2[i] (both normalized).
 *
 * Ported from density/ProductFeature.java.
 */
class ProductFeature : public Feature {
public:
    /**
     * @brief Construct a ProductFeature
     * @param values1 Shared pointer to first data vector
     * @param values2 Shared pointer to second data vector
     * @param name Feature name
     * @param min1 Minimum of first variable
     * @param max1 Maximum of first variable
     * @param min2 Minimum of second variable
     * @param max2 Maximum of second variable
     */
    ProductFeature(std::shared_ptr<std::vector<double>> values1,
                   std::shared_ptr<std::vector<double>> values2,
                   const std::string& name,
                   double min1, double max1,
                   double min2, double max2)
        : values2_(values2), min2_(min2), max2_(max2)
    {
        if (values1->size() != values2->size()) {
            throw std::invalid_argument(
                "ProductFeature: both value vectors must have the same size");
        }
        values_ = values1;
        name_   = name;
        min_    = min1;
        max_    = max1;
    }

    double eval(int i) const override {
        double v1 = (min_ == max_) ? 0.0 : ((*values_)[i] - min_) / (max_ - min_);
        double v2 = (min2_ == max2_) ? 0.0 : ((*values2_)[i] - min2_) / (max2_ - min2_);
        return v1 * v2;
    }

    double eval_from_env(const std::vector<double>& env_values) const override {
        if (var_index_ < 0 || var_index2_ < 0)
            throw std::runtime_error("ProductFeature::eval_from_env: var_index not set");
        double v1 = (min_ == max_) ? 0.0 : (env_values[var_index_] - min_) / (max_ - min_);
        double v2 = (min2_ == max2_) ? 0.0 : (env_values[var_index2_] - min2_) / (max2_ - min2_);
        if (v1 < 0.0) v1 = 0.0;
        if (v1 > 1.0) v1 = 1.0;
        if (v2 < 0.0) v2 = 0.0;
        if (v2 > 1.0) v2 = 1.0;
        return v1 * v2;
    }

    std::string type() const override { return "product"; }

    /**
     * @brief Get index of the second source variable.
     * @return 0-based index, or -1 if not set.
     */
    int var_index2() const { return var_index2_; }

    /**
     * @brief Set the second source variable index.
     */
    void set_var_index2(int idx) { var_index2_ = idx; }

private:
    std::shared_ptr<std::vector<double>> values2_; ///< Second variable values
    double min2_ = 0.0;                            ///< Min of second variable
    double max2_ = 0.0;                            ///< Max of second variable
    int var_index2_ = -1;                           ///< Second source variable index
};

/**
 * @brief Threshold (binary step) feature
 *
 * Returns 1.0 if values[i] >= threshold, 0.0 otherwise.
 *
 * Ported from density/ThresholdFeature.java (uses non-strict >= comparison,
 * matching Java Maxent's ThresholdGrid.eval()).
 */
class ThresholdFeature : public Feature {
public:
    /**
     * @brief Construct a ThresholdFeature
     * @param values Shared pointer to data vector
     * @param name Feature name
     * @param threshold The threshold value
     */
    ThresholdFeature(std::shared_ptr<std::vector<double>> values,
                     const std::string& name,
                     double threshold)
        : threshold_(threshold)
    {
        values_ = values;
        name_   = name;
        if (!values->empty()) {
            min_ = *std::min_element(values->begin(), values->end());
            max_ = *std::max_element(values->begin(), values->end());
        }
    }

    double eval(int i) const override {
        return ((*values_)[i] >= threshold_) ? 1.0 : 0.0;
    }

    double eval_from_env(const std::vector<double>& env_values) const override {
        if (var_index_ < 0)
            throw std::runtime_error("ThresholdFeature::eval_from_env: var_index not set");
        return (env_values[var_index_] >= threshold_) ? 1.0 : 0.0;
    }

    std::string type() const override { return "threshold"; }

    // Threshold features are 0/1 binary indicators — mirrors
    // density/ThresholdFeature.java:41 isBinary() => true.
    bool is_binary() const override { return true; }

    /**
     * @brief Get the threshold value
     * @return Threshold
     */
    double threshold() const { return threshold_; }

private:
    double threshold_; ///< The step threshold
};

/**
 * @brief Hinge feature (piecewise linear, forward or reverse)
 *
 * Forward hinge: 0 below min_knot, then rises linearly to 1 at max_knot.
 *   eval(i) = (values[i] > min_knot) ? (values[i] - min_knot) / (max_knot - min_knot) : 0.0
 *
 * Reverse hinge: 1 below min_knot, then falls linearly to 0 at max_knot.
 *   eval(i) = (values[i] < max_knot) ? (max_knot - values[i]) / (max_knot - min_knot) : 0.0
 *
 * Ported from density/HingeFeature.java.
 */
class HingeFeature : public Feature {
public:
    /**
     * @brief Construct a HingeFeature
     * @param values Shared pointer to data vector
     * @param name Feature name
     * @param min_knot Lower knot of the hinge
     * @param max_knot Upper knot of the hinge
     * @param reverse If true, use reverse hinge; if false, use forward hinge
     */
    HingeFeature(std::shared_ptr<std::vector<double>> values,
                 const std::string& name,
                 double min_knot,
                 double max_knot,
                 bool reverse = false)
        : min_knot_(min_knot), max_knot_(max_knot), reverse_(reverse)
    {
        if (min_knot_ >= max_knot_) {
            throw std::invalid_argument(
                "HingeFeature: min_knot must be strictly less than max_knot");
        }
        values_ = values;
        name_   = name;
        min_    = min_knot;
        max_    = max_knot;
    }

    double eval(int i) const override {
        double v = (*values_)[i];
        double range = max_knot_ - min_knot_;
        if (reverse_) {
            return (v < max_knot_) ? (max_knot_ - v) / range : 0.0;
        } else {
            return (v > min_knot_) ? (v - min_knot_) / range : 0.0;
        }
    }

    double eval_from_env(const std::vector<double>& env_values) const override {
        if (var_index_ < 0)
            throw std::runtime_error("HingeFeature::eval_from_env: var_index not set");
        double v = env_values[var_index_];
        double range = max_knot_ - min_knot_;
        if (reverse_) {
            if (v >= max_knot_) return 0.0;
            double val = (max_knot_ - v) / range;
            return (val > 1.0) ? 1.0 : val;
        } else {
            if (v <= min_knot_) return 0.0;
            double val = (v - min_knot_) / range;
            return (val > 1.0) ? 1.0 : val;
        }
    }

    std::string type() const override { return reverse_ ? "reverse_hinge" : "hinge"; }

    /**
     * @brief Get the lower knot
     * @return min_knot
     */
    double min_knot() const { return min_knot_; }

    /**
     * @brief Get the upper knot
     * @return max_knot
     */
    double max_knot() const { return max_knot_; }

    /**
     * @brief Check if this is a reverse hinge
     * @return true for reverse hinge
     */
    bool is_reverse() const { return reverse_; }

private:
    double min_knot_; ///< Lower knot position
    double max_knot_; ///< Upper knot position
    bool   reverse_;  ///< Forward or reverse hinge
};

/**
 * @brief Configuration for FeatureGenerator
 */
struct FeatureConfig {
    bool linear    = true;  ///< Generate linear features
    bool quadratic = true;  ///< Generate quadratic features
    bool product   = true;  ///< Generate product (interaction) features
    bool threshold = true;  ///< Generate threshold features
    bool hinge     = true;  ///< Generate hinge features (forward + reverse)
    int  n_thresholds = 10; ///< Number of threshold knots
    int  n_hinges     = 10; ///< Number of hinge knots per variable
};

/**
 * @brief Factory class that generates features from environmental variable data
 *
 * FeatureGenerator takes one or more vectors of environmental variable values
 * and produces all requested feature types. Configurable via FeatureConfig.
 */
class FeatureGenerator {
public:
    /// Alias for backward compatibility
    using Config = FeatureConfig;

    /**
     * @brief Generate all configured feature types from a set of variable vectors
     *
     * @param data List of (name, values) pairs, one per environmental variable
     * @param cfg Configuration flags
     * @return Vector of unique_ptr to generated Feature objects
     */
    static std::vector<std::unique_ptr<Feature>> generate(
        const std::vector<std::pair<std::string, std::vector<double>>>& data,
        const FeatureConfig& cfg = FeatureConfig())
    {
        std::vector<std::unique_ptr<Feature>> features;

        // Wrap each variable in a shared_ptr
        std::vector<std::shared_ptr<std::vector<double>>> shared_data;
        std::vector<double> mins, maxs;
        shared_data.reserve(data.size());
        mins.reserve(data.size());
        maxs.reserve(data.size());

        for (const auto& [var_name, values] : data) {
            auto sp = std::make_shared<std::vector<double>>(values);
            shared_data.push_back(sp);

            double vmin = values.empty() ? 0.0
                        : *std::min_element(values.begin(), values.end());
            double vmax = values.empty() ? 0.0
                        : *std::max_element(values.begin(), values.end());
            mins.push_back(vmin);
            maxs.push_back(vmax);
        }

        for (std::size_t i = 0; i < data.size(); ++i) {
            const std::string& vname = data[i].first;
            auto& sp = shared_data[i];
            double vmin = mins[i];
            double vmax = maxs[i];
            int vidx = static_cast<int>(i);

            // Linear
            if (cfg.linear) {
                auto f = std::make_unique<LinearFeature>(sp, vname + "_linear", vmin, vmax);
                f->set_var_index(vidx);
                features.push_back(std::move(f));
            }

            // Quadratic
            if (cfg.quadratic) {
                auto f = std::make_unique<QuadraticFeature>(sp, vname + "_quadratic", vmin, vmax);
                f->set_var_index(vidx);
                features.push_back(std::move(f));
            }

            // Threshold
            if (cfg.threshold && cfg.n_thresholds > 0 && vmin < vmax) {
                for (int k = 1; k <= cfg.n_thresholds; ++k) {
                    double t = vmin + (vmax - vmin) * k / (cfg.n_thresholds + 1.0);
                    auto f = std::make_unique<ThresholdFeature>(
                            sp, vname + "_threshold_" + std::to_string(k), t);
                    f->set_var_index(vidx);
                    features.push_back(std::move(f));
                }
            }

            // Hinge (forward + reverse)
            if (cfg.hinge && cfg.n_hinges > 0 && vmin < vmax) {
                for (int k = 1; k <= cfg.n_hinges; ++k) {
                    double knot = vmin + (vmax - vmin) * k / (cfg.n_hinges + 1.0);
                    // Forward hinge: [knot, vmax]
                    auto fwd = std::make_unique<HingeFeature>(
                            sp, vname + "_hinge_fwd_" + std::to_string(k),
                            knot, vmax, false);
                    fwd->set_var_index(vidx);
                    features.push_back(std::move(fwd));
                    // Reverse hinge: [vmin, knot]
                    auto rev = std::make_unique<HingeFeature>(
                            sp, vname + "_hinge_rev_" + std::to_string(k),
                            vmin, knot, true);
                    rev->set_var_index(vidx);
                    features.push_back(std::move(rev));
                }
            }
        }

        // Product features (all pairs)
        if (cfg.product && data.size() >= 2) {
            for (std::size_t i = 0; i < data.size(); ++i) {
                for (std::size_t j = i + 1; j < data.size(); ++j) {
                    std::string pname = data[i].first + "_x_" + data[j].first;
                    auto f = std::make_unique<ProductFeature>(
                            shared_data[i], shared_data[j], pname,
                            mins[i], maxs[i], mins[j], maxs[j]);
                    f->set_var_index(static_cast<int>(i));
                    f->set_var_index2(static_cast<int>(j));
                    features.push_back(std::move(f));
                }
            }
        }

        return features;
    }
};

} // namespace maxent

#endif // MAXENT_FEATURE_HPP
