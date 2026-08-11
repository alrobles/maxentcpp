# Tests for missing data handling

test_that("maxent_complete_cases filters NA values", {
    env <- list(
        temp  = c(15, NA, 25, 18, 20),
        precip = c(100, 200, 150, 80, 300)
    )
    valid <- maxent_complete_cases(env)
    expect_equal(valid, c(1L, 3L, 4L, 5L))
})

test_that("maxent_complete_cases filters NODATA sentinel", {
    env <- list(
        temp  = c(15, 20, 25, 18, -9999),
        precip = c(100, 200, 150, 80, 300)
    )
    valid <- maxent_complete_cases(env)
    expect_equal(valid, c(1L, 2L, 3L, 4L))
})

test_that("maxent_complete_cases filters NaN", {
    env <- list(
        temp  = c(15, NaN, 25),
        precip = c(100, 200, 150)
    )
    valid <- maxent_complete_cases(env)
    expect_equal(valid, c(1L, 3L))
})

test_that("maxent_complete_cases filters across multiple variables", {
    env <- list(
        temp   = c(15, 20, 25, NA, 18),
        precip = c(100, -9999, 150, 80, 300),
        elev   = c(500, 600, NaN, 400, 700)
    )
    valid <- maxent_complete_cases(env)
    # index 1: all valid
    # index 2: precip is NODATA
    # index 3: elev is NaN
    # index 4: temp is NA
    # index 5: all valid
    expect_equal(valid, c(1L, 5L))
})

test_that("maxent_complete_cases with custom nodata value", {
    env <- list(temp = c(15, -999, 25))
    valid <- maxent_complete_cases(env, nodata_value = -999)
    expect_equal(valid, c(1L, 3L))
})

test_that("maxent_complete_cases returns all when no missing", {
    env <- list(temp = c(15, 20, 25), precip = c(100, 200, 150))
    valid <- maxent_complete_cases(env)
    expect_equal(valid, c(1L, 2L, 3L))
})

test_that("maxent_impute_means replaces NA and NODATA with means", {
    env <- list(
        temp  = c(15, NA, 25, 18, -9999),
        precip = c(100, 200, 150, 80, 300)
    )
    filled <- maxent_impute_means(env)

    temp_mean <- mean(c(15, 25, 18))  # mean of valid values
    expect_equal(filled$temp[2], temp_mean)
    expect_equal(filled$temp[5], temp_mean)
    # precip unchanged
    expect_equal(filled$precip, c(100, 200, 150, 80, 300))
})

test_that("maxent_impute_means with no missing returns unchanged", {
    env <- list(temp = c(15, 20, 25))
    filled <- maxent_impute_means(env)
    expect_equal(filled$temp, c(15, 20, 25))
})

test_that("maxent_complete_cases validates input", {
    expect_error(maxent_complete_cases(list()), "non-empty")
    expect_error(maxent_complete_cases("not a list"), "non-empty")
    expect_error(
        maxent_complete_cases(list(a = 1:3, b = 1:4)),
        "same length"
    )
})
