# ---- Stage 2: Prediction PNG writer -----------------------------------------

#' Write a Maxent Prediction Grid as a PNG Image
#'
#' Converts a \code{GridFloat} prediction grid to a colour PNG image using
#' the canonical Maxent colour ramp (red = high, blue = low).  Optionally
#' overlays presence and test-point locations, and renders a small legend.
#'
#' @param grid          External pointer to a GridFloat prediction grid (e.g.
#'   from \code{\link{maxent_project_cloglog}}).
#' @param filename      Character: path for the output PNG file.
#' @param presence_rows Integer vector of presence row indices (0-based) or
#'   \code{NULL} (default).
#' @param presence_cols Integer vector of presence column indices (0-based) or
#'   \code{NULL} (default).
#' @param test_rows     Integer vector of test-set row indices (0-based) or
#'   \code{NULL} (default).
#' @param test_cols     Integer vector of test-set column indices (0-based) or
#'   \code{NULL} (default).
#' @param mode          Colour mode passed to \code{\link{maxent_color_ramp}}:
#'   one of \code{"plain"} (default), \code{"log"}, \code{"blackandwhite"},
#'   or \code{"redandyellow"}.
#' @param legend        Logical: draw a colour-bar legend (default \code{TRUE}).
#' @param width         Integer: PNG width in pixels (default 800).
#' @param height        Integer: PNG height in pixels (default 600).
#' @return Invisibly returns \code{filename}.
#' @export
#' @examples
#' \donttest{
#' set.seed(42)
#' n <- 50L; idx <- c(5L, 15L, 25L, 35L, 45L)
#' env <- list(bio1 = runif(n), bio12 = runif(n))
#' feats <- maxent_generate_features(env, types = "linear")
#' model <- maxent_featured_space(n, idx, feats)
#' maxent_fit(model, max_iter = 100)
#' g1 <- maxent_grid_from_matrix(matrix(env$bio1, 5, 10),
#'         -120, 35, 1, name = "bio1")
#' g2 <- maxent_grid_from_matrix(matrix(env$bio12, 5, 10),
#'         -120, 35, 1, name = "bio12")
#' pred <- maxent_project_cloglog(model, list(g1, g2), c("bio1", "bio12"))
#' maxent_write_prediction_png(pred, tempfile(fileext = ".png"))
#' }
maxent_write_prediction_png <- function(grid, filename,
                                        presence_rows = NULL,
                                        presence_cols = NULL,
                                        test_rows     = NULL,
                                        test_cols     = NULL,
                                        mode          = "plain",
                                        legend        = TRUE,
                                        width         = 800L,
                                        height        = 600L) {
    mat <- maxent_grid_to_matrix(grid)
    if (is.null(mat)) stop("Could not extract matrix from grid")

    nrows <- nrow(mat)
    ncols <- ncol(mat)
    n_pal <- 1020L
    pal   <- maxent_color_ramp(n_pal, mode = mode)

    val_min <- min(mat, na.rm = TRUE)
    val_max <- max(mat, na.rm = TRUE)

    # Map values to palette indices (1..n_pal): high values → index 1 (red),
    # low values → index n_pal (blue).
    if (val_max > val_min) {
        idx <- round((val_max - mat) / (val_max - val_min) * (n_pal - 1L)) + 1L
    } else {
        idx <- matrix(1L, nrow = nrows, ncol = ncols)
    }
    idx[is.na(mat)] <- NA_integer_

    # Build RGB arrays (dims: nrows x ncols x 3, values in [0,1])
    hex_to_rgb01 <- function(hex) {
        m <- grDevices::col2rgb(hex) / 255
        m  # 3 x length(hex)
    }
    rgb_mat <- hex_to_rgb01(pal)   # 3 x n_pal

    red_layer   <- matrix(0.85, nrow = nrows, ncol = ncols)  # grey for NODATA
    green_layer <- matrix(0.85, nrow = nrows, ncol = ncols)
    blue_layer  <- matrix(0.85, nrow = nrows, ncol = ncols)

    valid <- !is.na(idx)
    idx_v <- idx[valid]

    red_layer[valid]   <- rgb_mat[1, idx_v]
    green_layer[valid] <- rgb_mat[2, idx_v]
    blue_layer[valid]  <- rgb_mat[3, idx_v]

    # Assemble raster array (rows from top → flip)
    img <- array(NA_real_, dim = c(nrows, ncols, 3))
    img[, , 1] <- red_layer[nrows:1, ]
    img[, , 2] <- green_layer[nrows:1, ]
    img[, , 3] <- blue_layer[nrows:1, ]

    grDevices::png(filename, width = as.integer(width),
                   height = as.integer(height))
    oldpar <- graphics::par(mar = c(0, 0, 0, 0))
    on.exit({graphics::par(oldpar); grDevices::dev.off()}, add = TRUE)
    graphics::plot.new()
    graphics::plot.window(xlim = c(0, ncols), ylim = c(0, nrows),
                          xaxs = "i", yaxs = "i")
    graphics::rasterImage(img, 0, 0, ncols, nrows)

    # Presence points (white dots)
    if (!is.null(presence_rows) && length(presence_rows) > 0) {
        px <- as.integer(presence_cols) + 0.5
        py <- as.integer(presence_rows) + 0.5
        graphics::points(px, py, pch = 21, bg = "white",
                         col = "black", cex = 0.8, lwd = 0.5)
    }

    # Test points (violet dots)
    if (!is.null(test_rows) && length(test_rows) > 0) {
        px <- as.integer(test_cols) + 0.5
        py <- as.integer(test_rows) + 0.5
        graphics::points(px, py, pch = 21, bg = "#EE82EE",
                         col = "black", cex = 0.8, lwd = 0.5)
    }

    # Legend strip (right side)
    if (legend) {
        leg_x <- ncols * 0.93
        leg_y0 <- nrows * 0.10
        leg_y1 <- nrows * 0.90
        leg_w  <- ncols * 0.04
        n_leg  <- 100L
        leg_pal <- maxent_color_ramp(n_leg, mode = mode)
        for (i in seq_len(n_leg)) {
            yb <- leg_y0 + (i - 1L) * (leg_y1 - leg_y0) / n_leg
            yt <- leg_y0 + i         * (leg_y1 - leg_y0) / n_leg
            graphics::rect(leg_x, yb, leg_x + leg_w, yt,
                           col = leg_pal[n_leg - i + 1L], border = NA)
        }
        graphics::rect(leg_x, leg_y0, leg_x + leg_w, leg_y1, border = "black",
                       lwd = 0.8)
        graphics::text(leg_x - leg_w * 0.3, leg_y1,
                       sprintf("%.2f", val_max), adj = 1, cex = 0.7)
        graphics::text(leg_x - leg_w * 0.3, leg_y0,
                       sprintf("%.2f", val_min), adj = 1, cex = 0.7)
    }

    invisible(filename)
}


