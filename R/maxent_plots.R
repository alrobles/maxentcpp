# ---- Stage 3: Response Curve PNG Writer -------------------------------------

#' Write Response Curve PNGs for All Variables
#'
#' Generates response curve plots for each environmental variable and saves
#' them as PNG files, replicating \code{density/ResponsePlot.java::makeplot()}.
#' A full-size PNG and an optional thumbnail are written for every variable.
#'
#' @param model         External pointer to a trained FeaturedSpace object.
#' @param env_grids     List of external pointers to Grid<float> objects.
#' @param feature_names Character vector of environment variable names
#'   (one entry per element of \code{env_grids}).
#' @param output_dir    Character: directory under which a \code{plots/}
#'   sub-directory will be created.
#' @param species       Character: species name (used in file names).
#' @param var_indices   Integer vector of 0-based variable indices to plot.
#'   Defaults to all variables.
#' @param n_steps       Integer: number of steps in each curve (default 100).
#' @param thumbnail     Logical: also write a 210 × 140 pixel thumbnail PNG
#'   (default \code{TRUE}).
#' @param write_dat     Logical: also write a tab-delimited \code{.dat} file
#'   of the curve data (default \code{FALSE}).
#' @return Invisibly returns a named list of file paths written.
#' @export
#' @examples
#' \dontrun{
#' maxent_plot_response_curves(
#'   model, list(g1, g2), c("bio1", "bio12"),
#'   output_dir = tempdir(), species = "Sp1")
#' }
maxent_plot_response_curves <- function(model, env_grids, feature_names,
                                        output_dir, species,
                                        var_indices = NULL,
                                        n_steps     = 100L,
                                        thumbnail   = TRUE,
                                        write_dat   = FALSE) {
    feature_names <- as.character(feature_names)
    n_vars <- length(feature_names)

    if (is.null(var_indices)) {
        var_indices <- seq_len(n_vars) - 1L   # 0-based
    }
    var_indices <- as.integer(var_indices)

    plots_dir <- file.path(output_dir, "plots")
    if (!dir.exists(plots_dir)) dir.create(plots_dir, recursive = TRUE)

    file_list <- list()

    for (vi in var_indices) {
        var_name <- feature_names[vi + 1L]
        curve    <- maxent_response_curve(model, env_grids, feature_names,
                                          var_index = vi,
                                          n_steps   = as.integer(n_steps))

        # Full-size plot
        full_path <- file.path(plots_dir,
                               paste0(species, "_", var_name, ".png"))
        grDevices::png(full_path, width = 600L, height = 400L)
        oldpar <- graphics::par(mar = c(4, 4, 2, 1))
        graphics::plot(curve$value, curve$prediction,
                       type = "l", lwd = 2L, col = "#1B7837",
                       xlab = var_name,
                       ylab = "Cloglog prediction",
                       main = paste("Response curve:", var_name),
                       ylim = c(0, 1))
        graphics::par(oldpar)
        grDevices::dev.off()
        file_list[[paste0(var_name, "_full")]] <- full_path

        # Thumbnail
        if (thumbnail) {
            thumb_path <- file.path(plots_dir,
                                    paste0(species, "_", var_name, "_thumb.png"))
            grDevices::png(thumb_path, width = 210L, height = 140L)
            oldpar_th <- graphics::par(mar = c(2, 2, 1, 0.5))
            graphics::plot(curve$value, curve$prediction,
                           type = "l", lwd = 1L, col = "#1B7837",
                           xlab = "", ylab = "",
                           main = var_name, cex.main = 0.75,
                           ylim = c(0, 1))
            graphics::par(oldpar_th)
            grDevices::dev.off()
            file_list[[paste0(var_name, "_thumb")]] <- thumb_path
        }

        # Optional .dat file
        if (write_dat) {
            dat_path <- file.path(plots_dir,
                                  paste0(species, "_", var_name, ".dat"))
            utils::write.table(curve, dat_path, sep = "\t",
                               row.names = FALSE, quote = FALSE)
            file_list[[paste0(var_name, "_dat")]] <- dat_path
        }
    }

    invisible(file_list)
}


# ---- Stage 4: Variable Importance Bar Chart ---------------------------------

#' Write a Variable Importance Bar Chart PNG
#'
#' Creates a horizontal bar chart comparing percent contribution and
#' permutation importance for each environmental variable, replicating
#' \code{density/Runner.java::makeJackknifePlots()}.
#'
#' @param contributions_df A data.frame with columns \code{name} and
#'   \code{contribution} (from \code{\link{maxent_percent_contribution}}).
#' @param perm_imp_df      A data.frame with columns \code{name} and
#'   \code{permutation_importance} (from
#'   \code{\link{maxent_permutation_importance}}).
#' @param species          Character: species name (used in the filename).
#' @param output_dir       Character: directory under which a \code{plots/}
#'   sub-directory will be created.
#' @return Invisibly returns the path to the PNG file.
#' @export
#' @examples
#' \dontrun{
#' maxent_plot_variable_importance(contrib, perm_imp,
#'   species = "Sp1", output_dir = tempdir())
#' }
maxent_plot_variable_importance <- function(contributions_df, perm_imp_df,
                                            species, output_dir) {
    plots_dir <- file.path(output_dir, "plots")
    if (!dir.exists(plots_dir)) dir.create(plots_dir, recursive = TRUE)

    # Merge by name and sort by contribution (descending)
    merged <- merge(contributions_df, perm_imp_df, by = "name", all = TRUE)
    merged[is.na(merged)] <- 0
    merged <- merged[order(merged$contribution, decreasing = FALSE), ]

    n_vars <- nrow(merged)
    png_path <- file.path(plots_dir, paste0(species, "_varimp.png"))

    fig_height <- max(300L, 60L * n_vars + 100L)
    grDevices::png(png_path, width = 600L, height = fig_height)
    oldpar <- graphics::par(mar = c(4, max(nchar(merged$name)) * 0.55, 3, 1))
    on.exit({graphics::par(oldpar); grDevices::dev.off()}, add = TRUE)

    bar_mat <- rbind(merged$contribution,
                     merged$permutation_importance)
    colnames(bar_mat) <- merged$name

    graphics::barplot(bar_mat,
                      beside    = TRUE,
                      horiz     = TRUE,
                      las       = 1,
                      col       = c("#2166AC", "#D6604D"),
                      border    = NA,
                      xlab      = "Percent (%)",
                      main      = paste("Variable importance:", species),
                      xlim      = c(0, 100),
                      names.arg = merged$name,
                      legend.text = c("Percent contribution",
                                      "Permutation importance"),
                      args.legend = list(x = "bottomright",
                                         bty = "n",
                                         cex = 0.8))
    invisible(png_path)
}
