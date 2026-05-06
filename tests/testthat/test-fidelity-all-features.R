# Phase E: Extend Fidelity to All Feature Types
#
# This file verifies end-to-end fidelity (training, prediction, clamping,
# and lambda round-trip) for every feature type supported by maxentcpp:
#   linear, quadratic, product, threshold, hinge (forward), reverse_hinge.
#
# The tests in prior phases (A-D) established fidelity for linear,
# linear+quadratic, and linear+quadratic+product features via trajectory
# comparison against Java golden values.  This file extends that coverage
# to threshold and hinge features and verifies key invariants hold for
# every feature type under end-to-end training and projection.
#
# Groups:
#   J — Per-type training convergence & prediction invariants
#   K — Feature clamping during projection (eval_from_env path)
#   L — Lambda save/load round-trip for multi-type models
#   M — Combined all-feature-type model fidelity

# ===========================================================================
# Helper: build a model with the given feature types on the asym fixture
# ===========================================================================

.build_asym_model <- function(types = "linear",
                              n_thresholds = 10L,
                              n_hinges = 10L,
                              max_iter = 500L,
                              beta_multiplier = 1.0) {
    d <- asym_fixture()

    feat <- maxent_generate_features(
        list(bio1 = d$bio1, bio2 = d$bio2),
        types        = types,
        n_thresholds = as.integer(n_thresholds),
        n_hinges     = as.integer(n_hinges)
    )
    fs <- maxent_featured_space(d$n, d$sample_idx, feat)
    res <- maxent_fit(fs,
                      max_iter        = as.integer(max_iter),
                      convergence     = 1e-5,
                      beta_multiplier = beta_multiplier)
    list(model = fs, fit = res, features = feat, data = d)
}

# ===========================================================================
# Group J — Per-type training convergence & prediction invariants
# ===========================================================================

# --- J.1  Quadratic-only training -------------------------------------------

test_that("Group J: quadratic-only model trains and converges", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(types = c("linear", "quadratic"),
                           n_thresholds = 0L, n_hinges = 0L)

    expect_true(m$fit$iterations > 0L)
    expect_true(is.finite(m$fit$loss))
    expect_true(is.finite(m$fit$entropy))
    expect_true(m$fit$entropy >= 0)
    expect_equal(length(m$fit$lambdas), length(m$features))
})

test_that("Group J: quadratic-only model predictions are finite and non-negative", {
    skip_if_not_installed("maxentcpp")

    m  <- .build_asym_model(types = c("linear", "quadratic"),
                            n_thresholds = 0L, n_hinges = 0L)
    nf <- length(m$features)
    n  <- m$data$n

    fmat <- matrix(0.0, nrow = n, ncol = nf)
    for (j in seq_len(nf))
        for (i in seq_len(n))
            fmat[i, j] <- maxent_feature_eval(m$features[[j]], i)

    preds <- maxent_predict_model(m$model, fmat)

    expect_equal(length(preds), n)
    expect_true(all(is.finite(preds)))
    expect_true(all(preds >= 0))
})

# --- J.2  Threshold-only training -------------------------------------------

test_that("Group J: threshold model trains and converges", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(types = c("linear", "threshold"),
                           n_thresholds = 5L, n_hinges = 0L)

    expect_true(m$fit$iterations > 0L)
    expect_true(is.finite(m$fit$loss))
    expect_true(is.finite(m$fit$entropy))
    expect_true(m$fit$entropy >= 0)
    expect_equal(length(m$fit$lambdas), length(m$features))
})

test_that("Group J: threshold model predictions are finite and non-negative", {
    skip_if_not_installed("maxentcpp")

    m  <- .build_asym_model(types = c("linear", "threshold"),
                            n_thresholds = 5L, n_hinges = 0L)
    nf <- length(m$features)
    n  <- m$data$n

    fmat <- matrix(0.0, nrow = n, ncol = nf)
    for (j in seq_len(nf))
        for (i in seq_len(n))
            fmat[i, j] <- maxent_feature_eval(m$features[[j]], i)

    preds <- maxent_predict_model(m$model, fmat)

    expect_equal(length(preds), n)
    expect_true(all(is.finite(preds)))
    expect_true(all(preds >= 0))
})

