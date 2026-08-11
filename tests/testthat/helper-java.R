# Helper functions for Java numerical equivalency tests.
#
# These helpers are silently skipped when rJava is not installed or the
# JAR has not been compiled.  All other testthat test files are unaffected.

# ---------------------------------------------------------------------------
# JAR location and JVM initialisation
# ---------------------------------------------------------------------------

.java_jar_path <- function() {
    system.file("java", "maxent_mini.jar", package = "maxentcpp")
}

# Called once (idempotent) to start the JVM and load the JAR.
.init_jvm <- local({
    done <- FALSE
    function() {
        if (done) return(invisible(NULL))
        if (!requireNamespace("rJava", quietly = TRUE))
            stop("rJava not available")
        jar <- .java_jar_path()
        if (!file.exists(jar))
            stop("maxent_mini.jar not found; run `cd java && ./build.sh`")
        rJava::.jinit()
        rJava::.jaddClassPath(jar)
        done <<- TRUE
        invisible(NULL)
    }
})

# Skip helpers for Groups B / C / D.
skip_if_no_java <- function() {
    skip_if_not_installed("rJava")
    skip_if(
        !file.exists(.java_jar_path()),
        "maxent_mini.jar not compiled; run `cd java && ./build.sh`"
    )
}

# ---------------------------------------------------------------------------
# Canonical datasets
# ---------------------------------------------------------------------------

# Tiny 1-variable dataset (9 background + presence flags).
# Matches make_tiny_model() used in other test files.
tiny_1var_data <- function() {
    vals  <- seq(0, 1, length.out = 9L)
    flags <- c(0L, 0L, 1L, 0L, 0L, 1L, 0L, 0L, 1L)   # 1 at 1-based R indices 3,6,9 (0-based: 2,5,8)
    list(
        env    = vals,
        flags  = flags,
        n      = 9L,
        idx0   = c(2L, 5L, 8L)          # 0-based sample indices
    )
}

# Two-variable dataset from inst/extdata/test_data.csv (70 points).
# Returns NULL (and emits a skip) when the file is not found.
twovar_data <- function() {
    csv_path <- system.file("extdata", "test_data.csv", package = "maxentcpp")
    if (!nzchar(csv_path) || !file.exists(csv_path))
        testthat::skip("test_data.csv not found in inst/extdata/")

    df  <- read.csv(csv_path)
    idx <- which(df$species == 1L) - 1L   # 0-based presence indices

    list(
        bio1   = df$bio1,
        bio12  = df$bio12,
        flags  = as.integer(df$species),
        n      = nrow(df),
        idx0   = as.integer(idx)
    )
}

# ---------------------------------------------------------------------------
# C++ model builders
# ---------------------------------------------------------------------------

# Build and train a C++ model using bio1 from test_data.csv.
build_cpp_model_1var <- function() {
    d <- twovar_data()
    feat <- maxent_generate_features(
        list(bio1 = d$bio1),
        types        = "linear",
        n_thresholds = 0L,
        n_hinges     = 0L
    )
    model      <- maxent_featured_space(d$n, d$idx0, feat)
    fit_result <- maxent_fit(model,
                             max_iter        = 500L,
                             convergence     = 1e-5,
                             beta_multiplier = 1.0,
                             min_deviation   = 0.001)
    list(model = model, fit = fit_result, features = feat, data = d)
}

# Build and train a C++ model using bio1 + bio12 from test_data.csv.
build_cpp_model_2var <- function() {
    d <- twovar_data()
    feat <- maxent_generate_features(
        list(bio1 = d$bio1, bio12 = d$bio12),
        types        = "linear",
        n_thresholds = 0L,
        n_hinges     = 0L
    )
    model      <- maxent_featured_space(d$n, d$idx0, feat)
    fit_result <- maxent_fit(model,
                             max_iter        = 500L,
                             convergence     = 1e-5,
                             beta_multiplier = 1.0,
                             min_deviation   = 0.001)
    list(model = model, fit = fit_result, features = feat, data = d)
}

