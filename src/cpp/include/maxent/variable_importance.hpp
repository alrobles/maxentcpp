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

#ifndef MAXENT_VARIABLE_IMPORTANCE_HPP
#define MAXENT_VARIABLE_IMPORTANCE_HPP

#include "featured_space.hpp"
#include "grid.hpp"
#include "projection.hpp"
#include "model_evaluation.hpp"

#include <vector>
#include <string>
#include <algorithm>
#include <numeric>
#include <random>
#include <stdexcept>
#include <cmath>

namespace maxent {

// ============================================================================
// ImportanceResult – result for a single variable
// ============================================================================

/**
 * @brief Container for one variable's importance metrics.
 */
struct ImportanceResult {
    std::string name;                ///< Variable name
    double permutation_importance;   ///< AUC drop from permutation (normalised %)
    double contribution;             ///< Lambda-based percent contribution
};

// ============================================================================
// VariableImportance – permutation importance and percent contribution
// Ported from density/tools/PermutationImportance.java
// ============================================================================

/**
 * @brief Measure how much each environmental variable contributes to model
 *        prediction quality.
 *
 * Two measures are provided:
 *  - **Permutation importance**: randomly permute each variable in turn and
 *    measure the drop in AUC compared to the unpermuted baseline.
 *  - **Percent contribution**: proportional to the sum of absolute lambda
 *    values for features derived from each variable.
 */
class VariableImportance {
public:

    /**
     * @brief Compute permutation importance for each environmental variable.
     *
     * Steps:
     * 1. Compute baseline AUC from the model predictions.
     * 2. For each variable k, permute its values across all sample locations.
     * 3. Re-predict and compute AUC.
     * 4. Importance = max(0, baseline_AUC - permuted_AUC).
     * 5. Normalise so all importances sum to 100%.
     *
     * @param model          Trained FeaturedSpace.
     * @param env_grids      Environmental variable grids.
     * @param feature_names  Names matching env_grids order.
     * @param presence_rows  Row indices of presence sites.
     * @param presence_cols  Column indices of presence sites.
     * @param absence_rows   Row indices of absence/background sites.
     * @param absence_cols   Column indices of absence/background sites.
     * @param seed           Random seed for permutation reproducibility.
     * @return Vector of ImportanceResult, one per variable.
     */
    static std::vector<ImportanceResult> permutation_importance(
            const FeaturedSpace& model,
            const std::vector<const Grid<float>*>& env_grids,
            const std::vector<std::string>& feature_names,
            const std::vector<int>& presence_rows,
            const std::vector<int>& presence_cols,
            const std::vector<int>& absence_rows,
            const std::vector<int>& absence_cols,
            unsigned int seed = 42) {

        if (env_grids.empty())
            throw std::invalid_argument(
                "permutation_importance: env_grids must not be empty");
        if (env_grids.size() != feature_names.size())
            throw std::invalid_argument(
                "permutation_importance: env_grids and feature_names size mismatch");
        if (presence_rows.size() != presence_cols.size())
            throw std::invalid_argument(
                "permutation_importance: presence rows/cols size mismatch");
        if (absence_rows.size() != absence_cols.size())
            throw std::invalid_argument(
                "permutation_importance: absence rows/cols size mismatch");

        int n_vars = static_cast<int>(env_grids.size());

        // Extract unpermuted values at sample locations
        auto pres_vals = extract_env_matrix(env_grids, presence_rows, presence_cols);
        auto abs_vals  = extract_env_matrix(env_grids, absence_rows, absence_cols);

        // Baseline AUC
        auto pres_scores = predict_from_matrix(model, pres_vals, n_vars);
        auto abs_scores  = predict_from_matrix(model, abs_vals, n_vars);
        double baseline_auc = ModelEvaluation::auc(pres_scores, abs_scores);

        // Permute each variable and measure AUC drop
        std::vector<double> raw_importance(n_vars, 0.0);
        std::mt19937 rng(seed);

        for (int k = 0; k < n_vars; ++k) {
            // Copy matrices
            auto perm_pres = pres_vals;
            auto perm_abs  = abs_vals;

            // Permute variable k among presence points
            {
                std::vector<double> col_vals;
                col_vals.reserve(perm_pres.size());
                for (const auto& row : perm_pres) col_vals.push_back(row[k]);
                std::shuffle(col_vals.begin(), col_vals.end(), rng);
                for (size_t i = 0; i < perm_pres.size(); ++i)
                    perm_pres[i][k] = col_vals[i];
            }
            // Permute variable k among absence points
            {
                std::vector<double> col_vals;
                col_vals.reserve(perm_abs.size());
                for (const auto& row : perm_abs) col_vals.push_back(row[k]);
                std::shuffle(col_vals.begin(), col_vals.end(), rng);
                for (size_t i = 0; i < perm_abs.size(); ++i)
                    perm_abs[i][k] = col_vals[i];
            }

            auto perm_pres_scores = predict_from_matrix(model, perm_pres, n_vars);
            auto perm_abs_scores  = predict_from_matrix(model, perm_abs, n_vars);
            double perm_auc = ModelEvaluation::auc(perm_pres_scores, perm_abs_scores);

            raw_importance[k] = std::max(0.0, baseline_auc - perm_auc);
        }

        // Normalise to percentages
        double total = 0.0;
        for (double v : raw_importance) total += v;

        std::vector<ImportanceResult> results(n_vars);
        for (int k = 0; k < n_vars; ++k) {
            results[k].name = feature_names[k];
            results[k].permutation_importance =
                (total > 0.0) ? 100.0 * raw_importance[k] / total : 0.0;
            results[k].contribution = 0.0;  // filled separately
        }

        return results;
    }

