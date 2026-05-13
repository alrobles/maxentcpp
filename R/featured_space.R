#' Create a FeaturedSpace Object
#'
#' Constructs a MaxEnt FeaturedSpace from background point data, occurrence
#' sample indices, and a list of pre-built Feature objects.
#'
#' @param num_points     Integer: total number of background points.
#' @param sample_indices Integer vector: 0-based indices (into the background
#'   array) of the occurrence sample locations.
#' @param features       List of external pointers to Feature objects, as
#'   returned by \code{maxent_linear_feature()}, \code{maxent_hinge_feature()},
#'   \code{maxent_generate_features()}, etc.
#' @param bias_weights   Optional numeric vector of per-point bias weights
#'   (length \code{num_points}).  When supplied, background density is computed
#'   as \code{bias[i] * exp(lp[i] - lpn)} instead of the standard
#'   \code{exp(lp[i] - lpn)}.  This mirrors Java Maxent's \code{biasFile}
#'   parameter.  Pass \code{NULL} (default) for uniform (unbiased) background.
#' @return External pointer to a FeaturedSpace C++ object.
#' @export
#' @examples
#' n   <- 100L
#' idx <- 90:99  # 0-based sample indices
#' env <- seq(0, 1, length.out = n)
#' f   <- maxent_linear_feature(env, "env1")
#' fs  <- maxent_featured_space(n, idx, list(f))
maxent_featured_space <- function(num_points, sample_indices, features,
                                  bias_weights = NULL) {
    if (!is.list(features)) {
        stop("features must be a list of Feature external pointers")
    }
    bw <- if (is.null(bias_weights)) numeric(0) else as.numeric(bias_weights)
    maxent_featured_space_create(
        as.integer(num_points),
        as.integer(sample_indices),
        features,
        bw
    )
}

#' Train a MaxEnt Model
#'
#' Runs the sequential coordinate-ascent MaxEnt optimization on a FeaturedSpace.
#'
#' @param featured_space  External pointer to a FeaturedSpace object (from
#'   \code{maxent_featured_space()}).
#' @param max_iter        Maximum number of training iterations (default 500).
#' @param convergence     Convergence threshold: stop when the per-20-iteration
#'   loss improvement is below this value (default 1e-5).
#' @param beta_multiplier Regularization multiplier (default 1.0). Higher
#'   values increase regularization strength.
#' @param min_deviation   Minimum sample deviation floor used in regularization
#'   (default 0.001).
#' @return Named list with:
#'   \describe{
#'     \item{loss}{Final regularized loss (scalar).}
#'     \item{entropy}{Shannon entropy of the trained distribution.}
#'     \item{iterations}{Number of training iterations completed.}
#'     \item{converged}{Logical: whether the convergence threshold was reached.}
#'     \item{lambdas}{Numeric vector of final lambda (weight) values.}
#'   }
#' @export
#' @examples
#' n   <- 50L
#' idx <- c(5L, 15L, 25L, 35L, 45L)
#' env <- list(bio1 = runif(n), bio12 = runif(n))
#' feats <- maxent_generate_features(env, types = "linear")
#' fs  <- maxent_featured_space(n, idx, feats)
#' result <- maxent_fit(fs, max_iter = 100, convergence = 1e-5)
#' result$loss
maxent_fit <- function(featured_space,
                       max_iter        = 500L,
                       convergence     = 1e-5,
                       beta_multiplier = 1.0,
                       min_deviation   = 0.001) {
    maxent_train(
        featured_space,
        as.integer(max_iter),
        as.double(convergence),
        as.double(beta_multiplier),
        as.double(min_deviation)
    )
}

#' Predict with a Trained MaxEnt Model
#'
#' Computes raw Gibbs distribution scores for new environmental data, using
#' the feature lambdas stored in the trained FeaturedSpace.
#'
#' @param featured_space External pointer to a trained FeaturedSpace object.
#' @param newdata        Numeric matrix: one row per new point, one column per
#'   feature.  Column values must be the \emph{already-evaluated} feature
#'   values (e.g., from running \code{maxent_feature_eval()} for each feature
#'   and each point).
#' @return Numeric vector of raw (unnormalized) prediction scores.
#' @export
#' @examples
#' \donttest{
#' n   <- 50L
#' idx <- c(5L, 15L, 25L, 35L, 45L)
#' env <- list(bio1 = runif(n), bio12 = runif(n))
#' feats <- maxent_generate_features(env, types = "linear")
#' fs  <- maxent_featured_space(n, idx, feats)
#' maxent_fit(fs, max_iter = 100)
#' newdata <- matrix(runif(10), nrow = 5, ncol = 2)
#' preds <- maxent_predict_model(fs, newdata)
#' }
maxent_predict_model <- function(featured_space, newdata) {
    newdata <- as.matrix(newdata)
    maxent_predict(featured_space, newdata)
}

#' Get Model Distribution Weights
#'
#' Returns the normalized probability weights of the current MaxEnt
#' distribution over the background points.
#'
#' @param featured_space External pointer to a FeaturedSpace object.
#' @return Numeric vector of weights that sum to 1.
#' @export
maxent_model_weights <- function(featured_space) {
    maxent_get_weights(featured_space)
}

#' Get Model Entropy
#'
#' Returns the Shannon entropy of the current MaxEnt distribution.
#'
#' @param featured_space External pointer to a FeaturedSpace object.
#' @return Scalar: Shannon entropy (non-negative).
#' @export
maxent_model_entropy <- function(featured_space) {
    maxent_get_entropy(featured_space)
}

