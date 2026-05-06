test_that("Layer can be created and queried", {
    skip_if_not_installed("maxentcpp")

    l <- maxent_layer("bio1", "Continuous")
    info <- maxent_layer_info(l)

    expect_equal(info$name, "bio1")
    expect_equal(info$type, "Continuous")
})

test_that("Layer type is case-insensitive", {
    skip_if_not_installed("maxentcpp")

    l <- maxent_layer("mask", "MASK")
    expect_equal(maxent_layer_info(l)$type, "Mask")

    l2 <- maxent_layer("cat", "categorical")
    expect_equal(maxent_layer_info(l2)$type, "Categorical")
})

test_that("layer_name_from_path strips path and extension", {
    skip_if_not_installed("maxentcpp")

    expect_equal(maxent_layer_name("/data/bio1.asc"), "bio1")
    expect_equal(maxent_layer_name("temperature.tif"), "temperature")
    expect_equal(maxent_layer_name("noext"), "noext")
})

test_that("ASC round-trip: write then read", {
    skip_if_not_installed("maxentcpp")

    # Create a small grid from a matrix
    mat <- matrix(c(1.0, 2.0, 3.0,
                     4.0, NA,  6.0), nrow = 2, byrow = TRUE)
    g <- maxent_grid_from_matrix(mat, xll = 0, yll = 0, cellsize = 1,
                                 nodata = -9999, name = "test")

    tmp <- tempfile(fileext = ".asc")
    on.exit(unlink(tmp), add = TRUE)

    maxent_write_asc(g, tmp, scientific = FALSE)

    g2   <- maxent_read_asc(tmp)
    info <- maxent_grid_info(g2)

    expect_equal(info$nrows, 2)
    expect_equal(info$ncols, 3)
    expect_equal(info$cellsize, 1.0)
    expect_equal(info$count_data, 5)  # one NA cell

    mat2 <- maxent_grid_to_matrix(g2)
    expect_equal(mat2[1, 1], 1.0)
    expect_equal(mat2[1, 3], 3.0)
    expect_equal(mat2[2, 3], 6.0)
    expect_true(is.na(mat2[2, 2]))
})

test_that("read_grid auto-detects .asc format", {
    skip_if_not_installed("maxentcpp")

    mat <- matrix(c(10, 20, 30, 40), nrow = 2)
    g <- maxent_grid_from_matrix(mat, xll = -118, yll = 34,
                                 cellsize = 0.5, name = "elev")

    tmp <- tempfile(fileext = ".asc")
    on.exit(unlink(tmp), add = TRUE)
    maxent_write_asc(g, tmp)

    g2 <- maxent_read_grid(tmp)
    info <- maxent_grid_info(g2)
    expect_equal(info$nrows, 2)
    expect_equal(info$ncols, 2)
})

test_that("CSV reader reads headers and records", {
    skip_if_not_installed("maxentcpp")

    tmp <- tempfile(fileext = ".csv")
    on.exit(unlink(tmp), add = TRUE)
    writeLines(c("species,lon,lat",
                 "oak,-118.5,36.5",
                 "pine,-119.0,37.0"), tmp)

    reader <- maxent_csv_open(tmp)
    hdrs   <- maxent_csv_headers(reader)
    expect_equal(length(hdrs), 3)
    expect_equal(hdrs[1], "species")

    rec <- maxent_csv_next(reader)
    expect_equal(rec[1], "oak")

    rec2 <- maxent_csv_next(reader)
    expect_equal(rec2[1], "pine")

    rec3 <- maxent_csv_next(reader)
    expect_null(rec3)

    maxent_csv_close(reader)
})

test_that("CSV read_double_column returns correct values", {
    skip_if_not_installed("maxentcpp")

    tmp <- tempfile(fileext = ".csv")
    on.exit(unlink(tmp), add = TRUE)
    writeLines(c("x,y,temp",
                 "1,2,25.5",
                 "3,4,26.0",
                 "5,6,27.5"), tmp)

    reader <- maxent_csv_open(tmp)
    temps  <- maxent_csv_read_column(reader, "temp")
    expect_equal(length(temps), 3)
    expect_equal(temps[1], 25.5)
    expect_equal(temps[3], 27.5)
    maxent_csv_close(reader)
})

