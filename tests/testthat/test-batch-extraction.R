# Tests for grid_get_values_batch() — batch grid value extraction

make_test_grid <- function() {
    dim <- maxent_dimension(nrows = 3, ncols = 3, xll = 0, yll = 0, cellsize = 1)
    g <- maxent_grid(dim, "test")
    idx <- 0L
    for (r in 0:2) {
        for (cc in 0:2) {
            grid_set_value(g, r, cc, as.double(idx))
            idx <- idx + 1L
        }
    }
    g
}

test_that("grid_get_values_batch matches grid_get_value for valid cells", {
    skip_if_not_installed("maxentcpp")

    g <- make_test_grid()
    rows <- as.integer(c(0, 0, 1, 2))
    cols <- as.integer(c(0, 2, 1, 2))

    batch <- grid_get_values_batch(g, rows, cols)

    for (i in seq_along(rows)) {
        expect_equal(batch[i], grid_get_value(g, rows[i], cols[i]),
                     tolerance = 1e-6,
                     info = paste("mismatch at position", i))
    }
})

test_that("grid_get_values_batch returns NA for NODATA cells", {
    skip_if_not_installed("maxentcpp")

    dim <- maxent_dimension(nrows = 2, ncols = 2, xll = 0, yll = 0, cellsize = 1)
    g <- maxent_grid(dim, "nodata_test")
    grid_set_value(g, 0, 0, 1.0)
    # (0,1), (1,0), (1,1) are left as NODATA (never set)

    batch <- grid_get_values_batch(g, as.integer(c(0, 0, 1, 1)),
                                       as.integer(c(0, 1, 0, 1)))

    expect_equal(batch[1], 1.0, tolerance = 1e-6)
    expect_true(is.na(batch[2]))
    expect_true(is.na(batch[3]))
    expect_true(is.na(batch[4]))
})

test_that("grid_get_values_batch errors on mismatched rows/cols lengths", {
    skip_if_not_installed("maxentcpp")

    g <- make_test_grid()
    expect_error(
        grid_get_values_batch(g, as.integer(c(0, 1)), as.integer(c(0))),
        "same length"
    )
})

test_that("grid_get_values_batch errors on out-of-bounds indices", {
    skip_if_not_installed("maxentcpp")

    g <- make_test_grid()   # 3x3 grid, valid rows/cols: 0..2
    expect_error(
        grid_get_values_batch(g, as.integer(c(0, 5)), as.integer(c(0, 0))),
        "out of bounds"
    )
    expect_error(
        grid_get_values_batch(g, as.integer(c(0, -1)), as.integer(c(0, 0))),
        "out of bounds"
    )
})

test_that("grid_get_values_batch handles an empty index vector", {
    skip_if_not_installed("maxentcpp")

    g <- make_test_grid()
    result <- grid_get_values_batch(g, integer(0), integer(0))
    expect_length(result, 0)
})