# Compute Java-compatible raw scores for all training points of a C++ model.
# Returns a numeric vector of length n, each value in [0, 1].
cpp_raw_scores <- function(cpp_result) {
    model    <- cpp_result$model
    features <- cpp_result$features
    n        <- cpp_result$data$n
    info     <- maxent_space_info(model)

    # Build pre-evaluated feature matrix (n × num_features)
    nf   <- length(features)
    fmat <- matrix(0.0, nrow = n, ncol = nf)
    for (j in seq_len(nf)) {
        for (i in seq_len(n)) {
            fmat[i, j] <- maxent_feature_eval(features[[j]], i)
        }
    }

    unnorm <- maxent_predict_model(model, fmat)           # exp(lp - lpNorm)
    raw    <- unnorm / info$density_normalizer            # divide by Z
    pmin(raw, 1.0)                                        # cap at 1
}

# ---------------------------------------------------------------------------
# Java model builders
# ---------------------------------------------------------------------------

# Train a 1-variable Java model on bio1 from test_data.csv.
# Returns a named list mirroring the C++ model's information.
build_java_model_1var <- function() {
    .init_jvm()
    d <- twovar_data()

    j_out <- rJava::.jcall(
        "MaxentJavaRunner", "[D", "trainLinear1Var",
        rJava::.jarray(as.double(d$bio1)),
        rJava::.jarray(as.integer(d$flags)),
        500L, 1e-5, 1.0, 0.001
    )
    result <- if (is.numeric(j_out)) j_out else rJava::.jevalArray(j_out)

    n <- d$n
    list(
        lambda             = result[1],
        entropy            = result[2],
        density_normalizer = result[3],
        lp_normalizer      = result[4],
        loss               = result[5],
        raw_scores         = result[seq(6, 5 + n)]
    )
}

# Train a 2-variable Java model on bio1 + bio12 from test_data.csv.
build_java_model_2var <- function() {
    .init_jvm()
    d <- twovar_data()

    j_out <- rJava::.jcall(
        "MaxentJavaRunner", "[D", "trainLinear2Var",
        rJava::.jarray(as.double(d$bio1)),
        rJava::.jarray(as.double(d$bio12)),
        rJava::.jarray(as.integer(d$flags)),
        500L, 1e-5, 1.0, 0.001
    )
    result <- if (is.numeric(j_out)) j_out else rJava::.jevalArray(j_out)

    n <- d$n
    list(
        lambda1            = result[1],
        lambda2            = result[2],
        entropy            = result[3],
        density_normalizer = result[4],
        lp_normalizer      = result[5],
        loss               = result[6],
        raw_scores         = result[seq(7, 6 + n)]
    )
}

# ---------------------------------------------------------------------------
# Java trajectory builders (Phase B)
# ---------------------------------------------------------------------------

# Parse the flat double[] returned by trainLinear*VarTrajectory into a
# data.frame with columns (iteration, loss, entropy, lambda_0, [lambda_1, ...]).
#
# The return layout (from Sequential.runWithTrajectory) is:
#   result[1]                     = K (number of captured checkpoints)
#   For each k = 1..K, row width = 3 + nf:
#     result[1 + (k-1)*(3+nf) + 1] = 1-based iteration
#     result[1 + (k-1)*(3+nf) + 2] = loss
#     result[1 + (k-1)*(3+nf) + 3] = entropy
#     result[1 + (k-1)*(3+nf) + 4 .. 3+nf] = lambda values (one per feature)
.parse_trajectory <- function(result, nf) {
    raw <- if (is.numeric(result)) result else rJava::.jevalArray(result)
    K   <- as.integer(raw[1])
    if (K == 0L) {
        return(data.frame(
            iteration = integer(0), loss = double(0), entropy = double(0)))
    }
    rw  <- 3L + nf
    df  <- data.frame(
        iteration = integer(K),
        loss      = double(K),
        entropy   = double(K)
    )
    lam_cols <- setNames(
        replicate(nf, double(K), simplify = FALSE),
        paste0("lambda_", seq_len(nf) - 1L)
    )
    for (k in seq_len(K)) {
        base <- 1L + (k - 1L) * rw    # 1-based R index into raw[]
        df$iteration[k] <- as.integer(raw[base + 1L])
        df$loss[k]      <- raw[base + 2L]
        df$entropy[k]   <- raw[base + 3L]
        for (j in seq_len(nf)) {
            lam_cols[[j]][k] <- raw[base + 3L + j]
        }
    }
    cbind(df, as.data.frame(lam_cols))
}

