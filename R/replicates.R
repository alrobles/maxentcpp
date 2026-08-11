#' Cross-Validation for Maxent Models
#'
#' Splits occurrence data into \code{k} folds and trains one model per
#' fold using the remaining folds for training and the held-out fold for
#' testing.  This mirrors Java Maxent's \code{SampleSet.splitForCV()}.
#'
#' @param env_vals    Named list of numeric vectors (one per environmental
#'   variable, length = total points: background + occurrences).
#' @param sample_indices Integer vector: 0-based indices of occurrence
#'   samples within \code{env_vals}.
#' @param num_points  Integer: total number of points (background +
#'   occurrences).
#' @param k           Integer: number of folds (default 5).
#' @param types       Character vector of feature types (default
#'   \code{c("linear", "quadratic", "hinge")}).
#' @param n_hinges    Integer: number of hinge knots (default 15).
#' @param max_iter    Integer: maximum training iterations (default 500).
#' @param seed        Integer: random seed for fold assignment (default 42).
#' @param categorical Character vector of variable names that are
#'   categorical (default \code{NULL}).
#' @param bias_weights Optional numeric vector of per-point bias weights
#'   (default \code{NULL}).
#' @return A named list with:
#'   \describe{
#'     \item{fold_results}{A list of per-fold result lists, each containing
#'       \code{fold}, \code{train_gain}, \code{n_train}, \code{n_test},
#'       and \code{lambdas}.}
#'     \item{summary}{A \code{data.frame} with per-fold and overall
#'       mean/sd statistics.}
#'   }
#' @export
#' @examples
#' \dontrun{
#' env <- list(temp = rnorm(110), precip = rnorm(110))
#' cv <- maxent_cross_validate(env, sample_indices = 100:109,
#'                              num_points = 110L, k = 5L)
#' print(cv$summary)
#' }
maxent_cross_validate <- function(env_vals,
                                  sample_indices,
                                  num_points,
                                  k          = 5L,
                                  types      = c("linear", "quadratic", "hinge"),
                                  n_hinges   = 15L,
                                  max_iter   = 500L,
                                  seed       = 42L,
                                  categorical = NULL,
                                  bias_weights = NULL) {
    if (!is.list(env_vals) || is.null(names(env_vals))) {
        stop("env_vals must be a named list of numeric vectors")
    }
    k <- as.integer(k)
    n_occ <- length(sample_indices)
    if (k < 2L) stop("k must be >= 2")
    if (n_occ < k) stop("fewer occurrence samples than folds")

    set.seed(seed)
    perm <- sample.int(n_occ)
    fold_assign <- ((perm - 1L) %% k) + 1L

    bw <- if (is.null(bias_weights)) numeric(0) else as.numeric(bias_weights)

    fold_results <- vector("list", k)

    for (fold in seq_len(k)) {
        train_occ_pos <- which(fold_assign != fold)
        test_occ_pos  <- which(fold_assign == fold)
        train_occ_idx <- sample_indices[train_occ_pos]
        test_occ_idx  <- sample_indices[test_occ_pos]

        features <- maxent_generate_features(
            env_vals, types = types, n_hinges = n_hinges,
            categorical = categorical)

        train_fs <- maxent_featured_space(
            as.integer(num_points), as.integer(train_occ_idx),
            features, bias_weights = if (length(bw) > 0) bw else NULL)
        train_fit <- maxent_fit(train_fs, max_iter = as.integer(max_iter))

        fold_results[[fold]] <- list(
            fold       = fold,
            train_gain = train_fit$loss,
            n_train    = length(train_occ_idx),
            n_test     = length(test_occ_idx),
            lambdas    = train_fit$lambdas
        )
    }

    train_gains <- vapply(fold_results, `[[`, numeric(1), "train_gain")

    summary_df <- data.frame(
        fold       = c(seq_len(k), NA),
        train_gain = c(train_gains, mean(train_gains, na.rm = TRUE)),
        statistic  = c(rep("fold", k), "mean"),
        stringsAsFactors = FALSE
    )

    list(
        fold_results = fold_results,
        summary      = summary_df
    )
}