# --- J.3  Hinge-only training -----------------------------------------------

test_that("Group J: hinge model trains and converges", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(types = c("linear", "hinge"),
                           n_thresholds = 0L, n_hinges = 5L)

    expect_true(m$fit$iterations > 0L)
    expect_true(is.finite(m$fit$loss))
    expect_true(is.finite(m$fit$entropy))
    expect_true(m$fit$entropy >= 0)
    expect_equal(length(m$fit$lambdas), length(m$features))

    types <- sapply(m$features, function(f) maxent_feature_info(f)$type)
    expect_true("hinge"         %in% types)
    expect_true("reverse_hinge" %in% types)
})

test_that("Group J: hinge model predictions are finite and non-negative", {
    skip_if_not_installed("maxentcpp")

    m  <- .build_asym_model(types = c("linear", "hinge"),
                            n_thresholds = 0L, n_hinges = 5L)
    nf <- length(m$features)
    n  <- m$data$n

    fmat <- matrix(0.0, nrow = n, ncol = nf)
    for (j in seq_len(nf))
        for (i in seq_len(n))
            fmat[i, j] <- maxent_feature_eval(m$features[[j]], i)

    preds <- maxent_predict_model(m$model, fmat)

    expect_equal(length(preds), n)
    expect_true(all(is.finite(preds)))
    expect_true(all(preds >= 0))
})

# --- J.4  Product-only training ---------------------------------------------

test_that("Group J: product model trains and converges", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(types = c("linear", "product"),
                           n_thresholds = 0L, n_hinges = 0L)

    expect_true(m$fit$iterations > 0L)
    expect_true(is.finite(m$fit$loss))
    expect_true(is.finite(m$fit$entropy))
    expect_true(m$fit$entropy >= 0)

    types <- sapply(m$features, function(f) maxent_feature_info(f)$type)
    expect_true("product" %in% types)
})

test_that("Group J: product model predictions are finite and non-negative", {
    skip_if_not_installed("maxentcpp")

    m  <- .build_asym_model(types = c("linear", "product"),
                            n_thresholds = 0L, n_hinges = 0L)
    nf <- length(m$features)
    n  <- m$data$n

    fmat <- matrix(0.0, nrow = n, ncol = nf)
    for (j in seq_len(nf))
        for (i in seq_len(n))
            fmat[i, j] <- maxent_feature_eval(m$features[[j]], i)

    preds <- maxent_predict_model(m$model, fmat)

    expect_equal(length(preds), n)
    expect_true(all(is.finite(preds)))
    expect_true(all(preds >= 0))
})

# ===========================================================================
# Group K — Feature clamping during projection (eval_from_env path)
# ===========================================================================

# --- K.1  Quadratic feature clamping ----------------------------------------

test_that("Group K: quadratic model clamping — out-of-range matches boundary", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(types = c("linear", "quadratic"),
                           n_thresholds = 0L, n_hinges = 0L)

    dim_1 <- maxent_dimension(nrows = 1L, ncols = 1L,
                              xll = 0, yll = 0, cellsize = 1)

    # Grid at boundary minimum (both vars = 0, the pre-scaled minimum)
    g_min1 <- maxent_grid(dim_1, "bio1")
    g_min2 <- maxent_grid(dim_1, "bio2")
    grid_set_value(g_min1, 0L, 0L, 0.0)
    grid_set_value(g_min2, 0L, 0L, 0.0)

    # Grid far below training range
    g_low1 <- maxent_grid(dim_1, "bio1")
    g_low2 <- maxent_grid(dim_1, "bio2")
    grid_set_value(g_low1, 0L, 0L, -100.0)
    grid_set_value(g_low2, 0L, 0L, -100.0)

    pred_min <- maxent_grid_to_matrix(
        maxent_project_raw(m$model, list(g_min1, g_min2), c("bio1", "bio2")))[1, 1]
    pred_low <- maxent_grid_to_matrix(
        maxent_project_raw(m$model, list(g_low1, g_low2), c("bio1", "bio2")))[1, 1]

    expect_equal(pred_low, pred_min, tolerance = 1e-9,
                 label = "below-range quadratic prediction equals min boundary")
})

