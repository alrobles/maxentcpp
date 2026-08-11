#include <Rcpp.h>

// Enable C++17
// [[Rcpp::plugins(cpp17)]]

// Link to Eigen
// [[Rcpp::depends(RcppEigen)]]

#include "cpp/include/maxent/model_evaluation.hpp"
#include "cpp/include/maxent/projection.hpp"

using namespace Rcpp;
using namespace maxent;

// =========================================================================
// Model Evaluation
// =========================================================================

//' Compute AUC (Area Under the ROC Curve)
//'
//' Computes the Wilcoxon-Mann-Whitney AUC statistic from prediction scores
//' at presence and absence sites.
//'
//' @param presence Numeric vector of prediction scores at presence sites.
//' @param absence  Numeric vector of prediction scores at absence sites.
//' @return A named list with elements: auc, max_kappa, max_kappa_thresh.
//' @export
// [[Rcpp::export]]
List eval_auc(NumericVector presence, NumericVector absence) {
    std::vector<double> pres(presence.begin(), presence.end());
    std::vector<double> abs(absence.begin(), absence.end());
    double mk = 0.0, mkt = 0.0;
    double auc = ModelEvaluation::auc(pres, abs, &mk, &mkt);
    return List::create(
        Named("auc") = auc,
        Named("max_kappa") = mk,
        Named("max_kappa_thresh") = mkt
    );
}

//' Compute Pearson Correlation
//'
//' Computes Pearson correlation coefficient between two numeric vectors.
//'
//' @param x Numeric vector.
//' @param y Numeric vector (same length as x).
//' @return Correlation coefficient in [-1, 1].
//' @export
// [[Rcpp::export]]
double eval_correlation(NumericVector x, NumericVector y) {
    std::vector<double> vx(x.begin(), x.end());
    std::vector<double> vy(y.begin(), y.end());
    return ModelEvaluation::correlation(vx, vy);
}

//' Compute Log-Loss
//'
//' Computes average cross-entropy log-loss from predictions at
//' presence and absence sites.
//'
//' @param presence Numeric vector of prediction scores at presence sites.
//' @param absence  Numeric vector of prediction scores at absence sites.
//' @return Average log-loss value.
//' @export
// [[Rcpp::export]]
double eval_logloss(NumericVector presence, NumericVector absence) {
    std::vector<double> pres(presence.begin(), presence.end());
    std::vector<double> abs(absence.begin(), absence.end());
    return ModelEvaluation::logloss(pres, abs);
}

//' Compute Mean Squared Error
//'
//' Presence sites contribute (1-pred)^2, absence sites contribute pred^2.
//'
//' @param presence Numeric vector of prediction scores at presence sites.
//' @param absence  Numeric vector of prediction scores at absence sites.
//' @return Mean squared error.
//' @export
// [[Rcpp::export]]
double eval_square_error(NumericVector presence, NumericVector absence) {
    std::vector<double> pres(presence.begin(), presence.end());
    std::vector<double> abs(absence.begin(), absence.end());
    return ModelEvaluation::square_error(pres, abs);
}

//' Compute Misclassification Rate
//'
//' Fraction of misclassified samples at threshold 0.5.
//'
//' @param presence Numeric vector of prediction scores at presence sites.
//' @param absence  Numeric vector of prediction scores at absence sites.
//' @return Misclassification rate in [0, 1].
//' @export
// [[Rcpp::export]]
double eval_misclassification(NumericVector presence, NumericVector absence) {
    std::vector<double> pres(presence.begin(), presence.end());
    std::vector<double> abs(absence.begin(), absence.end());
    return ModelEvaluation::misclassification(pres, abs);
}