#' Replicate Runs for Maxent Models
#'
#' Trains multiple replicate models using either bootstrap sampling
#' or subsample splitting of occurrence data.  This mirrors Java
#' Maxent's \code{SampleSet.replicate()} method.
#'
#' @param env_vals    Named list of numeric vectors (one per environmental
#'   variable, length = total points: background + occurrences).
#' @param sample_indices Integer vector: 0-based indices of occurrence
#'   samples within \code{env_vals}.
#' @param num_points  Integer: total number of points.
#' @param n_replicates Integer: number of replicates (default 5).
#' @param replicate_type Character: \code{"bootstrap"} (default) samples
#'   with replacement, \code{"subsample"} uses a 75\% random subsample.
#' @param types       Character vector of feature types (default
#'   \code{c("linear", "quadratic", "hinge")}).
#' @param n_hinges    Integer: number of hinge knots (default 15).
#' @param max_iter    Integer: maximum training iterations (default 500).
#' @param seed        Integer: random seed (default 42).
#' @param categorical Character vector of variable names that are
#'   categorical (default \code{NULL}).
#' @param bias_weights Optional numeric vector of per-point bias weights.
#' @return A named list with:
#'   \describe{
#'     \item{replicate_results}{List of per-replicate result lists.}
#'     \item{summary}{A \code{data.frame} with mean and sd statistics.}
#'   }
#' @export
#' @examples
#' \dontrun{
#' env <- list(temp = rnorm(110), precip = rnorm(110))
#' reps <- maxent_replicate(env, sample_indices = 100:109,
#'                           num_points = 110L, n_replicates = 5L)
#' print(reps$summary)
#' }
maxent_replicate <- function(env_vals,
                             sample_indices,
                             num_points,
                             n_replicates    = 5L,
                             replicate_type  = "bootstrap",
                             types           = c("linear", "quadratic", "hinge"),
                             n_hinges        = 15L,
                             max_iter        = 500L,
                             seed            = 42L,
                             categorical     = NULL,
                             bias_weights    = NULL) {
    if (!is.list(env_vals) || is.null(names(env_vals))) {
        stop("env_vals must be a named list of numeric vectors")
    }
    replicate_type <- match.arg(replicate_type, c("bootstrap", "subsample"))
    n_replicates <- as.integer(n_replicates)
    n_occ <- length(sample_indices)

    set.seed(seed)
    bw <- if (is.null(bias_weights)) numeric(0) else as.numeric(bias_weights)

    replicate_results <- vector("list", n_replicates)

    for (rep_i in seq_len(n_replicates)) {
        if (replicate_type == "bootstrap") {
            sel <- sample.int(n_occ, n_occ, replace = TRUE)
        } else {
            n_sub <- max(1L, as.integer(0.75 * n_occ))
            sel <- sample.int(n_occ, n_sub, replace = FALSE)
        }
        rep_occ_idx <- sample_indices[sel]

        features <- maxent_generate_features(
            env_vals, types = types, n_hinges = n_hinges,
            categorical = categorical)

        fs <- maxent_featured_space(
            as.integer(num_points), as.integer(rep_occ_idx),
            features, bias_weights = if (length(bw) > 0) bw else NULL)
        fit <- maxent_fit(fs, max_iter = as.integer(max_iter))

        replicate_results[[rep_i]] <- list(
            replicate  = rep_i,
            train_gain = fit$loss,
            lambdas    = fit$lambdas
        )
    }

    train_gains <- vapply(replicate_results, `[[`, numeric(1), "train_gain")

    summary_df <- data.frame(
        statistic  = c("mean", "sd"),
        train_gain = c(mean(train_gains), stats::sd(train_gains)),
        stringsAsFactors = FALSE
    )

    list(
        replicate_results = replicate_results,
        summary           = summary_df
    )
}
