# Phase E.2: SpatRaster streaming provider bit-for-bit equivalence test.
#
# Compares the streaming `maxent_featured_space_from_rast()` path against the
# dense `maxent_featured_space()` path on the same SpatRaster data.  Both
# paths must agree at 1e-14 on weights / loss / entropy / lambdas.

# skip_if_no_terra() is provided by helper-terra.R

# -- Helpers ------------------------------------------------------------------

# Build a small deterministic 2-layer raster.  20x3 = 60 cells.
build_test_raster <- function(n_rows = 20L, n_cols = 3L) {
    skip_if_no_terra()
    set.seed(42L)
    n_cells <- n_rows * n_cols
    bio1  <- seq(10, 30, length.out = n_cells) + rnorm(n_cells, 0, 0.5)
    bio12 <- seq(500, 2000, length.out = n_cells) + rnorm(n_cells, 0, 20)
    r1 <- terra::rast(nrows = n_rows, ncols = n_cols,
                      xmin = 0, xmax = n_cols, ymin = 0, ymax = n_rows,
                      vals = bio1)
    names(r1) <- "bio1"
    r2 <- terra::rast(nrows = n_rows, ncols = n_cols,
                      xmin = 0, xmax = n_cols, ymin = 0, ymax = n_rows,
                      vals = bio12)
    names(r2) <- "bio12"
    rast <- c(r1, r2)
    rast
}

# Drain a SpatRaster into a dense matrix (num_points x num_layers), dropping
# rows that contain NAs, in the same order the streaming path would emit.
raster_to_dense <- function(rast) {
    vals <- terra::values(rast, mat = TRUE)
    vals[stats::complete.cases(vals), , drop = FALSE]
}

train_args <- list(
    max_iter        = 50L,
    convergence     = 1e-5,
    beta_multiplier = 1.0,
    min_deviation   = 0.001)

fit_dense <- function(rast, sample_indices, feature_types) {
    dense <- raster_to_dense(rast)
    features <- maxent_generate_features(
        data  = stats::setNames(as.list(as.data.frame(dense)), names(rast)),
        types = feature_types,
        n_thresholds = 10L,
        n_hinges     = 10L)
    fs <- maxent_featured_space(
        num_points     = nrow(dense),
        sample_indices = sample_indices,
        features       = features)
    res <- do.call(maxent_fit, c(list(featured_space = fs), train_args))
    list(fs = fs, res = res)
}

fit_streaming <- function(rast, sample_indices, feature_types) {
    fs <- maxent_featured_space_from_rast(
        rast           = rast,
        sample_indices = sample_indices,
        feature_types  = feature_types,
        n_thresholds   = 10L,
        n_hinges       = 10L)
    res <- do.call(maxent_fit, c(list(featured_space = fs), train_args))
    list(fs = fs, res = res)
}

# -- Tests --------------------------------------------------------------------

test_that("streaming path matches dense path bit-for-bit (linear + quadratic)", {
    skip_if_no_terra()
    rast <- build_test_raster()
    sample_indices <- c(3L, 11L, 29L, 41L, 55L)
    feature_types  <- c("linear", "quadratic")

    dense    <- fit_dense(rast,   sample_indices, feature_types)
    streamed <- fit_streaming(rast, sample_indices, feature_types)

    expect_equal(streamed$res$lambdas, dense$res$lambdas, tolerance = 1e-14)
    expect_equal(streamed$res$loss,    dense$res$loss,    tolerance = 1e-14)
    expect_equal(streamed$res$entropy, dense$res$entropy, tolerance = 1e-14)
    expect_equal(streamed$res$iterations, dense$res$iterations)
})

test_that("streaming path matches dense path (all feature types)", {
    skip_if_no_terra()
    rast <- build_test_raster()
    sample_indices <- c(3L, 11L, 29L, 41L, 55L)
    feature_types  <- c("linear", "quadratic", "product", "threshold", "hinge")

    dense    <- fit_dense(rast,   sample_indices, feature_types)
    streamed <- fit_streaming(rast, sample_indices, feature_types)

    expect_equal(streamed$res$lambdas, dense$res$lambdas, tolerance = 1e-14)
    expect_equal(streamed$res$loss,    dense$res$loss,    tolerance = 1e-14)
    expect_equal(streamed$res$entropy, dense$res$entropy, tolerance = 1e-14)
})

test_that("streaming path survives NA cells identical to dense path", {
    skip_if_no_terra()
    rast <- build_test_raster()
    # Poke some NAs into bio12.
    na_cells <- c(4L, 17L, 33L, 51L)
    terra::values(rast[[2]])[na_cells] <- NA_real_

    # Any sample index must land on a finite cell.  Finite-cell count is
    # (60 - length(na_cells)) = 56.
    sample_indices <- c(3L, 10L, 25L, 40L, 50L)
    feature_types  <- c("linear", "quadratic")

    dense    <- fit_dense(rast,   sample_indices, feature_types)
    streamed <- fit_streaming(rast, sample_indices, feature_types)

    expect_equal(streamed$res$lambdas, dense$res$lambdas, tolerance = 1e-14)
    expect_equal(streamed$res$loss,    dense$res$loss,    tolerance = 1e-14)
})