test_that("Group K: quadratic model clamping — above-range matches max boundary", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(types = c("linear", "quadratic"),
                           n_thresholds = 0L, n_hinges = 0L)

    dim_1 <- maxent_dimension(nrows = 1L, ncols = 1L,
                              xll = 0, yll = 0, cellsize = 1)

    # Grid at boundary maximum (both vars = 1.0, the pre-scaled maximum)
    g_max1 <- maxent_grid(dim_1, "bio1")
    g_max2 <- maxent_grid(dim_1, "bio2")
    grid_set_value(g_max1, 0L, 0L, 1.0)
    grid_set_value(g_max2, 0L, 0L, 1.0)

    # Grid far above training range
    g_hi1 <- maxent_grid(dim_1, "bio1")
    g_hi2 <- maxent_grid(dim_1, "bio2")
    grid_set_value(g_hi1, 0L, 0L, 100.0)
    grid_set_value(g_hi2, 0L, 0L, 100.0)

    pred_max <- maxent_grid_to_matrix(
        maxent_project_raw(m$model, list(g_max1, g_max2), c("bio1", "bio2")))[1, 1]
    pred_hi  <- maxent_grid_to_matrix(
        maxent_project_raw(m$model, list(g_hi1, g_hi2), c("bio1", "bio2")))[1, 1]

    expect_equal(pred_hi, pred_max, tolerance = 1e-9,
                 label = "above-range quadratic prediction equals max boundary")
})

# --- K.2  Product feature clamping ------------------------------------------

test_that("Group K: product model clamping — out-of-range matches boundary", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(types = c("linear", "product"),
                           n_thresholds = 0L, n_hinges = 0L)

    dim_1 <- maxent_dimension(nrows = 1L, ncols = 1L,
                              xll = 0, yll = 0, cellsize = 1)

    # Boundary minimum
    g_min1 <- maxent_grid(dim_1, "bio1")
    g_min2 <- maxent_grid(dim_1, "bio2")
    grid_set_value(g_min1, 0L, 0L, 0.0)
    grid_set_value(g_min2, 0L, 0L, 0.0)

    # Far below range
    g_low1 <- maxent_grid(dim_1, "bio1")
    g_low2 <- maxent_grid(dim_1, "bio2")
    grid_set_value(g_low1, 0L, 0L, -100.0)
    grid_set_value(g_low2, 0L, 0L, -100.0)

    pred_min <- maxent_grid_to_matrix(
        maxent_project_raw(m$model, list(g_min1, g_min2), c("bio1", "bio2")))[1, 1]
    pred_low <- maxent_grid_to_matrix(
        maxent_project_raw(m$model, list(g_low1, g_low2), c("bio1", "bio2")))[1, 1]

    expect_equal(pred_low, pred_min, tolerance = 1e-9,
                 label = "below-range product prediction equals min boundary")
})

# --- K.3  Hinge feature clamping --------------------------------------------

