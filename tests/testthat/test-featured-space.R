test_that("FeaturedSpace can be created from features", {
    skip_if_not_installed("maxentcpp")

    n   <- 100L
    env <- seq(0, 1, length.out = n)
    f   <- maxent_linear_feature(env, "env1")

    # Sample indices (0-based): last 10 points
    idx <- as.integer(90:99)

    fs <- maxent_featured_space(n, idx, list(f))
    expect_true(!is.null(fs))
})

test_that("FeaturedSpace retains feature pointers after garbage collection", {
    skip_if_not_installed("maxentcpp")

    n <- 50L
    idx <- as.integer(40:49)

    fs <- local({
        env <- seq(0, 1, length.out = n)
        maxent_featured_space(n, idx, list(maxent_linear_feature(env, "env1")))
    })

    invisible(gc())

    w <- maxent_model_weights(fs)
    expect_equal(length(w), n)
    expect_equal(sum(w), 1.0, tolerance = 1e-12)
})

test_that("Initial distribution is uniform (all lambdas = 0)", {
    skip_if_not_installed("maxentcpp")

    n   <- 100L
    env <- seq(0, 1, length.out = n)
    f   <- maxent_linear_feature(env, "env1")
    idx <- as.integer(90:99)

    fs <- maxent_featured_space(n, idx, list(f))
    w  <- maxent_model_weights(fs)

    expect_equal(length(w), n)
    expect_equal(sum(w), 1.0, tolerance = 1e-12)
    # Each weight should be 1/n for uniform distribution
    expect_equal(w[1], 1.0 / n, tolerance = 1e-9)
    expect_equal(w[50], 1.0 / n, tolerance = 1e-9)
})

test_that("Model weights sum to ~1.0", {
    skip_if_not_installed("maxentcpp")

    n   <- 50L
    env1 <- runif(n)
    env2 <- runif(n)
    f1   <- maxent_linear_feature(env1, "v1")
    f2   <- maxent_linear_feature(env2, "v2")
    idx  <- as.integer(40:49)

    fs <- maxent_featured_space(n, idx, list(f1, f2))

    # Even before training, weights should sum to 1
    w <- maxent_model_weights(fs)
    expect_equal(sum(w), 1.0, tolerance = 1e-12)
})

test_that("Entropy is non-negative and bounded by log(n)", {
    skip_if_not_installed("maxentcpp")

    n   <- 100L
    env <- seq(0, 1, length.out = n)
    f   <- maxent_linear_feature(env, "env1")
    idx <- as.integer(90:99)

    fs <- maxent_featured_space(n, idx, list(f))
    H  <- maxent_model_entropy(fs)

    expect_true(H >= 0)
    expect_true(H <= log(n) + 1e-9)

    # Uniform distribution has max entropy = log(n)
    expect_equal(H, log(n), tolerance = 1e-9)
})

test_that("Training reduces loss", {
    skip_if_not_installed("maxentcpp")

    set.seed(42)
    n    <- 100L
    env  <- seq(0, 1, length.out = n)
    f    <- maxent_linear_feature(env, "env1")
    idx  <- as.integer(90:99)

    # Record initial loss (all lambdas = 0)
    fs0 <- maxent_featured_space(n, idx, list(f))
    # Set sample expectations to get meaningful loss
    maxent_set_sample_expectations(fs0)
    initial_loss <- maxent_model_loss(fs0)

    # Train a fresh model
    f2  <- maxent_linear_feature(env, "env1")
    fs  <- maxent_featured_space(n, idx, list(f2))
    res <- maxent_fit(fs, max_iter = 300L, convergence = 1e-5)

    expect_true(res$loss <= initial_loss + 1e-9)
    expect_true(res$iterations > 0L)
    expect_equal(length(res$lambdas), 1L)
    expect_true(res$entropy >= 0)
    expect_true(is.logical(res$converged))
})

test_that("Loss is finite after training", {
    skip_if_not_installed("maxentcpp")

    n   <- 80L
    env <- seq(0, 1, length.out = n)
    f   <- maxent_linear_feature(env, "env1")
    idx <- as.integer(70:79)

    fs  <- maxent_featured_space(n, idx, list(f))
    res <- maxent_fit(fs, max_iter = 100L)

    expect_true(is.finite(res$loss))
    expect_true(is.finite(res$entropy))
})

