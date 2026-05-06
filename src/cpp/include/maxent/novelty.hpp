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

#ifndef MAXENT_NOVELTY_HPP
#define MAXENT_NOVELTY_HPP

#include "grid.hpp"
#include "grid_dimension.hpp"

#include <vector>
#include <string>
#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <limits>

namespace maxent {

// ============================================================================
// MessResult – MESS analysis result
// ============================================================================

/**
 * @brief Contains the MESS grid and the Most Dissimilar Variable (MoD) grid.
 */
struct MessResult {
    Grid<float> mess_grid;  ///< MESS values (negative = novel environment)
    Grid<float> mod_grid;   ///< Index of most dissimilar variable (1-based)

    MessResult(const GridDimension& dim)
        : mess_grid(dim, "mess")
        , mod_grid(dim, "mod") {}
};

// ============================================================================
// Novelty – MESS (Multivariate Environmental Similarity Surface) analysis
// Ported from density/tools/Novel.java
// ============================================================================

/**
 * @brief Compute the Multivariate Environmental Similarity Surface (MESS).
 *
 * MESS measures how similar a point is to the range of environments in
 * the reference (training) dataset. Negative MESS values indicate novel
 * conditions (extrapolation), while positive values indicate interpolation.
 *
 * For each variable at each cell, the similarity is computed as:
 *   - If value < min(reference): 100 * (value - min) / (max - min)   [negative]
 *   - If value > max(reference): 100 * (max - value) / (max - min)   [negative]
 *   - Otherwise: 100 * min(f, 100-f) / 50
 *     where f = 100 * (count of reference values <= value) / n_reference
 *
 * The MESS value for each cell is the minimum similarity across all
 * variables, and the MoD (Most Dissimilar Variable) grid records which
 * variable produced that minimum.
 *
 * Reference: Elith, J., Kearney, M., & Phillips, S. (2010).
 */
class Novelty {
public:

    /**
     * @brief Compute MESS from environmental grids and reference point data.
     *
     * @param env_grids        Environmental variable grids for the projection area.
     * @param reference_values [n_vars] vectors of reference (training) values.
     *                         Each vector contains the observed values of one
     *                         variable at the reference (training) sites.
     *                         Values are sorted internally.
     * @param feature_names    Names of the variables (for documentation).
     * @return MessResult containing the MESS grid and MoD grid.
     */
    static MessResult mess(
            const std::vector<const Grid<float>*>& env_grids,
            const std::vector<std::vector<double>>& reference_values,
            const std::vector<std::string>& feature_names) {

        validate_inputs(env_grids, reference_values, feature_names);

        int n_vars = static_cast<int>(env_grids.size());
        const auto& dim = env_grids[0]->getDimension();
        int nrows = dim.nrows;
        int ncols = dim.ncols;

        // Sort reference values for binary search
        std::vector<std::vector<double>> sorted_refs(n_vars);
        for (int k = 0; k < n_vars; ++k) {
            sorted_refs[k] = reference_values[k];
            std::sort(sorted_refs[k].begin(), sorted_refs[k].end());
        }

        MessResult result(dim);

        for (int r = 0; r < nrows; ++r) {
            for (int c = 0; c < ncols; ++c) {
                // Check for any NODATA
                bool has_nodata = false;
                for (int k = 0; k < n_vars; ++k) {
                    if (!env_grids[k]->hasData(r, c)) {
                        has_nodata = true;
                        break;
                    }
                }
                if (has_nodata) {
                    result.mess_grid.setValue(
                        r, c, result.mess_grid.getNodataValue());
                    result.mod_grid.setValue(
                        r, c, result.mod_grid.getNodataValue());
                    continue;
                }

                double min_sim = std::numeric_limits<double>::infinity();
                int mod_var = 0;

                for (int k = 0; k < n_vars; ++k) {
                    double val = static_cast<double>(
                        env_grids[k]->getValue(r, c));
                    double sim = compute_similarity(
                        val, sorted_refs[k]);

                    if (sim < min_sim) {
                        min_sim = sim;
                        mod_var = k + 1;  // 1-based index
                    }
                }

                result.mess_grid.setValue(r, c, static_cast<float>(min_sim));
                result.mod_grid.setValue(r, c, static_cast<float>(mod_var));
            }
        }

        return result;
    }

