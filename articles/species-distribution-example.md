# End-to-End Species Distribution Modeling with maxentcpp

## Overview

This vignette demonstrates a complete species distribution modeling
(SDM) workflow using **maxentcpp**, from loading environmental raster
data and species occurrence records through model training, evaluation,
projection, and diagnostics.

The workflow mirrors a typical “nicher”-style analysis:

1.  Load environmental layers (`.tif` or `.asc`)
2.  Ingest species occurrence data (CSV / data frame)
3.  Generate background (pseudo-absence) points
4.  Build features and train the model
5.  Evaluate the model (AUC, response curves, variable importance)
6.  Project the model onto a landscape and visualize

## 1. Load Environmental Layers

`maxentcpp` works with its own internal grid format. The package
provides bridge functions for the **terra** and **raster** packages so
you can load `.tif` (GeoTIFF) or any format those packages support.

### Using terra (recommended)

``` r

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
```

### Using raster (alternative)

``` r

library(raster)

r <- raster("path/to/bio1.tif")
mat <- as.matrix(r)
e <- extent(r)
g <- maxent_grid_from_matrix(mat,
                             xll = e@xmin, yll = e@ymin,
                             cellsize = res(r)[1],
                             name = names(r))
```

### Loading ESRI ASCII directly

``` r

g_asc <- maxent_read_asc("path/to/bio1.asc")
```

## 2. Prepare Species Occurrence Data

[`maxent_read_occurrences()`](https://alrobles.github.io/maxentcpp/reference/maxent_read_occurrences.md)
accepts a CSV file path or an R data frame (e.g. from
`rgbif::occ_data()`) and converts geographic coordinates to grid
row/column indices.

``` r

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
```

## 3. Generate Background Points

MaxEnt requires background (pseudo-absence) data drawn from the study
area.

``` r

bg <- maxent_background_indices(g_bio1, n = 10000, seed = 42)

cat("Number of background points:", length(bg$indices), "\n")
```

## 4. Extract Environmental Values and Build Features

We combine background and presence point indices, extract environmental
values, and generate features.

``` r

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
```

## 5. Train the Model

``` r

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
```

### Save the Model

``` r

maxent_save_lambdas(fs, "my_model.lambdas")
```

## 6. Project the Model

Apply the trained model to the environmental grids to produce a spatial
prediction.

``` r

pred_grid <- maxent_project_cloglog(fs,
                                     list(g_bio1, g_bio12),
                                     c("bio1", "bio12"))

# Convert the output to a terra raster for plotting
pred_raster <- maxent_grid_to_terra(pred_grid)
```

### Visualize the prediction map

``` r

library(terra)
plot(pred_raster,
     main = "Predicted Habitat Suitability (cloglog)",
     col  = hcl.colors(50, "YlOrRd", rev = TRUE))
```

## 7. Evaluate the Model

Compute AUC and other metrics using held-out presence and background
predictions.

``` r

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
```

## 8. Variable Importance

``` r

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
```

## 9. Response Curves

``` r

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
```

## 10. MESS Analysis (Environmental Novelty)

``` r

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
```

## 11. Clamping

When projecting to new regions or time periods, environmental values may
fall outside the training range. Clamping restricts them:

``` r

ranges <- maxent_variable_ranges(list(g_bio1, g_bio12))
print(ranges)

clamped <- maxent_clamp(list(g_bio1, g_bio12),
                        ranges$min, ranges$max)

# Project with clamped grids
pred_clamped <- maxent_project_cloglog(fs,
                                        clamped$clamped_grids,
                                        c("bio1", "bio12"))
```

## Complete Workflow Summary

    maxent_grid_from_terra()       ─── Load .tif layers
    maxent_read_occurrences()      ─── Ingest presence records
    maxent_background_indices()    ─── Sample background points
    maxent_generate_features()     ─── Build feature set
    maxent_featured_space()        ─── Create model object
    maxent_fit()                   ─── Train the MaxEnt model
    maxent_save_lambdas()          ─── Persist model to disk
    maxent_project_cloglog()       ─── Spatial prediction
    maxent_grid_to_terra()         ─── Convert output for plotting
    maxent_evaluate()              ─── Compute AUC + metrics
    maxent_response_curve()        ─── Variable response plots
    maxent_permutation_importance()─── Variable ranking
    maxent_mess()                  ─── Environmental novelty
    maxent_clamp()                 ─── Safe extrapolation

## One-Click Workflow with `maxent_run()`

For users who want a complete Java-Maxent-style output directory in a
single call,
[`maxent_run()`](https://alrobles.github.io/maxentcpp/reference/maxent_run.md)
orchestrates the full pipeline — from occurrence records to an HTML
report — and writes all the standard output files.

``` r

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
```

The output directory will contain:

| File | Description |
|----|----|
| `Abeillia_abeillei.html` | Full HTML report |
| `Abeillia_abeillei.lambdas` | Model coefficients |
| `Abeillia_abeillei_cloglog.png` | Prediction map |
| `Abeillia_abeillei_omission.csv` | Omission / threshold table |
| `Abeillia_abeillei_samplePredictions.csv` | Per-site predictions |
| `maxentResults.csv` | Species-level summary statistics |
| `plots/<species>_<var>.png` | Response curve (full) |
| `plots/<species>_<var>_thumb.png` | Response curve (thumbnail) |
| `plots/<species>_varimp.png` | Variable importance chart |