    /**
     * @brief Compute percent contribution based on lambda magnitudes.
     *
     * For each environmental variable, sums the absolute lambda values of
     * all features derived from that variable, then normalises to 100%.
     *
     * @param model          Trained FeaturedSpace.
     * @param feature_names  Names of the base environmental variables.
     * @return Vector of ImportanceResult with contribution field filled.
     */
    static std::vector<ImportanceResult> percent_contribution(
            const FeaturedSpace& model,
            const std::vector<std::string>& feature_names) {

        int n_vars = static_cast<int>(feature_names.size());
        std::vector<double> contrib(n_vars, 0.0);

        const auto& features = model.features();
        for (const auto& f : features) {
            const std::string& fname = f->name();
            double abs_lambda = std::abs(f->lambda());
            // Match feature name to variable: feature name starts with var name
            for (int k = 0; k < n_vars; ++k) {
                if (fname.find(feature_names[k]) == 0) {
                    contrib[k] += abs_lambda;
                    break;
                }
            }
        }

        double total = 0.0;
        for (double v : contrib) total += v;

        std::vector<ImportanceResult> results(n_vars);
        for (int k = 0; k < n_vars; ++k) {
            results[k].name = feature_names[k];
            results[k].permutation_importance = 0.0;
            results[k].contribution =
                (total > 0.0) ? 100.0 * contrib[k] / total : 0.0;
        }

        return results;
    }

private:

    /**
     * @brief Extract environmental values at sample locations into a matrix.
     *
     * @return [n_samples x n_vars] matrix of environmental values.
     */
    static std::vector<std::vector<double>> extract_env_matrix(
            const std::vector<const Grid<float>*>& env_grids,
            const std::vector<int>& rows,
            const std::vector<int>& cols) {

        int n = static_cast<int>(rows.size());
        int n_vars = static_cast<int>(env_grids.size());
        std::vector<std::vector<double>> result(n, std::vector<double>(n_vars, 0.0));

        for (int i = 0; i < n; ++i) {
            for (int k = 0; k < n_vars; ++k) {
                if (env_grids[k]->hasData(rows[i], cols[i]))
                    result[i][k] = static_cast<double>(
                        env_grids[k]->getValue(rows[i], cols[i]));
            }
        }
        return result;
    }

    /**
     * @brief Predict raw scores from a matrix of raw environmental values.
     */
    static std::vector<double> predict_from_matrix(
            const FeaturedSpace& model,
            const std::vector<std::vector<double>>& env_matrix,
            int /*n_vars*/) {
        return model.predict_from_env(env_matrix);
    }
};

} // namespace maxent

#endif // MAXENT_VARIABLE_IMPORTANCE_HPP
