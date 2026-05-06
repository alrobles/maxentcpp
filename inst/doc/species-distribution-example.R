## ----setup, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = FALSE
)


## ----load-terra---------------------------------------------------------------
library(maxentcpp)
library(terra)

# Load two bioclimatic layers
bio1 <- rast("path/to/wc2.1_30s_bio_1.tif")
bio12 <- rast("path/to/wc2.1_30s_bio_12.tif")

# Convert to maxentcpp grids
g_bio1  <- maxent_grid_from_terra(bio1)
g_bio12 <- maxent_grid_from_terra(bio12)

# Check grid metadata
maxent_grid_info(g_bio1)


## ----load-raster--------------------------------------------------------------
library(raster)

r <- raster("path/to/bio1.tif")
mat <- as.matrix(r)
e <- extent(r)
g <- maxent_grid_from_matrix(mat,
                             xll = e@xmin, yll = e@ymin,
                             cellsize = res(r)[1],
                             name = names(r))


## ----load-asc-----------------------------------------------------------------
g_asc <- maxent_read_asc("path/to/bio1.asc")


## ----load-occurrences---------------------------------------------------------
# From a data frame
occ_df <- read.csv("species_occurrences.csv")
head(occ_df)
#>   species  longitude  latitude
#> 1 Quercus   -118.50    36.50
#> 2 Quercus   -119.00    37.00
#> ...

# Build a GridDimension matching the environmental layers
info <- maxent_grid_info(g_bio1)
dim <- maxent_dimension(nrows    = info$nrows,
                        ncols    = info$ncols,
                        xll      = info$xll,
                        yll      = info$yll,
                        cellsize = info$cellsize)

# Convert occurrences to sample indices
occ <- maxent_read_occurrences(occ_df, dim,
                               lon_col = "longitude",
                               lat_col = "latitude")

cat("Number of presence points:", length(occ$indices), "\n")


## ----background---------------------------------------------------------------
bg <- maxent_background_indices(g_bio1, n = 10000, seed = 42)

cat("Number of background points:", length(bg$indices), "\n")


## ----features-----------------------------------------------------------------
# Total number of points: background + presence
all_rows <- c(bg$rows, occ$rows)
all_cols <- c(bg$cols, occ$cols)
n_total  <- length(all_rows)

# The presence samples are at the end
sample_indices <- seq(length(bg$rows), n_total - 1L)  # 0-based

# Extract environmental values at all point locations
bio1_vals  <- sapply(seq_along(all_rows), function(i) {
    grid_get_value(g_bio1, all_rows[i], all_cols[i])
})
bio12_vals <- sapply(seq_along(all_rows), function(i) {
    grid_get_value(g_bio12, all_rows[i], all_cols[i])
})

# Build a named list of environmental data
env_data <- list(bio1 = bio1_vals, bio12 = bio12_vals)

# Auto-generate features (linear + hinge by default for moderate sample sizes)
features <- maxent_generate_features(env_data,
                                     types = c("linear", "quadratic", "hinge"),
                                     n_hinges = 15)
cat("Generated", length(features), "features\n")


## ----train--------------------------------------------------------------------
# Create a FeaturedSpace and train
fs <- maxent_featured_space(n_total, as.integer(sample_indices), features)
result <- maxent_fit(fs,
                     max_iter        = 500,
                     convergence     = 1e-5,
                     beta_multiplier = 1.0)

cat("Converged:", result$converged, "\n")
cat("Final loss:", result$loss, "\n")
cat("Entropy:", result$entropy, "\n")
cat("Iterations:", result$iterations, "\n")


## ----save-model---------------------------------------------------------------
maxent_save_lambdas(fs, "my_model.lambdas")


## ----project------------------------------------------------------------------
pred_grid <- maxent_project_cloglog(fs,
                                     list(g_bio1, g_bio12),
                                     c("bio1", "bio12"))

# Convert the output to a terra raster for plotting
pred_raster <- maxent_grid_to_terra(pred_grid)


## ----plot-prediction----------------------------------------------------------
library(terra)
plot(pred_raster,
     main = "Predicted Habitat Suitability (cloglog)",
     col  = hcl.colors(50, "YlOrRd", rev = TRUE))


