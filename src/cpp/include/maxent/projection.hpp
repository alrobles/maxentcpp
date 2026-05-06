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

#ifndef MAXENT_PROJECTION_HPP
#define MAXENT_PROJECTION_HPP

#include "featured_space.hpp"
#include "grid.hpp"
#include "grid_dimension.hpp"

#include <vector>
#include <string>
#include <cmath>
#include <stdexcept>
#include <algorithm>

namespace maxent {

// ============================================================================
// Projection – apply a trained FeaturedSpace model to environmental grids
// Ported from density/Project.java
// ============================================================================

/**
 * @brief Project a trained Maxent model onto environmental grids.
 *
 * Given a set of environmental variable grids and a trained FeaturedSpace
 * model, computes raw Gibbs scores (or optionally cloglog-transformed scores)
 * for every cell in the study area.
 *
 * Inspired by density/Project.java in the Java Maxent implementation.
 */
class Projection {
public:

    /**
     * @brief Project model onto grids, producing a raw-score output grid.
     *
     * For each cell, evaluates all features at the environmental variable
     * values for that cell, then computes:
     *   raw_score = exp(sum_j lambda_j * feature_j(env) - lpNormalizer)
     *
     * Cells where any input grid has NODATA are marked NODATA in the output.
     *
     * @param model          Trained FeaturedSpace with lambdas set.
     * @param env_grids      Environmental variable grids (one per feature input).
     * @param feature_names  Names of environment variables, in order matching
     *                       env_grids. Must match the feature names used during
     *                       training.
     * @return A Grid<float> with raw Gibbs scores.
     */
    static Grid<float> project_raw(
            const FeaturedSpace& model,
            const std::vector<const Grid<float>*>& env_grids,
            const std::vector<std::string>& feature_names) {

        validate_inputs(model, env_grids, feature_names);

        const auto& dim = env_grids[0]->getDimension();
        int nrows = dim.nrows;
        int ncols = dim.ncols;

        Grid<float> output(dim, "raw_prediction");

        for (int r = 0; r < nrows; ++r) {
            for (int c = 0; c < ncols; ++c) {
                // Check for NODATA in any input grid
                bool has_nodata = false;
                for (const auto* g : env_grids) {
                    if (!g->hasData(r, c)) {
                        has_nodata = true;
                        break;
                    }
                }
                if (has_nodata) {
                    output.setValue(r, c, output.getNodataValue());
                    continue;
                }

                // Build env-variable vector for this cell
                std::vector<double> env_values(env_grids.size());
                for (size_t k = 0; k < env_grids.size(); ++k)
                    env_values[k] = static_cast<double>(env_grids[k]->getValue(r, c));

                // Predict using the model (evaluates features internally)
                std::vector<std::vector<double>> em = { env_values };
                std::vector<double> scores = model.predict_from_env(em);
                output.setValue(r, c, static_cast<float>(scores[0]));
            }
        }

        return output;
    }

    /**
     * @brief Project model onto grids, producing a cloglog-transformed output.
     *
     * cloglog(x) = 1 - exp(-x)
     *
     * Applies the complementary log-log transform directly to the raw Gibbs
     * score, producing values in [0, 1].
     *
     * @param model          Trained FeaturedSpace with lambdas set.
     * @param env_grids      Environmental variable grids.
     * @param feature_names  Names of environment variables.
     * @return A Grid<float> with cloglog-transformed scores in [0, 1].
     */
    static Grid<float> project_cloglog(
            const FeaturedSpace& model,
            const std::vector<const Grid<float>*>& env_grids,
            const std::vector<std::string>& feature_names) {

        Grid<float> raw = project_raw(model, env_grids, feature_names);
        const auto& dim = raw.getDimension();
        int nrows = dim.nrows;
        int ncols = dim.ncols;

        Grid<float> output(dim, "cloglog_prediction");

        for (int r = 0; r < nrows; ++r) {
            for (int c = 0; c < ncols; ++c) {
                if (!raw.hasData(r, c)) {
                    output.setValue(r, c, output.getNodataValue());
                    continue;
                }
                double raw_val = static_cast<double>(raw.getValue(r, c));
                double cloglog = 1.0 - std::exp(-raw_val);
                output.setValue(r, c, static_cast<float>(cloglog));
            }
        }

        return output;
    }