test_that("Prediction returns a numeric vector", {
    skip_if_not_installed("maxentcpp")

    n   <- 50L
    env <- seq(0, 1, length.out = n)
    f   <- maxent_linear_feature(env, "env1")
    idx <- as.integer(40:49)

    fs <- maxent_featured_space(n, idx, list(f))
    maxent_fit(fs, max_iter = 100L)

    # Predict on 5 new points (feature values already evaluated)
    newdata <- matrix(seq(0.1, 0.9, length.out = 5), ncol = 1)
    preds   <- maxent_predict_model(fs, newdata)

    expect_equal(length(preds), 5L)
    expect_true(all(is.finite(preds)))
    expect_true(all(preds >= 0))
})

test_that("Lambda save/load round-trip preserves values", {
    skip_if_not_installed("maxentcpp")

    n    <- 80L
    env1 <- seq(0, 1, length.out = n)
    env2 <- rev(env1)
    f1   <- maxent_linear_feature(env1, "v1")
    f2   <- maxent_linear_feature(env2, "v2")
    idx  <- as.integer(70:79)

    # Train
    fs   <- maxent_featured_space(n, idx, list(f1, f2))
    res1 <- maxent_fit(fs, max_iter = 200L)

    # Save
    tmpfile <- tempfile(fileext = ".lambdas")
    on.exit(unlink(tmpfile))
    maxent_save_lambdas(fs, tmpfile)

    expect_true(file.exists(tmpfile))

    # Load into a fresh space
    f1b <- maxent_linear_feature(env1, "v1")
    f2b <- maxent_linear_feature(env2, "v2")
    fs2 <- maxent_featured_space(n, idx, list(f1b, f2b))
    maxent_load_lambdas(fs2, tmpfile)

    # Weights should match
    w1 <- maxent_model_weights(fs)
    w2 <- maxent_model_weights(fs2)
    expect_equal(w1, w2, tolerance = 1e-6)

    # Density normalizer should match
    info1 <- maxent_space_info(fs)
    info2 <- maxent_space_info(fs2)
    expect_equal(info1$density_normalizer, info2$density_normalizer,
                 tolerance = 1e-6)
})

test_that("maxent_space_info returns correct structure", {
    skip_if_not_installed("maxentcpp")

    n   <- 60L
    env <- seq(0, 1, length.out = n)
    f   <- maxent_linear_feature(env, "env1")
    idx <- as.integer(50:59)

    fs   <- maxent_featured_space(n, idx, list(f))
    info <- maxent_space_info(fs)

    expect_equal(info$num_points,   n)
    expect_equal(info$num_samples,  10L)
    expect_equal(info$num_features, 1L)
    expect_true(is.numeric(info$density_normalizer))
    expect_true(is.numeric(info$linear_predictor_normalizer))
})

test_that("Multi-feature training works", {
    skip_if_not_installed("maxentcpp")

    set.seed(123)
    n    <- 100L
    env1 <- seq(0, 1, length.out = n)
    env2 <- rev(env1)
    idx  <- as.integer(80:99)

    f1 <- maxent_linear_feature(env1, "v1")
    f2 <- maxent_linear_feature(env2, "v2")
    fs <- maxent_featured_space(n, idx, list(f1, f2))

    res <- maxent_fit(fs, max_iter = 300L)

    expect_equal(length(res$lambdas), 2L)
    expect_true(is.finite(res$loss))

    w <- maxent_model_weights(fs)
    expect_equal(sum(w), 1.0, tolerance = 1e-12)
})

test_that("maxent_extract_lambdas returns a named numeric vector", {
    skip_if_not_installed("maxentcpp")

    set.seed(42)
    n    <- 100L
    env1 <- seq(0, 1, length.out = n)
    env2 <- rev(env1)
    idx  <- as.integer(80:99)

    f1 <- maxent_linear_feature(env1, "bio1")
    f2 <- maxent_linear_feature(env2, "bio12")
    fs <- maxent_featured_space(n, idx, list(f1, f2))

    fit  <- maxent_fit(fs, max_iter = 300L)

    # Wrap into a minimal run_result list (same structure as maxent_run())
    run_result <- list(model = fs, fit_result = fit)

    lambdas <- maxent_extract_lambdas(run_result)

    expect_true(is.numeric(lambdas))
    expect_equal(length(lambdas), 2L)
    expect_equal(names(lambdas), c("bio1", "bio12"))
    expect_equal(unname(lambdas), fit$lambdas)
})