# ---- Stage 5: Omission / Threshold CSV --------------------------------------

#' Write an Omission / Threshold CSV
#'
#' Computes cumulative predictions at all background + presence locations and
#' derives nine standard threshold statistics, writing the result to
#' \code{<output_dir>/<species>_omission.csv}.  The output format mirrors
#' \code{density/Runner.java::writeCumulativeIndex()}.
#'
#' @param model         External pointer to a trained FeaturedSpace object.
#' @param env_grids     List of external pointers to Grid<float> objects.
#' @param feature_names Character vector of environment variable names.
#' @param presence_rows Integer vector of presence row indices (0-based).
#' @param presence_cols Integer vector of presence column indices (0-based).
#' @param output_dir    Character: directory for output files.
#' @param species       Character: species name (used in the filename).
#' @param test_rows     Integer vector of test row indices (0-based) or
#'   \code{NULL} (default).
#' @param test_cols     Integer vector of test column indices (0-based) or
#'   \code{NULL} (default).
#' @return Invisibly returns the path to the written CSV file.
#' @export
#' @examples
#' \donttest{
#' set.seed(42)
#' n <- 50L; idx <- c(5L, 15L, 25L, 35L, 45L)
#' env <- list(bio1 = runif(n), bio12 = runif(n))
#' feats <- maxent_generate_features(env, types = "linear")
#' model <- maxent_featured_space(n, idx, feats)
#' maxent_fit(model, max_iter = 100)
#' g1 <- maxent_grid_from_matrix(matrix(env$bio1, 5, 10),
#'         -120, 35, 1, name = "bio1")
#' g2 <- maxent_grid_from_matrix(matrix(env$bio12, 5, 10),
#'         -120, 35, 1, name = "bio12")
#' pres_rows <- c(0L, 1L, 2L); pres_cols <- c(0L, 1L, 2L)
#' maxent_write_omission_csv(model, list(g1, g2), c("bio1", "bio12"),
#'   pres_rows, pres_cols, output_dir = tempdir(), species = "Sp1")
#' }
maxent_write_omission_csv <- function(model, env_grids, feature_names,
                                      presence_rows, presence_cols,
                                      output_dir, species,
                                      test_rows = NULL, test_cols = NULL) {
    if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

    feature_names <- as.character(feature_names)
    presence_rows <- as.integer(presence_rows)
    presence_cols <- as.integer(presence_cols)

    # Model parameters for Java-compatible transforms
    H    <- maxent_model_entropy(model)
    expH <- exp(H)

    # Java-compatible cloglog from a raw_java score (as returned by
    # maxent_project_raw()/maxent_extract_predictions_raw(), which both
    # route through Projection::project_raw_java and are thus already
    # divided by densityNormalizer).  No further /dn division here.
    raw_java_to_cloglog_java <- function(raw_java) {
        1.0 - exp(-expH * raw_java)
    }

    # Project full grid for cumulative thresholds
    proj_grid <- maxent_project_raw(model, env_grids, feature_names)
    bg_mat    <- maxent_grid_to_matrix(proj_grid)
    all_raw   <- as.numeric(bg_mat[!is.na(bg_mat)])

    # Sort background to build cumulative index
    all_sorted <- sort(all_raw)
    n_bg       <- length(all_sorted)

    # Cumulative value for a given raw score = fraction of background <= score
    raw_to_cum <- function(raw_vals) {
        vapply(raw_vals, function(v) {
            mean(all_sorted <= v)
        }, numeric(1L))
    }

    pres_raw <- maxent_extract_predictions_raw(model, env_grids, feature_names,
                                           presence_rows, presence_cols)
    pres_cum <- raw_to_cum(pres_raw)

    has_test <- !is.null(test_rows) && length(test_rows) > 0
    if (has_test) {
        test_raw <- maxent_extract_predictions_raw(model, env_grids, feature_names,
                                               as.integer(test_rows),
                                               as.integer(test_cols))
        test_cum <- raw_to_cum(test_raw)
    }

    # ---- Threshold calculations ----------------------------------------------

    cum_thresholds <- seq(0, 1, length.out = n_bg)   # cumulative grid values

    # Helper: omission rate at cumulative threshold t
    omit_train <- function(t) mean(pres_cum < t)
    omit_test  <- function(t) {
        if (!has_test) return(NA_real_)
        mean(test_cum < t)
    }

    # Fixed cumulative thresholds 1, 5, 10
    fixed_thresholds <- c(0.01, 0.05, 0.10)
    fixed_names      <- c("Fixed cumulative value 1",
                          "Fixed cumulative value 5",
                          "Fixed cumulative value 10")

    # Minimum training presence
    min_train_cum <- min(pres_cum)

    # 10th percentile training presence
    pct10_cum <- stats::quantile(pres_cum, 0.10, names = FALSE)

    # Helper: find threshold maximising (sensitivity + specificity) or
    # minimising |sensitivity - (1 - specificity)|
    find_equal_ss <- function(preds_cum, label) {
        # sensitivity = TP/(TP+FN), specificity = TN/(TN+FP)
        # Over bg: all bg as negatives, preds_cum as positives
        ts <- sort(unique(c(preds_cum, cum_thresholds)))
        best_t <- ts[1]
        best_d <- Inf
        for (t in ts) {
            sens <- mean(preds_cum >= t)
            spec <- mean(all_sorted / max(all_sorted) < t)
            d <- abs(sens - spec)
            if (d < best_d) { best_d <- d; best_t <- t }
        }
        best_t
    }

    find_max_ss <- function(preds_cum) {
        ts <- sort(unique(c(preds_cum, cum_thresholds)))
        best_t <- ts[1]
        best_s <- -Inf
        for (t in ts) {
            sens <- mean(preds_cum >= t)
            spec <- mean(all_sorted / max(all_sorted) < t)
            s    <- sens + spec
            if (s > best_s) { best_s <- s; best_t <- t }
        }
        best_t
    }

    t_equal_train <- find_equal_ss(pres_cum)
    t_max_train   <- find_max_ss(pres_cum)

    # Build row table
    threshold_names <- c(
        fixed_names,
        "Minimum training presence",
        "10 percentile training presence",
        "Equal training sensitivity and specificity",
        "Maximum training sensitivity plus specificity"
    )
    threshold_values <- c(
        fixed_thresholds,
        min_train_cum,
        pct10_cum,
        t_equal_train,
        t_max_train
    )

    if (has_test) {
        t_equal_test <- find_equal_ss(test_cum)
        t_max_test   <- find_max_ss(test_cum)
        threshold_names  <- c(threshold_names,
                               "Equal test sensitivity and specificity",
                               "Maximum test sensitivity plus specificity")
        threshold_values <- c(threshold_values, t_equal_test, t_max_test)
    }

    n_thresh <- length(threshold_names)
    omission_train <- vapply(threshold_values, omit_train, numeric(1L))
    omission_test  <- vapply(threshold_values, omit_test,  numeric(1L))
    bg_predicted   <- vapply(threshold_values, function(t) {
        mean(all_sorted >= t * max(all_sorted))
    }, numeric(1L))

    # Compute cloglog threshold for each cumulative threshold
    # The raw value at cumulative fraction t is the t-th quantile of all_sorted
    cloglog_thresholds <- vapply(threshold_values, function(t) {
        raw_java_at_t <- stats::quantile(all_sorted, t, names = FALSE)
        raw_java_to_cloglog_java(raw_java_at_t)
    }, numeric(1L))

    out <- data.frame(
        Threshold                    = threshold_names,
        `Cumulative threshold`       = threshold_values,
        `Cloglog threshold`          = cloglog_thresholds,
        `Area`                       = bg_predicted,
        `Training omission`          = omission_train,
        `Test omission`              = omission_test,
        stringsAsFactors             = FALSE,
        check.names                  = FALSE
    )

    csv_path <- file.path(output_dir, paste0(species, "_omission.csv"))
    utils::write.csv(out, csv_path, row.names = FALSE)
    invisible(csv_path)
}


