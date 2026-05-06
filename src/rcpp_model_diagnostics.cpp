#include <Rcpp.h>

// Enable C++17
// [[Rcpp::plugins(cpp17)]]

// Link to Eigen
// [[Rcpp::depends(RcppEigen)]]

#include "cpp/include/maxent/variable_importance.hpp"
#include "cpp/include/maxent/response_curve.hpp"
#include "cpp/include/maxent/clamping.hpp"
#include "cpp/include/maxent/novelty.hpp"

using namespace Rcpp;
using namespace maxent;

// =========================================================================
// Variable Importance
// =========================================================================

//' Compute Permutation Importance
//'
//' Measures how much each environmental variable contributes to model
//' prediction quality by permuting each variable and measuring AUC drop.
//'
//' @param fs_ptr         External pointer to a FeaturedSpace object.
//' @param grid_ptrs      List of external pointers to Grid<float> objects.
//' @param feature_names  Character vector of environment variable names.
//' @param presence_rows  Integer vector of presence site row indices.
//' @param presence_cols  Integer vector of presence site column indices.
//' @param absence_rows   Integer vector of absence site row indices.
//' @param absence_cols   Integer vector of absence site column indices.
//' @param seed           Random seed for reproducibility.
//' @return A data.frame with columns: name, permutation_importance.
//' @export
// [[Rcpp::export]]
DataFrame compute_permutation_importance(
        SEXP fs_ptr, List grid_ptrs, CharacterVector feature_names,
        IntegerVector presence_rows, IntegerVector presence_cols,
        IntegerVector absence_rows, IntegerVector absence_cols,
        int seed = 42) {

    XPtr<FeaturedSpace> fs(fs_ptr);

    std::vector<const Grid<float>*> grids;
    grids.reserve(grid_ptrs.size());
    for (int i = 0; i < grid_ptrs.size(); ++i) {
        XPtr<Grid<float>> gp(grid_ptrs[i]);
        grids.push_back(gp.get());
    }

    std::vector<std::string> names(feature_names.size());
    for (int i = 0; i < feature_names.size(); ++i)
        names[i] = as<std::string>(feature_names[i]);

    std::vector<int> pr(presence_rows.begin(), presence_rows.end());
    std::vector<int> pc(presence_cols.begin(), presence_cols.end());
    std::vector<int> ar(absence_rows.begin(), absence_rows.end());
    std::vector<int> ac(absence_cols.begin(), absence_cols.end());

    auto results = VariableImportance::permutation_importance(
        *fs, grids, names, pr, pc, ar, ac, static_cast<unsigned int>(seed));

    CharacterVector r_names(results.size());
    NumericVector r_importance(results.size());
    for (size_t i = 0; i < results.size(); ++i) {
        r_names[i] = results[i].name;
        r_importance[i] = results[i].permutation_importance;
    }

    return DataFrame::create(
        Named("name") = r_names,
        Named("permutation_importance") = r_importance,
        Named("stringsAsFactors") = false
    );
}

//' Compute Percent Contribution
//'
//' Computes variable contribution based on sum of absolute lambda values
//' for features derived from each variable.
//'
//' @param fs_ptr         External pointer to a FeaturedSpace object.
//' @param feature_names  Character vector of base variable names.
//' @return A data.frame with columns: name, contribution.
//' @export
// [[Rcpp::export]]
DataFrame compute_percent_contribution(SEXP fs_ptr,
                                       CharacterVector feature_names) {
    XPtr<FeaturedSpace> fs(fs_ptr);

    std::vector<std::string> names(feature_names.size());
    for (int i = 0; i < feature_names.size(); ++i)
        names[i] = as<std::string>(feature_names[i]);

    auto results = VariableImportance::percent_contribution(*fs, names);

    CharacterVector r_names(results.size());
    NumericVector r_contribution(results.size());
    for (size_t i = 0; i < results.size(); ++i) {
        r_names[i] = results[i].name;
        r_contribution[i] = results[i].contribution;
    }

    return DataFrame::create(
        Named("name") = r_names,
        Named("contribution") = r_contribution,
        Named("stringsAsFactors") = false
    );
}

// =========================================================================
// Response Curves
// =========================================================================