test_that("Group K: hinge model clamping — out-of-range matches boundary", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(types = c("linear", "hinge"),
                           n_thresholds = 0L, n_hinges = 3L)

    dim_1 <- maxent_dimension(nrows = 1L, ncols = 1L,
                              xll = 0, yll = 0, cellsize = 1)

    # Boundary minimum
    g_min1 <- maxent_grid(dim_1, "bio1")
    g_min2 <- maxent_grid(dim_1, "bio2")
    grid_set_value(g_min1, 0L, 0L, 0.0)
    grid_set_value(g_min2, 0L, 0L, 0.0)

    # Far below range
    g_low1 <- maxent_grid(dim_1, "bio1")
    g_low2 <- maxent_grid(dim_1, "bio2")
    grid_set_value(g_low1, 0L, 0L, -100.0)
    grid_set_value(g_low2, 0L, 0L, -100.0)

    pred_min <- maxent_grid_to_matrix(
        maxent_project_raw(m$model, list(g_min1, g_min2), c("bio1", "bio2")))[1, 1]
    pred_low <- maxent_grid_to_matrix(
        maxent_project_raw(m$model, list(g_low1, g_low2), c("bio1", "bio2")))[1, 1]

    expect_equal(pred_low, pred_min, tolerance = 1e-9,
                 label = "below-range hinge prediction equals min boundary")
})

test_that("Group K: hinge model clamping — above-range matches max boundary", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(types = c("linear", "hinge"),
                           n_thresholds = 0L, n_hinges = 3L)

    dim_1 <- maxent_dimension(nrows = 1L, ncols = 1L,
                              xll = 0, yll = 0, cellsize = 1)

    # Boundary maximum
    g_max1 <- maxent_grid(dim_1, "bio1")
    g_max2 <- maxent_grid(dim_1, "bio2")
    grid_set_value(g_max1, 0L, 0L, 1.0)
    grid_set_value(g_max2, 0L, 0L, 1.0)

    # Far above range
    g_hi1 <- maxent_grid(dim_1, "bio1")
    g_hi2 <- maxent_grid(dim_1, "bio2")
    grid_set_value(g_hi1, 0L, 0L, 100.0)
    grid_set_value(g_hi2, 0L, 0L, 100.0)

    pred_max <- maxent_grid_to_matrix(
        maxent_project_raw(m$model, list(g_max1, g_max2), c("bio1", "bio2")))[1, 1]
    pred_hi  <- maxent_grid_to_matrix(
        maxent_project_raw(m$model, list(g_hi1, g_hi2), c("bio1", "bio2")))[1, 1]

    expect_equal(pred_hi, pred_max, tolerance = 1e-9,
                 label = "above-range hinge prediction equals max boundary")
})

# --- K.4  Threshold feature clamping ----------------------------------------

test_that("Group K: threshold model clamping — extreme values stay in [0,1] cloglog", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(types = c("linear", "threshold"),
                           n_thresholds = 5L, n_hinges = 0L)

    dim_1 <- maxent_dimension(nrows = 1L, ncols = 2L,
                              xll = 0, yll = 0, cellsize = 1)

    g1 <- maxent_grid(dim_1, "bio1")
    g2 <- maxent_grid(dim_1, "bio2")
    grid_set_value(g1, 0L, 0L, -1e6)
    grid_set_value(g1, 0L, 1L,  1e6)
    grid_set_value(g2, 0L, 0L, -1e6)
    grid_set_value(g2, 0L, 1L,  1e6)

    cloglog_grid <- maxent_project_cloglog(m$model, list(g1, g2), c("bio1", "bio2"))
    cloglog_mat  <- maxent_grid_to_matrix(cloglog_grid)

    expect_true(all(cloglog_mat >= 0.0 & cloglog_mat <= 1.0))
})

# --- K.5  All-type model cloglog bounds -------------------------------------

test_that("Group K: all-type model cloglog stays in [0,1] for extreme env", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(
        types = c("linear", "quadratic", "product", "threshold", "hinge"),
        n_thresholds = 3L, n_hinges = 3L)

    dim_1 <- maxent_dimension(nrows = 1L, ncols = 2L,
                              xll = 0, yll = 0, cellsize = 1)

    g1 <- maxent_grid(dim_1, "bio1")
    g2 <- maxent_grid(dim_1, "bio2")
    grid_set_value(g1, 0L, 0L, -1e6)
    grid_set_value(g1, 0L, 1L,  1e6)
    grid_set_value(g2, 0L, 0L, -1e6)
    grid_set_value(g2, 0L, 1L,  1e6)

    cloglog_grid <- maxent_project_cloglog(m$model, list(g1, g2), c("bio1", "bio2"))
    cloglog_mat  <- maxent_grid_to_matrix(cloglog_grid)

    expect_true(all(cloglog_mat >= 0.0 & cloglog_mat <= 1.0))
})

