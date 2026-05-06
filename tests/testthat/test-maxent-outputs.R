## Helpers to build a minimal trained model for output tests
.make_test_model <- function() {
    skip_if_not_installed("maxentcpp")
    dim_obj <- maxent_dimension(nrows = 4, ncols = 4, xll = 0, yll = 0,
                                cellsize = 1)
    g0 <- maxent_grid(dim_obj, "env0")
    g1 <- maxent_grid(dim_obj, "env1")
    idx <- 0L
    for (r in 0:3) {
        for (cc in 0:3) {
            grid_set_value(g0, r, cc, idx / 15.0)
            grid_set_value(g1, r, cc, 1.0 - idx / 15.0)
            idx <- idx + 1L
        }
    }

    n   <- 16L
    vals0 <- sapply(0:15, function(i) i / 15.0)
    vals1 <- 1.0 - vals0

    features <- maxent_generate_features(
        list(env0 = vals0, env1 = vals1),
        types = "linear", n_thresholds = 0, n_hinges = 0)

    # Background = first 12, presence = last 4
    pres_idx <- 12:15
    model    <- maxent_featured_space(n, as.integer(pres_idx), features)
    maxent_fit(model, max_iter = 200, convergence = 1e-4,
               beta_multiplier = 1.0)

    pres_rows <- as.integer(pres_idx %/% 4L)
    pres_cols <- as.integer(pres_idx  %%  4L)

    list(model = model, g0 = g0, g1 = g1,
         pres_rows = pres_rows, pres_cols = pres_cols)
}

## ---- Prediction PNG ---------------------------------------------------------

test_that("maxent_write_prediction_png creates a non-empty file", {
    skip_if_not_installed("maxentcpp")
    m <- .make_test_model()
    pred <- maxent_project_cloglog(m$model, list(m$g0, m$g1),
                                   c("env0", "env1"))
    out  <- file.path(tempdir(), "test_pred.png")
    maxent_write_prediction_png(pred, out)
    expect_true(file.exists(out))
    expect_gt(file.size(out), 0L)
    unlink(out)
})

test_that("maxent_write_prediction_png with presence points", {
    skip_if_not_installed("maxentcpp")
    m <- .make_test_model()
    pred <- maxent_project_cloglog(m$model, list(m$g0, m$g1),
                                   c("env0", "env1"))
    out  <- file.path(tempdir(), "test_pred_pres.png")
    maxent_write_prediction_png(pred, out,
                                presence_rows = m$pres_rows,
                                presence_cols = m$pres_cols)
    expect_true(file.exists(out))
    expect_gt(file.size(out), 0L)
    unlink(out)
})

test_that("maxent_write_prediction_png modes work", {
    skip_if_not_installed("maxentcpp")
    m <- .make_test_model()
    pred <- maxent_project_cloglog(m$model, list(m$g0, m$g1),
                                   c("env0", "env1"))
    for (mode in c("plain", "log", "blackandwhite", "redandyellow")) {
        out <- file.path(tempdir(), paste0("test_pred_", mode, ".png"))
        maxent_write_prediction_png(pred, out, mode = mode)
        expect_true(file.exists(out))
        expect_gt(file.size(out), 0L)
        unlink(out)
    }
})

## ---- Omission CSV -----------------------------------------------------------

test_that("maxent_write_omission_csv creates CSV with correct columns", {
    skip_if_not_installed("maxentcpp")
    m   <- .make_test_model()
    out_dir <- file.path(tempdir(), "maxent_test_omit")
    on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

    csv_path <- maxent_write_omission_csv(
        m$model, list(m$g0, m$g1), c("env0", "env1"),
        m$pres_rows, m$pres_cols,
        output_dir = out_dir, species = "TestSp")

    expect_true(file.exists(csv_path))
    df <- utils::read.csv(csv_path, check.names = FALSE)
    expect_true("Threshold" %in% names(df))
    expect_true("Training omission" %in% names(df))
    # At least 7 threshold rows (9 without test data for some configs)
    expect_gte(nrow(df), 7L)
})