test_that("maxent_extract_lambdas errors on invalid input", {
    skip_if_not_installed("maxentcpp")

    expect_error(maxent_extract_lambdas(list()), "'run_result' must be")
    expect_error(maxent_extract_lambdas(42),     "'run_result' must be")
})

# =========================================================================
# Bias weights tests
# =========================================================================

test_that("Uniform bias weights match no-bias result", {
    skip_if_not_installed("maxentcpp")

    n   <- 100L
    env <- seq(0, 1, length.out = n)
    idx <- as.integer(90:99)

    f1 <- maxent_linear_feature(env, "env1")
    fs_no_bias <- maxent_featured_space(n, idx, list(f1))

    f2 <- maxent_linear_feature(env, "env1")
    bias <- rep(1.0, n)
    fs_biased <- maxent_featured_space(n, idx, list(f2), bias_weights = bias)

    w1 <- maxent_model_weights(fs_no_bias)
    w2 <- maxent_model_weights(fs_biased)
    expect_equal(w1, w2, tolerance = 1e-12)

    info1 <- maxent_space_info(fs_no_bias)
    info2 <- maxent_space_info(fs_biased)
    expect_false(info1$has_bias)
    expect_true(info2$has_bias)
})

test_that("Bias weights change density distribution", {
    skip_if_not_installed("maxentcpp")

    n   <- 100L
    env <- seq(0, 1, length.out = n)
    idx <- as.integer(90:99)

    # Heavy bias on first half
    bias <- rep(1.0, n)
    bias[1:50] <- 10.0

    f1 <- maxent_linear_feature(env, "env1")
    fs_no_bias <- maxent_featured_space(n, idx, list(f1))

    f2 <- maxent_linear_feature(env, "env1")
    fs_biased <- maxent_featured_space(n, idx, list(f2), bias_weights = bias)

    w_no <- maxent_model_weights(fs_no_bias)
    w_bi <- maxent_model_weights(fs_biased)

    # First half should have higher weight with bias
    expect_true(sum(w_bi[1:50]) > sum(w_no[1:50]))
    # Weights still sum to 1
    expect_equal(sum(w_bi), 1.0, tolerance = 1e-12)
})

test_that("Bias weights affect training results", {
    skip_if_not_installed("maxentcpp")

    n   <- 100L
    env <- seq(0, 1, length.out = n)
    idx <- as.integer(90:99)

    bias <- seq(1.0, 10.0, length.out = n)

    f1 <- maxent_linear_feature(env, "env1")
    fs_no_bias <- maxent_featured_space(n, idx, list(f1))
    res1 <- maxent_fit(fs_no_bias, max_iter = 200L)

    f2 <- maxent_linear_feature(env, "env1")
    fs_biased <- maxent_featured_space(n, idx, list(f2), bias_weights = bias)
    res2 <- maxent_fit(fs_biased, max_iter = 200L)

    # Lambdas should differ
    expect_false(isTRUE(all.equal(res1$lambdas, res2$lambdas, tolerance = 1e-6)))

    # Both should produce valid results
    expect_true(is.finite(res1$loss))
    expect_true(is.finite(res2$loss))
})

test_that("NULL bias_weights produces unbiased model", {
    skip_if_not_installed("maxentcpp")

    n   <- 50L
    env <- seq(0, 1, length.out = n)
    idx <- as.integer(40:49)

    f <- maxent_linear_feature(env, "env1")
    fs <- maxent_featured_space(n, idx, list(f), bias_weights = NULL)

    info <- maxent_space_info(fs)
    expect_false(info$has_bias)
    w <- maxent_model_weights(fs)
    expect_equal(w[1], 1.0 / n, tolerance = 1e-9)
})
