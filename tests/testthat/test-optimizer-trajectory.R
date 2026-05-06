# Phase B/D: Quantify Optimizer Gap — optimizer trajectory comparison tests.
#
# This file implements the "side-by-side diagnostics" called for in
# issue #38 (Phase B of the fidelity roadmap, issue #36) and the 1e-6 parity
# gate for Phase D (issue #40).
#
# Groups of tests provided:
#
# Group E — Full C++ Sequential trajectory vs. full Java golden (linear)
#   Uses maxent_sequential_fit() (the Phase C full port of density/Sequential.java)
#   on the 10×10 asymmetric fixture and asserts that every checkpoint in
#   {1,2,3,5,10,20,50,100,200,500} matches the committed Java golden to 1e-6.
#
# Group F — Simple Java Sequential trajectory self-consistency
#   (Requires rJava)  Runs the simplified goodAlpha / reduceAlpha loop in the
#   Java oracle (MaxentJavaRunner::trainLinear2VarTrajectory) on the bio1+bio12
#   dataset and verifies the trajectory is internally consistent: loss must be
#   monotonically non-increasing, entropy must be non-negative, and lambdas
#   must be finite at every checkpoint.
#
# Group G — Phase D: C++ Sequential trajectory vs. committed golden (L+Q)
#   Verifies that the full C++ Sequential optimizer matches the committed
#   Phase D golden (trajectory_java_lq.csv) on the asym fixture with
#   linear + quadratic features to 1e-6.
#
# Group H — Phase D: C++ Sequential trajectory vs. committed golden (L+Q+P)
#   Verifies that the full C++ Sequential optimizer matches the committed
#   Phase D golden (trajectory_java_lqp.csv) on the asym fixture with
#   linear + quadratic + product features to 1e-6.
#
# Group I — Phase D: simplified Java L+Q and L+Q+P trajectory self-consistency
#   (Requires rJava)  Runs the simplified Java optimizer on the asym fixture
#   with L+Q and L+Q+P features and verifies internal consistency.
#
# Together these groups establish the Phase D fidelity baseline.

# ===========================================================================
# Helper: build and run C++ sequential_fit on the asymmetric fixture
# ===========================================================================

.run_cpp_asym_trajectory <- function() {
    d <- asym_fixture()

    feat <- maxent_generate_features(
        list(bio1 = d$bio1, bio2 = d$bio2),
        types        = "linear",
        n_thresholds = 0L,
        n_hinges     = 0L
    )
    fs <- maxent_featured_space(d$n, d$sample_idx, feat)

    maxent_sequential_fit(
        fs,
        max_iter                  = 500L,
        convergence               = 0.0,
        disable_convergence_test  = TRUE,
        trajectory_iterations     = c(1L, 2L, 3L, 5L, 10L, 20L, 50L, 100L, 200L, 500L)
    )$trajectory
}

# ===========================================================================
# Group E — Full C++ Sequential trajectory vs. committed Java golden
# ===========================================================================

test_that("Group E: C++ trajectory row count matches Java golden (asym fixture)", {
    skip_if_not_installed("maxentcpp")

    traj   <- .run_cpp_asym_trajectory()
    golden <- asym_java_golden()

    expect_equal(nrow(traj), nrow(golden),
                 label = "number of captured checkpoints")
})

test_that("Group E: C++ trajectory iteration labels match Java golden (asym fixture)", {
    skip_if_not_installed("maxentcpp")

    traj   <- .run_cpp_asym_trajectory()
    golden <- asym_java_golden()

    expect_equal(traj$iteration, golden$iteration,
                 label = "checkpoint iteration numbers")
})

test_that("Group E: C++ loss trajectory matches Java golden to 1e-6 (asym fixture)", {
    skip_if_not_installed("maxentcpp")

    traj   <- .run_cpp_asym_trajectory()
    golden <- asym_java_golden()

    expect_equal(traj$loss, golden$loss,
                 tolerance = 1e-6,
                 label = "C++ loss trajectory",
                 expected.label = "Java golden loss")
})

test_that("Group E: C++ entropy trajectory matches Java golden to 1e-6 (asym fixture)", {
    skip_if_not_installed("maxentcpp")

    traj   <- .run_cpp_asym_trajectory()
    golden <- asym_java_golden()

    expect_equal(traj$entropy, golden$entropy,
                 tolerance = 1e-6,
                 label = "C++ entropy trajectory",
                 expected.label = "Java golden entropy")
})

test_that("Group E: C++ lambda_0 trajectory matches Java golden to 1e-6 (asym fixture)", {
    skip_if_not_installed("maxentcpp")

    traj   <- .run_cpp_asym_trajectory()
    golden <- asym_java_golden()

    expect_equal(traj$lambda_0, golden$lambda_0,
                 tolerance = 1e-6,
                 label = "C++ lambda_0 trajectory",
                 expected.label = "Java golden lambda_0")
})

