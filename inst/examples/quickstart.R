## maxentcpp Quick-Start Example
##
## Complete end-to-end species distribution modelling workflow using bundled
## example data (bio1 and bio12 cropped layers, Abeillia abeillei occurrence
## records from GBIF).
##
## Run from the package root:
##   Rscript inst/examples/quickstart.R
## or, after installing the package:
##   source(system.file("examples", "quickstart.R", package = "maxentcpp"))

library(maxentcpp)
library(terra)

## ---- 1. Load environmental layers ------------------------------------------

stack_path      <- system.file("extdata", "stack_1_12_crop.rds",
                               package = "maxentcpp")
example_rasters <- terra::unwrap(readRDS(stack_path))
bio1            <- example_rasters[[1]]
bio12           <- example_rasters[[2]]

# Convert to maxentcpp grids
g_bio1  <- maxent_grid_from_terra(bio1)
g_bio12 <- maxent_grid_from_terra(bio12)

cat("Grid info (bio1):\n")
print(maxent_grid_info(g_bio1))

## ---- 2. Prepare occurrence data --------------------------------------------

data(example_occ_df)        # columns: species, long, lat
occ_df <- example_occ_df

# Build a GridDimension that matches the environmental layers
info <- maxent_grid_info(g_bio1)
dim  <- maxent_dimension(nrows    = info$nrows,
                         ncols    = info$ncols,
                         xll      = info$xll,
                         yll      = info$yll,
                         cellsize = info$cellsize)

# Convert lon/lat to grid indices (note column names: "long" / "lat")
occ <- maxent_read_occurrences(occ_df, dim,
                               lon_col = "long",
                               lat_col = "lat")

cat("Number of presence points:", length(occ$indices), "\n")

## ---- 3. Background points --------------------------------------------------

bg <- maxent_background_indices(g_bio1, n = 10000, seed = 42)

cat("Number of background points:", length(bg$indices), "\n")

## ---- 4. Extract environmental values and build features --------------------

all_rows <- c(bg$rows, occ$rows)
all_cols <- c(bg$cols, occ$cols)
n_total  <- length(all_rows)

# Presence samples are appended at the end -> 0-based indices
sample_indices <- seq(length(bg$rows), n_total - 1L)

# grid_get_values_batch is an internal Rcpp helper (not in the public
# maxent_* surface).  Use maxentcpp::: to reach it from this example
# script.
bio1_vals  <- maxentcpp:::grid_get_values_batch(g_bio1,  all_rows, all_cols)
bio12_vals <- maxentcpp:::grid_get_values_batch(g_bio12, all_rows, all_cols)

env_data <- list(bio1 = bio1_vals, bio12 = bio12_vals)

features <- maxent_generate_features(env_data,
                                     types    = c("linear", "quadratic", "hinge"),
                                     n_hinges = 15)
cat("Generated", length(features), "features\n")

## ---- 5. Train the model ----------------------------------------------------

fs     <- maxent_featured_space(n_total, as.integer(sample_indices), features)
result <- maxent_fit(fs,
                     max_iter        = 500,
                     convergence     = 1e-5,
                     beta_multiplier = 1.0)

cat("Converged:", result$converged, "\n")
cat("Final loss:", result$loss,      "\n")
cat("Entropy:",    result$entropy,   "\n")
cat("Iterations:", result$iterations, "\n")

## Save lambdas to a temporary file
lambdas_file <- file.path(tempdir(), "quickstart_model.lambdas")
maxent_save_lambdas(fs, lambdas_file)
cat("Model saved to:", lambdas_file, "\n")

## ---- 6. Project the model --------------------------------------------------

pred_grid   <- maxent_project_cloglog(fs,
                                      list(g_bio1, g_bio12),
                                      c("bio1", "bio12"))
pred_raster <- maxent_grid_to_terra(pred_grid)

cat("Prediction raster extent:\n")
print(terra::ext(pred_raster))

