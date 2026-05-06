# Tests for Java Maxent numerical equivalency fixes:
#  Phase 1: raw_java capped at 1.0 for novel environments
#  Phase 2: Feature clamping for out-of-range env values
#  Phase 3: ThresholdFeature uses non-strict >= comparison
#  Phase 4: read_lambdas() preserves entropy and normalizers

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# A tiny model trained on 3 points (bio values 0.2, 0.5, 0.8) with 9 bg pts.
make_tiny_model <- function() {
    vals <- seq(0, 1, length.out = 9)
    env_data <- list(bio1 = vals)
    features <- maxent_generate_features(env_data, types = "linear",
                                         n_thresholds = 0L, n_hinges = 0L)
    model <- maxent_featured_space(9L, c(2L, 5L, 8L), features)
    maxent_fit(model, max_iter = 300L, convergence = 1e-6, beta_multiplier = 1.0)
    model
}

# ---------------------------------------------------------------------------
# Phase 1: raw_java cap at 1.0
# ---------------------------------------------------------------------------

test_that("raw_java is capped at 1.0 for in-range values", {
    skip_if_not_installed("maxentcpp")

    model <- make_tiny_model()
    info  <- maxent_featured_space_info(model)
    dn    <- info$density_normalizer

    # In-range env value should produce raw_java <= 1 without capping
    dim  <- maxent_dimension(nrows = 1L, ncols = 3L, xll = 0, yll = 0, cellsize = 1)
    g    <- maxent_grid(dim, "bio1")
    grid_set_value(g, 0L, 0L, 0.0)
    grid_set_value(g, 0L, 1L, 0.5)
    grid_set_value(g, 0L, 2L, 1.0)

    raw_java_grid <- maxent_project_raw(model, list(g), c("bio1"))
    raw_java_mat  <- maxent_grid_to_matrix(raw_java_grid)

    expect_true(all(raw_java_mat <= 1.0))
    expect_true(all(raw_java_mat >= 0.0))
})

test_that("extreme out-of-range env values produce the same raw_java as the training max boundary", {
    skip_if_not_installed("maxentcpp")

    model <- make_tiny_model()

    # With Phase 2 feature clamping, env value 1e6 is clamped to the training
    # max (1.0) and should produce the same prediction as env = 1.0.
    # The Phase 1 cap at 1.0 still applies as a safety bound.
    dim     <- maxent_dimension(nrows = 1L, ncols = 1L, xll = 0, yll = 0, cellsize = 1)
    g       <- maxent_grid(dim, "bio1")
    g_max   <- maxent_grid(dim, "bio1")
    grid_set_value(g,     0L, 0L, 1e6)   # extreme out-of-range value
    grid_set_value(g_max, 0L, 0L, 1.0)   # max training value

    raw_java_grid <- maxent_project_raw(model, list(g),     c("bio1"))
    raw_max_grid  <- maxent_project_raw(model, list(g_max), c("bio1"))
    raw_java_mat  <- maxent_grid_to_matrix(raw_java_grid)
    raw_max       <- maxent_grid_to_matrix(raw_max_grid)[1, 1]

    # Extreme values are clamped to the boundary, producing the same prediction
    expect_equal(raw_java_mat[1, 1], raw_max, tolerance = 1e-9)
    # The cap invariant: raw_java is always bounded by 1.0
    expect_true(raw_java_mat[1, 1] <= 1.0)
})

# ---------------------------------------------------------------------------
# Phase 2: Feature clamping
# ---------------------------------------------------------------------------

test_that("LinearFeature eval_from_env clamps out-of-range values to [0,1]", {
    skip_if_not_installed("maxentcpp")

    model <- make_tiny_model()

    # A grid where cell 0 has value below training range, cell 1 is in range,
    # cell 2 is above training range.
    dim <- maxent_dimension(nrows = 1L, ncols = 3L, xll = 0, yll = 0, cellsize = 1)
    g   <- maxent_grid(dim, "bio1")
    grid_set_value(g, 0L, 0L, -10.0)   # below min (0)
    grid_set_value(g, 0L, 1L,  0.5)    # in range
    grid_set_value(g, 0L, 2L,  10.0)   # above max (1)

    # With clamping, below-range cells produce the same prediction as the min,
    # and above-range cells produce the same prediction as the max.
    dim_min <- maxent_dimension(nrows = 1L, ncols = 1L, xll = 0, yll = 0, cellsize = 1)
    g_min   <- maxent_grid(dim_min, "bio1")
    g_max   <- maxent_grid(dim_min, "bio1")
    grid_set_value(g_min, 0L, 0L, 0.0)
    grid_set_value(g_max, 0L, 0L, 1.0)

    raw_java_grid <- maxent_project_raw(model, list(g),     c("bio1"))
    raw_min_grid  <- maxent_project_raw(model, list(g_min), c("bio1"))
    raw_max_grid  <- maxent_project_raw(model, list(g_max), c("bio1"))

    raw_java_mat <- maxent_grid_to_matrix(raw_java_grid)
    raw_min      <- maxent_grid_to_matrix(raw_min_grid)[1, 1]
    raw_max      <- maxent_grid_to_matrix(raw_max_grid)[1, 1]

    expect_equal(raw_java_mat[1, 1], raw_min, tolerance = 1e-9)  # below → same as min
    expect_equal(raw_java_mat[1, 3], raw_max, tolerance = 1e-9)  # above → same as max (capped at 1)
})