test_that("Group E: C++ lambda_1 trajectory matches Java golden to 1e-6 (asym fixture)", {
    skip_if_not_installed("maxentcpp")

    traj   <- .run_cpp_asym_trajectory()
    golden <- asym_java_golden()

    expect_equal(traj$lambda_1, golden$lambda_1,
                 tolerance = 1e-6,
                 label = "C++ lambda_1 trajectory",
                 expected.label = "Java golden lambda_1")
})

test_that("Group E: worst ||delta_lambda||_inf < 1e-6 across all checkpoints (asym fixture)", {
    skip_if_not_installed("maxentcpp")

    traj   <- .run_cpp_asym_trajectory()
    golden <- asym_java_golden()

    worst <- max(
        abs(traj$lambda_0 - golden$lambda_0),
        abs(traj$lambda_1 - golden$lambda_1)
    )
    expect_lt(worst, 1e-6,
              label = "worst ||delta_lambda||_inf across all checkpoints")
})

# ===========================================================================
# Group F — Simple Java Sequential trajectory self-consistency
# (rJava required)
# ===========================================================================

test_that("Group F: simple Java trajectory has correct number of checkpoints (2-var)", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    checkpoints <- c(1L, 2L, 3L, 5L, 10L, 20L, 50L, 100L, 200L, 500L)
    traj <- build_java_trajectory_2var(checkpoints)

    # The Java optimizer may converge early (before max_iter) so it may
    # not capture all requested checkpoints.  We only require that the
    # returned checkpoints are a prefix of the requested ones.
    expect_true(nrow(traj) >= 1L && nrow(traj) <= length(checkpoints),
                label = "number of Java trajectory rows is in valid range")
    expect_equal(traj$iteration, checkpoints[seq_len(nrow(traj))],
                 label = "Java trajectory iteration labels")
})

test_that("Group F: simple Java trajectory loss is non-increasing at checkpoints (2-var)", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    traj <- build_java_trajectory_2var()

    # Allow a tiny numerical tolerance for non-strict monotonicity.
    diffs <- diff(traj$loss)
    expect_true(all(diffs <= 1e-9),
                label = "Java trajectory loss is non-increasing at every checkpoint")
})

test_that("Group F: simple Java trajectory entropy is non-negative at all checkpoints (2-var)", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    traj <- build_java_trajectory_2var()

    expect_true(all(traj$entropy >= 0),
                label = "Java trajectory entropy >= 0 at every checkpoint")
})

test_that("Group F: simple Java trajectory lambdas are finite at all checkpoints (2-var)", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    traj <- build_java_trajectory_2var()

    expect_true(all(is.finite(traj$lambda_0)),
                label = "Java trajectory lambda_0 finite at every checkpoint")
    expect_true(all(is.finite(traj$lambda_1)),
                label = "Java trajectory lambda_1 finite at every checkpoint")
})

test_that("Group F: simple Java trajectory matches expected checkpoint values (2-var)", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    checkpoints <- c(1L, 10L, 100L, 500L)
    traj <- build_java_trajectory_2var(checkpoints)

    cpp <- build_cpp_model_2var()

    # At convergence (checkpoint 500 or final), simple Java lambda should agree
    # with C++ maxent_fit() (goodAlpha loop) to within 1e-5 tolerance.
    final_row <- traj[traj$iteration == max(traj$iteration), ]
    expect_equal(final_row$lambda_0[1], cpp$fit$lambdas[[1]],
                 tolerance = 1e-5,
                 label = "simple Java final lambda_0",
                 expected.label = "C++ maxent_fit final lambda_0 (same algorithm)")
    expect_equal(final_row$lambda_1[1], cpp$fit$lambdas[[2]],
                 tolerance = 1e-5,
                 label = "simple Java final lambda_1",
                 expected.label = "C++ maxent_fit final lambda_1 (same algorithm)")
})

# ===========================================================================
# Helpers: build and run C++ sequential_fit on the asym fixture with L+Q / L+Q+P
# ===========================================================================

.run_cpp_asym_lq_trajectory <- function() {
    d <- asym_fixture()

    feat <- maxent_generate_features(
        list(bio1 = d$bio1, bio2 = d$bio2),
        types        = c("linear", "quadratic"),
        n_thresholds = 0L,
        n_hinges     = 0L
    )
    fs <- maxent_featured_space(d$n, d$sample_idx, feat)

    maxent_sequential_fit(
        fs,
        max_iter                  = 500L,
        convergence               = 0.0,
        beta_multiplier           = 0.8,
        min_deviation             = 0.001,
        disable_convergence_test  = TRUE,
        trajectory_iterations     = c(1L, 2L, 3L, 5L, 10L, 20L, 50L, 100L, 200L, 500L)
    )$trajectory
}

