library(testthat)
test_that("maxent_grid_from_terra creates grid from SpatRaster", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_proj()

    library(terra)

    # Create a simple SpatRaster
    r <- rast(xmin = -120, xmax = -116,
              ymin = 35, ymax = 40, res = 1,
              crs = "EPSG:4326")
    values(r) <- 1:(nrow(r)*ncol(r))
    names(r) <- "test_layer"

    g <- maxent_grid_from_terra(r)
    info <- maxent_grid_info(g)

    expect_equal(info$nrows, 5)
    expect_equal(info$ncols, 4)
    expect_equal(info$xll, -120)
    expect_equal(info$yll, 35)
    expect_equal(info$cellsize, 1.0)
    expect_equal(info$name, "test_layer")
    expect_equal(info$count_data, 20)
})

test_that("maxent_grid_to_terra creates SpatRaster from grid", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_proj()

    library(terra)

    mat <- matrix(c(1, 2, 3, 4, NA, 6), nrow = 2, byrow = TRUE)
    g <- maxent_grid_from_matrix(mat, xll = -120, yll = 35,
                                 cellsize = 0.5, name = "bio1")

    r <- maxent_grid_to_terra(g)

    expect_true(inherits(r, "SpatRaster"))
    expect_equal(nrow(r), 2)
    expect_equal(ncol(r), 3)
    expect_equal(names(r), "bio1")

    e <- ext(r)
    expect_equal(unname(e[1]), -120)   # xmin
    expect_equal(unname(e[2]), -118.5) # xmax
    expect_equal(unname(e[3]), 35)     # ymin
    expect_equal(unname(e[4]), 36)     # ymax
    expect_equal(as.numeric(e[1]), -120)   # xmin
    expect_equal(as.numeric(e[2]), -118.5) # xmax
    expect_equal(as.numeric(e[3]), 35)     # ymin
    expect_equal(as.numeric(e[4]), 36)     # ymax

    vals <- as.matrix(r, wide = TRUE)
    expect_equal(vals[1, 1], 1)
    expect_equal(vals[1, 3], 3)
    expect_equal(vals[2, 3], 6)
    expect_true(is.na(vals[2, 2]))
})

test_that("terra round-trip preserves values", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_proj()

    library(terra)

    # Create a raster with known values including NA
    r_orig <- rast(nrows = 3, ncols = 4,
                   xmin = 0, xmax = 4,
                   ymin = 0, ymax = 3,
                   crs = "EPSG:4326")
    vals <- c(1.5, 2.5, NA, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5, 10.5, 11.5, 12.5)
    values(r_orig) <- vals
    names(r_orig) <- "roundtrip"

    # terra → maxentcpp → terra
    g <- maxent_grid_from_terra(r_orig)
    r_back <- maxent_grid_to_terra(g)

    mat_orig <- as.matrix(r_orig, wide = TRUE)
    mat_back <- as.matrix(r_back, wide = TRUE)

    # Compare non-NA cells
    for (i in 1:3) {
        for (j in 1:4) {
            if (is.na(mat_orig[i, j])) {
                expect_true(is.na(mat_back[i, j]))
            } else {
                expect_equal(mat_back[i, j], mat_orig[i, j], tolerance = 1e-5)
            }
        }
    }
})

test_that("maxent_grid_from_terra rejects multi-layer raster", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_terra()

    library(terra)

    r <- rast(nrows = 2, ncols = 2, nlyr = 2,
              xmin = 0, xmax = 2, ymin = 0, ymax = 2)
    values(r) <- 1:8

    expect_error(maxent_grid_from_terra(r), "exactly one layer")
})

test_that("maxent_grid_from_terra rejects non-SpatRaster", {
    skip_if_not_installed("maxentcpp")

    expect_error(maxent_grid_from_terra(matrix(1:4, 2, 2)),
                 "SpatRaster")
})

