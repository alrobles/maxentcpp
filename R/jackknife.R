#' Jackknife Variable Importance Analysis
#'
#' Performs a leave-one-variable-out jackknife analysis following the
#' procedure in Java Maxent's \code{Runner.jackknifeGain()}.  For each
#' environmental variable, two additional models are trained:
#' \enumerate{
#'   \item \strong{Leave-one-out}: the variable is excluded and the model
#'     is trained on all remaining variables.
#'   \item \strong{Only-one}: the model is trained using \emph{only} that
#'     single variable.
#' }
#' The resulting training gain and AUC are compared to the full model to
#' assess variable importance.
#'
#' @param env_vals    Named list of numeric vectors (one per environmental
#'   variable, length = total points: background + occurrences).
#' @param sample_indices Integer vector: 0-based indices of occurrence
#'   samples within \code{env_vals}.
#' @param num_points  Integer: total number of points (background +
#'   occurrences).
#' @param types       Character vector of feature types (default
#'   \code{c("linear", "quadratic", "hinge")}).
#' @param n_hinges    Integer: number of hinge knots (default 15).
#' @param max_iter    Integer: maximum training iterations (default 500).
#' @param categorical Character vector of variable names that are
#'   categorical (default \code{NULL}).
#' @param bias_weights Optional numeric vector of per-point bias weights
#'   (default \code{NULL}).
#' @return A \code{data.frame} with columns:
#'   \describe{
#'     \item{variable}{Variable name.}
#'     \item{gain_without}{Training gain of the model with this variable
#'       excluded.}
#'     \item{gain_only}{Training gain of the model using only this
#'       variable.}
#'     \item{gain_full}{Training gain of the full model (same for all
#'       rows).}
#'   }
#' @export
#' @examples
#' \dontrun{
#' env <- list(
#'   temp  = rnorm(110),
#'   precip = rnorm(110),
#'   elev  = rnorm(110)
#' )
#' jk <- maxent_jackknife(env, sample_indices = 100:109,
#'                         num_points = 110L)
#' print(jk)
#' }
maxent_jackknife <- function(env_vals,
                             sample_indices,
                             num_points,
                             types      = c("linear", "quadratic", "hinge"),
                             n_hinges   = 15L,
                             max_iter   = 500L,
                             categorical = NULL,
                             bias_weights = NULL) {
    if (!is.list(env_vals) || is.null(names(env_vals))) {
        stop("env_vals must be a named list of numeric vectors")
    }
    var_names <- names(env_vals)
    n_vars    <- length(var_names)

    bw <- if (is.null(bias_weights)) numeric(0) else as.numeric(bias_weights)

    # --- Full model (all variables) -------------------------------------------
    full_features <- maxent_generate_features(
        env_vals, types = types, n_hinges = n_hinges, categorical = categorical)
    full_fs <- maxent_featured_space(
        as.integer(num_points), as.integer(sample_indices),
        full_features, bias_weights = if (length(bw) > 0) bw else NULL)
    full_fit <- maxent_fit(full_fs, max_iter = as.integer(max_iter))
    full_gain <- full_fit$loss

    # --- Leave-one-out runs ---------------------------------------------------
    gain_without <- numeric(n_vars)
    for (i in seq_len(n_vars)) {
        reduced_env <- env_vals[-i]
        reduced_cat <- NULL
        if (!is.null(categorical)) {
            reduced_cat <- setdiff(categorical, var_names[i])
            if (length(reduced_cat) == 0L) reduced_cat <- NULL
        }
        feats <- maxent_generate_features(
            reduced_env, types = types, n_hinges = n_hinges,
            categorical = reduced_cat)
        fs <- maxent_featured_space(
            as.integer(num_points), as.integer(sample_indices),
            feats, bias_weights = if (length(bw) > 0) bw else NULL)
        fit <- maxent_fit(fs, max_iter = as.integer(max_iter))
        gain_without[i] <- fit$loss
    }

    # --- Only-one runs --------------------------------------------------------
    gain_only <- numeric(n_vars)
    for (i in seq_len(n_vars)) {
        single_env <- env_vals[i]
        single_cat <- NULL
        if (!is.null(categorical) && var_names[i] %in% categorical) {
            single_cat <- var_names[i]
        }
        feats <- maxent_generate_features(
            single_env, types = types, n_hinges = n_hinges,
            categorical = single_cat)
        fs <- maxent_featured_space(
            as.integer(num_points), as.integer(sample_indices),
            feats, bias_weights = if (length(bw) > 0) bw else NULL)
        fit <- maxent_fit(fs, max_iter = as.integer(max_iter))
        gain_only[i] <- fit$loss
    }

    data.frame(
        variable     = var_names,
        gain_without = gain_without,
        gain_only    = gain_only,
        gain_full    = rep(full_gain, n_vars),
        stringsAsFactors = FALSE
    )
}
