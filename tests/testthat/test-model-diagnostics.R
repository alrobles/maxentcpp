test_that("Percent contribution returns correct structure", {
    skip_if_not_installed("maxentcpp")

    # Create a simple model
    dim <- maxent_dimension(nrows = 3, ncols = 3, xll = 0, yll = 0, cellsize = 1)
    g0 <- maxent_grid(dim, "env0")
    g1 <- maxent_grid(dim, "env1")
    idx <- 0
    for (r in 0:2) {
        for (cc in 0:2) {
            grid_set_value(g0, r, cc, idx / 8.0)
            grid_set_value(g1, r, cc, 0.5)
            idx <- idx + 1
        }
    }

    vals0 <- sapply(0:8, function(i) i / 8.0)
    vals1 <- rep(0.5, 9)

    # Use named list with correct API: types vector, n_thresholds, n_hinges
    env_data <- list(env0 = vals0, env1 = vals1)
    features <- maxent_generate_features(env_data, types = "linear",
                                         n_thresholds = 0, n_hinges = 0)

    model <- maxent_featured_space(9, c(6L, 7L, 8L), features)
    maxent_fit(model, max_iter = 100, convergence = 0.001, beta_multiplier = 1.0)

    contrib <- maxent_percent_contribution(model, c("env0", "env1"))

    expect_true(is.data.frame(contrib))
    expect_true("name" %in% names(contrib))
    expect_true("contribution" %in% names(contrib))
    expect_equal(nrow(contrib), 2)
    expect_equal(sum(contrib$contribution), 100.0, tolerance = 1e-6)
})

test_that("Percent contribution handles prefix-colliding names (bio1/bio12)", {
    skip_if_not_installed("maxentcpp")

    # bio12 starts with "bio1" — old prefix-matching assigned all bio12
    # features to bio1, resulting in 0% for bio12.
    vals1  <- seq(0, 1, length.out = 9)
    vals12 <- seq(1, 0, length.out = 9)

    env_data <- list(bio1 = vals1, bio12 = vals12)
    features <- maxent_generate_features(env_data, types = "linear",
                                         n_thresholds = 0, n_hinges = 0)

    model <- maxent_featured_space(9, c(6L, 7L, 8L), features)
    maxent_fit(model, max_iter = 100, convergence = 0.001, beta_multiplier = 1.0)

    contrib <- maxent_percent_contribution(model, c("bio1", "bio12"))

    expect_equal(nrow(contrib), 2)
    expect_equal(sum(contrib$contribution), 100.0, tolerance = 1e-6)
    # bio12 must NOT be zero when its features have non-zero lambdas
    expect_true(contrib$contribution[contrib$name == "bio12"] > 0)
})

test_that("Clamping works correctly via R wrapper", {
    skip_if_not_installed("maxentcpp")

    dim <- maxent_dimension(nrows = 1, ncols = 3, xll = 0, yll = 0, cellsize = 1)
    g0 <- maxent_grid(dim, "temp")
    grid_set_value(g0, 0, 0, -5.0)   # below min
    grid_set_value(g0, 0, 1, 10.0)   # within range
    grid_set_value(g0, 0, 2, 30.0)   # above max

    result <- maxent_clamp(list(g0), c(0.0), c(20.0))

    expect_true("clamped_grids" %in% names(result))
    expect_true("clamp_grid" %in% names(result))
    expect_length(result$clamped_grids, 1)

    # Check clamped values via grid_to_matrix
    clamped_mat <- grid_float_to_matrix(result$clamped_grids[[1]])
    expect_equal(clamped_mat[1, 1], 0.0, tolerance = 1e-6)
    expect_equal(clamped_mat[1, 2], 10.0, tolerance = 1e-6)
    expect_equal(clamped_mat[1, 3], 20.0, tolerance = 1e-6)

    # Check clamping magnitude grid
    clamp_mat <- grid_float_to_matrix(result$clamp_grid)
    expect_equal(clamp_mat[1, 1], 5.0, tolerance = 1e-6)
    expect_equal(clamp_mat[1, 2], 0.0, tolerance = 1e-6)
    expect_equal(clamp_mat[1, 3], 10.0, tolerance = 1e-6)
})

