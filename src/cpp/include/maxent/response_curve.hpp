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

#ifndef MAXENT_RESPONSE_CURVE_HPP
#define MAXENT_RESPONSE_CURVE_HPP

#include "featured_space.hpp"
#include "grid.hpp"

#include <vector>
#include <string>
#include <algorithm>
#include <stdexcept>
#include <cmath>

namespace maxent {

// ============================================================================
// ResponsePoint – a single point on a response curve
// ============================================================================

/**
 * @brief A (value, prediction) pair on a response curve.
 */
struct ResponsePoint {
    double value;       ///< Environmental variable value
    double prediction;  ///< Model prediction at that value
};

// ============================================================================
// ResponseCurve – marginal and independent response curve generation
// Ported from density/ResponsePlot.java (data generation only, no GUI)
// ============================================================================

/**
 * @brief Generate response-curve data for Maxent model interpretation.
 *
 * Two types of response curves are supported:
 *
 * - **Marginal**: vary one variable while holding all others at their mean
 *   values across the training background.
 * - **Independent**: vary one variable while all other features are set to
 *   zero (shows the effect of the variable alone in the model).
 */
class ResponseCurve {
public:

    /**
     * @brief Generate a marginal response curve for a single variable.
     *
     * The target variable is varied from its minimum to its maximum in
     * `n_steps` equal increments, while all other variables are held at
     * their mean value across the supplied grids.
     *
     * @param model          Trained FeaturedSpace.
     * @param env_grids      Environmental variable grids.
     * @param feature_names  Names matching env_grids order.
     * @param var_index      Index of the variable to vary.
     * @param n_steps        Number of steps across the variable range.
     * @return Vector of ResponsePoint.
     */
    static std::vector<ResponsePoint> marginal(
            const FeaturedSpace& model,
            const std::vector<const Grid<float>*>& env_grids,
            const std::vector<std::string>& feature_names,
            int var_index,
            int n_steps = 100) {

        validate_inputs(model, env_grids, feature_names, var_index);
        if (n_steps < 2)
            throw std::invalid_argument("response_curve: n_steps must be >= 2");

        int n_vars = static_cast<int>(env_grids.size());

        // Compute mean, min, max for each variable across valid cells
        std::vector<double> means(n_vars, 0.0);
        double var_min = 0.0, var_max = 0.0;
        compute_grid_stats(env_grids, var_index, means, var_min, var_max);

        // Build feature matrix: n_steps rows, n_vars columns
        std::vector<std::vector<double>> fm(n_steps, std::vector<double>(n_vars));
        double step = (n_steps > 1) ? (var_max - var_min) / (n_steps - 1) : 0.0;

        for (int s = 0; s < n_steps; ++s) {
            for (int k = 0; k < n_vars; ++k)
                fm[s][k] = means[k];
            fm[s][var_index] = var_min + s * step;
        }

        // Predict (evaluates features from raw env values internally)
        auto scores = model.predict_from_env(fm);

        // Convert raw scores to cloglog
        std::vector<ResponsePoint> curve(n_steps);
        for (int s = 0; s < n_steps; ++s) {
            curve[s].value = fm[s][var_index];
            curve[s].prediction = 1.0 - std::exp(-scores[s]);
        }
        return curve;
    }