.run_cpp_asym_lqp_trajectory <- function() {
    d <- asym_fixture()

    feat <- maxent_generate_features(
        list(bio1 = d$bio1, bio2 = d$bio2),
        types        = c("linear", "quadratic", "product"),
        n_thresholds = 0L,
        n_hinges     = 0L
    )
    fs <- maxent_featured_space(d$n, d$sample_idx, feat)

    maxent_sequential_fit(
        fs,
        max_iter                  = 500L,
        convergence               = 0.0,
        beta_multiplier           = 1.6,
        min_deviation             = 0.001,
        disable_convergence_test  = TRUE,
        trajectory_iterations     = c(1L, 2L, 3L, 5L, 10L, 20L, 50L, 100L, 200L, 500L)
    )$trajectory
}

# ===========================================================================
# Group G — Phase D: C++ Sequential L+Q trajectory vs. committed golden
# ===========================================================================

test_that("Group G: C++ L+Q trajectory row count matches golden (asym fixture)", {
    skip_if_not_installed("maxentcpp")

    traj   <- .run_cpp_asym_lq_trajectory()
    golden <- asym_java_golden_lq()

    expect_equal(nrow(traj), nrow(golden),
                 label = "number of captured L+Q checkpoints")
})

test_that("Group G: C++ L+Q iteration labels match golden (asym fixture)", {
    skip_if_not_installed("maxentcpp")

    traj   <- .run_cpp_asym_lq_trajectory()
    golden <- asym_java_golden_lq()

    expect_equal(traj$iteration, golden$iteration,
                 label = "L+Q checkpoint iteration numbers")
})

test_that("Group G: C++ L+Q loss trajectory matches golden to 1e-6 (asym fixture)", {
    skip_if_not_installed("maxentcpp")

    traj   <- .run_cpp_asym_lq_trajectory()
    golden <- asym_java_golden_lq()

    expect_equal(traj$loss, golden$loss,
                 tolerance = 1e-6,
                 label = "C++ L+Q loss trajectory",
                 expected.label = "Phase D golden loss (L+Q)")
})

test_that("Group G: C++ L+Q entropy trajectory matches golden to 1e-6 (asym fixture)", {
    skip_if_not_installed("maxentcpp")

    traj   <- .run_cpp_asym_lq_trajectory()
    golden <- asym_java_golden_lq()

    expect_equal(traj$entropy, golden$entropy,
                 tolerance = 1e-6,
                 label = "C++ L+Q entropy trajectory",
                 expected.label = "Phase D golden entropy (L+Q)")
})

test_that("Group G: C++ L+Q lambda trajectories match golden to 1e-6 (asym fixture)", {
    skip_if_not_installed("maxentcpp")

    traj   <- .run_cpp_asym_lq_trajectory()
    golden <- asym_java_golden_lq()

    worst <- max(
        abs(traj$lambda_0 - golden$lambda_0),
        abs(traj$lambda_1 - golden$lambda_1),
        abs(traj$lambda_2 - golden$lambda_2),
        abs(traj$lambda_3 - golden$lambda_3)
    )
    expect_lt(worst, 1e-6,
              label = "worst ||delta_lambda||_inf across all L+Q checkpoints")
})

# ===========================================================================
# Group H — Phase D: C++ Sequential L+Q+P trajectory vs. committed golden
# ===========================================================================

test_that("Group H: C++ L+Q+P trajectory row count matches golden (asym fixture)", {
    skip_if_not_installed("maxentcpp")

    traj   <- .run_cpp_asym_lqp_trajectory()
    golden <- asym_java_golden_lqp()

    expect_equal(nrow(traj), nrow(golden),
                 label = "number of captured L+Q+P checkpoints")
})

test_that("Group H: C++ L+Q+P iteration labels match golden (asym fixture)", {
    skip_if_not_installed("maxentcpp")

    traj   <- .run_cpp_asym_lqp_trajectory()
    golden <- asym_java_golden_lqp()

    expect_equal(traj$iteration, golden$iteration,
                 label = "L+Q+P checkpoint iteration numbers")
})

test_that("Group H: C++ L+Q+P loss trajectory matches golden to 1e-6 (asym fixture)", {
    skip_if_not_installed("maxentcpp")

    traj   <- .run_cpp_asym_lqp_trajectory()
    golden <- asym_java_golden_lqp()

    expect_equal(traj$loss, golden$loss,
                 tolerance = 1e-6,
                 label = "C++ L+Q+P loss trajectory",
                 expected.label = "Phase D golden loss (L+Q+P)")
})

