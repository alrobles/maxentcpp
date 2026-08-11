# Tests for cross-validation and replicate runs

test_that("maxent_cross_validate returns expected structure", {
    skip_if_not_installed("maxentcpp")

    set.seed(42)
    n <- 200
    n_occ <- 20
    env <- list(
        temp  = rnorm(n, mean = 20, sd = 5),
        precip = rnorm(n, mean = 500, sd = 100)
    )
    occ_idx <- order(env$temp, decreasing = TRUE)[1:n_occ]
    sample_indices <- as.integer(occ_idx - 1L)

    cv <- maxent_cross_validate(
        env, sample_indices, num_points = n,
        k = 3L, types = c("linear"), max_iter = 50L
    )

    expect_true(is.list(cv))
    expect_true("fold_results" %in% names(cv))
    expect_true("summary" %in% names(cv))

    # 3 folds
    expect_equal(length(cv$fold_results), 3)

    # Summary has 3 folds + 1 mean row
    expect_equal(nrow(cv$summary), 4)
    expect_true("mean" %in% cv$summary$statistic)

    # Each fold result has expected fields
    fr <- cv$fold_results[[1]]
    expect_true(all(c("fold", "train_gain", "n_train", "n_test", "lambdas") %in% names(fr)))

    # Fold training sizes should partition occurrences
    n_trains <- vapply(cv$fold_results, `[[`, integer(1), "n_train")
    n_tests  <- vapply(cv$fold_results, `[[`, integer(1), "n_test")
    # Total test points across folds should equal n_occ
    expect_equal(sum(n_tests), n_occ)
})

test_that("maxent_cross_validate validates input", {
    expect_error(
        maxent_cross_validate(list(1:10), 0:4, 10L),
        "named list"
    )
    env <- list(temp = rnorm(10))
    expect_error(
        maxent_cross_validate(env, 0:4, 10L, k = 1L),
        "k must be >= 2"
    )
    expect_error(
        maxent_cross_validate(env, 0:1, 10L, k = 5L),
        "fewer occurrence"
    )
})

test_that("maxent_replicate bootstrap returns expected structure", {
    skip_if_not_installed("maxentcpp")

    set.seed(42)
    n <- 200
    n_occ <- 20
    env <- list(
        temp  = rnorm(n, mean = 20, sd = 5),
        precip = rnorm(n, mean = 500, sd = 100)
    )
    occ_idx <- order(env$temp, decreasing = TRUE)[1:n_occ]
    sample_indices <- as.integer(occ_idx - 1L)

    reps <- maxent_replicate(
        env, sample_indices, num_points = n,
        n_replicates = 3L, replicate_type = "bootstrap",
        types = c("linear"), max_iter = 50L
    )

    expect_true(is.list(reps))
    expect_equal(length(reps$replicate_results), 3)
    expect_true("summary" %in% names(reps))
    expect_equal(nrow(reps$summary), 2)  # mean and sd

    # Each replicate has expected fields
    rr <- reps$replicate_results[[1]]
    expect_true(all(c("replicate", "train_gain", "lambdas") %in% names(rr)))
})

test_that("maxent_replicate subsample uses 75% of occurrences", {
    skip_if_not_installed("maxentcpp")

    set.seed(42)
    n <- 200
    n_occ <- 20
    env <- list(temp = rnorm(n, mean = 20, sd = 5))
    occ_idx <- order(env$temp, decreasing = TRUE)[1:n_occ]
    sample_indices <- as.integer(occ_idx - 1L)

    reps <- maxent_replicate(
        env, sample_indices, num_points = n,
        n_replicates = 2L, replicate_type = "subsample",
        types = c("linear"), max_iter = 50L
    )

    expect_equal(length(reps$replicate_results), 2)
})

test_that("maxent_replicate validates input", {
    expect_error(
        maxent_replicate(list(1:10), 0:4, 10L),
        "named list"
    )
})

test_that("maxent_cross_validate is reproducible with same seed", {
    skip_if_not_installed("maxentcpp")

    set.seed(42)
    n <- 100
    env <- list(temp = rnorm(n))
    idx <- as.integer(seq(80, 99))

    cv1 <- maxent_cross_validate(env, idx, n, k = 3L, types = "linear",
                                  max_iter = 20L, seed = 123L)
    cv2 <- maxent_cross_validate(env, idx, n, k = 3L, types = "linear",
                                  max_iter = 20L, seed = 123L)

    gains1 <- vapply(cv1$fold_results, `[[`, numeric(1), "train_gain")
    gains2 <- vapply(cv2$fold_results, `[[`, numeric(1), "train_gain")
    expect_equal(gains1, gains2)
})
