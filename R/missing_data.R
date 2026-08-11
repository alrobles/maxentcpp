#' Remove Samples with Missing Environmental Data
#'
#' Filters out samples (occurrence or background points) that have
#' \code{NA}, \code{NaN}, or a designated NODATA sentinel value in any
#' of their environmental variable values.  This mirrors the Java
#' Maxent \code{hasAllData()} check in \code{FeaturedSpace.java} and the
#' \code{NODATA_value = -9999} sentinel used throughout the Java code.
#'
#' @param env_vals Named list of numeric vectors (one per environmental
#'   variable).  All vectors must have the same length.
#' @param nodata_value Numeric: sentinel value treated as missing
#'   (default \code{-9999}).
#' @return An integer vector of 1-based indices of samples that have
#'   valid (non-missing) values for \emph{all} environmental variables.
#' @export
#' @examples
#' env <- list(
#'   temp  = c(15, NA, 25, 18, -9999),
#'   precip = c(100, 200, 150, 80, 300)
#' )
#' valid <- maxent_complete_cases(env)
#' # Returns c(1, 3, 4) -- indices 2 (NA) and 5 (-9999) are removed
maxent_complete_cases <- function(env_vals, nodata_value = -9999) {
    if (!is.list(env_vals) || length(env_vals) == 0L) {
        stop("env_vals must be a non-empty named list of numeric vectors")
    }
    n <- length(env_vals[[1]])
    valid <- rep(TRUE, n)
    for (v in env_vals) {
        if (length(v) != n) {
            stop("all environmental variable vectors must have the same length")
        }
        valid <- valid & !is.na(v) & !is.nan(v) & (v != nodata_value)
    }
    which(valid)
}

#' Replace Missing Values with Variable Means
#'
#' For each environmental variable, replaces \code{NA}, \code{NaN}, and
#' NODATA sentinel values with the mean of the valid values.  This
#' mirrors the Java Maxent partial-data handling where
#' \code{FeaturedSpace.setSampleExpectations()} uses mean substitution
#' for samples with missing feature values.
#'
#' @param env_vals Named list of numeric vectors (one per variable).
#' @param nodata_value Numeric: sentinel value treated as missing
#'   (default \code{-9999}).
#' @return Named list of numeric vectors with missing values replaced.
#' @export
#' @examples
#' env <- list(
#'   temp  = c(15, NA, 25, 18, -9999),
#'   precip = c(100, 200, 150, 80, 300)
#' )
#' filled <- maxent_impute_means(env)
#' filled$temp[2]  # mean of valid values replaces NA
maxent_impute_means <- function(env_vals, nodata_value = -9999) {
    if (!is.list(env_vals) || length(env_vals) == 0L) {
        stop("env_vals must be a non-empty named list of numeric vectors")
    }
    lapply(env_vals, function(v) {
        missing <- is.na(v) | is.nan(v) | (v == nodata_value)
        if (any(missing)) {
            v[missing] <- mean(v[!missing], na.rm = TRUE)
        }
        v
    })
}