# ---- Stage 6: Sample Predictions CSV ----------------------------------------

#' Write Sample Predictions CSV
#'
#' Computes model predictions at presence (and optionally test) locations and
#' writes \code{<output_dir>/<species>_samplePredictions.csv}.
#'
#' @param model         External pointer to a trained FeaturedSpace object.
#' @param env_grids     List of external pointers to Grid<float> objects.
#' @param feature_names Character vector of environment variable names.
#' @param presence_rows Integer vector of presence row indices (0-based).
#' @param presence_cols Integer vector of presence column indices (0-based).
#' @param output_dir    Character: directory for the output file.
#' @param species       Character: species name (used in the filename).
#' @param test_rows     Integer vector of test row indices (0-based) or
#'   \code{NULL} (default).
#' @param test_cols     Integer vector of test column indices (0-based) or
#'   \code{NULL} (default).
#' @return Invisibly returns the path to the written CSV.
#' @export
#' @examples
#' \donttest{
#' set.seed(42)
#' n <- 50L; idx <- c(5L, 15L, 25L, 35L, 45L)
#' env <- list(bio1 = runif(n), bio12 = runif(n))
#' feats <- maxent_generate_features(env, types = "linear")
#' model <- maxent_featured_space(n, idx, feats)
#' maxent_fit(model, max_iter = 100)
#' g1 <- maxent_grid_from_matrix(matrix(env$bio1, 5, 10),
#'         -120, 35, 1, name = "bio1")
#' g2 <- maxent_grid_from_matrix(matrix(env$bio12, 5, 10),
#'         -120, 35, 1, name = "bio12")
#' pres_rows <- c(0L, 1L, 2L); pres_cols <- c(0L, 1L, 2L)
#' maxent_write_sample_predictions(model, list(g1, g2), c("bio1", "bio12"),
#'   pres_rows, pres_cols, output_dir = tempdir(), species = "Sp1")
#' }
maxent_write_sample_predictions <- function(model, env_grids, feature_names,
                                            presence_rows, presence_cols,
                                            output_dir, species,
                                            test_rows = NULL,
                                            test_cols = NULL) {
    if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

    feature_names <- as.character(feature_names)
    presence_rows <- as.integer(presence_rows)
    presence_cols <- as.integer(presence_cols)

    pres_raw <- maxent_extract_predictions_raw(model, env_grids, feature_names,
                                           presence_rows, presence_cols)

    # Java-compatible cloglog: 1 - exp(-exp(H) * raw_java).  Note that
    # maxent_extract_predictions_raw() already returns raw_java (scores
    # are produced via predict_raw_java_from_env, which divides by
    # densityNormalizer), so the cloglog formula is applied directly.
    H    <- maxent_model_entropy(model)
    expH <- exp(H)

    raw_java_to_cloglog_java <- function(raw_java) {
        1.0 - exp(-expH * raw_java)
    }

    pres_cl  <- raw_java_to_cloglog_java(pres_raw)

    set_label <- rep("train", length(presence_rows))

    rows_all <- presence_rows
    cols_all <- presence_cols
    raw_all  <- pres_raw
    cl_all   <- pres_cl
    set_all  <- set_label

    if (!is.null(test_rows) && length(test_rows) > 0) {
        test_rows <- as.integer(test_rows)
        test_cols <- as.integer(test_cols)
        t_raw <- maxent_extract_predictions_raw(model, env_grids, feature_names,
                                            test_rows, test_cols)
        t_cl  <- raw_java_to_cloglog_java(t_raw)
        rows_all <- c(rows_all, test_rows)
        cols_all <- c(cols_all, test_cols)
        raw_all  <- c(raw_all, t_raw)
        cl_all   <- c(cl_all,  t_cl)
        set_all  <- c(set_all, rep("test", length(test_rows)))
    }

    out <- data.frame(
        species    = species,
        row        = rows_all,
        col        = cols_all,
        `set`      = set_all,
        raw        = raw_all,
        cloglog    = cl_all,
        stringsAsFactors = FALSE,
        check.names      = FALSE
    )

    csv_path <- file.path(output_dir,
                          paste0(species, "_samplePredictions.csv"))
    utils::write.csv(out, csv_path, row.names = FALSE)
    invisible(csv_path)
}


