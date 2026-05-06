test_that("maxent_read_occurrences works with data.frame", {
    skip_if_not_installed("maxentcpp")

    dim <- maxent_dimension(100, 100, -120, 35, 0.1)

    occ_df <- data.frame(
        longitude = c(-119.5, -119.0, -118.5),
        latitude  = c(36.0, 37.0, 38.0)
    )

    result <- maxent_read_occurrences(occ_df, dim)

    expect_true(is.list(result))
    expect_equal(length(result$samples), 3)
    expect_equal(length(result$rows), 3)
    expect_equal(length(result$cols), 3)
    expect_equal(length(result$indices), 3)

    # All indices should be non-negative
    expect_true(all(result$rows >= 0))
    expect_true(all(result$cols >= 0))
    expect_true(all(result$indices >= 0))

    # indices should be row * ncols + col
    for (i in seq_along(result$indices)) {
        expect_equal(result$indices[i], result$rows[i] * 100 + result$cols[i])
    }
})

test_that("maxent_read_occurrences works with CSV file", {
    skip_if_not_installed("maxentcpp")

    dim <- maxent_dimension(100, 100, -120, 35, 0.1)

    tmp <- tempfile(fileext = ".csv")
    on.exit(unlink(tmp), add = TRUE)

    writeLines(c("species,lon,lat",
                 "oak,-119.5,36.0",
                 "pine,-119.0,37.0"), tmp)

    result <- maxent_read_occurrences(tmp, dim,
                                      lon_col = "lon", lat_col = "lat")

    expect_equal(length(result$samples), 2)
    expect_equal(length(result$indices), 2)
})

test_that("maxent_read_occurrences handles custom name column", {
    skip_if_not_installed("maxentcpp")

    dim <- maxent_dimension(100, 100, -120, 35, 0.1)

    occ_df <- data.frame(
        longitude = c(-119.5, -119.0),
        latitude  = c(36.0, 37.0),
        site_name = c("site_A", "site_B")
    )

    result <- maxent_read_occurrences(occ_df, dim, name_col = "site_name")

    info1 <- get_sample_info(result$samples[[1]])
    info2 <- get_sample_info(result$samples[[2]])

    expect_equal(info1$name, "site_A")
    expect_equal(info2$name, "site_B")
})

test_that("maxent_read_occurrences drops NA coordinates", {
    skip_if_not_installed("maxentcpp")

    dim <- maxent_dimension(100, 100, -120, 35, 0.1)

    occ_df <- data.frame(
        longitude = c(-119.5, NA, -118.5),
        latitude  = c(36.0, 37.0, NA)
    )

    result <- maxent_read_occurrences(occ_df, dim)

    # Only the first row has valid lon+lat
    expect_equal(length(result$samples), 1)
    expect_equal(length(result$indices), 1)
})

test_that("maxent_read_occurrences errors on missing columns", {
    skip_if_not_installed("maxentcpp")

    dim <- maxent_dimension(100, 100, -120, 35, 0.1)

    occ_df <- data.frame(x = 1, y = 2)

    expect_error(maxent_read_occurrences(occ_df, dim),
                 "longitude")
})

test_that("maxent_background_indices returns valid indices", {
    skip_if_not_installed("maxentcpp")

    # Create a grid with some valid and some NA cells
    mat <- matrix(runif(100), nrow = 10, ncol = 10)
    mat[1, 1] <- NA
    mat[5, 5] <- NA

    g <- maxent_grid_from_matrix(mat, xll = 0, yll = 0, cellsize = 1)

    bg <- maxent_background_indices(g, n = 20, seed = 42)

    expect_true(is.list(bg))
    expect_equal(length(bg$rows), 20)
    expect_equal(length(bg$cols), 20)
    expect_equal(length(bg$indices), 20)

    # All indices should be non-negative
    expect_true(all(bg$rows >= 0))
    expect_true(all(bg$cols >= 0))
    expect_true(all(bg$indices >= 0))

    # None of the selected cells should be NA
    for (i in seq_along(bg$rows)) {
        val <- grid_get_value(g, bg$rows[i], bg$cols[i])
        expect_false(is.na(val))
    }
})

test_that("maxent_background_indices respects seed", {
    skip_if_not_installed("maxentcpp")

    mat <- matrix(runif(100), nrow = 10, ncol = 10)
    g <- maxent_grid_from_matrix(mat, xll = 0, yll = 0, cellsize = 1)

    bg1 <- maxent_background_indices(g, n = 20, seed = 123)
    bg2 <- maxent_background_indices(g, n = 20, seed = 123)

    expect_equal(bg1$indices, bg2$indices)
})

test_that("maxent_background_indices caps n at valid cell count", {
    skip_if_not_installed("maxentcpp")

    mat <- matrix(c(1, 2, NA, 4), nrow = 2, ncol = 2)
    g <- maxent_grid_from_matrix(mat, xll = 0, yll = 0, cellsize = 1)

    bg <- maxent_background_indices(g, n = 100, seed = 1)

    # Only 3 valid cells, so should get at most 3
    expect_equal(length(bg$indices), 3)
})
