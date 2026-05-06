#' Compute AUC (Area Under the ROC Curve)
#'
#' Computes the Wilcoxon-Mann-Whitney AUC statistic from prediction scores
#' at presence and absence sites. Also returns max-Kappa and its threshold.
#'
#' @param presence Numeric vector of prediction scores at presence sites.
#' @param absence  Numeric vector of prediction scores at absence sites.
#' @return A named list with elements:
#'   \describe{
#'     \item{auc}{AUC value in [0, 1]}
#'     \item{max_kappa}{Best Cohen's Kappa found}
#'     \item{max_kappa_thresh}{Threshold at best Kappa}
#'   }
#' @export
#' @examples
#' \dontrun{
#' result <- maxent_auc(c(0.8, 0.9, 1.0), c(0.1, 0.2, 0.3))
#' result$auc  # 1.0
#' }
maxent_auc <- function(presence, absence) {
    eval_auc(as.numeric(presence), as.numeric(absence))
}

#' Compute Pearson Correlation
#'
#' Computes the Pearson correlation coefficient between two numeric vectors.
#'
#' @param x Numeric vector.
#' @param y Numeric vector (same length as x).
#' @return Correlation coefficient in [-1, 1].
#' @export
#' @examples
#' \dontrun{
#' maxent_correlation(c(1, 2, 3), c(2, 4, 6))  # 1.0
#' }
maxent_correlation <- function(x, y) {
    eval_correlation(as.numeric(x), as.numeric(y))
}

#' Compute Log-Loss
#'
#' Computes the average cross-entropy log-loss from predictions at
#' presence and absence sites.
#'
#' @param presence Numeric vector of prediction scores at presence sites.
#' @param absence  Numeric vector of prediction scores at absence sites.
#' @return Average log-loss value (lower is better).
#' @export
#' @examples
#' \dontrun{
#' maxent_logloss(c(0.9, 0.8), c(0.1, 0.2))
#' }
maxent_logloss <- function(presence, absence) {
    eval_logloss(as.numeric(presence), as.numeric(absence))
}

#' Compute Mean Squared Error
#'
#' Presence sites contribute (1 - pred)^2, absence sites contribute pred^2.
#'
#' @param presence Numeric vector of prediction scores at presence sites.
#' @param absence  Numeric vector of prediction scores at absence sites.
#' @return Mean squared error.
#' @export
#' @examples
#' \dontrun{
#' maxent_square_error(c(1.0, 1.0), c(0.0, 0.0))  # 0.0
#' }
maxent_square_error <- function(presence, absence) {
    eval_square_error(as.numeric(presence), as.numeric(absence))
}

#' Compute Misclassification Rate
#'
#' Fraction of misclassified samples at threshold 0.5.
#'
#' @param presence Numeric vector of prediction scores at presence sites.
#' @param absence  Numeric vector of prediction scores at absence sites.
#' @return Misclassification rate in [0, 1].
#' @export
#' @examples
#' \dontrun{
#' maxent_misclassification(c(0.8, 0.9), c(0.1, 0.2))  # 0.0
#' }
maxent_misclassification <- function(presence, absence) {
    eval_misclassification(as.numeric(presence), as.numeric(absence))
}

#' Full Model Evaluation
#'
#' Computes all evaluation metrics at once: AUC, correlation, log-loss,
#' squared error, misclassification, max Kappa, and prevalence.
#'
#' @param presence Numeric vector of prediction scores at presence sites.
#' @param absence  Numeric vector of prediction scores at absence sites.
#' @return A named list with:
#'   \describe{
#'     \item{auc}{AUC value}
#'     \item{max_kappa}{Best Cohen's Kappa}
#'     \item{max_kappa_thresh}{Threshold at best Kappa}
#'     \item{correlation}{Pearson correlation with labels}
#'     \item{square_error}{Mean squared error}
#'     \item{logloss}{Cross-entropy log-loss}
#'     \item{misclassification}{Misclassification rate}
#'     \item{prevalence}{Fraction of presence sites}
#'   }
#' @export
#' @examples
#' \dontrun{
#' res <- maxent_evaluate(c(0.9, 0.85, 0.95), c(0.1, 0.15, 0.2))
#' res$auc          # 1.0
#' res$correlation  # > 0
#' }
maxent_evaluate <- function(presence, absence) {
    eval_model(as.numeric(presence), as.numeric(absence))
}

