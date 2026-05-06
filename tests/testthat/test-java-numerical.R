# Tests for Java Maxent numerical equivalency.
#
# Compares outputs of the maxentcpp C++ implementation with a minimal
# Java reimplementation of the core Maxent algorithm (linear features,
# raw output).
#
# Java source files live in java/ at the repository root.
# The compiled JAR (inst/java/maxent_mini.jar) is required for
# Groups B, C, and D.  Build it with:
#   cd java && ./build.sh
#
# Source classes tested:
#   Group A — density/LinearFeature.java    (feature evaluation formula)
#   Group B — density/FeaturedSpace.java +  (training invariants)
#             density/Sequential.java
#   Group C — density/FeaturedSpace.java    (raw output formula)
#   Group D — end-to-end on test_data.csv   (bio1 + bio12 linear model)

# ===========================================================================
# Group A — Linear feature normalization
# (No Java runtime required; tests the formula against the C++ implementation)
# ===========================================================================

test_that("Linear feature eval matches (x - min)/(max - min) for in-range values", {
    skip_if_not_installed("maxentcpp")

    # Use bio1 column from test_data.csv if available, otherwise a small vector
    csv_path <- system.file("extdata", "test_data.csv", package = "maxentcpp")
    if (nzchar(csv_path) && file.exists(csv_path)) {
        vals <- read.csv(csv_path)$bio1
    } else {
        vals <- c(56.6, 104.7, 181.1, 248.2, 299.4)
    }

    mn <- min(vals)
    mx <- max(vals)
    f  <- maxent_linear_feature(vals, "bio1", min_val = mn, max_val = mx)

    expected <- (vals - mn) / (mx - mn)
    actual   <- sapply(seq_along(vals), function(i) maxent_feature_eval(f, i))

    expect_equal(actual, expected, tolerance = 1e-12)
})

test_that("Linear feature eval clamps: below min -> 0, above max -> 1 (projection)", {
    skip_if_not_installed("maxentcpp")

    # Use projection (eval_from_env) to test clamping:
    # build a tiny 1-point grid with an out-of-range value and compare
    # to the boundary value.
    vals <- seq(10.0, 100.0, length.out = 5)
    features <- maxent_generate_features(
        list(bio1 = vals), types = "linear",
        n_thresholds = 0L, n_hinges = 0L
    )
    model <- maxent_featured_space(5L, c(3L, 4L), features)
    maxent_fit(model, max_iter = 100L, convergence = 1e-5)

    # Build single-cell grids at boundary values
    dim_1 <- maxent_dimension(nrows = 1L, ncols = 1L,
                              xll = 0, yll = 0, cellsize = 1)
    g_min <- maxent_grid(dim_1, "bio1")
    g_max <- maxent_grid(dim_1, "bio1")
    g_low <- maxent_grid(dim_1, "bio1")   # below training min
    g_hi  <- maxent_grid(dim_1, "bio1")   # above training max

    grid_set_value(g_min, 0L, 0L, min(vals))
    grid_set_value(g_max, 0L, 0L, max(vals))
    grid_set_value(g_low, 0L, 0L, min(vals) - 1000)
    grid_set_value(g_hi,  0L, 0L, max(vals) + 1000)

    pred_min <- maxent_grid_to_matrix(
        maxent_project_raw(model, list(g_min), c("bio1")))[1, 1]
    pred_max <- maxent_grid_to_matrix(
        maxent_project_raw(model, list(g_max), c("bio1")))[1, 1]
    pred_low <- maxent_grid_to_matrix(
        maxent_project_raw(model, list(g_low), c("bio1")))[1, 1]
    pred_hi  <- maxent_grid_to_matrix(
        maxent_project_raw(model, list(g_hi),  c("bio1")))[1, 1]

    expect_equal(pred_low, pred_min, tolerance = 1e-9,
                 label = "below-range prediction equals boundary min prediction")
    expect_equal(pred_hi,  pred_max, tolerance = 1e-9,
                 label = "above-range prediction equals boundary max prediction")
})

test_that("Linear feature formula: min == max returns 0", {
    skip_if_not_installed("maxentcpp")

    vals <- c(5.0, 5.0, 5.0)
    f    <- maxent_linear_feature(vals, "constant", min_val = 5.0, max_val = 5.0)
    expect_equal(maxent_feature_eval(f, 1), 0.0)
    expect_equal(maxent_feature_eval(f, 2), 0.0)
    expect_equal(maxent_feature_eval(f, 3), 0.0)
})

# ===========================================================================
# Group B — Training invariants (C++ vs Java)
# Tolerance 1e-6 across all invariants.
# ===========================================================================

test_that("Entropy matches Java after training (1-variable model)", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    cpp  <- build_cpp_model_1var()
    java <- build_java_model_1var()

    expect_equal(cpp$fit$entropy, java$entropy,
                 tolerance = 1e-6,
                 label = "C++ entropy", expected.label = "Java entropy")
})

test_that("density_normalizer matches Java after training (1-variable model)", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    cpp  <- build_cpp_model_1var()
    java <- build_java_model_1var()

    cpp_dn <- maxent_space_info(cpp$model)$density_normalizer
    expect_equal(cpp_dn, java$density_normalizer,
                 tolerance = 1e-6,
                 label = "C++ density_normalizer",
                 expected.label = "Java density_normalizer")
})

