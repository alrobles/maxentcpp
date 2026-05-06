test_that("LinearFeature creation and evaluation work", {
    skip_if_not_installed("maxentcpp")

    vals <- c(0.0, 5.0, 10.0, 3.0)
    f <- maxent_linear_feature(vals, "temperature", min_val = 0.0, max_val = 10.0)
    expect_true(!is.null(f))

    # 1-based indexing in R
    expect_equal(maxent_feature_eval(f, 1), 0.0)   # (0 - 0) / 10 = 0
    expect_equal(maxent_feature_eval(f, 2), 0.5)   # (5 - 0) / 10 = 0.5
    expect_equal(maxent_feature_eval(f, 3), 1.0)   # (10 - 0) / 10 = 1
    expect_equal(maxent_feature_eval(f, 4), 0.3)   # (3 - 0) / 10 = 0.3
})

test_that("LinearFeature auto-computes min/max", {
    skip_if_not_installed("maxentcpp")

    vals <- c(2.0, 4.0, 6.0, 8.0)
    f <- maxent_linear_feature(vals, "temp")  # no min_val/max_val
    info <- maxent_feature_info(f)
    expect_equal(info$min, 2.0)
    expect_equal(info$max, 8.0)
    expect_equal(maxent_feature_eval(f, 1), 0.0)  # (2-2)/(8-2)
    expect_equal(maxent_feature_eval(f, 4), 1.0)  # (8-2)/(8-2)
})

test_that("LinearFeature min == max returns 0", {
    skip_if_not_installed("maxentcpp")

    vals <- c(5.0, 5.0, 5.0)
    f <- maxent_linear_feature(vals, "constant", min_val = 5.0, max_val = 5.0)
    expect_equal(maxent_feature_eval(f, 1), 0.0)
    expect_equal(maxent_feature_eval(f, 2), 0.0)
})

test_that("QuadraticFeature creation and evaluation work", {
    skip_if_not_installed("maxentcpp")

    vals <- c(0.0, 5.0, 10.0)
    f <- maxent_quadratic_feature(vals, "temperature_sq", min_val = 0.0, max_val = 10.0)
    expect_true(!is.null(f))

    expect_equal(maxent_feature_eval(f, 1), 0.0)   # (0/10)^2
    expect_equal(maxent_feature_eval(f, 2), 0.25)  # (5/10)^2
    expect_equal(maxent_feature_eval(f, 3), 1.0)   # (10/10)^2
})

test_that("QuadraticFeature min == max returns 0", {
    skip_if_not_installed("maxentcpp")

    vals <- c(3.0, 3.0)
    f <- maxent_quadratic_feature(vals, "flat_sq", min_val = 3.0, max_val = 3.0)
    expect_equal(maxent_feature_eval(f, 1), 0.0)
})

test_that("ProductFeature creation and evaluation work", {
    skip_if_not_installed("maxentcpp")

    v1 <- c(0.0, 5.0, 10.0)
    v2 <- c(0.0, 2.0, 4.0)
    f <- maxent_product_feature(v1, v2, "temp_x_prec",
                                min1 = 0, max1 = 10,
                                min2 = 0, max2 = 4)
    expect_true(!is.null(f))

    expect_equal(maxent_feature_eval(f, 1), 0.0)   # 0 * 0
    expect_equal(maxent_feature_eval(f, 2), 0.25)  # 0.5 * 0.5
    expect_equal(maxent_feature_eval(f, 3), 1.0)   # 1 * 1
})

test_that("ProductFeature auto-computes min/max", {
    skip_if_not_installed("maxentcpp")

    v1 <- c(0.0, 5.0, 10.0)
    v2 <- c(100.0, 200.0, 150.0)
    f <- maxent_product_feature(v1, v2, "temp_x_prec")
    expect_true(!is.null(f))
    # Just check it runs without error
    val <- maxent_feature_eval(f, 1)
    expect_true(is.numeric(val))
})

test_that("ProductFeature mismatched lengths raise error", {
    skip_if_not_installed("maxentcpp")

    expect_error(
        maxent_product_feature(c(1, 2, 3), c(1, 2), "bad"),
        "same length"
    )
})

test_that("ThresholdFeature creation and evaluation work", {
    skip_if_not_installed("maxentcpp")

    vals <- c(1.0, 5.0, 10.0, 5.0)
    f <- maxent_threshold_feature(vals, "temp_threshold", threshold = 5.0)
    expect_true(!is.null(f))

    expect_equal(maxent_feature_eval(f, 1), 0.0)  # 1 < 5 → No
    expect_equal(maxent_feature_eval(f, 2), 1.0)  # 5 >= 5 → Yes (non-strict, matches Java)
    expect_equal(maxent_feature_eval(f, 3), 1.0)  # 10 > 5 → Yes
    expect_equal(maxent_feature_eval(f, 4), 1.0)  # 5 >= 5 → Yes (non-strict, matches Java)
})