//' Full Model Evaluation
//'
//' Computes all evaluation metrics at once: AUC, correlation, log-loss,
//' squared error, misclassification, max kappa, and prevalence.
//'
//' @param presence Numeric vector of prediction scores at presence sites.
//' @param absence  Numeric vector of prediction scores at absence sites.
//' @return A named list with: auc, max_kappa, max_kappa_thresh,
//'   correlation, square_error, logloss, misclassification, prevalence.
//' @export
// [[Rcpp::export]]
List eval_model(NumericVector presence, NumericVector absence) {
    std::vector<double> pres(presence.begin(), presence.end());
    std::vector<double> abs(absence.begin(), absence.end());
    EvalResult res = ModelEvaluation::evaluate(pres, abs);
    return List::create(
        Named("auc") = res.auc,
        Named("max_kappa") = res.max_kappa,
        Named("max_kappa_thresh") = res.max_kappa_thresh,
        Named("correlation") = res.correlation,
        Named("square_error") = res.square_error,
        Named("logloss") = res.logloss,
        Named("misclassification") = res.misclassification,
        Named("prevalence") = res.prevalence
    );
}

// =========================================================================
// Java-compatible projection (matches Java Maxent / dismo output)
// =========================================================================

//' Project Model onto Grids (Java-compatible raw output)
//'
//' Applies a trained FeaturedSpace model to produce Java Maxent "raw" scores:
//'   raw_java = exp(lp - lpNorm) / densityNorm
//'
//' This matches the raw output of the Java Maxent software and the dismo
//' R package.
//'
//' @param fs_ptr         External pointer to a FeaturedSpace object.
//' @param grid_ptrs      List of external pointers to Grid<float> objects.
//' @param feature_names  Character vector of environment variable names.
//' @return External pointer to a Grid<float> with Java raw scores.
//' @export
// [[Rcpp::export]]
SEXP project_raw(SEXP fs_ptr, List grid_ptrs, CharacterVector feature_names) {
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

    auto* result = new Grid<float>(
        Projection::project_raw_java(*fs, grids, names));
    XPtr<Grid<float>> ptr(result, true);
    return ptr;
}

//' Project Model onto Grids (Java-compatible cloglog output)
//'
//' Applies the Java Maxent cloglog formula:
//'   cloglog_java = 1 - exp(-exp(H) * raw_java)
//'
//' where H is the model entropy and raw_java is the normalised probability.
//' This matches the cloglog output of Java Maxent and dismo.
//'
//' @param fs_ptr         External pointer to a FeaturedSpace object.
//' @param grid_ptrs      List of external pointers to Grid<float> objects.
//' @param feature_names  Character vector of environment variable names.
//' @return External pointer to a Grid<float> with Java cloglog scores in [0, 1].
//' @export
// [[Rcpp::export]]
SEXP project_cloglog(SEXP fs_ptr, List grid_ptrs, CharacterVector feature_names) {
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

    auto* result = new Grid<float>(
        Projection::project_cloglog_java(*fs, grids, names));
    XPtr<Grid<float>> ptr(result, true);
    return ptr;
}

//' Project Model onto Grids (Java-compatible logistic output)
//'
//' Applies the Java Maxent logistic formula:
//'   logistic_java = (exp(H) * raw_java) / (1 + exp(H) * raw_java)
//'
//' where H is the model entropy and raw_java is the normalised probability.
//' This matches the logistic output of Java Maxent and dismo.
//'
//' @param fs_ptr         External pointer to a FeaturedSpace object.
//' @param grid_ptrs      List of external pointers to Grid<float> objects.
//' @param feature_names  Character vector of environment variable names.
//' @return External pointer to a Grid<float> with Java logistic scores in [0, 1].
//' @export
// [[Rcpp::export]]
SEXP project_logistic(SEXP fs_ptr, List grid_ptrs, CharacterVector feature_names) {
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

    auto* result = new Grid<float>(
        Projection::project_logistic_java(*fs, grids, names));
    XPtr<Grid<float>> ptr(result, true);
    return ptr;
}