#' Get Model Loss
#'
#' Returns the current (negative log-likelihood) loss of the model.
#'
#' @param featured_space External pointer to a FeaturedSpace object.
#' @return Scalar: current loss value.
#' @export
maxent_model_loss <- function(featured_space) {
    maxent_get_loss(featured_space)
}

#' Save Model Lambdas to File
#'
#' Writes the trained model coefficients (lambdas) to a CSV file in
#' the standard Maxent .lambdas format.
#'
#' @param featured_space External pointer to a trained FeaturedSpace object.
#' @param file           Character: path to the output file.
#' @return Invisibly returns the output file path.
#' @export
#' @examples
#' \donttest{
#' n   <- 50L
#' idx <- c(5L, 15L, 25L, 35L, 45L)
#' env <- list(bio1 = runif(n), bio12 = runif(n))
#' feats <- maxent_generate_features(env, types = "linear")
#' fs  <- maxent_featured_space(n, idx, feats)
#' maxent_fit(fs, max_iter = 100)
#' maxent_save_lambdas(fs, tempfile(fileext = ".lambdas"))
#' }
maxent_save_lambdas <- function(featured_space, file) {
    maxent_write_lambdas(featured_space, as.character(file))
    invisible(file)
}

#' Load Model Lambdas from File
#'
#' Reads model coefficients from a .lambdas file and applies them to
#' a FeaturedSpace that was created with the same features.
#'
#' @param featured_space External pointer to a FeaturedSpace object (must have
#'   features with the same names as those in the file).
#' @param file           Character: path to the lambdas file.
#' @return Invisibly returns the FeaturedSpace external pointer (updated
#'   in-place).
#' @export
#' @examples
#' \donttest{
#' n   <- 50L
#' idx <- c(5L, 15L, 25L, 35L, 45L)
#' env <- list(bio1 = runif(n), bio12 = runif(n))
#' feats <- maxent_generate_features(env, types = "linear")
#' fs  <- maxent_featured_space(n, idx, feats)
#' maxent_fit(fs, max_iter = 100)
#' f <- tempfile(fileext = ".lambdas")
#' maxent_save_lambdas(fs, f)
#' maxent_load_lambdas(fs, f)
#' }
maxent_load_lambdas <- function(featured_space, file) {
    maxent_read_lambdas(featured_space, as.character(file))
    invisible(featured_space)
}

#' Get FeaturedSpace Information
#'
#' Returns basic metadata about a FeaturedSpace object.
#'
#' @param featured_space External pointer to a FeaturedSpace object.
#' @return Named list with: \code{num_points}, \code{num_samples},
#'   \code{num_features}, \code{density_normalizer},
#'   \code{linear_predictor_normalizer}.
#' @export
maxent_space_info <- function(featured_space) {
    maxent_featured_space_info(featured_space)
}

#' Extract Lambda Values from a Maxent Run Result
#'
#' Retrieves the trained lambda (weight) coefficients from the output of
#' \code{\link{maxent_run}}, returning them as a named numeric vector.
#' Each element is the lambda value for the corresponding feature, and the
#' name of each element is the feature name (e.g. \code{"bio1"},
#' \code{"bio1^2"}, \code{"bio1'1"}).
#'
#' The function reads lambdas directly from the trained model object, so
#' it also works correctly after reloading coefficients with
#' \code{\link{maxent_load_lambdas}}.
#'
#' @param run_result A named list as returned by \code{\link{maxent_run}}.
#'   Must contain an element \code{model} holding the trained FeaturedSpace
#'   external pointer.
#' @return A named numeric vector of lambda values, one per feature.  Names
#'   are the feature names as stored in the model.
#' @export
#' @examples
#' \donttest{
#' if (requireNamespace("terra", quietly = TRUE)) {
#'   stack_path      <- system.file("extdata", "stack_1_12_crop.rds",
#'                                  package = "maxentcpp")
#'   example_rasters <- terra::unwrap(readRDS(stack_path))
#'   grids <- list(
#'     bio1  = maxent_grid_from_terra(example_rasters[[1]]),
#'     bio12 = maxent_grid_from_terra(example_rasters[[2]])
#'   )
#'   data(example_occ_df)
#'
#'   result <- maxent_run(
#'     species    = "Abeillia_abeillei",
#'     env_grids  = grids,
#'     occ_df     = example_occ_df,
#'     output_dir = tempdir(),
#'     lon_col    = "long",
#'     lat_col    = "lat")
#'
#'   lambdas <- maxent_extract_lambdas(result)
#'   print(lambdas)
#' }
#' }
maxent_extract_lambdas <- function(run_result) {
    if (!is.list(run_result) || !"model" %in% names(run_result)) {
        stop("'run_result' must be the list returned by maxent_run()")
    }

    feature_ptrs <- attr(run_result$model, "feature_ptrs")
    if (is.null(feature_ptrs)) {
        stop("'run_result$model' has no 'feature_ptrs' attribute; ",
             "was it created by maxent_run() or maxent_featured_space()?")
    }

    n          <- length(feature_ptrs)
    feat_names <- character(n)
    lambdas    <- numeric(n)

    for (i in seq_len(n)) {
        info          <- feature_get_info(feature_ptrs[[i]])
        feat_names[i] <- info$name
        lambdas[i]    <- info$lambda
    }

    names(lambdas) <- feat_names
    lambdas
}