    /**
     * @brief Project model onto grids, producing a logistic output.
     *
     * logistic(x) = x / (1 + x)
     *
     * Applies the logistic transform directly to the raw Gibbs score,
     * producing values in [0, 1].
     *
     * @param model          Trained FeaturedSpace with lambdas set.
     * @param env_grids      Environmental variable grids.
     * @param feature_names  Names of environment variables.
     * @return A Grid<float> with logistic scores in [0, 1].
     */
    static Grid<float> project_logistic(
            const FeaturedSpace& model,
            const std::vector<const Grid<float>*>& env_grids,
            const std::vector<std::string>& feature_names) {

        Grid<float> raw = project_raw(model, env_grids, feature_names);
        const auto& dim = raw.getDimension();
        int nrows = dim.nrows;
        int ncols = dim.ncols;

        Grid<float> output(dim, "logistic_prediction");

        for (int r = 0; r < nrows; ++r) {
            for (int c = 0; c < ncols; ++c) {
                if (!raw.hasData(r, c)) {
                    output.setValue(r, c, output.getNodataValue());
                    continue;
                }
                double raw_val = static_cast<double>(raw.getValue(r, c));
                double logistic = raw_val / (1.0 + raw_val);
                output.setValue(r, c, static_cast<float>(logistic));
            }
        }

        return output;
    }

    // ========================================================================
    // Java-compatible projection methods (matching Java Maxent / dismo output)
    // ========================================================================

    /**
     * @brief Project model onto grids, producing Java-compatible raw scores.
     *
     * Java Maxent "raw" is the normalized probability:
     *   raw_java = exp(lp - lpNorm) / densityNorm
     *
     * This matches the output of the Java Maxent software and the dismo
     * R package.
     *
     * @param model          Trained FeaturedSpace with lambdas set.
     * @param env_grids      Environmental variable grids.
     * @param feature_names  Names of environment variables.
     * @return A Grid<float> with Java-compatible raw scores.
     */
    static Grid<float> project_raw_java(
            const FeaturedSpace& model,
            const std::vector<const Grid<float>*>& env_grids,
            const std::vector<std::string>& feature_names) {

        validate_inputs(model, env_grids, feature_names);

        const auto& dim = env_grids[0]->getDimension();
        int nrows = dim.nrows;
        int ncols = dim.ncols;

        Grid<float> output(dim, "raw_java_prediction");

        for (int r = 0; r < nrows; ++r) {
            for (int c = 0; c < ncols; ++c) {
                bool has_nodata = false;
                for (const auto* g : env_grids) {
                    if (!g->hasData(r, c)) { has_nodata = true; break; }
                }
                if (has_nodata) {
                    output.setValue(r, c, output.getNodataValue());
                    continue;
                }

                std::vector<double> env_values(env_grids.size());
                for (size_t k = 0; k < env_grids.size(); ++k)
                    env_values[k] = static_cast<double>(env_grids[k]->getValue(r, c));

                std::vector<std::vector<double>> em = { env_values };
                std::vector<double> scores = model.predict_raw_java_from_env(em);
                output.setValue(r, c, static_cast<float>(scores[0]));
            }
        }

        return output;
    }