//' Compute Java-compatible Marginal Response Curve
//'
//' Like compute_response_curve() but applies the Java Maxent cloglog:
//'   cloglog_java = 1 - exp(-exp(H) * raw_java)
//'
//' This matches the response curves produced by Java Maxent and dismo.
//'
//' @param fs_ptr         External pointer to a FeaturedSpace object.
//' @param grid_ptrs      List of external pointers to Grid<float> objects.
//' @param feature_names  Character vector of environment variable names.
//' @param var_index      0-based index of the variable to vary.
//' @param n_steps        Number of steps across the variable range.
//' @return A data.frame with columns: value, prediction.
//' @export
// [[Rcpp::export]]
DataFrame compute_response_curve(
        SEXP fs_ptr, List grid_ptrs, CharacterVector feature_names,
        int var_index, int n_steps = 100) {

    XPtr<FeaturedSpace> fs(fs_ptr);

    std::vector<const Grid<float>*> grids;
    grids.reserve(grid_ptrs.size());
    for (int i = 0; i < grid_ptrs.size(); ++i) {
        XPtr<Grid<float>> gp(grid_ptrs[i]);
        grids.push_back(gp.get());
    }

    std::vector<std::string> names(feature_names.size());
    for (int i = 0; i < feature_names.size(); ++i)
        names[i] = as<std::string>(feature_names[i]);

    auto curve = ResponseCurve::marginal_java(
        *fs, grids, names, var_index, n_steps);

    NumericVector values(curve.size());
    NumericVector preds(curve.size());
    for (size_t i = 0; i < curve.size(); ++i) {
        values[i] = curve[i].value;
        preds[i]  = curve[i].prediction;
    }

    return DataFrame::create(
        Named("value") = values,
        Named("prediction") = preds
    );
}

//' Compute Java-compatible Response Curve with Fixed Values
//'
//' Like compute_response_curve_fixed() but applies the Java Maxent cloglog:
//'   cloglog_java = 1 - exp(-exp(H) * raw_java)
//'
//' @param fs_ptr         External pointer to a FeaturedSpace object.
//' @param fixed_values   Numeric vector of fixed values for each variable.
//' @param feature_names  Character vector of environment variable names.
//' @param var_index      0-based index of the variable to vary.
//' @param var_min        Minimum value of the target variable.
//' @param var_max        Maximum value of the target variable.
//' @param n_steps        Number of steps.
//' @return A data.frame with columns: value, prediction.
//' @export
// [[Rcpp::export]]
DataFrame compute_response_curve_fixed(
        SEXP fs_ptr, NumericVector fixed_values,
        CharacterVector feature_names,
        int var_index, double var_min, double var_max,
        int n_steps = 100) {

    XPtr<FeaturedSpace> fs(fs_ptr);

    std::vector<double> fixed(fixed_values.begin(), fixed_values.end());
    std::vector<std::string> names(feature_names.size());
    for (int i = 0; i < feature_names.size(); ++i)
        names[i] = as<std::string>(feature_names[i]);

    auto curve = ResponseCurve::marginal_fixed_java(
        *fs, fixed, names, var_index, var_min, var_max, n_steps);

    NumericVector values(curve.size());
    NumericVector preds(curve.size());
    for (size_t i = 0; i < curve.size(); ++i) {
        values[i] = curve[i].value;
        preds[i]  = curve[i].prediction;
    }

    return DataFrame::create(
        Named("value") = values,
        Named("prediction") = preds
    );
}

//' Clamp Environmental Grids
//'
//' Restricts environmental variable values to the training range.
//' Returns clamped grids and a clamping indicator grid.
//'
//' @param grid_ptrs List of external pointers to Grid<float> objects.
//' @param var_mins  Numeric vector of minimum training values per variable.
//' @param var_maxs  Numeric vector of maximum training values per variable.
//' @return A named list with:
//'   \describe{
//'     \item{clamped_grids}{List of external pointers to clamped Grid<float>}
//'     \item{clamp_grid}{External pointer to Grid<float> with clamping magnitudes}
//'   }
//' @export
// [[Rcpp::export]]
List clamp_grids(List grid_ptrs, NumericVector var_mins,
                 NumericVector var_maxs) {

    std::vector<const Grid<float>*> grids;
    grids.reserve(grid_ptrs.size());
    for (int i = 0; i < grid_ptrs.size(); ++i) {
        XPtr<Grid<float>> gp(grid_ptrs[i]);
        grids.push_back(gp.get());
    }

    std::vector<double> mins(var_mins.begin(), var_mins.end());
    std::vector<double> maxs(var_maxs.begin(), var_maxs.end());

    auto result = Clamping::clamp(grids, mins, maxs);

    // Convert clamped grids to XPtr list
    List clamped_list(result.clamped_grids.size());
    for (size_t i = 0; i < result.clamped_grids.size(); ++i) {
        auto* g = new Grid<float>(std::move(result.clamped_grids[i]));
        clamped_list[i] = XPtr<Grid<float>>(g, true);
    }

    auto* cg = new Grid<float>(std::move(result.clamp_grid));
    XPtr<Grid<float>> clamp_ptr(cg, true);

    return List::create(
        Named("clamped_grids") = clamped_list,
        Named("clamp_grid") = clamp_ptr
    );
}

