# Tests for categorical variable support (BinaryFeature)

test_that("BinaryFeature creation and evaluation work", {
    skip_if_not_installed("maxentcpp")

    vals <- c(1, 2, 3, 1, 2)
    f <- maxent_binary_feature(vals, "(landcover=1)", target = 1)
    expect_true(!is.null(f))

    # 1-based indexing in R
    expect_equal(maxent_feature_eval(f, 1), 1.0)  # vals[1] == 1
    expect_equal(maxent_feature_eval(f, 2), 0.0)  # vals[2] == 2
    expect_equal(maxent_feature_eval(f, 3), 0.0)  # vals[3] == 3
    expect_equal(maxent_feature_eval(f, 4), 1.0)  # vals[4] == 1
    expect_equal(maxent_feature_eval(f, 5), 0.0)  # vals[5] == 2
})

test_that("BinaryFeature info reports binary type", {
    skip_if_not_installed("maxentcpp")

    vals <- c(1, 2, 3)
    f <- maxent_binary_feature(vals, "(cat=2)", target = 2)
    info <- maxent_feature_info(f)
    expect_equal(info$type, "binary")
    expect_equal(info$min, 0.0)
    expect_equal(info$max, 1.0)
})

test_that("generate_features with categorical creates binary indicators", {
    skip_if_not_installed("maxentcpp")

    env <- list(
        temp     = c(15, 20, 25, 18, 22, 30, 10, 12, 28, 17),
        landtype = c(1, 2, 3, 1, 2, 3, 1, 2, 3, 1)
    )

    features <- maxent_generate_features(
        env,
        types = c("linear", "quadratic"),
        categorical = "landtype"
    )
    expect_true(length(features) > 0)

    # Should have linear + quadratic for temp, plus 3 binary for landtype
    # (3 distinct landtype values: 1, 2, 3)
    feature_names <- vapply(features, function(f) maxent_feature_info(f)$name, "")
    feature_types <- vapply(features, function(f) maxent_feature_info(f)$type, "")

    # Check binary features exist
    binary_feats <- feature_names[feature_types == "binary"]
    expect_true(length(binary_feats) == 3)
    expect_true(any(grepl("landtype=1", binary_feats)))
    expect_true(any(grepl("landtype=2", binary_feats)))
    expect_true(any(grepl("landtype=3", binary_feats)))

    # Check continuous features exist for temp
    linear_feats <- feature_names[feature_types == "linear"]
    expect_true(length(linear_feats) >= 1)
})

test_that("categorical parameter validates names", {
    skip_if_not_installed("maxentcpp")

    env <- list(temp = c(1, 2, 3), precip = c(4, 5, 6))
    expect_error(
        maxent_generate_features(env, categorical = "nonexistent"),
        "not found"
    )
})

test_that("all-categorical environment produces only binary features", {
    skip_if_not_installed("maxentcpp")

    env <- list(
        soil = c(1, 2, 3, 1, 2),
        veg  = c(10, 20, 10, 20, 10)
    )

    features <- maxent_generate_features(
        env,
        types = c("linear"),
        categorical = c("soil", "veg")
    )

    feature_types <- vapply(features, function(f) maxent_feature_info(f)$type, "")
    expect_true(all(feature_types == "binary"))
    # soil: 3 categories + veg: 2 categories = 5 binary features
    expect_equal(length(features), 5)
})