test_that("HingeFeature (forward) creation and evaluation work", {
    skip_if_not_installed("maxentcpp")

    vals <- c(0.0, 5.0, 10.0, 3.0)
    f <- maxent_hinge_feature(vals, "temp_hinge", min_knot = 2.0, max_knot = 8.0)
    expect_true(!is.null(f))

    expect_equal(maxent_feature_eval(f, 1), 0.0)             # 0 <= 2 → 0
    expect_equal(maxent_feature_eval(f, 2), 0.5)             # (5-2)/(8-2) = 0.5
    expect_equal(maxent_feature_eval(f, 3), 8.0 / 6.0)      # (10-2)/(8-2)
    expect_equal(maxent_feature_eval(f, 4), 1.0 / 6.0)      # (3-2)/(8-2)
})

test_that("HingeFeature (reverse) creation and evaluation work", {
    skip_if_not_installed("maxentcpp")

    vals <- c(0.0, 5.0, 10.0, 8.0)
    f <- maxent_hinge_feature(vals, "temp_rev_hinge",
                              min_knot = 2.0, max_knot = 8.0,
                              reverse = TRUE)
    expect_true(!is.null(f))

    expect_equal(maxent_feature_eval(f, 1), 8.0 / 6.0)  # (8-0)/(8-2)
    expect_equal(maxent_feature_eval(f, 2), 0.5)         # (8-5)/(8-2)
    expect_equal(maxent_feature_eval(f, 3), 0.0)         # 10 >= 8 → 0
    expect_equal(maxent_feature_eval(f, 4), 0.0)         # 8 < 8? No → 0
})

test_that("HingeFeature invalid knots raise error", {
    skip_if_not_installed("maxentcpp")

    expect_error(
        maxent_hinge_feature(c(1, 2, 3), "bad", min_knot = 5, max_knot = 3),
        "min_knot"
    )
})

test_that("feature_get_info returns correct metadata", {
    skip_if_not_installed("maxentcpp")

    vals <- c(0.0, 5.0, 10.0)
    f <- maxent_linear_feature(vals, "my_feature", min_val = 0.0, max_val = 10.0)
    info <- maxent_feature_info(f)

    expect_equal(info$name,   "my_feature")
    expect_equal(info$type,   "linear")
    expect_equal(info$lambda, 0.0)
    expect_equal(info$min,    0.0)
    expect_equal(info$max,    10.0)
    expect_equal(info$size,   3L)
})

test_that("maxent_feature_eval validates index bounds", {
    skip_if_not_installed("maxentcpp")

    f <- maxent_linear_feature(c(0, 5, 10), "temp")

    expect_error(maxent_feature_eval(f, 0), "between 1 and 3")
    expect_error(maxent_feature_eval(f, 4), "between 1 and 3")
    expect_error(maxent_feature_eval(f, NA_real_), "single finite value")
    expect_error(maxent_feature_eval(f, 1.5), "whole number")
})

test_that("maxent_generate_features generates expected number of features", {
    skip_if_not_installed("maxentcpp")

    data <- list(
        temperature   = c(15.0, 20.0, 25.0, 18.0, 22.0),
        precipitation = c(100.0, 200.0, 150.0, 80.0, 300.0)
    )

    features <- maxent_generate_features(
        data,
        types = c("linear", "quadratic"),
        n_thresholds = 0,
        n_hinges = 0
    )

    # 2 variables × (1 linear + 1 quadratic) = 4
    expect_equal(length(features), 4L)

    types <- sapply(features, function(f) maxent_feature_info(f)$type)
    expect_true("linear" %in% types)
    expect_true("quadratic" %in% types)
})

test_that("maxent_generate_features: all types", {
    skip_if_not_installed("maxentcpp")

    data <- list(
        temp = c(10.0, 20.0, 30.0),
        prec = c(50.0, 100.0, 200.0)
    )

    features <- maxent_generate_features(
        data,
        types = c("linear", "quadratic", "product", "threshold", "hinge"),
        n_thresholds = 3,
        n_hinges = 2
    )

    # Per variable: linear(1) + quadratic(1) + threshold(3) + hinge_fwd(2) + hinge_rev(2) = 9
    # Product pairs: 1
    # Total: 9*2 + 1 = 19
    expect_equal(length(features), 19L)

    types <- sapply(features, function(f) maxent_feature_info(f)$type)
    expect_true("linear"        %in% types)
    expect_true("quadratic"     %in% types)
    expect_true("product"       %in% types)
    expect_true("threshold"     %in% types)
    expect_true("hinge"         %in% types)
    expect_true("reverse_hinge" %in% types)
})

test_that("maxent_generate_features: single variable, linear only", {
    skip_if_not_installed("maxentcpp")

    data <- list(elevation = c(100.0, 500.0, 1000.0))
    features <- maxent_generate_features(data, types = "linear",
                                         n_thresholds = 0, n_hinges = 0)
    expect_equal(length(features), 1L)
    expect_equal(maxent_feature_info(features[[1]])$type, "linear")
})

test_that("maxent_generate_features: unnamed list raises error", {
    skip_if_not_installed("maxentcpp")

    expect_error(
        maxent_generate_features(list(c(1, 2, 3))),
        "named list"
    )
})