# Save prediction map
out_png <- file.path(tempdir(), "quickstart_prediction.png")
png(out_png, width = 800, height = 600)
terra::plot(pred_raster,
            main = "Predicted Habitat Suitability (cloglog)",
            col  = hcl.colors(50, "YlOrRd", rev = TRUE))
dev.off()
cat("Prediction map saved to:", out_png, "\n")

## ---- 7. Evaluate the model -------------------------------------------------

pres_preds <- maxent_extract_predictions_raw(
    fs, list(g_bio1, g_bio12), c("bio1", "bio12"),
    occ$rows, occ$cols)

bg_preds <- maxent_extract_predictions_raw(
    fs, list(g_bio1, g_bio12), c("bio1", "bio12"),
    bg$rows, bg$cols)

eval_result <- maxent_evaluate(pres_preds, bg_preds)
cat("AUC:",       eval_result$auc,       "\n")
cat("Max Kappa:", eval_result$max_kappa, "\n")
cat("Log-loss:",  eval_result$logloss,   "\n")

## ---- 8. Variable importance ------------------------------------------------

contrib <- maxent_percent_contribution(fs, c("bio1", "bio12"))
cat("\nPercent contribution:\n")
print(contrib)

perm_imp <- maxent_permutation_importance(
    fs, list(g_bio1, g_bio12), c("bio1", "bio12"),
    occ$rows, occ$cols,
    bg$rows,  bg$cols,
    seed = 42)
cat("\nPermutation importance:\n")
print(perm_imp)

## ---- 9. Response curves ----------------------------------------------------

curve_bio1 <- maxent_response_curve(fs,
                                    list(g_bio1, g_bio12),
                                    c("bio1", "bio12"),
                                    var_index = 0L,
                                    n_steps   = 100L)

curve_bio12 <- maxent_response_curve(fs,
                                     list(g_bio1, g_bio12),
                                     c("bio1", "bio12"),
                                     var_index = 1L,
                                     n_steps   = 100L)

# Save response-curve plots
curves_png <- file.path(tempdir(), "quickstart_response_curves.png")
png(curves_png, width = 1000, height = 500)
par(mfrow = c(1, 2))
plot(curve_bio1$value,  curve_bio1$prediction,
     type = "l", lwd = 2,
     xlab = "Annual Mean Temperature (bio1)",
     ylab = "Cloglog Prediction",
     main = "Response Curve: bio1")
plot(curve_bio12$value, curve_bio12$prediction,
     type = "l", lwd = 2,
     xlab = "Annual Precipitation (bio12)",
     ylab = "Cloglog Prediction",
     main = "Response Curve: bio12")
dev.off()
cat("Response curves saved to:", curves_png, "\n")

## ---- 10. MESS analysis -----------------------------------------------------

ref_vals <- list(
    bio1_vals[seq_len(length(bg$rows))],
    bio12_vals[seq_len(length(bg$rows))]
)

mess_result <- maxent_mess(list(g_bio1, g_bio12),
                           ref_vals,
                           c("bio1", "bio12"))
mess_raster <- maxent_grid_to_terra(mess_result$mess_grid)

mess_png <- file.path(tempdir(), "quickstart_mess.png")
png(mess_png, width = 800, height = 600)
terra::plot(mess_raster,
            main = "MESS: Negative = Novel Environment",
            col  = hcl.colors(50, "RdYlGn"))
dev.off()
cat("MESS map saved to:", mess_png, "\n")

## ---- 11. Clamping ----------------------------------------------------------

ranges  <- maxent_variable_ranges(list(g_bio1, g_bio12))
clamped <- maxent_clamp(list(g_bio1, g_bio12),
                        ranges$min, ranges$max)

pred_clamped <- maxent_project_cloglog(fs,
                                       clamped$clamped_grids,
                                       c("bio1", "bio12"))

cat("\nClamped prediction range:",
    range(terra::values(maxent_grid_to_terra(pred_clamped)), na.rm = TRUE),
    "\n")

cat("\nQuick-start workflow complete.\n")