    /**
     * @brief Generate a marginal response curve at fixed percentile values
     *        for the other variables.
     *
     * Same as marginal() but allows the user to supply the fixed values
     * for non-target variables explicitly (e.g. medians).
     *
     * @param model          Trained FeaturedSpace.
     * @param fixed_values   Values for each variable (non-target entries used).
     * @param feature_names  Names (used for validation only).
     * @param var_index      Index of the variable to vary.
     * @param var_min        Minimum value of the target variable.
     * @param var_max        Maximum value of the target variable.
     * @param n_steps        Number of steps.
     * @return Vector of ResponsePoint.
     */
    static std::vector<ResponsePoint> marginal_fixed(
            const FeaturedSpace& model,
            const std::vector<double>& fixed_values,
            const std::vector<std::string>& feature_names,
            int var_index,
            double var_min,
            double var_max,
            int n_steps = 100) {

        int n_vars = static_cast<int>(feature_names.size());
        if (static_cast<int>(fixed_values.size()) != n_vars)
            throw std::invalid_argument(
                "response_curve: fixed_values size must equal number of variables");
        if (var_index < 0 || var_index >= n_vars)
            throw std::invalid_argument(
                "response_curve: var_index out of range");
        if (n_steps < 2)
            throw std::invalid_argument("response_curve: n_steps must be >= 2");

        std::vector<std::vector<double>> fm(n_steps, std::vector<double>(n_vars));
        double step = (var_max - var_min) / (n_steps - 1);

        for (int s = 0; s < n_steps; ++s) {
            for (int k = 0; k < n_vars; ++k)
                fm[s][k] = fixed_values[k];
            fm[s][var_index] = var_min + s * step;
        }

        auto scores = model.predict_from_env(fm);

        std::vector<ResponsePoint> curve(n_steps);
        for (int s = 0; s < n_steps; ++s) {
            curve[s].value = fm[s][var_index];
            curve[s].prediction = 1.0 - std::exp(-scores[s]);
        }
        return curve;
    }

    /**
     * @brief Generate a Java-compatible marginal response curve.
     *
     * Same as marginal() but applies the Java Maxent cloglog transform:
     *   cloglog_java = 1 - exp(-exp(H) * raw_java)
     *
     * where raw_java = raw_unnormalized / densityNormalizer.
     * This matches the response curves produced by Java Maxent and dismo.
     *
     * @param model          Trained FeaturedSpace.
     * @param env_grids      Environmental variable grids.
     * @param feature_names  Names matching env_grids order.
     * @param var_index      Index of the variable to vary.
     * @param n_steps        Number of steps across the variable range.
     * @return Vector of ResponsePoint with Java cloglog predictions.
     */
    static std::vector<ResponsePoint> marginal_java(
            const FeaturedSpace& model,
            const std::vector<const Grid<float>*>& env_grids,
            const std::vector<std::string>& feature_names,
            int var_index,
            int n_steps = 100) {

        validate_inputs(model, env_grids, feature_names, var_index);
        if (n_steps < 2)
            throw std::invalid_argument("response_curve: n_steps must be >= 2");

        int n_vars = static_cast<int>(env_grids.size());

        std::vector<double> means(n_vars, 0.0);
        double var_min = 0.0, var_max = 0.0;
        compute_grid_stats(env_grids, var_index, means, var_min, var_max);

        std::vector<std::vector<double>> fm(n_steps, std::vector<double>(n_vars));
        double step = (n_steps > 1) ? (var_max - var_min) / (n_steps - 1) : 0.0;

        for (int s = 0; s < n_steps; ++s) {
            for (int k = 0; k < n_vars; ++k)
                fm[s][k] = means[k];
            fm[s][var_index] = var_min + s * step;
        }

        auto raw_scores = model.predict_raw_java_from_env(fm);
        double expH = std::exp(model.get_entropy());

        std::vector<ResponsePoint> curve(n_steps);
        for (int s = 0; s < n_steps; ++s) {
            curve[s].value      = fm[s][var_index];
            curve[s].prediction = 1.0 - std::exp(-expH * raw_scores[s]);
        }
        return curve;
    }