test_that("Variable ranges are computed correctly", {
    skip_if_not_installed("maxentcpp")

    dim <- maxent_dimension(nrows = 2, ncols = 2, xll = 0, yll = 0, cellsize = 1)
    g0 <- maxent_grid(dim, "temp")
    grid_set_value(g0, 0, 0, 5.0)
    grid_set_value(g0, 0, 1, 15.0)
    grid_set_value(g0, 1, 0, 10.0)
    grid_set_value(g0, 1, 1, 25.0)

    ranges <- maxent_variable_ranges(list(g0))

    expect_true(is.data.frame(ranges))
    expect_equal(ranges$min[1], 5.0, tolerance = 1e-6)
    expect_equal(ranges$max[1], 25.0, tolerance = 1e-6)
})

test_that("MESS range detects novel environments", {
    skip_if_not_installed("maxentcpp")

    dim <- maxent_dimension(nrows = 1, ncols = 3, xll = 0, yll = 0, cellsize = 1)
    g0 <- maxent_grid(dim, "temp")
    grid_set_value(g0, 0, 0, -5.0)   # below min → novel
    grid_set_value(g0, 0, 1, 10.0)   # within range
    grid_set_value(g0, 0, 2, 25.0)   # above max → novel

    result <- maxent_mess_range(list(g0), c(0.0), c(20.0))

    expect_true("mess_grid" %in% names(result))
    expect_true("mod_grid" %in% names(result))

    mess_mat <- grid_float_to_matrix(result$mess_grid)
    expect_true(mess_mat[1, 1] < 0)   # novel
    expect_true(mess_mat[1, 2] >= 0)  # within range
    expect_true(mess_mat[1, 3] < 0)   # novel
})

test_that("MESS with full reference values works", {
    skip_if_not_installed("maxentcpp")

    dim <- maxent_dimension(nrows = 1, ncols = 2, xll = 0, yll = 0, cellsize = 1)
    g0 <- maxent_grid(dim, "temp")
    grid_set_value(g0, 0, 0, 10.0)   # within range
    grid_set_value(g0, 0, 1, -20.0)  # novel

    ref <- list(c(0, 5, 10, 15, 20))

    result <- maxent_mess(list(g0), ref, c("temp"))

    mess_mat <- grid_float_to_matrix(result$mess_grid)
    expect_true(mess_mat[1, 1] >= 0)   # within reference
    expect_true(mess_mat[1, 2] < 0)    # novel
})

test_that("Response curve returns correct structure", {
    skip_if_not_installed("maxentcpp")

    dim <- maxent_dimension(nrows = 3, ncols = 3, xll = 0, yll = 0, cellsize = 1)
    g0 <- maxent_grid(dim, "env0")
    g1 <- maxent_grid(dim, "env1")
    idx <- 0
    for (r in 0:2) {
        for (cc in 0:2) {
            grid_set_value(g0, r, cc, idx / 8.0)
            grid_set_value(g1, r, cc, 0.5)
            idx <- idx + 1
        }
    }

    vals0 <- sapply(0:8, function(i) i / 8.0)
    vals1 <- rep(0.5, 9)

    # Use named list with correct API: types vector, n_thresholds, n_hinges
    env_data <- list(env0 = vals0, env1 = vals1)
    features <- maxent_generate_features(env_data, types = "linear",
                                         n_thresholds = 0, n_hinges = 0)

    model <- maxent_featured_space(9, c(6L, 7L, 8L), features)
    maxent_fit(model, max_iter = 100, convergence = 0.001, beta_multiplier = 1.0)

    curve <- maxent_response_curve(model, list(g0, g1), c("env0", "env1"),
                                   var_index = 0, n_steps = 20)

    expect_true(is.data.frame(curve))
    expect_true("value" %in% names(curve))
    expect_true("prediction" %in% names(curve))
    expect_equal(nrow(curve), 20)
    expect_true(all(curve$prediction >= 0))
    expect_true(all(curve$prediction <= 1))
})