#' Project Model onto Grids (Raw Output, deprecated)
#'
#' Applies a trained FeaturedSpace model to environmental grids to produce
#' raw Gibbs scores for every cell.
#'
#' @param model         External pointer to a FeaturedSpace object.
#' @param env_grids     List of external pointers to Grid<float> objects.
#' @param feature_names Character vector of environment variable names,
#'   matching the order of env_grids.
#' @return External pointer to a Grid<float> with raw prediction scores.
#' @keywords internal
maxent_project_raw_deprecated <- function(model, env_grids, feature_names) {
    project_raw_deprecated(model, env_grids, as.character(feature_names))
}

#' Project Model onto Grids (Cloglog Output, deprecated)
#'
#' cloglog(x) = 1 - exp(-x). Produces values in [0, 1].
#'
#' @param model         External pointer to a FeaturedSpace object.
#' @param env_grids     List of external pointers to Grid<float> objects.
#' @param feature_names Character vector of environment variable names.
#' @return External pointer to a Grid<float> with cloglog scores.
#' @keywords internal
maxent_project_cloglog_deprecated <- function(model, env_grids, feature_names) {
    project_cloglog_deprecated(model, env_grids, as.character(feature_names))
}

#' Project Model onto Grids (Logistic Output, deprecated)
#'
#' logistic(x) = x / (1 + x). Produces values in [0, 1].
#'
#' @param model         External pointer to a FeaturedSpace object.
#' @param env_grids     List of external pointers to Grid<float> objects.
#' @param feature_names Character vector of environment variable names.
#' @return External pointer to a Grid<float> with logistic scores.
#' @keywords internal
maxent_project_logistic_deprecated <- function(model, env_grids, feature_names) {
    project_logistic_deprecated(model, env_grids, as.character(feature_names))
}

#' Extract Predictions at Sample Locations (deprecated)
#'
#' Gets model predictions at specific grid cell locations.
#'
#' @param model         External pointer to a FeaturedSpace object.
#' @param env_grids     List of external pointers to Grid<float> objects.
#' @param feature_names Character vector of environment variable names.
#' @param rows          Integer vector of row indices.
#' @param cols          Integer vector of column indices.
#' @return Numeric vector of raw prediction scores. NaN for NODATA cells.
#' @keywords internal
maxent_extract_predictions_deprecated <- function(model, env_grids, feature_names,
                                                   rows, cols) {
    extract_predictions_deprecated(model, env_grids, as.character(feature_names),
                                   as.integer(rows), as.integer(cols))
}

# ---------------------------------------------------------------------------
# Java-compatible prediction APIs (match Java Maxent / dismo output)
# These are now the default implementations.
# ---------------------------------------------------------------------------

#' Project Model onto Grids (Raw Output)
#'
#' Produces Java Maxent "raw" scores for every grid cell:
#' \deqn{raw = \frac{exp(lp - lpNorm)}{densityNorm}}
#'
#' This matches the raw output of the Java Maxent software and the
#' \pkg{dismo} R package.  See \code{vignette("PREDICTION_SCALES")} or
#' \code{docs/PREDICTION_SCALES.md} for a full description of prediction
#' scales.
#'
#' @param model         External pointer to a FeaturedSpace object.
#' @param env_grids     List of external pointers to Grid<float> objects.
#' @param feature_names Character vector of environment variable names.
#' @return External pointer to a Grid<float> with Java raw scores.
#' @export
#' @seealso \code{\link{maxent_project_cloglog}},
#'   \code{\link{maxent_project_logistic}}
maxent_project_raw <- function(model, env_grids, feature_names) {
    project_raw(model, env_grids, as.character(feature_names))
}

#' Project Model onto Grids (Cloglog Output)
#'
#' Applies the Java Maxent cloglog transform to grid predictions:
#' \deqn{cloglog = 1 - exp(-exp(H) \cdot raw)}
#'
#' where \eqn{H} is the model entropy and \eqn{raw} is the
#' normalised probability.  This matches the cloglog output of Java
#' Maxent and \pkg{dismo}, and is the recommended output for reporting.
#'
#' @param model         External pointer to a FeaturedSpace object.
#' @param env_grids     List of external pointers to Grid<float> objects.
#' @param feature_names Character vector of environment variable names.
#' @return External pointer to a Grid<float> with cloglog scores in [0, 1].
#' @export
#' @seealso \code{\link{maxent_project_raw}},
#'   \code{\link{maxent_project_logistic}}
maxent_project_cloglog <- function(model, env_grids, feature_names) {
    project_cloglog(model, env_grids, as.character(feature_names))
}