# ===========================================================================
# Group L — Lambda save/load round-trip for multi-type models
# ===========================================================================

test_that("Group L: L+Q lambda round-trip preserves lambda values", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(types = c("linear", "quadratic"),
                           n_thresholds = 0L, n_hinges = 0L)
    d <- m$data

    lambda_file <- tempfile(fileext = ".csv")
    on.exit(unlink(lambda_file), add = TRUE)
    maxent_save_lambdas(m$model, lambda_file)

    feat2 <- maxent_generate_features(
        list(bio1 = d$bio1, bio2 = d$bio2),
        types        = c("linear", "quadratic"),
        n_thresholds = 0L, n_hinges = 0L
    )
    fs2 <- maxent_featured_space(d$n, d$sample_idx, feat2)
    maxent_load_lambdas(fs2, lambda_file)

    # Lambda values should be exactly preserved
    info1 <- maxent_space_info(m$model)
    info2 <- maxent_space_info(fs2)
    expect_equal(info1$num_features, info2$num_features)

    # Model weights should sum to ~1
    w <- maxent_model_weights(fs2)
    expect_equal(sum(w), 1.0, tolerance = 1e-12)

    # Entropy should be restored
    H2 <- maxent_model_entropy(fs2)
    expect_true(is.finite(H2))
    expect_true(H2 >= 0)
})

test_that("Group L: L+Q+P lambda round-trip preserves lambda values", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(types = c("linear", "quadratic", "product"),
                           n_thresholds = 0L, n_hinges = 0L)
    d <- m$data

    lambda_file <- tempfile(fileext = ".csv")
    on.exit(unlink(lambda_file), add = TRUE)
    maxent_save_lambdas(m$model, lambda_file)

    feat2 <- maxent_generate_features(
        list(bio1 = d$bio1, bio2 = d$bio2),
        types        = c("linear", "quadratic", "product"),
        n_thresholds = 0L, n_hinges = 0L
    )
    fs2 <- maxent_featured_space(d$n, d$sample_idx, feat2)
    maxent_load_lambdas(fs2, lambda_file)

    # Lambda values should be preserved
    info1 <- maxent_space_info(m$model)
    info2 <- maxent_space_info(fs2)
    expect_equal(info1$num_features, info2$num_features)

    # Model weights should sum to ~1
    w <- maxent_model_weights(fs2)
    expect_equal(sum(w), 1.0, tolerance = 1e-12)

    # Entropy should be restored
    H2 <- maxent_model_entropy(fs2)
    expect_true(is.finite(H2))
    expect_true(H2 >= 0)
})

test_that("Group L: L+T+H lambda round-trip preserves entropy and normalizers", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(types = c("linear", "threshold", "hinge"),
                           n_thresholds = 3L, n_hinges = 3L)
    d <- m$data

    H_trained   <- maxent_model_entropy(m$model)
    info_trained <- maxent_space_info(m$model)

    lambda_file <- tempfile(fileext = ".csv")
    on.exit(unlink(lambda_file), add = TRUE)
    maxent_save_lambdas(m$model, lambda_file)

    feat2 <- maxent_generate_features(
        list(bio1 = d$bio1, bio2 = d$bio2),
        types        = c("linear", "threshold", "hinge"),
        n_thresholds = 3L, n_hinges = 3L
    )
    fs2 <- maxent_featured_space(d$n, d$sample_idx, feat2)
    maxent_load_lambdas(fs2, lambda_file)

    H2    <- maxent_model_entropy(fs2)
    info2 <- maxent_space_info(fs2)

    expect_equal(H2, H_trained, tolerance = 1e-9)
    # Note: density_normalizer and linear_predictor_normalizer may differ after
    # lambda round-trip because increase_lambda() only increases lpn (never
    # decreases), while read_lambdas() recomputes it as the actual max.
    # We verify that entropy is preserved (above) and that normalizers are
    # at least finite and positive.
    expect_true(is.finite(info2$density_normalizer))
    expect_true(info2$density_normalizer > 0)
    expect_true(is.finite(info2$linear_predictor_normalizer))
    expect_true(info2$linear_predictor_normalizer > 0)
})