# Capture the simple-Java-Sequential trajectory for a 1-variable model on
# bio1 from test_data.csv.  Returns a data.frame with columns:
#   iteration, loss, entropy, lambda_0
#
# convergence=0.0 is used so that the optimizer runs to max_iter
# deterministically, ensuring all checkpoint rows are captured.
build_java_trajectory_1var <- function(
        checkpoints = c(1L, 2L, 3L, 5L, 10L, 20L, 50L, 100L, 200L, 500L)) {
    .init_jvm()
    d <- twovar_data()

    j_out <- rJava::.jcall(
        "MaxentJavaRunner", "[D", "trainLinear1VarTrajectory",
        rJava::.jarray(as.double(d$bio1)),
        rJava::.jarray(as.integer(d$flags)),
        500L, 0.0, 1.0, 0.001,
        rJava::.jarray(as.integer(checkpoints))
    )
    .parse_trajectory(j_out, nf = 1L)
}

# Capture the simple-Java-Sequential trajectory for a 2-variable model on
# bio1 + bio12 from test_data.csv.  Returns a data.frame with columns:
#   iteration, loss, entropy, lambda_0, lambda_1
#
# convergence=0.0 is used so that the optimizer runs to max_iter
# deterministically, ensuring all checkpoint rows are captured.
build_java_trajectory_2var <- function(
        checkpoints = c(1L, 2L, 3L, 5L, 10L, 20L, 50L, 100L, 200L, 500L)) {
    .init_jvm()
    d <- twovar_data()

    j_out <- rJava::.jcall(
        "MaxentJavaRunner", "[D", "trainLinear2VarTrajectory",
        rJava::.jarray(as.double(d$bio1)),
        rJava::.jarray(as.double(d$bio12)),
        rJava::.jarray(as.integer(d$flags)),
        500L, 0.0, 1.0, 0.001,
        rJava::.jarray(as.integer(checkpoints))
    )
    .parse_trajectory(j_out, nf = 2L)
}

# ---------------------------------------------------------------------------
# Asymmetric fixture (Phase B)
# ---------------------------------------------------------------------------

# The 10x10 asymmetric fixture used by the C++ test_sequential.cpp golden.
# bio1[r][c] = 10 + c + 2*r  (scaled to [0,1])
# bio2[r][c] = 100 + 50*c + 10*r  (scaled to [0,1])
# 10 occurrences clustered in the bottom-right quadrant.
asym_fixture <- function() {
    nrows <- 10L; ncols <- 10L
    n     <- nrows * ncols

    # Build row-major (C-order) vectors to match the C++ FeaturedSpace
    # layout: index = row * ncols + col.
    bio1_raw <- numeric(n)
    bio2_raw <- numeric(n)
    for (r in seq_len(nrows) - 1L) {
        for (c in seq_len(ncols) - 1L) {
            idx <- r * ncols + c + 1L  # 1-based R index
            bio1_raw[idx] <- 10 + c + 2 * r          # range 10..37
            bio2_raw[idx] <- 100 + 50 * c + 10 * r   # range 100..640
        }
    }

    prescale <- function(v) {
        mn <- min(v); mx <- max(v)
        if (mx == mn) v else (v - mn) / (mx - mn)
    }
    bio1 <- prescale(bio1_raw)
    bio2 <- prescale(bio2_raw)

    # 0-based sample indices (row-major: idx = row * ncols + col)
    sample_idx <- c(
        6L * ncols + 8L,   # lon=8.5 lat=3.5
        7L * ncols + 7L,   # lon=7.5 lat=2.5
        7L * ncols + 8L,   # lon=8.5 lat=2.5
        7L * ncols + 9L,   # lon=9.5 lat=2.5
        8L * ncols + 7L,   # lon=7.5 lat=1.5
        8L * ncols + 8L,   # lon=8.5 lat=1.5
        8L * ncols + 9L,   # lon=9.5 lat=1.5
        9L * ncols + 7L,   # lon=7.5 lat=0.5
        9L * ncols + 8L,   # lon=8.5 lat=0.5
        9L * ncols + 9L    # lon=9.5 lat=0.5
    )

    list(
        bio1       = bio1,
        bio2       = bio2,
        n          = nrows * ncols,
        sample_idx = sample_idx
    )
}