# ---- Stage 8: maxentResults.csv writer --------------------------------------

#' Append a Row to maxentResults.csv
#'
#' Appends one row of species-level summary statistics to a
#' \code{maxentResults.csv} file, creating the file (with a header) if it does
#' not yet exist.  Column names match the Java Maxent output for
#' cross-tool compatibility.
#'
#' @param results_file    Character: path to the results CSV file.
#' @param species         Character: species name.
#' @param n_training      Integer: number of training presence points.
#' @param n_test          Integer: number of test presence points (default 0).
#' @param training_gain   Numeric: regularized training gain.
#' @param training_auc    Numeric: training AUC.
#' @param test_gain       Numeric or \code{NA}: regularized test gain.
#' @param test_auc        Numeric or \code{NA}: test AUC.
#' @param entropy         Numeric: model entropy.
#' @param contributions_df A data.frame with columns \code{name} and
#'   \code{contribution} (from \code{\link{maxent_percent_contribution}}).
#' @param perm_imp_df     A data.frame with columns \code{name} and
#'   \code{permutation_importance} (from
#'   \code{\link{maxent_permutation_importance}}).
#' @return Invisibly returns \code{results_file}.
#' @export
#' @examples
#' \donttest{
#' contrib <- data.frame(name = c("bio1", "bio12"),
#'                       contribution = c(60, 40))
#' perm_imp <- data.frame(name = c("bio1", "bio12"),
#'                        permutation_importance = c(55, 45))
#' maxent_append_results_csv(
#'   file.path(tempdir(), "maxentResults.csv"),
#'   species = "Sp1", n_training = 50L, training_gain = 1.23,
#'   training_auc = 0.95, entropy = 6.7,
#'   contributions_df = contrib, perm_imp_df = perm_imp)
#' }
maxent_append_results_csv <- function(results_file,
                                      species,
                                      n_training,
                                      n_test          = 0L,
                                      training_gain,
                                      training_auc,
                                      test_gain       = NA_real_,
                                      test_auc        = NA_real_,
                                      entropy,
                                      contributions_df,
                                      perm_imp_df) {
    # Base columns (Java column order)
    row <- data.frame(
        Species                    = as.character(species),
        `X..Training.samples`      = as.integer(n_training),
        `X..Test.samples`          = as.integer(n_test),
        `Regularized.training.gain`= as.numeric(training_gain),
        `Regularized.test.gain`    = as.numeric(test_gain),
        `Training.AUC`             = as.numeric(training_auc),
        `Test.AUC`                 = as.numeric(test_auc),
        Entropy                    = as.numeric(entropy),
        stringsAsFactors           = FALSE,
        check.names                = FALSE
    )

    # Contribution columns: "<name> contribution"
    if (!is.null(contributions_df) && is.data.frame(contributions_df)) {
        for (i in seq_len(nrow(contributions_df))) {
            nm <- paste0(contributions_df$name[i], " contribution")
            row[[nm]] <- as.numeric(contributions_df$contribution[i])
        }
    }

    # Permutation importance columns: "<name> permutation importance"
    if (!is.null(perm_imp_df) && is.data.frame(perm_imp_df)) {
        for (i in seq_len(nrow(perm_imp_df))) {
            nm <- paste0(perm_imp_df$name[i], " permutation importance")
            row[[nm]] <- as.numeric(perm_imp_df$permutation_importance[i])
        }
    }

    if (file.exists(results_file)) {
        existing <- utils::read.csv(results_file,
                                    stringsAsFactors = FALSE,
                                    check.names      = FALSE)
        # Align columns
        all_cols <- union(names(existing), names(row))
        for (col in setdiff(all_cols, names(existing))) existing[[col]] <- NA
        for (col in setdiff(all_cols, names(row)))     row[[col]]      <- NA
        combined <- rbind(existing[, all_cols], row[, all_cols])
        utils::write.csv(combined, results_file, row.names = FALSE)
    } else {
        utils::write.csv(row, results_file, row.names = FALSE)
    }

    invisible(results_file)
}
