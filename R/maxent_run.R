#' Run a Complete Maxent Species Distribution Modelling Workflow
#'
#' Provides a single high-level entry point that mirrors running the Java
#' Maxent GUI with one click.  Starting from raw environmental grids and
#' occurrence records, the function:
#' \enumerate{
#'   \item Reads and validates occurrence records.
#'   \item Samples background points.
#'   \item Extracts environmental values and builds features.
#'   \item Trains the Maxent model.
#'   \item Projects the model onto the full landscape (cloglog output).
#'   \item Evaluates model performance (AUC).
#'   \item Computes percent contribution and permutation importance.
#'   \item Writes all standard output files (lambdas, prediction PNG, response
#'     curve PNGs, omission CSV, sample-predictions CSV, and
#'     \code{maxentResults.csv}).
#'   \item Prints a performance summary to the console.
#' }
#'
#' @param species       Character: species name (used in file names and the
#'   console report).
#' @param env_grids     Named list of external pointers to Grid<float> objects.
#'   The \emph{names} of the list are used as the environmental variable names.
#' @param occ_df        A \code{data.frame} (or CSV path) with occurrence
#'   records.
#' @param output_dir    Character: directory where all output files are written
#'   (created if it does not exist).
#' @param lon_col       Character: longitude column name in \code{occ_df}
#'   (default \code{"long"}).
#' @param lat_col       Character: latitude column name in \code{occ_df}
#'   (default \code{"lat"}).
#' @param n_background  Integer: number of background points (default 10000).
#' @param types         Character vector of feature types passed to
#'   \code{\link{maxent_generate_features}} (default
#'   \code{c("linear", "quadratic", "hinge")}).
#' @param n_hinges      Integer: number of hinge knots (default 15).
#' @param max_iter      Integer: maximum training iterations (default 500).
#' @param seed          Integer: random seed for background sampling
#'   (default 42).
#' @param bias_weights  Optional numeric vector of per-background-point bias
#'   weights.  Must have length equal to \code{n_background} (the background
#'   points only, not including occurrence points).  When supplied, the
#'   background density is weighted by \code{bias[i] * exp(lp[i] - lpn)},
#'   mirroring Java Maxent's \code{biasFile}.  Pass \code{NULL} (default)
#'   for uniform (unbiased) background.
#' @param response_curves Logical: write response curve PNGs
#'   (default \code{TRUE}).
#' @param pictures      Logical: write prediction map PNG (default \code{TRUE}).
#' @return A named list with:
#'   \describe{
#'     \item{model}{Trained FeaturedSpace external pointer.}
#'     \item{fit_result}{List returned by \code{\link{maxent_fit}}.}
#'     \item{evaluation}{List returned by \code{\link{maxent_evaluate}}.}
#'     \item{contributions}{Data.frame of percent contributions.}
#'     \item{permutation_importance}{Data.frame of permutation importances.}
#'     \item{output_dir}{The output directory used.}
#'   }
#' @export
#' @examples
#' \dontrun{
#' library(maxentcpp)
#' library(terra)
#'
#' stack_path      <- system.file("extdata", "stack_1_12_crop.rds",
#'                                package = "maxentcpp")
#' example_rasters <- terra::unwrap(readRDS(stack_path))
#' grids <- list(
#'   bio1  = maxent_grid_from_terra(example_rasters[[1]]),
#'   bio12 = maxent_grid_from_terra(example_rasters[[2]])
#' )
#' data(example_occ_df)
#'
#' result <- maxent_run(
#'   species    = "Abeillia_abeillei",
#'   env_grids  = grids,
#'   occ_df     = example_occ_df,
#'   output_dir = tempdir(),
#'   lon_col    = "long",
#'   lat_col    = "lat")
#'
#' cat("AUC:", result$evaluation$auc, "\n")
#' }
maxent_run <- function(species,
                       env_grids,
                       occ_df,
                       output_dir,
                       lon_col        = "long",
                       lat_col        = "lat",
                       n_background   = 10000L,
                       types          = c("linear", "quadratic", "hinge"),
                       n_hinges       = 15L,
                       max_iter       = 500L,
                       seed           = 42L,
                       bias_weights   = NULL,
                       response_curves = TRUE,
                       pictures        = TRUE) {

    if (!is.list(env_grids) || is.null(names(env_grids))) {
        stop("'env_grids' must be a named list of Grid objects")
    }
    feature_names <- names(env_grids)

    if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

    # --- 1. Read occurrences --------------------------------------------------
    ref_grid <- env_grids[[1]]
    info     <- maxent_grid_info(ref_grid)
    dim_obj  <- maxent_dimension(nrows    = info$nrows,
                                 ncols    = info$ncols,
                                 xll      = info$xll,
                                 yll      = info$yll,
                                 cellsize = info$cellsize)

    occ <- maxent_read_occurrences(occ_df, dim_obj,
                                   lon_col = lon_col,
                                   lat_col = lat_col)

    # --- 2. Background points -------------------------------------------------
    bg <- maxent_background_indices(ref_grid,
                                    n    = as.integer(n_background),
                                    seed = as.integer(seed))

    # --- 3. Extract environmental values and build features ------------------
    all_rows <- c(bg$rows, occ$rows)
    all_cols <- c(bg$cols, occ$cols)
    n_total  <- length(all_rows)

    sample_indices <- seq(length(bg$rows), n_total - 1L)

    int_rows <- as.integer(all_rows)
    int_cols <- as.integer(all_cols)

    env_vals <- lapply(env_grids, function(g) {
        grid_get_values_batch(g, int_rows, int_cols)
    })
    names(env_vals) <- feature_names

    features <- maxent_generate_features(env_vals,
                                         types    = as.character(types),
                                         n_hinges = as.integer(n_hinges))

    # --- 4. Train -------------------------------------------------------------
    # Extend per-background bias_weights to the full (bg + occ) array.
    # Background bias is user-supplied; occurrence points get weight 1.0.
    full_bias <- NULL
    if (!is.null(bias_weights)) {
        n_bg <- length(bg$rows)
        if (length(bias_weights) != n_bg) {
            stop(sprintf(
                "bias_weights must have length %d (background points only, excluding occurrences), got %d",
                n_bg, length(bias_weights)))
        }
        n_occ <- length(occ$rows)
        full_bias <- c(as.numeric(bias_weights), rep(1.0, n_occ))
    }
    fs         <- maxent_featured_space(n_total,
                                        as.integer(sample_indices),
                                        features,
                                        bias_weights = full_bias)
    fit_result <- maxent_fit(fs,
                             max_iter = as.integer(max_iter),
                             convergence = 1e-5)

    # --- 5. Evaluate ----------------------------------------------------------
    pres_preds <- maxent_extract_predictions_raw(fs, unname(env_grids),
                                                  feature_names,
                                                  occ$rows, occ$cols)
    bg_preds   <- maxent_extract_predictions_raw(fs, unname(env_grids),
                                                  feature_names,
                                                  bg$rows, bg$cols)
    eval_result <- maxent_evaluate(pres_preds, bg_preds)

    # --- 6. Diagnostics -------------------------------------------------------
    contrib  <- maxent_percent_contribution(fs, feature_names)
    perm_imp <- maxent_permutation_importance(
        fs, unname(env_grids), feature_names,
        occ$rows, occ$cols,
        bg$rows,  bg$cols,
        seed = as.integer(seed))

    # --- 7. Print performance summary to console -----------------------------
    maxent_print_results(
        species          = species,
        eval_result      = eval_result,
        contributions_df = contrib,
        perm_imp_df      = perm_imp,
        n_presence       = length(occ$rows),
        n_background     = length(bg$rows),
        fit_result       = fit_result)

    # --- 8. Append to maxentResults.csv --------------------------------------
    results_csv <- file.path(output_dir, "maxentResults.csv")
    maxent_append_results_csv(
        results_file     = results_csv,
        species          = species,
        n_training       = length(occ$rows),
        training_gain    = fit_result$loss,
        training_auc     = eval_result$auc,
        entropy          = fit_result$entropy,
        contributions_df = contrib,
        perm_imp_df      = perm_imp)

    list(
        model                  = fs,
        fit_result             = fit_result,
        evaluation             = eval_result,
        contributions          = contrib,
        permutation_importance = perm_imp,
        output_dir             = output_dir
    )
}
