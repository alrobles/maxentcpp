#' @useDynLib maxentcpp, .registration = TRUE
#' @importFrom Rcpp sourceCpp
NULL

#' Create a Linear Feature
#'
#' Creates a linear (normalized) feature that evaluates to
#' \code{(values[i] - min) / (max - min)}. Returns 0 when \code{min == max}.
#'
#' @param values Numeric vector of environmental variable values.
#' @param name Character string: feature name/identifier.
#' @param min_val Minimum value for normalization. If \code{NULL} (default),
#'   computed as \code{min(values)}.
#' @param max_val Maximum value for normalization. If \code{NULL} (default),
#'   computed as \code{max(values)}.
#' @return External pointer to a LinearFeature C++ object.
#' @export
#' @examples
#' vals <- c(0, 5, 10, 3)
#' f <- maxent_linear_feature(vals, "temperature")
#' maxent_feature_eval(f, 1)  # index 1 (R) -> 0-based index 0
maxent_linear_feature <- function(values, name, min_val = NULL, max_val = NULL) {
    values <- as.numeric(values)
    if (is.null(min_val)) min_val <- min(values)
    if (is.null(max_val)) max_val <- max(values)
    create_linear_feature(values, name, min_val, max_val)
}

#' Create a Quadratic Feature
#'
#' Creates a quadratic feature that evaluates to \code{linear_val^2} where
#' \code{linear_val = (values[i] - min) / (max - min)}.
#'
#' @param values Numeric vector of environmental variable values.
#' @param name Character string: feature name/identifier.
#' @param min_val Minimum value for normalization. If \code{NULL} (default),
#'   computed as \code{min(values)}.
#' @param max_val Maximum value for normalization. If \code{NULL} (default),
#'   computed as \code{max(values)}.
#' @return External pointer to a QuadraticFeature C++ object.
#' @export
#' @examples
#' vals <- c(0, 5, 10)
#' f <- maxent_quadratic_feature(vals, "temperature_sq")
#' maxent_feature_eval(f, 2)  # evaluates at index 2 (1-based -> 0-based: 1)
maxent_quadratic_feature <- function(values, name, min_val = NULL, max_val = NULL) {
    values <- as.numeric(values)
    if (is.null(min_val)) min_val <- min(values)
    if (is.null(max_val)) max_val <- max(values)
    create_quadratic_feature(values, name, min_val, max_val)
}

#' Create a Product Feature
#'
#' Creates an interaction feature between two environmental variables:
#' \code{eval(i) = norm(values1[i]) * norm(values2[i])}.
#'
#' @param values1 Numeric vector for the first environmental variable.
#' @param values2 Numeric vector for the second environmental variable
#'   (must have the same length as \code{values1}).
#' @param name Character string: feature name/identifier.
#' @param min1 Minimum of the first variable. If \code{NULL} (default),
#'   computed as \code{min(values1)}.
#' @param max1 Maximum of the first variable. If \code{NULL} (default),
#'   computed as \code{max(values1)}.
#' @param min2 Minimum of the second variable. If \code{NULL} (default),
#'   computed as \code{min(values2)}.
#' @param max2 Maximum of the second variable. If \code{NULL} (default),
#'   computed as \code{max(values2)}.
#' @return External pointer to a ProductFeature C++ object.
#' @export
#' @examples
#' temp <- c(0, 5, 10)
#' prec <- c(100, 200, 150)
#' f <- maxent_product_feature(temp, prec, "temp_x_prec")
#' maxent_feature_eval(f, 2)
maxent_product_feature <- function(values1, values2, name,
                                   min1 = NULL, max1 = NULL,
                                   min2 = NULL, max2 = NULL) {
    values1 <- as.numeric(values1)
    values2 <- as.numeric(values2)
    if (length(values1) != length(values2)) {
        stop("values1 and values2 must have the same length")
    }
    if (is.null(min1)) min1 <- min(values1)
    if (is.null(max1)) max1 <- max(values1)
    if (is.null(min2)) min2 <- min(values2)
    if (is.null(max2)) max2 <- max(values2)
    create_product_feature(values1, values2, name, min1, max1, min2, max2)
}

#' Create a Threshold Feature
#'
#' Creates a binary step feature: \code{eval(i) = 1} if
#' \code{values[i] > threshold}, else \code{0}.
#'
#' @param values Numeric vector of environmental variable values.
#' @param name Character string: feature name/identifier.
#' @param threshold The threshold value.
#' @return External pointer to a ThresholdFeature C++ object.
#' @export
#' @examples
#' vals <- c(1, 5, 10, 3)
#' f <- maxent_threshold_feature(vals, "temperature_threshold", threshold = 5)
#' maxent_feature_eval(f, 3)  # values[3] = 10 > 5 -> 1
maxent_threshold_feature <- function(values, name, threshold) {
    values <- as.numeric(values)
    create_threshold_feature(values, name, threshold)
}

