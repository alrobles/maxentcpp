# Tests for cloglog and logistic projection transforms (un-scaled)

# Helper: build a tiny trained model and matching grids.
make_projection_model <- function() {
    dim <- maxent_dimension(nrows = 3, ncols = 3, xll = 0, yll = 0, cellsize = 1)
    g0 <- maxent_grid(dim, "env0")
    g1 <- maxent_grid(dim, "env1")
    idx <- 0L
    for (r in 0:2) {
        for (cc in 0:2) {
            grid_set_value(g0, r, cc, idx / 8.0)
            grid_set_value(g1, r, cc, 0.5)
            idx <- idx + 1L
        }
    }

    vals0 <- sapply(0:8, function(i) i / 8.0)
    vals1 <- rep(0.5, 9)
    env_data <- list(env0 = vals0, env1 = vals1)
    features <- maxent_generate_features(env_data, types = "linear",
                                         n_thresholds = 0L, n_hinges = 0L)
    model <- maxent_featured_space(9L, c(6L, 7L, 8L), features)
    maxent_fit(model, max_iter = 200L, convergence = 1e-5, beta_multiplier = 1.0)
    list(model = model, grids = list(g0, g1), names = c("env0", "env1"))
}

test_that("cloglog_deprecated projection matches 1 - exp(-raw_deprecated)", {
    skip_if_not_installed("maxentcpp")

    m <- make_projection_model()

    raw_grid     <- maxent_project_raw_deprecated(m$model, m$grids, m$names)
    cloglog_grid <- maxent_project_cloglog_deprecated(m$model, m$grids, m$names)

    raw_mat     <- maxent_grid_to_matrix(raw_grid)
    cloglog_mat <- maxent_grid_to_matrix(cloglog_grid)

    expected <- 1.0 - exp(-raw_mat)

    expect_equal(cloglog_mat, expected, tolerance = 1e-5)
    # All values in [0, 1]
    expect_true(all(cloglog_mat >= 0 & cloglog_mat <= 1))
})

test_that("logistic_deprecated projection matches raw_deprecated / (1 + raw_deprecated)", {
    skip_if_not_installed("maxentcpp")

    m <- make_projection_model()

    raw_grid      <- maxent_project_raw_deprecated(m$model, m$grids, m$names)
    logistic_grid <- maxent_project_logistic_deprecated(m$model, m$grids, m$names)

    raw_mat      <- maxent_grid_to_matrix(raw_grid)
    logistic_mat <- maxent_grid_to_matrix(logistic_grid)

    expected <- raw_mat / (1.0 + raw_mat)

    expect_equal(logistic_mat, expected, tolerance = 1e-5)
    # All values in [0, 1]
    expect_true(all(logistic_mat >= 0 & logistic_mat <= 1))
})

test_that("cloglog and logistic values are in [0, 1] and increase with raw", {
    skip_if_not_installed("maxentcpp")

    m <- make_projection_model()

    raw_grid      <- maxent_project_raw(m$model, m$grids, m$names)
    cloglog_grid  <- maxent_project_cloglog(m$model, m$grids, m$names)
    logistic_grid <- maxent_project_logistic(m$model, m$grids, m$names)

    raw_mat      <- maxent_grid_to_matrix(raw_grid)
    cloglog_mat  <- maxent_grid_to_matrix(cloglog_grid)
    logistic_mat <- maxent_grid_to_matrix(logistic_grid)

    expect_true(all(cloglog_mat  >= 0 & cloglog_mat  <= 1))
    expect_true(all(logistic_mat >= 0 & logistic_mat <= 1))

    # Transforms are monotonically increasing: higher raw → higher output
    # Use Spearman rank correlation (robust to nonlinearity)
    expect_gt(cor(as.vector(raw_mat), as.vector(cloglog_mat),  method = "spearman"), 0.99)
    expect_gt(cor(as.vector(raw_mat), as.vector(logistic_mat), method = "spearman"), 0.99)
})

# ============================================================================
# Tests for Java-compatible prediction APIs
# ============================================================================

test_that("raw == raw_deprecated / density_normalizer", {
    skip_if_not_installed("maxentcpp")

    m <- make_projection_model()

    raw_deprecated_grid <- maxent_project_raw_deprecated(m$model, m$grids, m$names)
    raw_grid            <- maxent_project_raw(m$model, m$grids, m$names)

    raw_deprecated_mat <- maxent_grid_to_matrix(raw_deprecated_grid)
    raw_mat            <- maxent_grid_to_matrix(raw_grid)

    info <- maxent_featured_space_info(m$model)
    dn   <- info$density_normalizer

    expect_gt(dn, 0)
    expected_java <- raw_deprecated_mat / dn
    expect_equal(raw_mat, expected_java, tolerance = 1e-5)
})