test_that("maxent_raster_sample_indices maps cells into the finite stream", {
    skip_if_no_terra()
    rast <- build_test_raster()
    # Poke NAs into bio1 cells 5,10,15 (1-based); they should be dropped.
    terra::values(rast[[1]])[c(5L, 10L, 15L)] <- NA_real_

    # Pick three occurrence cells, two finite (1,20) and one on an NA (10).
    cells <- c(1L, 10L, 20L)
    expect_warning(
        idx <- maxent_raster_sample_indices(rast, cells),
        "drop"
    )
    # cell 1  -> cumsum(is_finite)[1]  - 1 = 1  - 1 = 0
    # cell 10 -> NA, dropped
    # cell 20 -> cumsum(is_finite)[20] - 1 = 17 - 1 = 16
    expect_equal(idx, c(0L, 16L))
})

test_that("streaming path handles mid-stream all-NA blocks without truncation", {
    # Regression test for Devin Review BUG_pr-review-job-a516d323_0001:
    # if a full block contains only NA cells, next_tile_fn() used to emit a
    # 0-row tile which the C++ streaming constructor interpreted as
    # end-of-stream, truncating the background matrix and throwing
    # "BackgroundProvider emitted fewer rows than declared".  The fix is to
    # skip over all-NA blocks inside next_tile_fn() instead of emitting them.
    skip_if_no_terra()
    rast <- build_test_raster(n_rows = 20L, n_cols = 3L)
    # Force several small blocks so one of them can be fully NA.  1 row per
    # block = 20 blocks, each with 3 cells.
    terra::terraOptions(memfrac = 1e-6)
    on.exit(terra::terraOptions(memfrac = 0.6), add = TRUE)
    # Wipe an entire interior row (cells 25-27 = row 9, 1-based indices) to
    # create an all-NA block between finite ones.
    terra::values(rast[[1]])[25:27] <- NA_real_
    terra::values(rast[[2]])[25:27] <- NA_real_

    sample_indices <- c(3L, 10L, 25L, 40L, 50L)
    feature_types  <- c("linear", "quadratic")

    dense    <- fit_dense(rast,   sample_indices, feature_types)
    # Must not throw "BackgroundProvider emitted fewer rows..."
    streamed <- fit_streaming(rast, sample_indices, feature_types)

    expect_equal(streamed$res$lambdas, dense$res$lambdas, tolerance = 1e-14)
    expect_equal(streamed$res$loss,    dense$res$loss,    tolerance = 1e-14)
})

test_that("maxent_raster_sample_indices handles NA cells without error", {
    # Regression test for Devin Review BUG_pr-review-job-a516d323_0002:
    # NA entries in `cells` used to propagate into `valid` via
    # `NA >= 1L` -> NA and `is_finite[NA]` -> NA, which then made
    # `if (!all(valid))` raise "missing value where TRUE/FALSE needed".
    skip_if_no_terra()
    rast <- build_test_raster()
    # Cells returned by terra::cellFromXY() for out-of-extent points are NA;
    # make sure the helper treats them the same as on-NA cells: drop + warn.
    cells <- c(1L, NA_integer_, 20L)
    expect_warning(
        idx <- maxent_raster_sample_indices(rast, cells),
        "drop"
    )
    expect_equal(idx, c(0L, 19L))
})

test_that("maxent_extract_occurrence_env_terra matches terra::extract", {
    skip_if_no_terra()
    rast <- build_test_raster()
    pts <- data.frame(longitude = c(0.5, 1.5, 2.5),
                      latitude  = c(1.5, 5.5, 10.5))

    got <- maxent_extract_occurrence_env_terra(
        rast,
        occurrences = pts,
        lon_col = "longitude",
        lat_col = "latitude")
    expect_equal(colnames(got), names(rast))

    cells <- terra::cellFromXY(rast, as.matrix(pts[, c("longitude", "latitude")]))
    ref <- terra::values(rast, mat = TRUE)[cells, , drop = FALSE]
    expect_equal(unname(got), unname(ref), tolerance = 1e-14)
})

test_that("maxent_train_terra matches manual streaming fit", {
    skip_if_no_terra()
    rast <- build_test_raster()
    pts <- data.frame(longitude = c(0.5, 1.5, 2.5, 0.5, 2.5),
                      latitude  = c(1.5, 5.5, 10.5, 12.5, 18.5))
    feature_types <- c("linear", "quadratic")

    cells <- terra::cellFromXY(rast, as.matrix(pts[, c("longitude", "latitude")]))
    idx <- maxent_raster_sample_indices(rast, cells)

    manual_fs <- maxent_featured_space_from_rast(
        rast = rast,
        sample_indices = idx,
        feature_types = feature_types,
        n_thresholds = 10L,
        n_hinges = 10L,
        enable_streaming_eval = TRUE)
    manual <- maxent_fit(manual_fs, max_iter = 50L, convergence = 1e-5,
                         beta_multiplier = 1.0, min_deviation = 0.001)

    auto <- maxent_train_terra(
        rast = rast,
        occurrences = pts,
        lon_col = "longitude",
        lat_col = "latitude",
        feature_types = feature_types,
        n_thresholds = 10L,
        n_hinges = 10L,
        max_iter = 50L,
        convergence = 1e-5,
        beta_multiplier = 1.0,
        min_deviation = 0.001)

    expect_equal(auto$sample_indices, idx)
    expect_equal(auto$lambdas, manual$lambdas, tolerance = 1e-14)
    expect_equal(auto$loss, manual$loss, tolerance = 1e-14)
    expect_equal(auto$entropy, manual$entropy, tolerance = 1e-14)
    expect_true(inherits(auto$model, "externalptr"))
})