## ---- Sample Predictions CSV -------------------------------------------------

test_that("maxent_write_sample_predictions creates CSV with correct shape", {
    skip_if_not_installed("maxentcpp")
    m   <- .make_test_model()
    out_dir <- file.path(tempdir(), "maxent_test_sp")
    on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

    csv_path <- maxent_write_sample_predictions(
        m$model, list(m$g0, m$g1), c("env0", "env1"),
        m$pres_rows, m$pres_cols,
        output_dir = out_dir, species = "TestSp")

    expect_true(file.exists(csv_path))
    df <- utils::read.csv(csv_path, check.names = FALSE)
    expect_equal(ncol(df), 6L)
    expect_equal(nrow(df), length(m$pres_rows))
    expect_true("species" %in% names(df))
    expect_true("cloglog" %in% names(df))
    expect_true(all(df$set == "train"))
})

test_that("maxent_write_sample_predictions includes test rows when provided", {
    skip_if_not_installed("maxentcpp")
    m   <- .make_test_model()
    out_dir <- file.path(tempdir(), "maxent_test_sp2")
    on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

    csv_path <- maxent_write_sample_predictions(
        m$model, list(m$g0, m$g1), c("env0", "env1"),
        m$pres_rows, m$pres_cols,
        output_dir = out_dir, species = "TestSp2",
        test_rows = c(0L, 1L), test_cols = c(0L, 1L))

    df <- utils::read.csv(csv_path, check.names = FALSE)
    expect_equal(nrow(df), length(m$pres_rows) + 2L)
    expect_true(any(df$set == "test"))
})

## ---- maxentResults.csv ------------------------------------------------------

test_that("maxent_append_results_csv creates file on first call", {
    skip_if_not_installed("maxentcpp")
    m   <- .make_test_model()
    contrib  <- maxent_percent_contribution(m$model, c("env0", "env1"))
    perm_imp <- maxent_permutation_importance(
        m$model, list(m$g0, m$g1), c("env0", "env1"),
        m$pres_rows, m$pres_cols,
        c(0L, 1L, 2L), c(0L, 1L, 2L))

    results_file <- file.path(tempdir(), "maxentResults_test.csv")
    on.exit(unlink(results_file), add = TRUE)

    maxent_append_results_csv(
        results_file  = results_file,
        species       = "TestSp",
        n_training    = 4L,
        training_gain = 1.23,
        training_auc  = 0.85,
        entropy       = 5.5,
        contributions_df = contrib,
        perm_imp_df      = perm_imp)

    expect_true(file.exists(results_file))
    df <- utils::read.csv(results_file, check.names = FALSE)
    expect_equal(nrow(df), 1L)
    expect_equal(df$Species, "TestSp")
})

test_that("maxent_append_results_csv appends second row without duplicating header", {
    skip_if_not_installed("maxentcpp")
    m   <- .make_test_model()
    contrib  <- maxent_percent_contribution(m$model, c("env0", "env1"))
    perm_imp <- maxent_permutation_importance(
        m$model, list(m$g0, m$g1), c("env0", "env1"),
        m$pres_rows, m$pres_cols,
        c(0L, 1L, 2L), c(0L, 1L, 2L))

    results_file <- file.path(tempdir(), "maxentResults_test2.csv")
    on.exit(unlink(results_file), add = TRUE)

    for (sp in c("Sp1", "Sp2")) {
        maxent_append_results_csv(
            results_file  = results_file,
            species       = sp,
            n_training    = 4L,
            training_gain = 1.0,
            training_auc  = 0.8,
            entropy       = 5.0,
            contributions_df = contrib,
            perm_imp_df      = perm_imp)
    }

    df <- utils::read.csv(results_file, check.names = FALSE)
    expect_equal(nrow(df), 2L)
    expect_equal(df$Species, c("Sp1", "Sp2"))
})