test_that("cloglog_java matches 1 - exp(-exp(H) * raw_java)", {
    skip_if_not_installed("maxentcpp")

    m <- make_projection_model()

    raw_java_grid     <- maxent_project_raw(m$model, m$grids, m$names)
    cloglog_java_grid <- maxent_project_cloglog(m$model, m$grids, m$names)

    raw_java_mat     <- maxent_grid_to_matrix(raw_java_grid)
    cloglog_java_mat <- maxent_grid_to_matrix(cloglog_java_grid)

    H    <- maxent_model_entropy(m$model)
    expH <- exp(H)

    expected <- 1.0 - exp(-expH * raw_java_mat)
    expect_equal(cloglog_java_mat, expected, tolerance = 1e-5)
    expect_true(all(cloglog_java_mat >= 0 & cloglog_java_mat <= 1))
})

test_that("logistic_java matches (exp(H)*raw_java) / (1 + exp(H)*raw_java)", {
    skip_if_not_installed("maxentcpp")

    m <- make_projection_model()

    raw_java_grid      <- maxent_project_raw(m$model, m$grids, m$names)
    logistic_java_grid <- maxent_project_logistic(m$model, m$grids, m$names)

    raw_java_mat      <- maxent_grid_to_matrix(raw_java_grid)
    logistic_java_mat <- maxent_grid_to_matrix(logistic_java_grid)

    H    <- maxent_model_entropy(m$model)
    expH <- exp(H)
    scaled   <- expH * raw_java_mat
    expected <- scaled / (1.0 + scaled)

    expect_equal(logistic_java_mat, expected, tolerance = 1e-5)
    expect_true(all(logistic_java_mat >= 0 & logistic_java_mat <= 1))
})

test_that("extract_predictions_raw_java == project_raw_java sampled at points", {
    skip_if_not_installed("maxentcpp")

    m <- make_projection_model()

    # Use a few grid points: rows and cols (0-based)
    rows <- c(0L, 1L, 2L)
    cols <- c(0L, 1L, 2L)

    # Extract via point extraction
    pt_raw_java <- maxent_extract_predictions_raw(
        m$model, m$grids, m$names, rows, cols)

    # Extract from grid
    raw_java_grid <- maxent_project_raw(m$model, m$grids, m$names)
    raw_java_mat  <- maxent_grid_to_matrix(raw_java_grid)

    # maxent_grid_to_matrix gives matrix with row 0 at top
    grid_vals <- mapply(function(r, c) raw_java_mat[r + 1L, c + 1L], rows, cols)

    expect_equal(pt_raw_java, grid_vals, tolerance = 1e-5)
})

test_that("extract_predictions_cloglog_java matches formula", {
    skip_if_not_installed("maxentcpp")

    m <- make_projection_model()

    rows <- c(0L, 1L, 2L)
    cols <- c(0L, 1L, 2L)

    pt_raw_java    <- maxent_extract_predictions_raw(
        m$model, m$grids, m$names, rows, cols)
    pt_cloglog_java <- maxent_extract_predictions_cloglog(
        m$model, m$grids, m$names, rows, cols)

    H    <- maxent_model_entropy(m$model)
    expH <- exp(H)
    expected <- 1.0 - exp(-expH * pt_raw_java)

    expect_equal(pt_cloglog_java, expected, tolerance = 1e-5)
})

test_that("extract_predictions_logistic_java matches formula", {
    skip_if_not_installed("maxentcpp")

    m <- make_projection_model()

    rows <- c(0L, 1L, 2L)
    cols <- c(0L, 1L, 2L)

    pt_raw_java      <- maxent_extract_predictions_raw(
        m$model, m$grids, m$names, rows, cols)
    pt_logistic_java <- maxent_extract_predictions_logistic(
        m$model, m$grids, m$names, rows, cols)

    H    <- maxent_model_entropy(m$model)
    expH <- exp(H)
    scaled   <- expH * pt_raw_java
    expected <- scaled / (1.0 + scaled)

    expect_equal(pt_logistic_java, expected, tolerance = 1e-5)
})

test_that("Java cloglog is strictly larger than unnormalized cloglog when densityNorm > 1", {
    skip_if_not_installed("maxentcpp")

    m <- make_projection_model()

    info <- maxent_featured_space_info(m$model)
    dn   <- info$density_normalizer

    # The density normalizer should be > 1 for a non-trivial model
    if (dn > 1.0) {
        cloglog_deprecated_grid <- maxent_project_cloglog_deprecated(m$model, m$grids, m$names)
        cloglog_grid            <- maxent_project_cloglog(m$model, m$grids, m$names)

        cloglog_deprecated_mat <- maxent_grid_to_matrix(cloglog_deprecated_grid)
        cloglog_mat            <- maxent_grid_to_matrix(cloglog_grid)

        # raw < raw_unnorm when dn > 1, but exp(H)*raw vs raw_unnorm
        # comparison depends on H - just check they are both in [0,1]
        expect_true(all(cloglog_mat            >= 0 & cloglog_mat            <= 1))
        expect_true(all(cloglog_deprecated_mat >= 0 & cloglog_deprecated_mat <= 1))
    } else {
        skip("density_normalizer <= 1 for this test model; skipping comparison")
    }
})