#' Project Model onto Grids (Logistic Output)
#'
#' Applies the Java Maxent logistic transform to grid predictions:
#' \deqn{logistic = \frac{exp(H) \cdot raw}{1 + exp(H) \cdot raw}}
#'
#' where \eqn{H} is the model entropy and \eqn{raw} is the
#' normalised probability.  This matches the logistic output of Java
#' Maxent and \pkg{dismo}.
#'
#' @param model         External pointer to a FeaturedSpace object.
#' @param env_grids     List of external pointers to Grid<float> objects.
#' @param feature_names Character vector of environment variable names.
#' @return External pointer to a Grid<float> with logistic scores in [0, 1].
#' @export
#' @seealso \code{\link{maxent_project_raw}},
#'   \code{\link{maxent_project_cloglog}}
maxent_project_logistic <- function(model, env_grids, feature_names) {
    project_logistic(model, env_grids, as.character(feature_names))
}

#' Extract Raw Predictions at Sample Locations
#'
#' Gets Java Maxent raw scores at specific grid cell locations:
#' \deqn{raw = \frac{exp(lp - lpNorm)}{densityNorm}}
#'
#' This matches the raw output of Java Maxent and \pkg{dismo}.
#'
#' @param model         External pointer to a FeaturedSpace object.
#' @param env_grids     List of external pointers to Grid<float> objects.
#' @param feature_names Character vector of environment variable names.
#' @param rows          Integer vector of row indices.
#' @param cols          Integer vector of column indices.
#' @return Numeric vector of Java raw scores. NaN for NODATA cells.
#' @export
#' @seealso \code{\link{maxent_project_raw}}
maxent_extract_predictions_raw <- function(model, env_grids, feature_names,
                                           rows, cols) {
    extract_predictions_raw(model, env_grids, as.character(feature_names),
                            as.integer(rows), as.integer(cols))
}

#' Extract Cloglog Predictions at Sample Locations
#'
#' Gets Java Maxent cloglog scores at specific grid cell locations:
#' \deqn{cloglog = 1 - exp(-exp(H) \cdot raw)}
#'
#' @param model         External pointer to a FeaturedSpace object.
#' @param env_grids     List of external pointers to Grid<float> objects.
#' @param feature_names Character vector of environment variable names.
#' @param rows          Integer vector of row indices.
#' @param cols          Integer vector of column indices.
#' @return Numeric vector of cloglog scores in [0, 1]. NaN for NODATA cells.
#' @export
#' @seealso \code{\link{maxent_extract_predictions_raw}},
#'   \code{\link{maxent_project_cloglog}}
maxent_extract_predictions_cloglog <- function(model, env_grids,
                                               feature_names, rows, cols) {
    raw <- maxent_extract_predictions_raw(
        model, env_grids, feature_names, rows, cols)
    H    <- maxent_model_entropy(model)
    expH <- exp(H)
    1.0 - exp(-expH * raw)
}

#' Extract Logistic Predictions at Sample Locations
#'
#' Gets Java Maxent logistic scores at specific grid cell locations:
#' \deqn{logistic = \frac{exp(H) \cdot raw}{1 + exp(H) \cdot raw}}
#'
#' @param model         External pointer to a FeaturedSpace object.
#' @param env_grids     List of external pointers to Grid<float> objects.
#' @param feature_names Character vector of environment variable names.
#' @param rows          Integer vector of row indices.
#' @param cols          Integer vector of column indices.
#' @return Numeric vector of logistic scores in [0, 1]. NaN for NODATA cells.
#' @export
#' @seealso \code{\link{maxent_extract_predictions_raw}},
#'   \code{\link{maxent_project_logistic}}
maxent_extract_predictions_logistic <- function(model, env_grids,
                                                feature_names, rows, cols) {
    raw   <- maxent_extract_predictions_raw(
        model, env_grids, feature_names, rows, cols)
    H     <- maxent_model_entropy(model)
    expH  <- exp(H)
    scaled <- expH * raw
    scaled / (1.0 + scaled)
}