test_that("Group H: C++ L+Q+P entropy trajectory matches golden to 1e-6 (asym fixture)", {
    skip_if_not_installed("maxentcpp")

    traj   <- .run_cpp_asym_lqp_trajectory()
    golden <- asym_java_golden_lqp()

    expect_equal(traj$entropy, golden$entropy,
                 tolerance = 1e-6,
                 label = "C++ L+Q+P entropy trajectory",
                 expected.label = "Phase D golden entropy (L+Q+P)")
})

test_that("Group H: C++ L+Q+P lambda trajectories match golden to 1e-6 (asym fixture)", {
    skip_if_not_installed("maxentcpp")

    traj   <- .run_cpp_asym_lqp_trajectory()
    golden <- asym_java_golden_lqp()

    worst <- max(
        abs(traj$lambda_0 - golden$lambda_0),
        abs(traj$lambda_1 - golden$lambda_1),
        abs(traj$lambda_2 - golden$lambda_2),
        abs(traj$lambda_3 - golden$lambda_3),
        abs(traj$lambda_4 - golden$lambda_4)
    )
    expect_lt(worst, 1e-6,
              label = "worst ||delta_lambda||_inf across all L+Q+P checkpoints")
})

# ===========================================================================
# Group I — Phase D: simplified Java L+Q / L+Q+P trajectory self-consistency
# (Requires rJava)
# ===========================================================================

test_that("Group I: simplified Java L+Q trajectory has correct checkpoints", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    checkpoints <- c(1L, 2L, 3L, 5L, 10L, 20L, 50L, 100L, 200L, 500L)
    traj <- build_java_trajectory_asym_lq(checkpoints)

    expect_equal(nrow(traj), length(checkpoints),
                 label = "number of Java L+Q trajectory rows")
    expect_equal(traj$iteration, checkpoints,
                 label = "Java L+Q trajectory iteration labels")
})

test_that("Group I: simplified Java L+Q trajectory loss is non-increasing", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    traj <- build_java_trajectory_asym_lq()

    diffs <- diff(traj$loss)
    expect_true(all(diffs <= 1e-9),
                label = "simplified Java L+Q loss non-increasing at every checkpoint")
})

test_that("Group I: simplified Java L+Q trajectory entropy is non-negative", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    traj <- build_java_trajectory_asym_lq()

    expect_true(all(traj$entropy >= 0),
                label = "simplified Java L+Q entropy >= 0 at every checkpoint")
})

test_that("Group I: simplified Java L+Q trajectory lambdas are finite", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    traj <- build_java_trajectory_asym_lq()

    expect_true(all(is.finite(traj$lambda_0)), label = "Java L+Q lambda_0 finite")
    expect_true(all(is.finite(traj$lambda_1)), label = "Java L+Q lambda_1 finite")
    expect_true(all(is.finite(traj$lambda_2)), label = "Java L+Q lambda_2 finite")
    expect_true(all(is.finite(traj$lambda_3)), label = "Java L+Q lambda_3 finite")
})

test_that("Group I: simplified Java L+Q+P trajectory has correct checkpoints", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    checkpoints <- c(1L, 2L, 3L, 5L, 10L, 20L, 50L, 100L, 200L, 500L)
    traj <- build_java_trajectory_asym_lqp(checkpoints)

    expect_equal(nrow(traj), length(checkpoints),
                 label = "number of Java L+Q+P trajectory rows")
    expect_equal(traj$iteration, checkpoints,
                 label = "Java L+Q+P trajectory iteration labels")
})

test_that("Group I: simplified Java L+Q+P trajectory loss is non-increasing", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    traj <- build_java_trajectory_asym_lqp()

    diffs <- diff(traj$loss)
    expect_true(all(diffs <= 1e-9),
                label = "simplified Java L+Q+P loss non-increasing at every checkpoint")
})

test_that("Group I: simplified Java L+Q+P trajectory entropy is non-negative", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    traj <- build_java_trajectory_asym_lqp()

    expect_true(all(traj$entropy >= 0),
                label = "simplified Java L+Q+P entropy >= 0 at every checkpoint")
})

test_that("Group I: simplified Java L+Q+P trajectory lambdas are finite", {
    skip_if_not_installed("maxentcpp")
    skip_if_no_java()

    traj <- build_java_trajectory_asym_lqp()

    expect_true(all(is.finite(traj$lambda_0)), label = "Java L+Q+P lambda_0 finite")
    expect_true(all(is.finite(traj$lambda_1)), label = "Java L+Q+P lambda_1 finite")
    expect_true(all(is.finite(traj$lambda_2)), label = "Java L+Q+P lambda_2 finite")
    expect_true(all(is.finite(traj$lambda_3)), label = "Java L+Q+P lambda_3 finite")
    expect_true(all(is.finite(traj$lambda_4)), label = "Java L+Q+P lambda_4 finite")
})