    /**
     * @brief Project model onto grids using Java-compatible cloglog transform.
     *
     * Applies the Java Maxent cloglog formula:
     *   cloglog_java = 1 - exp(-exp(H) * raw_java)
     *
     * where H is the model entropy and raw_java is the normalized probability.
     * This matches the cloglog output of Java Maxent and dismo.
     *
     * @param model          Trained FeaturedSpace with lambdas set.
     * @param env_grids      Environmental variable grids.
     * @param feature_names  Names of environment variables.
     * @return A Grid<float> with Java-compatible cloglog scores in [0, 1].
     */
    static Grid<float> project_cloglog_java(
            const FeaturedSpace& model,
            const std::vector<const Grid<float>*>& env_grids,
            const std::vector<std::string>& feature_names) {

        Grid<float> raw = project_raw_java(model, env_grids, feature_names);
        const auto& dim = raw.getDimension();
        int nrows = dim.nrows;
        int ncols = dim.ncols;

        double expH = std::exp(model.get_entropy());

        Grid<float> output(dim, "cloglog_java_prediction");

        for (int r = 0; r < nrows; ++r) {
            for (int c = 0; c < ncols; ++c) {
                if (!raw.hasData(r, c)) {
                    output.setValue(r, c, output.getNodataValue());
                    continue;
                }
                double raw_val = static_cast<double>(raw.getValue(r, c));
                double cloglog = 1.0 - std::exp(-expH * raw_val);
                output.setValue(r, c, static_cast<float>(cloglog));
            }
        }

        return output;
    }

    /**
     * @brief Project model onto grids using Java-compatible logistic transform.
     *
     * Applies the Java Maxent logistic formula:
     *   logistic_java = (exp(H) * raw_java) / (1 + exp(H) * raw_java)
     *
     * where H is the model entropy and raw_java is the normalized probability.
     * This matches the logistic output of Java Maxent and dismo.
     *
     * @param model          Trained FeaturedSpace with lambdas set.
     * @param env_grids      Environmental variable grids.
     * @param feature_names  Names of environment variables.
     * @return A Grid<float> with Java-compatible logistic scores in [0, 1].
     */
    static Grid<float> project_logistic_java(
            const FeaturedSpace& model,
            const std::vector<const Grid<float>*>& env_grids,
            const std::vector<std::string>& feature_names) {

        Grid<float> raw = project_raw_java(model, env_grids, feature_names);
        const auto& dim = raw.getDimension();
        int nrows = dim.nrows;
        int ncols = dim.ncols;

        double expH = std::exp(model.get_entropy());

        Grid<float> output(dim, "logistic_java_prediction");

        for (int r = 0; r < nrows; ++r) {
            for (int c = 0; c < ncols; ++c) {
                if (!raw.hasData(r, c)) {
                    output.setValue(r, c, output.getNodataValue());
                    continue;
                }
                double raw_val = static_cast<double>(raw.getValue(r, c));
                double scaled  = expH * raw_val;
                double logistic = scaled / (1.0 + scaled);
                output.setValue(r, c, static_cast<float>(logistic));
            }
        }

        return output;
    }

    /**
     * @brief Extract Java-compatible raw scores at specific sample locations.
     *
     * raw_java = exp(lp - lpNorm) / densityNorm
     *
     * @param model          Trained FeaturedSpace with lambdas set.
     * @param env_grids      Environmental variable grids.
     * @param feature_names  Names of environment variables.
     * @param rows           Row indices of sample locations.
     * @param cols           Column indices of sample locations.
     * @return Vector of Java raw scores. NaN for NODATA cells.
     */
    static std::vector<double> extract_predictions_raw_java(
            const FeaturedSpace& model,
            const std::vector<const Grid<float>*>& env_grids,
            const std::vector<std::string>& feature_names,
            const std::vector<int>& rows,
            const std::vector<int>& cols) {

        if (rows.size() != cols.size())
            throw std::invalid_argument(
                "extract_predictions_raw_java: rows and cols must have the same length");

        validate_inputs(model, env_grids, feature_names);

        int n = static_cast<int>(rows.size());
        std::vector<double> results(n, std::numeric_limits<double>::quiet_NaN());

        for (int i = 0; i < n; ++i) {
            int r = rows[i], c = cols[i];

            bool has_nodata = false;
            for (const auto* g : env_grids) {
                if (!g->hasData(r, c)) { has_nodata = true; break; }
            }
            if (has_nodata) continue;

            std::vector<double> env_values(env_grids.size());
            for (size_t k = 0; k < env_grids.size(); ++k)
                env_values[k] = static_cast<double>(env_grids[k]->getValue(r, c));

            std::vector<std::vector<double>> em = { env_values };
            std::vector<double> scores = model.predict_raw_java_from_env(em);
            results[i] = scores[0];
        }

        return results;
    }