test_that("Grid from matrix and back preserves values", {
    skip_if_not_installed("maxentcpp")

    m <- matrix(runif(20), nrow = 4, ncol = 5)
    m[2, 3] <- NA  # one nodata cell

    g   <- maxent_grid_from_matrix(m, xll = -120, yll = 35,
                                    cellsize = 0.1)
    m2  <- maxent_grid_to_matrix(g)

    # Non-NA cells should match
    for (i in 1:4) {
        for (j in 1:5) {
            if (i == 2 && j == 3) {
                expect_true(is.na(m2[i, j]))
            } else {
                expect_equal(m2[i, j], m[i, j], tolerance = 1e-5)
            }
        }
    }
})

test_that("grid_float_info returns correct metadata", {
    skip_if_not_installed("maxentcpp")

    m    <- matrix(1:12, nrow = 3, ncol = 4)
    g    <- maxent_grid_from_matrix(m, xll = 0, yll = 0,
                                    cellsize = 0.5, name = "testgrid")
    info <- maxent_grid_info(g)

    expect_equal(info$nrows, 3)
    expect_equal(info$ncols, 4)
    expect_equal(info$xll, 0)
    expect_equal(info$cellsize, 0.5)
    expect_equal(info$name, "testgrid")
    expect_equal(info$count_data, 12)
})

test_that("CSV writer writes string and numeric values", {
    skip_if_not_installed("maxentcpp")

    tmp <- tempfile(fileext = ".csv")
    on.exit(unlink(tmp), add = TRUE)

    w <- maxent_csv_write_open(tmp)
    maxent_csv_write(w, "species", "oak")
    maxent_csv_write_num(w, "score", 0.85)
    maxent_csv_write_row(w)
    maxent_csv_write(w, "species", "pine")
    maxent_csv_write_num(w, "score", 0.72)
    maxent_csv_write_row(w)
    maxent_csv_write_close(w)

    # Verify the written file
    reader <- maxent_csv_open(tmp)
    hdrs   <- maxent_csv_headers(reader)
    expect_equal(length(hdrs), 2)
    expect_true("species" %in% hdrs)
    expect_true("score" %in% hdrs)

    rec1 <- maxent_csv_next(reader)
    expect_equal(rec1[which(hdrs == "species")], "oak")

    rec2 <- maxent_csv_next(reader)
    expect_equal(rec2[which(hdrs == "species")], "pine")

    maxent_csv_close(reader)
})

test_that("CSV writer round-trip preserves numeric precision", {
    skip_if_not_installed("maxentcpp")

    tmp <- tempfile(fileext = ".csv")
    on.exit(unlink(tmp), add = TRUE)

    values <- c(1.2345, 98.7654, -0.0001)

    w <- maxent_csv_write_open(tmp, precision = 4L)
    for (v in values) {
        maxent_csv_write_num(w, "value", v)
        maxent_csv_write_row(w)
    }
    maxent_csv_write_close(w)

    reader <- maxent_csv_open(tmp)
    result <- maxent_csv_read_column(reader, "value")
    maxent_csv_close(reader)

    expect_equal(length(result), 3)
    expect_equal(result[1], 1.2345, tolerance = 1e-4)
    expect_equal(result[2], 98.7654, tolerance = 1e-4)
    expect_equal(result[3], -0.0001, tolerance = 1e-4)
})

test_that("CSV writer append mode adds rows to existing file", {
    skip_if_not_installed("maxentcpp")

    tmp <- tempfile(fileext = ".csv")
    on.exit(unlink(tmp), add = TRUE)

    # Write first batch
    w1 <- maxent_csv_write_open(tmp, append = FALSE)
    maxent_csv_write(w1, "name", "alpha")
    maxent_csv_write_row(w1)
    maxent_csv_write_close(w1)

    # Append second batch
    w2 <- maxent_csv_write_open(tmp, append = TRUE)
    maxent_csv_write(w2, "name", "beta")
    maxent_csv_write_row(w2)
    maxent_csv_write_close(w2)

    reader <- maxent_csv_open(tmp)
    rec1 <- maxent_csv_next(reader)
    rec2 <- maxent_csv_next(reader)
    maxent_csv_close(reader)

    expect_equal(rec1[1], "alpha")
    expect_equal(rec2[1], "beta")
})