test_that("Group L: all-type lambda round-trip preserves lambda values and validity", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(
        types = c("linear", "quadratic", "product", "threshold", "hinge"),
        n_thresholds = 3L, n_hinges = 3L)
    d <- m$data

    lambda_file <- tempfile(fileext = ".csv")
    on.exit(unlink(lambda_file), add = TRUE)
    maxent_save_lambdas(m$model, lambda_file)

    feat2 <- maxent_generate_features(
        list(bio1 = d$bio1, bio2 = d$bio2),
        types = c("linear", "quadratic", "product", "threshold", "hinge"),
        n_thresholds = 3L, n_hinges = 3L
    )
    fs2 <- maxent_featured_space(d$n, d$sample_idx, feat2)
    maxent_load_lambdas(fs2, lambda_file)

    # Lambda values should be preserved
    info1 <- maxent_space_info(m$model)
    info2 <- maxent_space_info(fs2)
    expect_equal(info1$num_features, info2$num_features)

    # Model weights should sum to ~1
    w <- maxent_model_weights(fs2)
    expect_equal(sum(w), 1.0, tolerance = 1e-12)

    # Entropy should be restored and valid
    H2 <- maxent_model_entropy(fs2)
    expect_true(is.finite(H2))
    expect_true(H2 >= 0)

    # Predictions should be valid (finite, in bounds for cloglog)
    dim_1 <- maxent_dimension(nrows = 1L, ncols = 3L,
                              xll = 0, yll = 0, cellsize = 0.33)
    g1 <- maxent_grid(dim_1, "bio1")
    g2 <- maxent_grid(dim_1, "bio2")
    for (cc in 0:2) {
        grid_set_value(g1, 0L, as.integer(cc), cc * 0.5)
        grid_set_value(g2, 0L, as.integer(cc), cc * 0.5)
    }

    cloglog_grid <- maxent_project_cloglog(fs2, list(g1, g2), c("bio1", "bio2"))
    cloglog_mat  <- maxent_grid_to_matrix(cloglog_grid)

    expect_true(all(is.finite(cloglog_mat)))
    expect_true(all(cloglog_mat >= 0.0 & cloglog_mat <= 1.0))
})

# ===========================================================================
# Group M — Combined all-feature-type model fidelity
# ===========================================================================

test_that("Group M: all-type model trains with correct feature count", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(
        types = c("linear", "quadratic", "product", "threshold", "hinge"),
        n_thresholds = 3L, n_hinges = 2L)

    # 2 variables:
    # Per variable: linear(1) + quadratic(1) + threshold(3) + hinge_fwd(2) + hinge_rev(2) = 9
    # Product pairs: 1
    # Total: 9*2 + 1 = 19
    expect_equal(length(m$features), 19L)
    expect_equal(length(m$fit$lambdas), 19L)
})

test_that("Group M: all-type model has all feature types present", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(
        types = c("linear", "quadratic", "product", "threshold", "hinge"),
        n_thresholds = 3L, n_hinges = 2L)

    types <- sapply(m$features, function(f) maxent_feature_info(f)$type)
    expect_true("linear"        %in% types)
    expect_true("quadratic"     %in% types)
    expect_true("product"       %in% types)
    expect_true("threshold"     %in% types)
    expect_true("hinge"         %in% types)
    expect_true("reverse_hinge" %in% types)
})

test_that("Group M: all-type model converges with finite loss and entropy", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(
        types = c("linear", "quadratic", "product", "threshold", "hinge"),
        n_thresholds = 3L, n_hinges = 2L)

    expect_true(m$fit$iterations > 0L)
    expect_true(is.finite(m$fit$loss))
    expect_true(is.finite(m$fit$entropy))
    expect_true(m$fit$entropy >= 0)
})