    /**
     * @brief Generate a Java-compatible marginal response curve with fixed
     *        values for non-target variables.
     *
     * Same as marginal_fixed() but applies the Java Maxent cloglog transform:
     *   cloglog_java = 1 - exp(-exp(H) * raw_java)
     *
     * @param model          Trained FeaturedSpace.
     * @param fixed_values   Values for each variable (non-target entries used).
     * @param feature_names  Names (used for validation only).
     * @param var_index      Index of the variable to vary.
     * @param var_min        Minimum value of the target variable.
     * @param var_max        Maximum value of the target variable.
     * @param n_steps        Number of steps.
     * @return Vector of ResponsePoint with Java cloglog predictions.
     */
    static std::vector<ResponsePoint> marginal_fixed_java(
            const FeaturedSpace& model,
            const std::vector<double>& fixed_values,
            const std::vector<std::string>& feature_names,
            int var_index,
            double var_min,
            double var_max,
            int n_steps = 100) {

        int n_vars = static_cast<int>(feature_names.size());
        if (static_cast<int>(fixed_values.size()) != n_vars)
            throw std::invalid_argument(
                "response_curve: fixed_values size must equal number of variables");
        if (var_index < 0 || var_index >= n_vars)
            throw std::invalid_argument(
                "response_curve: var_index out of range");
        if (n_steps < 2)
            throw std::invalid_argument("response_curve: n_steps must be >= 2");

        std::vector<std::vector<double>> fm(n_steps, std::vector<double>(n_vars));
        double step = (var_max - var_min) / (n_steps - 1);

        for (int s = 0; s < n_steps; ++s) {
            for (int k = 0; k < n_vars; ++k)
                fm[s][k] = fixed_values[k];
            fm[s][var_index] = var_min + s * step;
        }

        auto raw_scores = model.predict_raw_java_from_env(fm);
        double expH = std::exp(model.get_entropy());

        std::vector<ResponsePoint> curve(n_steps);
        for (int s = 0; s < n_steps; ++s) {
            curve[s].value      = fm[s][var_index];
            curve[s].prediction = 1.0 - std::exp(-expH * raw_scores[s]);
        }
        return curve;
    }

private:

    static void validate_inputs(
            const FeaturedSpace& model,
            const std::vector<const Grid<float>*>& env_grids,
            const std::vector<std::string>& feature_names,
            int var_index) {
        if (env_grids.empty())
            throw std::invalid_argument("response_curve: env_grids must not be empty");
        if (env_grids.size() != feature_names.size())
            throw std::invalid_argument(
                "response_curve: env_grids and feature_names size mismatch");
        int n_env = model.num_env_variables();
        if (n_env > 0 && static_cast<int>(env_grids.size()) != n_env)
            throw std::invalid_argument(
                "response_curve: number of env_grids (" +
                std::to_string(env_grids.size()) +
                ") must equal number of environmental variables (" +
                std::to_string(n_env) + ")");
        if (var_index < 0 || var_index >= static_cast<int>(env_grids.size()))
            throw std::invalid_argument(
                "response_curve: var_index out of range");
    }

    /**
     * @brief Compute mean of each grid (over valid cells) and min/max of
     *        the target variable.
     */
    static void compute_grid_stats(
            const std::vector<const Grid<float>*>& env_grids,
            int var_index,
            std::vector<double>& means,
            double& var_min,
            double& var_max) {

        int n_vars = static_cast<int>(env_grids.size());
        const auto& dim = env_grids[0]->getDimension();
        int nrows = dim.nrows;
        int ncols = dim.ncols;

        std::vector<double> sums(n_vars, 0.0);
        int valid_count = 0;
        var_min =  std::numeric_limits<double>::infinity();
        var_max = -std::numeric_limits<double>::infinity();

        for (int r = 0; r < nrows; ++r) {
            for (int c = 0; c < ncols; ++c) {
                bool all_valid = true;
                for (int k = 0; k < n_vars; ++k) {
                    if (!env_grids[k]->hasData(r, c)) {
                        all_valid = false;
                        break;
                    }
                }
                if (!all_valid) continue;

                for (int k = 0; k < n_vars; ++k)
                    sums[k] += static_cast<double>(env_grids[k]->getValue(r, c));

                double v = static_cast<double>(env_grids[var_index]->getValue(r, c));
                if (v < var_min) var_min = v;
                if (v > var_max) var_max = v;

                ++valid_count;
            }
        }

        if (valid_count > 0) {
            for (int k = 0; k < n_vars; ++k)
                means[k] = sums[k] / valid_count;
        }
    }
};

} // namespace maxent

#endif // MAXENT_RESPONSE_CURVE_HPP