//' Compute Variable Ranges from Grids
//'
//' Scans all valid cells to determine min/max of each variable.
//'
//' @param grid_ptrs List of external pointers to Grid<float> objects.
//' @return A data.frame with columns: min, max.
//' @export
// [[Rcpp::export]]
DataFrame compute_variable_ranges(List grid_ptrs) {
    std::vector<const Grid<float>*> grids;
    grids.reserve(grid_ptrs.size());
    for (int i = 0; i < grid_ptrs.size(); ++i) {
        XPtr<Grid<float>> gp(grid_ptrs[i]);
        grids.push_back(gp.get());
    }

    std::vector<double> mins, maxs;
    Clamping::compute_ranges(grids, mins, maxs);

    return DataFrame::create(
        Named("min") = NumericVector(mins.begin(), mins.end()),
        Named("max") = NumericVector(maxs.begin(), maxs.end())
    );
}

// =========================================================================
// Novelty / MESS
// =========================================================================

//' Compute MESS (Multivariate Environmental Similarity Surface)
//'
//' Measures how similar each cell is to the training environment.
//' Negative values indicate novel (non-analog) conditions.
//'
//' @param grid_ptrs         List of external pointers to Grid<float> objects.
//' @param reference_values  List of numeric vectors with reference values
//'   for each variable (e.g. values at training sites).
//' @param feature_names     Character vector of variable names.
//' @return A named list with:
//'   \describe{
//'     \item{mess_grid}{External pointer to Grid<float> with MESS values}
//'     \item{mod_grid}{External pointer to Grid<float> with MoD variable index (1-based)}
//'   }
//' @export
// [[Rcpp::export]]
List compute_mess(List grid_ptrs, List reference_values,
                  CharacterVector feature_names) {

    std::vector<const Grid<float>*> grids;
    grids.reserve(grid_ptrs.size());
    for (int i = 0; i < grid_ptrs.size(); ++i) {
        XPtr<Grid<float>> gp(grid_ptrs[i]);
        grids.push_back(gp.get());
    }

    std::vector<std::vector<double>> refs(reference_values.size());
    for (int i = 0; i < reference_values.size(); ++i) {
        NumericVector rv = reference_values[i];
        refs[i] = std::vector<double>(rv.begin(), rv.end());
    }

    std::vector<std::string> names(feature_names.size());
    for (int i = 0; i < feature_names.size(); ++i)
        names[i] = as<std::string>(feature_names[i]);

    auto result = Novelty::mess(grids, refs, names);

    auto* mg = new Grid<float>(std::move(result.mess_grid));
    auto* modg = new Grid<float>(std::move(result.mod_grid));

    return List::create(
        Named("mess_grid") = XPtr<Grid<float>>(mg, true),
        Named("mod_grid") = XPtr<Grid<float>>(modg, true)
    );
}

//' Compute MESS from Min/Max Ranges
//'
//' Simplified MESS using only the min/max of reference data.
//'
//' @param grid_ptrs List of external pointers to Grid<float> objects.
//' @param var_mins  Numeric vector of minimum reference values.
//' @param var_maxs  Numeric vector of maximum reference values.
//' @return A named list with mess_grid and mod_grid (external pointers).
//' @export
// [[Rcpp::export]]
List compute_mess_range(List grid_ptrs, NumericVector var_mins,
                        NumericVector var_maxs) {

    std::vector<const Grid<float>*> grids;
    grids.reserve(grid_ptrs.size());
    for (int i = 0; i < grid_ptrs.size(); ++i) {
        XPtr<Grid<float>> gp(grid_ptrs[i]);
        grids.push_back(gp.get());
    }

    std::vector<double> mins(var_mins.begin(), var_mins.end());
    std::vector<double> maxs(var_maxs.begin(), var_maxs.end());

    auto result = Novelty::mess_range(grids, mins, maxs);

    auto* mg = new Grid<float>(std::move(result.mess_grid));
    auto* modg = new Grid<float>(std::move(result.mod_grid));

    return List::create(
        Named("mess_grid") = XPtr<Grid<float>>(mg, true),
        Named("mod_grid") = XPtr<Grid<float>>(modg, true)
    );
}
