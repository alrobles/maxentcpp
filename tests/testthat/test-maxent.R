test_that("GridDimension creation works", {
    skip_if_not_installed("maxentcpp")
    
    dim <- create_grid_dimension(100, 100, -120.0, 35.0, 0.1)
    expect_true(!is.null(dim))
    
    info <- get_grid_dimension_info(dim)
    expect_equal(info$nrows, 100)
    expect_equal(info$ncols, 100)
    expect_equal(info$xll, -120.0)
    expect_equal(info$yll, 35.0)
    expect_equal(info$cellsize, 0.1)
    expect_equal(info$size, 10000)
})

test_that("Coordinate conversion works", {
    skip_if_not_installed("maxentcpp")
    
    dim <- create_grid_dimension(100, 100, -120.0, 35.0, 0.1)
    rc <- coords_to_rowcol(dim, -119.5, 36.0)
    
    expect_length(rc, 2)
    expect_true(rc[1] >= 0 && rc[1] < 100)
    expect_true(rc[2] >= 0 && rc[2] < 100)
})

test_that("Sample creation works", {
    skip_if_not_installed("maxentcpp")
    
    sample <- create_sample(0, 50, 50, 36.5, -118.5, "test")
    expect_true(!is.null(sample))
    
    info <- get_sample_info(sample)
    expect_equal(info$point, 0)
    expect_equal(info$row, 50)
    expect_equal(info$col, 50)
    expect_equal(info$lat, 36.5)
    expect_equal(info$lon, -118.5)
    expect_equal(info$name, "test")
})

test_that("Sample features work", {
    skip_if_not_installed("maxentcpp")
    
    sample <- create_sample(0, 50, 50, 36.5, -118.5, "test")
    
    # Set features
    sample_set_feature(sample, "temperature", 25.5)
    sample_set_feature(sample, "precipitation", 100.0)
    
    # Get features
    temp <- sample_get_feature(sample, "temperature")
    precip <- sample_get_feature(sample, "precipitation")
    missing <- sample_get_feature(sample, "elevation", -999.0)
    
    expect_equal(temp, 25.5)
    expect_equal(precip, 100.0)
    expect_equal(missing, -999.0)
})

test_that("Grid creation and manipulation work", {
    skip_if_not_installed("maxentcpp")
    
    dim <- create_grid_dimension(10, 10, -120.0, 35.0, 0.1)
    grid <- create_grid_float(dim, "test_grid", -9999.0)
    
    expect_true(!is.null(grid))
    
    # Set and get values
    grid_set_value(grid, 5, 5, 42.5)
    val <- grid_get_value(grid, 5, 5)
    expect_equal(val, 42.5)
    
    # Check has_data
    expect_true(grid_has_data(grid, 5, 5))
})

test_that("Grid matrix conversion works", {
    skip_if_not_installed("maxentcpp")
    
    dim <- create_grid_dimension(5, 5, -120.0, 35.0, 0.1)
    grid <- create_grid_float(dim, "test_grid")
    
    # Create a test matrix
    test_mat <- matrix(1:25, nrow = 5, ncol = 5, byrow = TRUE)
    
    # Set grid from matrix
    grid_from_matrix(grid, test_mat)
    
    # Convert back to matrix
    result_mat <- grid_to_matrix(grid)
    
    expect_equal(dim(result_mat), c(5, 5))
    expect_equal(result_mat, test_mat)
})

test_that("High-level R functions work", {
    skip_if_not_installed("maxentcpp")
    
    # Create dimension
    dim <- maxent_dimension(20, 20, -120, 35, 0.1)
    expect_true(!is.null(dim))
    
    # Create sample
    sample <- maxent_sample(lon = -119.5, lat = 36.0, name = "site1", dim = dim)
    expect_true(!is.null(sample))
    
    # Create grid
    grid <- maxent_grid(dim, "temperature")
    expect_true(!is.null(grid))
    
    # Test matrix operations
    mat <- as_matrix(grid)
    expect_equal(dim(mat), c(20, 20))
})