//' Extract Java-compatible Raw Predictions at Sample Locations
//'
//' Gets Java Maxent raw scores (raw_java = exp(lp - lpNorm) / densityNorm)
//' at specific grid cell locations.
//'
//' @param fs_ptr         External pointer to a FeaturedSpace object.
//' @param grid_ptrs      List of external pointers to Grid<float> objects.
//' @param feature_names  Character vector of environment variable names.
//' @param rows           Integer vector of row indices.
//' @param cols           Integer vector of column indices.
//' @return Numeric vector of Java raw scores. NaN for NODATA cells.
//' @export
// [[Rcpp::export]]
NumericVector extract_predictions_raw(SEXP fs_ptr, List grid_ptrs,
                                       CharacterVector feature_names,
                                       IntegerVector rows, IntegerVector cols) {
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

    std::vector<int> r(rows.begin(), rows.end());
    std::vector<int> c(cols.begin(), cols.end());

    auto result = Projection::extract_predictions_raw_java(*fs, grids, names, r, c);
    return NumericVector(result.begin(), result.end());
}
// Projection
// =========================================================================

//' Project Model onto Grids (raw output)
//'
//' Applies a trained FeaturedSpace model to environmental grids to produce
//' raw Gibbs scores.
//'
//' @param fs_ptr         External pointer to a FeaturedSpace object.
//' @param grid_ptrs      List of external pointers to Grid<float> objects.
//' @param feature_names  Character vector of environment variable names,
//'   matching the order of grid_ptrs.
//' @return External pointer to a Grid<float> with raw prediction scores.
//' @export
// [[Rcpp::export]]
SEXP project_raw_deprecated(SEXP fs_ptr, List grid_ptrs, CharacterVector feature_names) {
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

    auto* result = new Grid<float>(
        Projection::project_raw(*fs, grids, names));
    XPtr<Grid<float>> ptr(result, true);
    return ptr;
}

//' Project Model onto Grids (cloglog output)
//'
//' cloglog(x) = 1 - exp(-x). Recommended output format for Maxent v3.4+.
//'
//' @param fs_ptr         External pointer to a FeaturedSpace object.
//' @param grid_ptrs      List of external pointers to Grid<float> objects.
//' @param feature_names  Character vector of environment variable names.
//' @return External pointer to a Grid<float> with cloglog scores in [0, 1].
//' @export
// [[Rcpp::export]]
SEXP project_cloglog_deprecated(SEXP fs_ptr, List grid_ptrs, CharacterVector feature_names) {
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

    auto* result = new Grid<float>(
        Projection::project_cloglog(*fs, grids, names));
    XPtr<Grid<float>> ptr(result, true);
    return ptr;
}

//' Project Model onto Grids (logistic output)
//'
//' logistic(x) = x / (1 + x).
//'
//' @param fs_ptr         External pointer to a FeaturedSpace object.
//' @param grid_ptrs      List of external pointers to Grid<float> objects.
//' @param feature_names  Character vector of environment variable names.
//' @return External pointer to a Grid<float> with logistic scores in [0, 1].
//' @export
// [[Rcpp::export]]
SEXP project_logistic_deprecated(SEXP fs_ptr, List grid_ptrs, CharacterVector feature_names) {
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

    auto* result = new Grid<float>(
        Projection::project_logistic(*fs, grids, names));
    XPtr<Grid<float>> ptr(result, true);
    return ptr;
}

//' Extract Predictions at Sample Locations
//'
//' Gets model predictions at specific grid cell locations.
//'
//' @param fs_ptr         External pointer to a FeaturedSpace object.
//' @param grid_ptrs      List of external pointers to Grid<float> objects.
//' @param feature_names  Character vector of environment variable names.
//' @param rows           Integer vector of row indices.
//' @param cols           Integer vector of column indices.
//' @return Numeric vector of raw prediction scores. NaN for NODATA cells.
//' @export
// [[Rcpp::export]]
NumericVector extract_predictions_deprecated(SEXP fs_ptr, List grid_ptrs,
                                              CharacterVector feature_names,
                                              IntegerVector rows, IntegerVector cols) {
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

    std::vector<int> r(rows.begin(), rows.end());
    std::vector<int> c(cols.begin(), cols.end());

    auto result = Projection::extract_predictions(*fs, grids, names, r, c);
    return NumericVector(result.begin(), result.end());
}