test_that("cloglog_java stays in [0,1] for extreme env values", {
    skip_if_not_installed("maxentcpp")

    model <- make_tiny_model()

    dim <- maxent_dimension(nrows = 1L, ncols = 2L, xll = 0, yll = 0, cellsize = 1)
    g   <- maxent_grid(dim, "bio1")
    grid_set_value(g, 0L, 0L, -1e6)
    grid_set_value(g, 0L, 1L,  1e6)

    cloglog_grid <- maxent_project_cloglog(model, list(g), c("bio1"))
    cloglog_mat  <- maxent_grid_to_matrix(cloglog_grid)

    expect_true(all(cloglog_mat >= 0.0 & cloglog_mat <= 1.0))
})

# ---------------------------------------------------------------------------
# Phase 3: ThresholdFeature >= semantics
# ---------------------------------------------------------------------------

test_that("ThresholdFeature returns 1.0 when value equals threshold", {
    skip_if_not_installed("maxentcpp")

    vals <- c(3.0, 5.0, 7.0)
    f    <- maxent_threshold_feature(vals, "thresh", threshold = 5.0)

    expect_equal(maxent_feature_eval(f, 1L), 0.0)  # 3.0 < 5.0 → 0
    expect_equal(maxent_feature_eval(f, 2L), 1.0)  # 5.0 == 5.0 → 1 (non-strict >=)
    expect_equal(maxent_feature_eval(f, 3L), 1.0)  # 7.0 > 5.0 → 1
})

test_that("ThresholdFeature returns 0.0 for value strictly below threshold", {
    skip_if_not_installed("maxentcpp")

    vals <- c(4.9, 5.0, 5.1)
    f    <- maxent_threshold_feature(vals, "thresh2", threshold = 5.0)

    expect_equal(maxent_feature_eval(f, 1L), 0.0)  # 4.9 < 5.0
    expect_equal(maxent_feature_eval(f, 2L), 1.0)  # 5.0 == 5.0
    expect_equal(maxent_feature_eval(f, 3L), 1.0)  # 5.1 > 5.0
})

# ---------------------------------------------------------------------------
# Phase 4: read_lambdas() preserves entropy and normalizers
# ---------------------------------------------------------------------------

test_that("read_lambdas restores entropy matching the trained model", {
    skip_if_not_installed("maxentcpp")

    model <- make_tiny_model()

    H_trained <- maxent_model_entropy(model)
    info_trained <- maxent_featured_space_info(model)
    lpn_trained  <- info_trained$linear_predictor_normalizer
    dn_trained   <- info_trained$density_normalizer

    # Write and read back into a fresh model
    lambda_file <- tempfile(fileext = ".csv")
    on.exit(unlink(lambda_file), add = TRUE)
    maxent_write_lambdas(model, lambda_file)

    # Build an identical empty featured space and read lambdas into it
    vals_empty <- seq(0, 1, length.out = 9)
    env_data   <- list(bio1 = vals_empty)
    features2  <- maxent_generate_features(env_data, types = "linear",
                                           n_thresholds = 0L, n_hinges = 0L)
    model2 <- maxent_featured_space(9L, c(2L, 5L, 8L), features2)
    maxent_read_lambdas(model2, lambda_file)

    H2    <- maxent_model_entropy(model2)
    info2 <- maxent_featured_space_info(model2)

    expect_equal(H2,                      H_trained,   tolerance = 1e-9)
    expect_equal(info2$density_normalizer,          dn_trained,  tolerance = 1e-9)
    expect_equal(info2$linear_predictor_normalizer, lpn_trained, tolerance = 1e-9)
})

test_that("predictions from read_lambdas model match original", {
    skip_if_not_installed("maxentcpp")

    model <- make_tiny_model()

    lambda_file <- tempfile(fileext = ".csv")
    on.exit(unlink(lambda_file), add = TRUE)
    maxent_write_lambdas(model, lambda_file)

    vals_empty <- seq(0, 1, length.out = 9)
    env_data   <- list(bio1 = vals_empty)
    features2  <- maxent_generate_features(env_data, types = "linear",
                                           n_thresholds = 0L, n_hinges = 0L)
    model2 <- maxent_featured_space(9L, c(2L, 5L, 8L), features2)
    maxent_read_lambdas(model2, lambda_file)

    # Build a small grid and compare cloglog_java predictions
    dim <- maxent_dimension(nrows = 1L, ncols = 5L, xll = 0, yll = 0, cellsize = 0.25)
    g   <- maxent_grid(dim, "bio1")
    for (cc in 0:4) grid_set_value(g, 0L, as.integer(cc), cc * 0.25)

    pred1 <- maxent_grid_to_matrix(
        maxent_project_cloglog(model,  list(g), c("bio1")))
    pred2 <- maxent_grid_to_matrix(
        maxent_project_cloglog(model2, list(g), c("bio1")))

    expect_equal(pred1, pred2, tolerance = 1e-6)
})
