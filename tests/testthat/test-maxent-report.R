## ---- Console Results Print --------------------------------------------------

.make_print_test_model <- function() {
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
    vals0 <- sapply(0:15, function(i) i / 15.0)
    vals1 <- 1.0 - vals0
    features <- maxent_generate_features(
        list(env0 = vals0, env1 = vals1),
        types = "linear", n_thresholds = 0, n_hinges = 0)
    pres_idx <- 12:15
    model <- maxent_featured_space(16L, as.integer(pres_idx), features)
    fit_r <- maxent_fit(model, max_iter = 200, convergence = 1e-4,
                        beta_multiplier = 1.0)
    pres_rows <- as.integer(pres_idx %/% 4L)
    pres_cols <- as.integer(pres_idx  %%  4L)
    bg_rows   <- as.integer(c(0L, 1L, 2L))
    bg_cols   <- as.integer(c(0L, 1L, 2L))
    list(model = model, fit_result = fit_r,
         g0 = g0, g1 = g1,
         pres_rows = pres_rows, pres_cols = pres_cols,
         bg_rows = bg_rows, bg_cols = bg_cols)
}

test_that("maxent_print_results returns invisibly with correct structure", {
    skip_if_not_installed("maxentcpp")
    m <- .make_print_test_model()

    pres_preds <- maxent_extract_predictions_raw(
        m$model, list(m$g0, m$g1), c("env0", "env1"),
        m$pres_rows, m$pres_cols)
    bg_preds <- maxent_extract_predictions_raw(
        m$model, list(m$g0, m$g1), c("env0", "env1"),
        m$bg_rows, m$bg_cols)
    eval_r   <- maxent_evaluate(pres_preds, bg_preds)
    contrib  <- maxent_percent_contribution(m$model, c("env0", "env1"))
    perm_imp <- maxent_permutation_importance(
        m$model, list(m$g0, m$g1), c("env0", "env1"),
        m$pres_rows, m$pres_cols,
        m$bg_rows, m$bg_cols)

    result <- maxent_print_results(
        species          = "TestSp",
        eval_result      = eval_r,
        contributions_df = contrib,
        perm_imp_df      = perm_imp,
        n_presence       = length(m$pres_rows),
        n_background     = length(m$bg_rows),
        fit_result       = m$fit_result)

    expect_type(result, "list")
    expect_equal(result$species, "TestSp")
    expect_equal(result$n_presence, length(m$pres_rows))
    expect_equal(result$n_background, length(m$bg_rows))
    expect_equal(result$n_test, 0L)
    expect_true(is.numeric(result$training_auc))
    expect_true(result$training_auc >= 0 && result$training_auc <= 1)
})

test_that("maxent_print_results outputs expected lines to console", {
    skip_if_not_installed("maxentcpp")
    m <- .make_print_test_model()

    pres_preds <- maxent_extract_predictions_raw(
        m$model, list(m$g0, m$g1), c("env0", "env1"),
        m$pres_rows, m$pres_cols)
    bg_preds <- maxent_extract_predictions_raw(
        m$model, list(m$g0, m$g1), c("env0", "env1"),
        m$bg_rows, m$bg_cols)
    eval_r   <- maxent_evaluate(pres_preds, bg_preds)
    contrib  <- maxent_percent_contribution(m$model, c("env0", "env1"))
    perm_imp <- maxent_permutation_importance(
        m$model, list(m$g0, m$g1), c("env0", "env1"),
        m$pres_rows, m$pres_cols,
        m$bg_rows, m$bg_cols)

    output <- capture.output(
        maxent_print_results(
            species          = "TestSp",
            eval_result      = eval_r,
            contributions_df = contrib,
            perm_imp_df      = perm_imp,
            n_presence       = length(m$pres_rows),
            n_background     = length(m$bg_rows),
            fit_result       = m$fit_result))

    combined <- paste(output, collapse = "\n")
    expect_true(grepl("MaxEnt",             combined))
    expect_true(grepl("TestSp",             combined))
    expect_true(grepl("n presence",         combined))
    expect_true(grepl("n background",       combined))
    expect_true(grepl("Training statistics", combined))
    expect_true(grepl("AUC",               combined))
    expect_true(grepl("Variable contributions", combined))
    expect_true(grepl("env0",              combined))
    expect_true(grepl("env1",              combined))
})

test_that("maxent_print_results reports test AUC when test_eval_result provided", {
    skip_if_not_installed("maxentcpp")
    m <- .make_print_test_model()

    pres_preds <- maxent_extract_predictions_raw(
        m$model, list(m$g0, m$g1), c("env0", "env1"),
        m$pres_rows, m$pres_cols)
    bg_preds <- maxent_extract_predictions_raw(
        m$model, list(m$g0, m$g1), c("env0", "env1"),
        m$bg_rows, m$bg_cols)
    eval_r      <- maxent_evaluate(pres_preds, bg_preds)
    test_eval_r <- maxent_evaluate(pres_preds, bg_preds)
    contrib  <- maxent_percent_contribution(m$model, c("env0", "env1"))
    perm_imp <- maxent_permutation_importance(
        m$model, list(m$g0, m$g1), c("env0", "env1"),
        m$pres_rows, m$pres_cols,
        m$bg_rows, m$bg_cols)

    output <- capture.output(
        result <- maxent_print_results(
            species          = "TestSp",
            eval_result      = eval_r,
            contributions_df = contrib,
            perm_imp_df      = perm_imp,
            n_presence       = length(m$pres_rows),
            n_background     = length(m$bg_rows),
            test_eval_result = test_eval_r,
            n_test           = 4L,
            fit_result       = m$fit_result))

    combined <- paste(output, collapse = "\n")
    expect_true(grepl("n test",           combined))
    expect_true(grepl("Test statistics",  combined))
    expect_equal(result$n_test, 4L)
    expect_true(is.numeric(result$test_auc))
})