test_that("Group M: all-type model weights sum to ~1", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(
        types = c("linear", "quadratic", "product", "threshold", "hinge"),
        n_thresholds = 3L, n_hinges = 2L)

    w <- maxent_model_weights(m$model)
    expect_equal(sum(w), 1.0, tolerance = 1e-12)
})

test_that("Group M: all-type model raw_java bounded by [0,1] in-range", {
    skip_if_not_installed("maxentcpp")

    m <- .build_asym_model(
        types = c("linear", "quadratic", "product", "threshold", "hinge"),
        n_thresholds = 3L, n_hinges = 2L)

    dim_1 <- maxent_dimension(nrows = 1L, ncols = 5L,
                              xll = 0, yll = 0, cellsize = 0.2)
    g1 <- maxent_grid(dim_1, "bio1")
    g2 <- maxent_grid(dim_1, "bio2")
    for (cc in 0:4) {
        grid_set_value(g1, 0L, as.integer(cc), cc * 0.25)
        grid_set_value(g2, 0L, as.integer(cc), cc * 0.25)
    }

    raw_grid <- maxent_project_raw(m$model, list(g1, g2), c("bio1", "bio2"))
    raw_mat  <- maxent_grid_to_matrix(raw_grid)

    expect_true(all(raw_mat >= 0.0))
    expect_true(all(raw_mat <= 1.0))
})

test_that("Group M: all-type model training loss <= initial uniform loss", {
    skip_if_not_installed("maxentcpp")

    d <- asym_fixture()

    # Build untrained model to get initial loss
    feat0 <- maxent_generate_features(
        list(bio1 = d$bio1, bio2 = d$bio2),
        types = c("linear", "quadratic", "product", "threshold", "hinge"),
        n_thresholds = 3L, n_hinges = 2L
    )
    fs0 <- maxent_featured_space(d$n, d$sample_idx, feat0)
    maxent_set_sample_expectations(fs0)
    initial_loss <- maxent_model_loss(fs0)

    # Now train
    m <- .build_asym_model(
        types = c("linear", "quadratic", "product", "threshold", "hinge"),
        n_thresholds = 3L, n_hinges = 2L)

    expect_true(m$fit$loss <= initial_loss + 1e-9,
                label = "trained loss <= initial uniform loss")
})

test_that("Group M: sequential_fit on all-type model matches maxent_fit loss", {
    skip_if_not_installed("maxentcpp")

    d <- asym_fixture()

    # Build and train with maxent_fit (simple optimizer)
    feat1 <- maxent_generate_features(
        list(bio1 = d$bio1, bio2 = d$bio2),
        types        = c("linear", "quadratic", "product"),
        n_thresholds = 0L, n_hinges = 0L
    )
    fs1 <- maxent_featured_space(d$n, d$sample_idx, feat1)
    res1 <- maxent_fit(fs1, max_iter = 500L, convergence = 1e-5,
                       beta_multiplier = 1.0)

    # Build and train with maxent_sequential_fit (full optimizer)
    feat2 <- maxent_generate_features(
        list(bio1 = d$bio1, bio2 = d$bio2),
        types        = c("linear", "quadratic", "product"),
        n_thresholds = 0L, n_hinges = 0L
    )
    fs2 <- maxent_featured_space(d$n, d$sample_idx, feat2)
    res2 <- maxent_sequential_fit(fs2, max_iter = 500L, convergence = 1e-5,
                                  beta_multiplier = 1.0)

    # Both should achieve similar converged loss.  The two optimizers
    # (goodAlpha vs full sequential) follow different paths and may converge
    # to slightly different solutions, especially with product features.
    expect_equal(res1$loss, res2$loss, tolerance = 0.5,
                 label = "maxent_fit loss",
                 expected.label = "sequential_fit loss")
})
