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

#ifndef MAXENT_CLAMPING_HPP
#define MAXENT_CLAMPING_HPP

#include "grid.hpp"
#include "grid_dimension.hpp"

#include <vector>
#include <string>
#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace maxent {

// ============================================================================
// ClampResult – result of clamping a set of grids
// ============================================================================

/**
 * @brief Contains the clamped grids and a clamping indicator grid.
 */
struct ClampResult {
    std::vector<Grid<float>> clamped_grids;  ///< Clamped environmental grids
    Grid<float> clamp_grid;                  ///< Per-cell total clamping magnitude

    ClampResult(const GridDimension& dim)
        : clamp_grid(dim, "clamping") {}
};

// ============================================================================
// Clamping – restrict environmental variables to training range
// Ported from density/Project.java (clamping logic)
// ============================================================================

/**
 * @brief Clamp environmental variable grids to the range observed during
 *        training.
 *
 * When projecting a model to new areas or time periods, environmental
 * variables may take values outside the range seen during training.
 * Clamping restricts each variable to its training [min, max] range.
 *
 * The clamping grid records, for each cell, the total amount by which
 * variables were clamped (sum of absolute differences from the nearest
 * training-range bound).
 */
class Clamping {
public:

    /**
     * @brief Clamp environmental grids to specified min/max ranges.
     *
     * For each cell and each variable, if the cell value is below var_mins[k],
     * it is set to var_mins[k]; if above var_maxs[k], set to var_maxs[k].
     * The clamping grid accumulates the total absolute clamping amount per cell.
     *
     * @param env_grids   Environmental variable grids.
     * @param var_mins    Minimum training-range value for each variable.
     * @param var_maxs    Maximum training-range value for each variable.
     * @return ClampResult with clamped grids and clamping indicator grid.
     */
    static ClampResult clamp(
            const std::vector<const Grid<float>*>& env_grids,
            const std::vector<double>& var_mins,
            const std::vector<double>& var_maxs) {

        validate_inputs(env_grids, var_mins, var_maxs);

        int n_vars = static_cast<int>(env_grids.size());
        const auto& dim = env_grids[0]->getDimension();
        int nrows = dim.nrows;
        int ncols = dim.ncols;

        ClampResult result(dim);
        result.clamped_grids.reserve(n_vars);

        // Create clamped copies
        for (int k = 0; k < n_vars; ++k) {
            result.clamped_grids.emplace_back(dim, env_grids[k]->getName());
        }

        for (int r = 0; r < nrows; ++r) {
            for (int c = 0; c < ncols; ++c) {
                double total_clamp = 0.0;
                bool any_nodata = false;

                for (int k = 0; k < n_vars; ++k) {
                    if (!env_grids[k]->hasData(r, c)) {
                        any_nodata = true;
                        result.clamped_grids[k].setValue(
                            r, c, result.clamped_grids[k].getNodataValue());
                        continue;
                    }

                    double val = static_cast<double>(env_grids[k]->getValue(r, c));
                    double clamped_val = val;

                    if (val < var_mins[k]) {
                        total_clamp += var_mins[k] - val;
                        clamped_val = var_mins[k];
                    } else if (val > var_maxs[k]) {
                        total_clamp += val - var_maxs[k];
                        clamped_val = var_maxs[k];
                    }

                    result.clamped_grids[k].setValue(
                        r, c, static_cast<float>(clamped_val));
                }

                if (any_nodata)
                    result.clamp_grid.setValue(
                        r, c, result.clamp_grid.getNodataValue());
                else
                    result.clamp_grid.setValue(
                        r, c, static_cast<float>(total_clamp));
            }
        }

        return result;
    }

    /**
     * @brief Compute min/max ranges for each variable from grids.
     *
     * Scans all valid cells to determine the observed [min, max] range
     * of each variable. Useful for deriving training ranges.
     *
     * @param env_grids Environmental variable grids.
     * @param[out] var_mins  Minimum value for each variable.
     * @param[out] var_maxs  Maximum value for each variable.
     */
    static void compute_ranges(
            const std::vector<const Grid<float>*>& env_grids,
            std::vector<double>& var_mins,
            std::vector<double>& var_maxs) {

        int n_vars = static_cast<int>(env_grids.size());
        var_mins.assign(n_vars,  std::numeric_limits<double>::infinity());
        var_maxs.assign(n_vars, -std::numeric_limits<double>::infinity());

        if (env_grids.empty()) return;

        const auto& dim = env_grids[0]->getDimension();
        for (int r = 0; r < dim.nrows; ++r) {
            for (int c = 0; c < dim.ncols; ++c) {
                for (int k = 0; k < n_vars; ++k) {
                    if (!env_grids[k]->hasData(r, c)) continue;
                    double v = static_cast<double>(env_grids[k]->getValue(r, c));
                    if (v < var_mins[k]) var_mins[k] = v;
                    if (v > var_maxs[k]) var_maxs[k] = v;
                }
            }
        }
    }

private:

    static void validate_inputs(
            const std::vector<const Grid<float>*>& env_grids,
            const std::vector<double>& var_mins,
            const std::vector<double>& var_maxs) {
        if (env_grids.empty())
            throw std::invalid_argument("clamp: env_grids must not be empty");
        if (var_mins.size() != env_grids.size())
            throw std::invalid_argument("clamp: var_mins size mismatch");
        if (var_maxs.size() != env_grids.size())
            throw std::invalid_argument("clamp: var_maxs size mismatch");

        const auto& ref_dim = env_grids[0]->getDimension();
        for (size_t i = 1; i < env_grids.size(); ++i) {
            const auto& d = env_grids[i]->getDimension();
            if (d.nrows != ref_dim.nrows || d.ncols != ref_dim.ncols)
                throw std::invalid_argument(
                    "clamp: all env_grids must have the same dimensions");
        }
    }
};

} // namespace maxent

#endif // MAXENT_CLAMPING_HPP
