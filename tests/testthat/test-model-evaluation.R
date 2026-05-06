test_that("AUC gives 1.0 for perfect separation", {
    skip_if_not_installed("maxentcpp")

    res <- maxent_auc(c(0.8, 0.9, 1.0), c(0.1, 0.2, 0.3))
    expect_equal(res$auc, 1.0, tolerance = 1e-9)
    expect_true(res$max_kappa >= 0)
})

test_that("AUC gives 0.5 for no discrimination", {
    skip_if_not_installed("maxentcpp")

    res <- maxent_auc(c(0.5, 0.5, 0.5), c(0.5, 0.5, 0.5))
    expect_equal(res$auc, 0.5, tolerance = 1e-9)
})

test_that("Pearson correlation works correctly", {
    skip_if_not_installed("maxentcpp")

    # Perfect positive
    r <- maxent_correlation(c(1, 2, 3, 4, 5), c(2, 4, 6, 8, 10))
    expect_equal(r, 1.0, tolerance = 1e-9)

    # Perfect negative
    r2 <- maxent_correlation(c(1, 2, 3, 4, 5), c(10, 8, 6, 4, 2))
    expect_equal(r2, -1.0, tolerance = 1e-9)
})

test_that("Log-loss is 0 for perfect predictions", {
    skip_if_not_installed("maxentcpp")

    ll <- maxent_logloss(c(1.0, 1.0), c(0.0, 0.0))
    expect_equal(ll, 0.0, tolerance = 1e-9)
})

test_that("Log-loss clamps finite predictions outside [0, 1]", {
    skip_if_not_installed("maxentcpp")

    ll <- maxent_logloss(c(-0.2, 1.2), c(1.4, -0.3))
    expect_true(is.finite(ll))
    expect_true(ll >= 0)
})

test_that("Log-loss rejects non-finite predictions", {
    skip_if_not_installed("maxentcpp")

    expect_error(maxent_logloss(c(0.5, NA_real_), c(0.2)), "must be finite")
    expect_error(maxent_logloss(c(0.5), c(Inf)), "must be finite")
})

test_that("Squared error is 0 for perfect predictions", {
    skip_if_not_installed("maxentcpp")

    se <- maxent_square_error(c(1.0, 1.0), c(0.0, 0.0))
    expect_equal(se, 0.0, tolerance = 1e-9)
})

test_that("Misclassification is 0 for correct predictions", {
    skip_if_not_installed("maxentcpp")

    mc <- maxent_misclassification(c(0.8, 0.9), c(0.1, 0.2))
    expect_equal(mc, 0.0, tolerance = 1e-9)
})

test_that("Misclassification is 1 for all wrong", {
    skip_if_not_installed("maxentcpp")

    mc <- maxent_misclassification(c(0.1, 0.2), c(0.8, 0.9))
    expect_equal(mc, 1.0, tolerance = 1e-9)
})

test_that("Full evaluate returns all metrics", {
    skip_if_not_installed("maxentcpp")

    res <- maxent_evaluate(c(0.9, 0.85, 0.95), c(0.1, 0.15, 0.2))
    expect_true("auc" %in% names(res))
    expect_true("max_kappa" %in% names(res))
    expect_true("correlation" %in% names(res))
    expect_true("square_error" %in% names(res))
    expect_true("logloss" %in% names(res))
    expect_true("misclassification" %in% names(res))
    expect_true("prevalence" %in% names(res))

    expect_equal(res$auc, 1.0, tolerance = 1e-9)
    expect_equal(res$prevalence, 0.5, tolerance = 1e-9)
    expect_true(res$correlation > 0)
})

test_that("AUC handles partial overlap", {
    skip_if_not_installed("maxentcpp")

    res <- maxent_auc(c(0.6, 0.7, 0.8), c(0.3, 0.5, 0.65))
    expect_true(res$auc > 0.5)
    expect_true(res$auc < 1.0)
})
