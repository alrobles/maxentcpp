## Helpers reuse the same minimal model builder as test-maxent-outputs.R
.make_plot_test_model <- function() {
    skip_if_not_installed("maxentcpp")
    dim_obj <- maxent_dimension(nrows = 4, ncols = 4, xll = 0, yll = 0,
                                cellsize = 1)
    g0 <- maxent_grid(dim_obj, "env0")
    g1 <- maxent_grid(dim_obj, "env1")
    idx <- 0L
    for (r in 0:3) {
        for (cc in 0:3) {
            grid_set_value(g0, r, cc, idx / 15.0)
            grid_set_value(g1, r, cc, 1.0 - idx / 15.0)
            idx <- idx + 1L
        }
    }
    vals0 <- sapply(0:15, function(i) i / 15.0)
    vals1 <- 1.0 - vals0
    features <- maxent_generate_features(
        list(env0 = vals0, env1 = vals1),
        types = "linear", n_thresholds = 0, n_hinges = 0)
    pres_idx <- 12:15
    model    <- maxent_featured_space(16L, as.integer(pres_idx), features)
    maxent_fit(model, max_iter = 200, convergence = 1e-4,
               beta_multiplier = 1.0)
    pres_rows <- as.integer(pres_idx %/% 4L)
    pres_cols <- as.integer(pres_idx  %%  4L)
    list(model = model, g0 = g0, g1 = g1,
         pres_rows = pres_rows, pres_cols = pres_cols)
}

## ---- Response Curve PNGs ----------------------------------------------------

test_that("maxent_plot_response_curves creates full and thumbnail PNGs", {
    skip_if_not_installed("maxentcpp")
    m       <- .make_plot_test_model()
    out_dir <- file.path(tempdir(), "test_rc_plots")
    on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

    file_list <- maxent_plot_response_curves(
        m$model, list(m$g0, m$g1), c("env0", "env1"),
        output_dir = out_dir,
        species    = "TestSp",
        thumbnail  = TRUE)

    expect_true(length(file_list) >= 4L)  # 2 full + 2 thumbs

    for (p in unlist(file_list)) {
        expect_true(file.exists(p))
        expect_gt(file.size(p), 0L)
    }
})

test_that("maxent_plot_response_curves thumbnail dimensions are ~210x140", {
    skip_if_not_installed("maxentcpp")
    skip_if_not_installed("png")

    m       <- .make_plot_test_model()
    out_dir <- file.path(tempdir(), "test_rc_thumb_dims")
    on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

    file_list <- maxent_plot_response_curves(
        m$model, list(m$g0, m$g1), c("env0", "env1"),
        output_dir = out_dir,
        species    = "ThumbSp",
        thumbnail  = TRUE)

    thumb_files <- file_list[grepl("_thumb$", names(file_list))]
    if (length(thumb_files) > 0) {
        img <- png::readPNG(thumb_files[[1]])
        # dim is [height, width, channels]
        expect_equal(dim(img)[1], 140L)
        expect_equal(dim(img)[2], 210L)
    }
})

test_that("maxent_plot_response_curves write_dat creates .dat files", {
    skip_if_not_installed("maxentcpp")
    m       <- .make_plot_test_model()
    out_dir <- file.path(tempdir(), "test_rc_dat")
    on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

    file_list <- maxent_plot_response_curves(
        m$model, list(m$g0, m$g1), c("env0", "env1"),
        output_dir = out_dir,
        species    = "DatSp",
        thumbnail  = FALSE,
        write_dat  = TRUE)

    dat_files <- file_list[grepl("_dat$", names(file_list))]
    expect_true(length(dat_files) > 0)
    for (p in unlist(dat_files)) {
        expect_true(file.exists(p))
    }
})

test_that("maxent_plot_response_curves var_indices subset works", {
    skip_if_not_installed("maxentcpp")
    m       <- .make_plot_test_model()
    out_dir <- file.path(tempdir(), "test_rc_subset")
    on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

    file_list <- maxent_plot_response_curves(
        m$model, list(m$g0, m$g1), c("env0", "env1"),
        output_dir  = out_dir,
        species     = "SubSp",
        var_indices = 0L,   # only env0
        thumbnail   = FALSE)

    full_files <- file_list[grepl("_full$", names(file_list))]
    expect_equal(length(full_files), 1L)
})

## ---- Variable Importance Plot -----------------------------------------------

test_that("maxent_plot_variable_importance creates a valid PNG", {
    skip_if_not_installed("maxentcpp")
    m       <- .make_plot_test_model()
    contrib <- maxent_percent_contribution(m$model, c("env0", "env1"))
    perm_ip <- maxent_permutation_importance(
        m$model, list(m$g0, m$g1), c("env0", "env1"),
        m$pres_rows, m$pres_cols,
        c(0L, 1L, 2L), c(0L, 1L, 2L))

    out_dir <- file.path(tempdir(), "test_varimp")
    on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

    png_path <- maxent_plot_variable_importance(contrib, perm_ip,
                                                species    = "VISp",
                                                output_dir = out_dir)
    expect_true(file.exists(png_path))
    expect_gt(file.size(png_path), 0L)
})