## ----evaluate-----------------------------------------------------------------
# Extract predictions at presence and background locations
pres_preds <- maxent_extract_predictions_raw(
    fs, list(g_bio1, g_bio12), c("bio1", "bio12"),
    occ$rows, occ$cols)

bg_preds <- maxent_extract_predictions_raw(
    fs, list(g_bio1, g_bio12), c("bio1", "bio12"),
    bg$rows, bg$cols)

# Full evaluation
eval_result <- maxent_evaluate(pres_preds, bg_preds)
cat("AUC:", eval_result$auc, "\n")
cat("Max Kappa:", eval_result$max_kappa, "\n")
cat("Log-loss:", eval_result$logloss, "\n")


## ----variable-importance------------------------------------------------------
# Percent contribution (based on lambda values)
contrib <- maxent_percent_contribution(fs, c("bio1", "bio12"))
print(contrib)

# Permutation importance (based on AUC drop)
perm_imp <- maxent_permutation_importance(
    fs, list(g_bio1, g_bio12), c("bio1", "bio12"),
    occ$rows, occ$cols,
    bg$rows, bg$cols,
    seed = 42)
print(perm_imp)


## ----response-curves----------------------------------------------------------
# Response curve for bio1 (index 0)
curve_bio1 <- maxent_response_curve(fs, list(g_bio1, g_bio12),
                                     c("bio1", "bio12"),
                                     var_index = 0, n_steps = 100)

plot(curve_bio1$value, curve_bio1$prediction,
     type = "l", lwd = 2,
     xlab = "Annual Mean Temperature (bio1)",
     ylab = "Cloglog Prediction",
     main = "Response Curve: bio1")

# Response curve for bio12 (index 1)
curve_bio12 <- maxent_response_curve(fs, list(g_bio1, g_bio12),
                                      c("bio1", "bio12"),
                                      var_index = 1, n_steps = 100)

plot(curve_bio12$value, curve_bio12$prediction,
     type = "l", lwd = 2,
     xlab = "Annual Precipitation (bio12)",
     ylab = "Cloglog Prediction",
     main = "Response Curve: bio12")


## ----mess---------------------------------------------------------------------
# Reference values = environmental values at training sites
ref_vals <- list(
    bio1_vals[seq_len(length(bg$rows))],   # background values for bio1
    bio12_vals[seq_len(length(bg$rows))]    # background values for bio12
)

mess_result <- maxent_mess(list(g_bio1, g_bio12),
                           ref_vals,
                           c("bio1", "bio12"))

mess_raster <- maxent_grid_to_terra(mess_result$mess_grid)
plot(mess_raster,
     main = "MESS: Negative = Novel Environment",
     col  = hcl.colors(50, "RdYlGn"))


## ----clamp--------------------------------------------------------------------
ranges <- maxent_variable_ranges(list(g_bio1, g_bio12))
print(ranges)

clamped <- maxent_clamp(list(g_bio1, g_bio12),
                        ranges$min, ranges$max)

# Project with clamped grids
pred_clamped <- maxent_project_cloglog(fs,
                                        clamped$clamped_grids,
                                        c("bio1", "bio12"))


## ----maxent-run---------------------------------------------------------------
library(maxentcpp)
library(terra)

stack_path      <- system.file("extdata", "stack_1_12_crop.rds",
                               package = "maxentcpp")
example_rasters <- terra::unwrap(readRDS(stack_path))

grids <- list(
  bio1  = maxent_grid_from_terra(example_rasters[[1]]),
  bio12 = maxent_grid_from_terra(example_rasters[[2]])
)

data(example_occ_df)

result <- maxent_run(
  species    = "Abeillia_abeillei",
  env_grids  = grids,
  occ_df     = example_occ_df,
  output_dir = file.path(tempdir(), "maxent_output"),
  lon_col    = "long",
  lat_col    = "lat",
  n_background = 10000,
  types      = c("linear", "quadratic", "hinge"),
  n_hinges   = 15,
  max_iter   = 500,
  seed       = 42)

cat("Training AUC :", result$evaluation$auc, "\n")
cat("HTML report  :", result$html_file, "\n")
cat("Output files :\n")
list.files(result$output_dir, recursive = TRUE)