    /**
     * @brief Extract prediction scores at specific sample locations.
     *
     * Useful for evaluating the model: given test occurrence points and
     * environmental grids, extract the model's prediction score at each
     * point location.
     *
     * @param model          Trained FeaturedSpace with lambdas set.
     * @param env_grids      Environmental variable grids.
     * @param feature_names  Names of environment variables.
     * @param rows           Row indices of sample locations.
     * @param cols           Column indices of sample locations.
     * @return Vector of raw prediction scores at each sample location.
     *         NaN for locations where any grid has NODATA.
     */
    static std::vector<double> extract_predictions(
            const FeaturedSpace& model,
            const std::vector<const Grid<float>*>& env_grids,
            const std::vector<std::string>& feature_names,
            const std::vector<int>& rows,
            const std::vector<int>& cols) {

        if (rows.size() != cols.size())
            throw std::invalid_argument(
                "extract_predictions: rows and cols must have the same length");

        validate_inputs(model, env_grids, feature_names);

        int n = static_cast<int>(rows.size());
        std::vector<double> results(n, std::numeric_limits<double>::quiet_NaN());

        for (int i = 0; i < n; ++i) {
            int r = rows[i], c = cols[i];

            // Check NODATA
            bool has_nodata = false;
            for (const auto* g : env_grids) {
                if (!g->hasData(r, c)) {
                    has_nodata = true;
                    break;
                }
            }
            if (has_nodata) continue;

            std::vector<double> env_values(env_grids.size());
            for (size_t k = 0; k < env_grids.size(); ++k)
                env_values[k] = static_cast<double>(env_grids[k]->getValue(r, c));

            std::vector<std::vector<double>> em = { env_values };
            std::vector<double> scores = model.predict_from_env(em);
            results[i] = scores[0];
        }

        return results;
    }

private:

    /**
     * @brief Validate projection inputs.
     *
     * Checks that env_grids and feature_names have the same length,
     * and that the number of grids matches the number of raw environmental
     * variables expected by the model (inferred from the features'
     * var_index values).
     */
    static void validate_inputs(
            const FeaturedSpace& model,
            const std::vector<const Grid<float>*>& env_grids,
            const std::vector<std::string>& feature_names) {
        if (env_grids.empty())
            throw std::invalid_argument("project: env_grids must not be empty");
        if (env_grids.size() != feature_names.size())
            throw std::invalid_argument(
                "project: env_grids and feature_names must have the same length");

        int n_env = model.num_env_variables();
        if (n_env > 0 && static_cast<int>(env_grids.size()) != n_env)
            throw std::invalid_argument(
                "project: number of env_grids (" +
                std::to_string(env_grids.size()) +
                ") must equal number of environmental variables (" +
                std::to_string(n_env) + ")");

        // Verify all grids share the same dimensions
        const auto& ref_dim = env_grids[0]->getDimension();
        for (size_t i = 1; i < env_grids.size(); ++i) {
            const auto& d = env_grids[i]->getDimension();
            if (d.nrows != ref_dim.nrows || d.ncols != ref_dim.ncols)
                throw std::invalid_argument(
                    "project: all env_grids must have the same dimensions");
        }
    }
};

} // namespace maxent

#endif // MAXENT_PROJECTION_HPP