# Committed Phase D golden: trajectory of the full Java Sequential optimizer
# on the asymmetric fixture with linear + quadratic features (L+Q, 4 features).
# Values are from inst/extdata/golden/asym/trajectory_java_lq.csv.
# beta_multiplier = 0.8 (Runner.java schedule for n=10, quadratic=true).
asym_java_golden_lq <- function() {
    path <- system.file("extdata", "golden", "asym", "trajectory_java_lq.csv",
                        package = "maxentcpp")
    if (nzchar(path) && file.exists(path)) {
        return(read.csv(path))
    }
    # Fallback: inline values identical to kJavaGolden in test_sequential_lq.cpp.
    data.frame(
        iteration = c(1L, 2L, 3L, 5L, 10L, 20L, 50L, 100L, 200L, 500L),
        loss      = c(4.5421182033281940, 4.4821067643752470, 4.4247504414752160,
                      4.3158369946915425, 4.0820758340185614, 3.2325401364872697,
                      3.1617709439417760, 3.1197924344039323, 3.1197924344039314,
                      3.1197924344039314),
        entropy   = c(4.6042914838480070, 4.6027068726461810, 4.5998290427816150,
                      4.5903933898033730, 4.5483808348650310, 3.1735804811921800,
                      3.1469676964979194, 3.1197924344050634, 3.1197924344039296,
                      3.1197924344039296),
        lambda_0  = c(0.0, 0.0, 0.0, 0.0, 0.0, 0.1840686396557502,
                      1.6527633458811182, 6.0624645573901740, 6.0624645574787560,
                      6.0624645574787560),
        lambda_1  = c(0.0, 0.1440826808525652, 0.2848388206506464,
                      0.4199891999959157, 0.7973445741951862, 3.8763474799751347,
                      2.6166075278309027, 0.0, 0.0, 0.0),
        lambda_2  = c(0.0, 0.0, 0.0, 0.0, 0.0, 0.1918902211537277,
                      4.4453724246267360, 4.1317372609637160, 4.1317372608782830,
                      4.1317372608782830),
        lambda_3  = c(0.1485486498637492, 0.1485486498637492, 0.1485486498637492,
                      0.2883496256734949, 0.5470248844025938, 2.4854448484169174,
                      0.0, 0.0, 0.0, 0.0)
    )
}