test_that("linear_predictor_normalizer matches Java after training (1-variable model)", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    cpp  <- build_cpp_model_1var()
    java <- build_java_model_1var()

    cpp_lpn <- maxent_space_info(cpp$model)$linear_predictor_normalizer
    expect_equal(cpp_lpn, java$lp_normalizer,
                 tolerance = 1e-6,
                 label = "C++ lp_normalizer",
                 expected.label = "Java lp_normalizer")
})

test_that("Lambda value matches Java for bio1 linear feature (1-variable model)", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    cpp  <- build_cpp_model_1var()
    java <- build_java_model_1var()

    expect_equal(cpp$fit$lambdas[[1]], java$lambda,
                 tolerance = 1e-6,
                 label = "C++ lambda", expected.label = "Java lambda")
})

test_that("Loss matches Java after training (1-variable model)", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    cpp  <- build_cpp_model_1var()
    java <- build_java_model_1var()

    expect_equal(cpp$fit$loss, java$loss,
                 tolerance = 1e-6,
                 label = "C++ loss", expected.label = "Java loss")
})

# ===========================================================================
# Group C — Raw output formula (C++ vs Java)
# ===========================================================================

test_that("Raw score matches Java for all background training points (1-variable)", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    cpp  <- build_cpp_model_1var()
    java <- build_java_model_1var()

    cpp_raw  <- cpp_raw_scores(cpp)
    java_raw <- java$raw_scores

    expect_equal(cpp_raw, java_raw,
                 tolerance = 1e-9,
                 label = "C++ raw scores",
                 expected.label = "Java raw scores")
})

test_that("Raw scores are capped at 1.0 by both C++ and Java (1-variable)", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    cpp  <- build_cpp_model_1var()
    java <- build_java_model_1var()

    cpp_raw  <- cpp_raw_scores(cpp)
    java_raw <- java$raw_scores

    expect_true(all(cpp_raw  <= 1.0), label = "C++ raw scores <= 1")
    expect_true(all(java_raw <= 1.0), label = "Java raw scores <= 1")
    expect_true(all(cpp_raw  >= 0.0), label = "C++ raw scores >= 0")
    expect_true(all(java_raw >= 0.0), label = "Java raw scores >= 0")
})

test_that("Raw scores for presence points match Java (1-variable model)", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    cpp  <- build_cpp_model_1var()
    java <- build_java_model_1var()

    d <- twovar_data()
    pres_idx <- which(d$flags == 1L)    # 1-based R indices into all-points vector

    cpp_raw  <- cpp_raw_scores(cpp)[pres_idx]
    java_raw <- java$raw_scores[pres_idx]

    expect_equal(cpp_raw, java_raw,
                 tolerance = 1e-9,
                 label = "C++ presence raw scores",
                 expected.label = "Java presence raw scores")
})

# ===========================================================================
# Group D — End-to-end on test_data.csv (bio1 + bio12 linear model)
# ===========================================================================

test_that("Entropy matches Java after training (bio1 + bio12 linear model)", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    cpp  <- build_cpp_model_2var()
    java <- build_java_model_2var()

    expect_equal(cpp$fit$entropy, java$entropy,
                 tolerance = 1e-6,
                 label = "C++ entropy", expected.label = "Java entropy")
})

test_that("Lambdas match Java for bio1 and bio12 features", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    cpp  <- build_cpp_model_2var()
    java <- build_java_model_2var()

    expect_equal(cpp$fit$lambdas[[1]], java$lambda1,
                 tolerance = 1e-6,
                 label = "C++ lambda bio1", expected.label = "Java lambda bio1")
    expect_equal(cpp$fit$lambdas[[2]], java$lambda2,
                 tolerance = 1e-6,
                 label = "C++ lambda bio12", expected.label = "Java lambda bio12")
})

test_that("density_normalizer matches Java (bio1 + bio12 linear model)", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    cpp  <- build_cpp_model_2var()
    java <- build_java_model_2var()

    cpp_dn <- maxent_space_info(cpp$model)$density_normalizer
    expect_equal(cpp_dn, java$density_normalizer,
                 tolerance = 1e-6,
                 label = "C++ density_normalizer",
                 expected.label = "Java density_normalizer")
})

test_that("linear_predictor_normalizer matches Java (bio1 + bio12 linear model)", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    cpp  <- build_cpp_model_2var()
    java <- build_java_model_2var()

    cpp_lpn <- maxent_space_info(cpp$model)$linear_predictor_normalizer
    expect_equal(cpp_lpn, java$lp_normalizer,
                 tolerance = 1e-6,
                 label = "C++ lp_normalizer",
                 expected.label = "Java lp_normalizer")
})

test_that("Loss matches Java (bio1 + bio12 linear model)", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    cpp  <- build_cpp_model_2var()
    java <- build_java_model_2var()

    expect_equal(cpp$fit$loss, java$loss,
                 tolerance = 1e-6,
                 label = "C++ loss", expected.label = "Java loss")
})

test_that("Raw scores at all training points match Java (bio1 + bio12 linear model)", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    cpp  <- build_cpp_model_2var()
    java <- build_java_model_2var()

    cpp_raw  <- cpp_raw_scores(cpp)
    java_raw <- java$raw_scores

    expect_equal(cpp_raw, java_raw,
                 tolerance = 1e-9,
                 label = "C++ raw scores",
                 expected.label = "Java raw scores")
})