test_that("Projection works with multi-type features (quadratic + hinge)", {
    skip_if_not_installed("maxentcpp")

    dim <- maxent_dimension(nrows = 3, ncols = 3, xll = 0, yll = 0, cellsize = 1)
    g0 <- maxent_grid(dim, "env0")
    g1 <- maxent_grid(dim, "env1")
    idx <- 0
    for (r in 0:2) {
        for (cc in 0:2) {
            grid_set_value(g0, r, cc, idx / 8.0)
            grid_set_value(g1, r, cc, 1.0 - idx / 8.0)
            idx <- idx + 1
        }
    }

    vals0 <- sapply(0:8, function(i) i / 8.0)
    vals1 <- 1.0 - vals0

    env_data <- list(env0 = vals0, env1 = vals1)
    # Generate features with linear, quadratic, and hinge types
    features <- maxent_generate_features(env_data,
                                         types = c("linear", "quadratic", "hinge"),
                                         n_thresholds = 0, n_hinges = 2)

    # Should have more than 2 features: 2 linear + 2 quadratic + 2*2*2 hinges = 12
    expect_true(length(features) > 2)

    model <- maxent_featured_space(9, c(6L, 7L, 8L), features)
    maxent_fit(model, max_iter = 100, convergence = 0.001, beta_multiplier = 1.0)

    # Projection with 2 grids should work despite having 12+ features
    pred <- maxent_project_cloglog(model, list(g0, g1), c("env0", "env1"))
    expect_true(!is.null(pred))

    mat <- maxent_grid_to_matrix(pred)
    expect_equal(dim(mat), c(3, 3))
    expect_true(all(!is.na(mat)))
    expect_true(all(mat >= 0))
    expect_true(all(mat <= 1))
})

test_that("extract_predictions_raw works with multi-type features", {
    skip_if_not_installed("maxentcpp")

    dim <- maxent_dimension(nrows = 3, ncols = 3, xll = 0, yll = 0, cellsize = 1)
    g0 <- maxent_grid(dim, "env0")
    g1 <- maxent_grid(dim, "env1")
    idx <- 0
    for (r in 0:2) {
        for (cc in 0:2) {
            grid_set_value(g0, r, cc, idx / 8.0)
            grid_set_value(g1, r, cc, 1.0 - idx / 8.0)
            idx <- idx + 1
        }
    }

    vals0 <- sapply(0:8, function(i) i / 8.0)
    vals1 <- 1.0 - vals0

    env_data <- list(env0 = vals0, env1 = vals1)
    features <- maxent_generate_features(env_data,
                                         types = c("linear", "quadratic", "hinge"),
                                         n_thresholds = 0, n_hinges = 2)

    model <- maxent_featured_space(9, c(6L, 7L, 8L), features)
    maxent_fit(model, max_iter = 100, convergence = 0.001, beta_multiplier = 1.0)

    preds <- maxent_extract_predictions_raw(model, list(g0, g1), c("env0", "env1"),
                                        c(0L, 1L, 2L), c(0L, 1L, 2L))
    expect_equal(length(preds), 3)
    expect_true(all(is.finite(preds)))
    expect_true(all(preds >= 0))
})

test_that("Response curve works with multi-type features", {
    skip_if_not_installed("maxentcpp")

    dim <- maxent_dimension(nrows = 3, ncols = 3, xll = 0, yll = 0, cellsize = 1)
    g0 <- maxent_grid(dim, "env0")
    g1 <- maxent_grid(dim, "env1")
    idx <- 0
    for (r in 0:2) {
        for (cc in 0:2) {
            grid_set_value(g0, r, cc, idx / 8.0)
            grid_set_value(g1, r, cc, 1.0 - idx / 8.0)
            idx <- idx + 1
        }
    }

    vals0 <- sapply(0:8, function(i) i / 8.0)
    vals1 <- 1.0 - vals0

    env_data <- list(env0 = vals0, env1 = vals1)
    features <- maxent_generate_features(env_data,
                                         types = c("linear", "quadratic", "hinge"),
                                         n_thresholds = 0, n_hinges = 2)

    model <- maxent_featured_space(9, c(6L, 7L, 8L), features)
    maxent_fit(model, max_iter = 100, convergence = 0.001, beta_multiplier = 1.0)

    curve <- maxent_response_curve(model, list(g0, g1), c("env0", "env1"),
                                   var_index = 0, n_steps = 20)

    expect_true(is.data.frame(curve))
    expect_equal(nrow(curve), 20)
    expect_true(all(curve$prediction >= 0))
    expect_true(all(curve$prediction <= 1))
})