#' Create a Hinge Feature
#'
#' Creates a piecewise-linear hinge feature.
#'
#' \strong{Forward hinge} (\code{reverse = FALSE}):
#' \code{eval(i) = max(0, (values[i] - min_knot) / (max_knot - min_knot))}
#'
#' \strong{Reverse hinge} (\code{reverse = TRUE}):
#' \code{eval(i) = max(0, (max_knot - values[i]) / (max_knot - min_knot))}
#'
#' @param values Numeric vector of environmental variable values.
#' @param name Character string: feature name/identifier.
#' @param min_knot Lower knot of the hinge.
#' @param max_knot Upper knot of the hinge (must be strictly greater than
#'   \code{min_knot}).
#' @param reverse Logical; if \code{TRUE}, use reverse hinge. Default is
#'   \code{FALSE} (forward hinge).
#' @return External pointer to a HingeFeature C++ object.
#' @export
#' @examples
#' vals <- c(0, 5, 10, 3)
#' f <- maxent_hinge_feature(vals, "temperature_hinge", min_knot = 2, max_knot = 8)
#' maxent_feature_eval(f, 2)  # values[2] = 5 -> (5-2)/(8-2) = 0.5
maxent_hinge_feature <- function(values, name, min_knot, max_knot, reverse = FALSE) {
    values <- as.numeric(values)
    if (min_knot >= max_knot) {
        stop("min_knot must be strictly less than max_knot")
    }
    create_hinge_feature(values, name, min_knot, max_knot, reverse)
}

#' Evaluate a Feature at a Given Index
#'
#' Evaluates the feature function at the specified index (1-based, as is
#' standard in R). Internally converts to 0-based indexing for C++.
#'
#' @param feature External pointer to a Feature C++ object.
#' @param index 1-based integer index into the data vector.
#' @return Numeric scalar: the feature value at that index.
#' @export
#' @examples
#' vals <- c(0, 5, 10)
#' f <- maxent_linear_feature(vals, "temp")
#' maxent_feature_eval(f, 2)  # 5/10 = 0.5
maxent_feature_eval <- function(feature, index) {
    if (length(index) != 1L || is.na(index) || !is.finite(index)) {
        stop("index must be a single finite value")
    }

    index_int <- as.integer(index)
    if (!identical(as.numeric(index_int), as.numeric(index))) {
        stop("index must be a whole number")
    }

    size <- maxent_feature_info(feature)$size
    if (index_int < 1L || index_int > size) {
        stop(sprintf("index must be between 1 and %d", size))
    }

    feature_eval(feature, index_int - 1L)
}

#' Get Feature Properties
#'
#' Returns a list of metadata for a feature object.
#'
#' @param feature External pointer to a Feature C++ object.
#' @return Named list with elements: \code{name}, \code{type}, \code{lambda},
#'   \code{min}, \code{max}, \code{size}.
#' @export
#' @examples
#' vals <- c(0, 5, 10)
#' f <- maxent_linear_feature(vals, "temp")
#' maxent_feature_info(f)
maxent_feature_info <- function(feature) {
    feature_get_info(feature)
}

#' Generate Features from Environmental Variable Data
#'
#' Automatically generates all configured feature types from one or more
#' environmental variable vectors.
#'
#' @param data Named list of numeric vectors, one per environmental variable.
#' @param types Character vector of feature types to generate. Valid values:
#'   \code{"linear"}, \code{"quadratic"}, \code{"product"},
#'   \code{"threshold"}, \code{"hinge"}. Defaults to all types.
#' @param n_thresholds Integer; number of threshold knots per variable
#'   (default: 10).
#' @param n_hinges Integer; number of hinge knots per variable (default: 10).
#' @return Named list of external pointers to Feature C++ objects.
#' @export
#' @examples
#' env_data <- list(
#'   temperature   = c(15, 20, 25, 18, 22),
#'   precipitation = c(100, 200, 150, 80, 300)
#' )
#' features <- maxent_generate_features(env_data, types = c("linear", "hinge"))
#' length(features)
maxent_generate_features <- function(
    data,
    types = c("linear", "quadratic", "product", "threshold", "hinge"),
    n_thresholds = 10L,
    n_hinges = 10L)
{
    if (!is.list(data) || is.null(names(data))) {
        stop("data must be a named list of numeric vectors")
    }
    data <- lapply(data, as.numeric)
    generate_features(data, types, as.integer(n_thresholds), as.integer(n_hinges))
}