    /**
     * @brief Compute MESS from grids and min/max ranges (simplified version).
     *
     * When only min/max of reference data are available (not the full
     * distribution), uses a simplified MESS that only checks whether
     * values fall outside the training range.
     *
     * Similarity for each variable:
     *   - Inside [min, max]: 100 * min(f, 1-f) where f = (val-min)/(max-min)
     *   - Below min:  100 * (val - min) / (max - min)    [negative]
     *   - Above max:  100 * (max - val) / (max - min)    [negative]
     *
     * @param env_grids  Environmental variable grids.
     * @param var_mins   Minimum reference value for each variable.
     * @param var_maxs   Maximum reference value for each variable.
     * @return MessResult containing the MESS and MoD grids.
     */
    static MessResult mess_range(
            const std::vector<const Grid<float>*>& env_grids,
            const std::vector<double>& var_mins,
            const std::vector<double>& var_maxs) {

        int n_vars = static_cast<int>(env_grids.size());
        if (var_mins.size() != env_grids.size() ||
            var_maxs.size() != env_grids.size())
            throw std::invalid_argument(
                "mess_range: var_mins/var_maxs size mismatch");
        if (env_grids.empty())
            throw std::invalid_argument("mess_range: env_grids must not be empty");

        const auto& dim = env_grids[0]->getDimension();
        int nrows = dim.nrows;
        int ncols = dim.ncols;

        MessResult result(dim);

        for (int r = 0; r < nrows; ++r) {
            for (int c = 0; c < ncols; ++c) {
                bool has_nodata = false;
                for (int k = 0; k < n_vars; ++k) {
                    if (!env_grids[k]->hasData(r, c)) {
                        has_nodata = true;
                        break;
                    }
                }
                if (has_nodata) {
                    result.mess_grid.setValue(
                        r, c, result.mess_grid.getNodataValue());
                    result.mod_grid.setValue(
                        r, c, result.mod_grid.getNodataValue());
                    continue;
                }

                double min_sim = std::numeric_limits<double>::infinity();
                int mod_var = 0;

                for (int k = 0; k < n_vars; ++k) {
                    double val = static_cast<double>(
                        env_grids[k]->getValue(r, c));
                    double range = var_maxs[k] - var_mins[k];
                    double sim;

                    if (range <= 0.0) {
                        sim = (val == var_mins[k]) ? 100.0 : -100.0;
                    } else if (val < var_mins[k]) {
                        sim = 100.0 * (val - var_mins[k]) / range;
                    } else if (val > var_maxs[k]) {
                        sim = 100.0 * (var_maxs[k] - val) / range;
                    } else {
                        double f = (val - var_mins[k]) / range;
                        sim = 100.0 * std::min(f, 1.0 - f) * 2.0;
                    }

                    if (sim < min_sim) {
                        min_sim = sim;
                        mod_var = k + 1;
                    }
                }

                result.mess_grid.setValue(r, c, static_cast<float>(min_sim));
                result.mod_grid.setValue(r, c, static_cast<float>(mod_var));
            }
        }

        return result;
    }

private:

    /**
     * @brief Compute similarity for one variable at one cell.
     *
     * @param val         Cell value.
     * @param sorted_ref  Sorted reference values.
     * @return Similarity score (negative = novel, positive = within range).
     */
    static double compute_similarity(
            double val,
            const std::vector<double>& sorted_ref) {

        int n = static_cast<int>(sorted_ref.size());
        if (n == 0) return 0.0;

        double ref_min = sorted_ref.front();
        double ref_max = sorted_ref.back();
        double range = ref_max - ref_min;

        if (range <= 0.0) {
            return (val == ref_min) ? 100.0 : -100.0;
        }

        if (val < ref_min) {
            return 100.0 * (val - ref_min) / range;
        }
        if (val > ref_max) {
            return 100.0 * (ref_max - val) / range;
        }

        // Count how many reference values are <= val
        auto it = std::upper_bound(sorted_ref.begin(), sorted_ref.end(), val);
        int count_le = static_cast<int>(it - sorted_ref.begin());

        double f = 100.0 * static_cast<double>(count_le) / n;
        return std::min(f, 100.0 - f) * 2.0;
    }

    static void validate_inputs(
            const std::vector<const Grid<float>*>& env_grids,
            const std::vector<std::vector<double>>& reference_values,
            const std::vector<std::string>& feature_names) {

        if (env_grids.empty())
            throw std::invalid_argument("mess: env_grids must not be empty");
        if (reference_values.size() != env_grids.size())
            throw std::invalid_argument(
                "mess: reference_values must have same size as env_grids");
        if (feature_names.size() != env_grids.size())
            throw std::invalid_argument(
                "mess: feature_names must have same size as env_grids");

        const auto& ref_dim = env_grids[0]->getDimension();
        for (size_t i = 1; i < env_grids.size(); ++i) {
            const auto& d = env_grids[i]->getDimension();
            if (d.nrows != ref_dim.nrows || d.ncols != ref_dim.ncols)
                throw std::invalid_argument(
                    "mess: all env_grids must have the same dimensions");
        }
    }
};

} // namespace maxent

#endif // MAXENT_NOVELTY_HPP