# Committed Phase D golden: trajectory of the full Java Sequential optimizer
# on the asymmetric fixture with linear + quadratic + product features
# (L+Q+P, 5 features).
# Values are from inst/extdata/golden/asym/trajectory_java_lqp.csv.
# beta_multiplier = 1.6 (Runner.java schedule for n=10, product=true).
asym_java_golden_lqp <- function() {
    path <- system.file("extdata", "golden", "asym", "trajectory_java_lqp.csv",
                        package = "maxentcpp")
    if (nzchar(path) && file.exists(path)) {
        return(read.csv(path))
    }
    # Fallback: inline values identical to kJavaGolden in test_sequential_lqp.cpp.
    data.frame(
        iteration = c(1L, 2L, 3L, 5L, 10L, 20L, 50L, 100L, 200L, 500L),
        loss      = c(4.5445471190472690, 4.4864626474063850, 4.4308592054085090,
                      4.3268492682186140, 4.1056844205583840, 3.3687650148865110,
                      3.3161976479591400, 3.3156340906479533, 3.3156340906479533,
                      3.3156340906479533),
        entropy   = c(4.6045625322128485, 4.6027457807404190, 4.5997345788713020,
                      4.5902214481545150, 4.5477752860752190, 3.3074182965897080,
                      3.3152035092852740, 3.3156340904802220, 3.3156340904802220,
                      3.3156340904802220),
        lambda_0  = c(0.0, 0.0, 0.0, 0.0, 0.0, 0.2871495803078118,
                      5.6095976837979840, 5.3733744303312730, 5.3733744303312730,
                      5.3733744303312730),
        lambda_1  = c(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
        lambda_2  = c(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.4527918072852968,
                      3.6925604260961236, 3.6925604260961236, 3.6925604260961236),
        lambda_3  = c(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
        lambda_4  = c(0.1445946125260754, 0.2859648790693891, 0.4241384982541208,
                      0.6910226500687243, 1.3048083334902638, 5.7652180937050250,
                      0.0, 0.0, 0.0, 0.0)
    )
}

# Capture the simplified-Java-Sequential trajectory for the asymmetric
# 10x10 fixture with linear + quadratic features (L+Q, 4 features).
# Returns a data.frame with columns:
#   iteration, loss, entropy, lambda_0, lambda_1, lambda_2, lambda_3
#
# Note: the simplified Java optimizer (goodAlpha / reduceAlpha loop) produces
# a different trajectory from the full Java Sequential (density/Sequential.java).
# These trajectory values are only comparable with themselves, not with the
# golden CSV files produced by the full optimizer.
build_java_trajectory_asym_lq <- function(
        checkpoints = c(1L, 2L, 3L, 5L, 10L, 20L, 50L, 100L, 200L, 500L)) {
    .init_jvm()

    j_out <- rJava::.jcall(
        "MaxentJavaRunner", "[D", "trainAsymLQTrajectory",
        rJava::.jarray(as.integer(checkpoints))
    )
    .parse_trajectory(j_out, nf = 4L)
}

# Capture the simplified-Java-Sequential trajectory for the asymmetric
# 10x10 fixture with linear + quadratic + product features (L+Q+P, 5 features).
# Returns a data.frame with columns:
#   iteration, loss, entropy, lambda_0, lambda_1, lambda_2, lambda_3, lambda_4
#
# Note: the simplified Java optimizer (goodAlpha / reduceAlpha loop) produces
# a different trajectory from the full Java Sequential (density/Sequential.java).
# These trajectory values are only comparable with themselves, not with the
# golden CSV files produced by the full optimizer.
build_java_trajectory_asym_lqp <- function(
        checkpoints = c(1L, 2L, 3L, 5L, 10L, 20L, 50L, 100L, 200L, 500L)) {
    .init_jvm()

    j_out <- rJava::.jcall(
        "MaxentJavaRunner", "[D", "trainAsymLQPTrajectory",
        rJava::.jarray(as.integer(checkpoints))
    )
    .parse_trajectory(j_out, nf = 5L)
}

# Committed Phase B golden: trajectory of the full Java Sequential optimizer
# on the asymmetric fixture.  Values are embedded from
# inst/extdata/golden/asym/trajectory_java.csv and the C++ test
# test_sequential.cpp (kJavaGolden array).
asym_java_golden <- function() {
    path <- system.file("extdata", "golden", "asym", "trajectory_java.csv",
                        package = "maxentcpp")
    if (nzchar(path) && file.exists(path)) {
        return(read.csv(path))
    }
    # Fallback: inline values identical to kJavaGolden in test_sequential.cpp.
    data.frame(
        iteration = c(  1L,   2L,   3L,   5L,   10L,    20L,     50L,    100L,    200L,    500L),
        loss      = c(4.5534670404943647, 4.5044834711287370, 4.4580810114815135,
                      4.3720945694427646, 4.1835670471368118, 3.2037850143863942,
                      3.1709389711531495, 3.1709389280031175, 3.1709389280031170,
                      3.1709389280031170),
        entropy   = c(4.6043911168777019, 4.6021307223743895, 4.5985044305670746,
                      4.5902747732142490, 4.5581876611341912, 3.4675596532919681,
                      3.1705613150634631, 3.1709389276298126, 3.1709389281312537,
                      3.1709389281312537),
        lambda_0  = c(0.0000000000000000, 0.0000000000000000, 0.0000000000000000,
                      0.13045194323897974, 0.50462215463779610, 4.1326468050985640,
                      5.8805050188416480, 5.8795313549995200, 5.8795313516019400,
                      5.8795313516019400),
        lambda_1  = c(0.14557239069988340, 0.28771862438045490, 0.42652212318552490,
                      0.56206675272495440, 0.81416830898974410, 4.1203851942018460,
                      4.0147649660976490, 4.0135187975142200, 4.0135187980476040,
                      4.0135187980476040)
    )
}
