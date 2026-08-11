# Tests for jackknife variable importance

test_that("maxent_jackknife returns expected structure", {
    skip_if_not_installed("maxentcpp")

    set.seed(42)
    n <- 200
    n_occ <- 20
    env <- list(
        temp  = rnorm(n, mean = 20, sd = 5),
        precip = rnorm(n, mean = 500, sd = 100)
    )
    # Make occurrences slightly correlated with temp
    occ_idx <- order(env$temp, decreasing = TRUE)[1:n_occ]
    sample_indices <- as.integer(occ_idx - 1L)  # 0-based

    jk <- maxent_jackknife(
        env, sample_indices, num_points = n,
        types = c("linear", "quadratic"),
        max_iter = 50L
    )

    expect_true(is.data.frame(jk))
    expect_equal(nrow(jk), 2)  # 2 variables
    expect_true(all(c("variable", "gain_without", "gain_only", "gain_full") %in% names(jk)))
    expect_equal(jk$variable, c("temp", "precip"))

    # Full model gain should be the same for all rows
    expect_equal(jk$gain_full[1], jk$gain_full[2])

    # gain_only should be positive (model learned something)
    expect_true(all(jk$gain_only >= 0))
})

test_that("maxent_jackknife validates input", {
    expect_error(
        maxent_jackknife(list(1:10), sample_indices = 0:4, num_points = 10L),
        "named list"
    )
})

test_that("maxent_jackknife with categorical variable", {
    skip_if_not_installed("maxentcpp")

    set.seed(42)
    n <- 200
    n_occ <- 20
    env <- list(
        temp  = rnorm(n, mean = 20, sd = 5),
        soil  = sample(c(1, 2, 3), n, replace = TRUE)
    )
    occ_idx <- order(env$temp, decreasing = TRUE)[1:n_occ]
    sample_indices <- as.integer(occ_idx - 1L)

    jk <- maxent_jackknife(
        env, sample_indices, num_points = n,
        types = c("linear"),
        max_iter = 50L,
        categorical = "soil"
    )

    expect_true(is.data.frame(jk))
    expect_equal(nrow(jk), 2)
    expect_equal(jk$variable, c("temp", "soil"))
})
