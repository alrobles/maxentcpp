# maxentcpp

Maximum Entropy Species Distribution Modeling - C++ Implementation with
R Interface

## Overview

`maxentcpp` is a high-performance C++ implementation of the Maxent
species distribution modeling algorithm, with seamless R integration
through Rcpp. This package aims to provide:

- **Performance**: Faster execution through optimized C++ code
- **Compatibility**: File format compatibility with the Java Maxent
- **Integration**: Native R interface for easy use in R workflows
- **Modern**: Built with modern C++17 and R best practices

## Installation

### Prerequisites

- R \>= 4.0.0
- C++17 compatible compiler
- Eigen3 library (usually installed via Rcpp/RcppEigen)

### From Source

``` r

# Install dependencies
install.packages(c("Rcpp", "RcppEigen", "testthat"))

# Build and install
devtools::install("path/to/R-package")
```

## Testing

Local test execution requires an R installation available on `PATH`.

``` r

# Run the package test suite
testthat::test_dir("tests/testthat", reporter = "summary")

# Run the full package check
rcmdcheck::rcmdcheck(args = c("--no-manual"), error_on = "warning")
```

GitHub Actions already runs `R CMD check` for pushes and pull requests
via
[.github/workflows/test-r-package.yml](https://alrobles.github.io/maxentcpp/.github/workflows/test-r-package.yml),
which exercises the `testthat` suite on Ubuntu, Windows, and macOS.

## Quick Start

The package ships with a complete reproducible example in
[`inst/examples/quickstart.R`](https://alrobles.github.io/maxentcpp/inst/examples/quickstart.R).
After installing the package you can run the full workflow with:

``` r

source(system.file("examples", "quickstart.R", package = "maxentcpp"))
```

The example uses two bundled bioclimatic layers (bio1 – Annual Mean
Temperature, bio12 – Annual Precipitation, cropped to the distribution
range of *Abeillia abeillei*) and GBIF occurrence records for the same
species.

### Condensed walkthrough

``` r

library(maxentcpp)
library(terra)

# --- 1. Load raster data from the package -----------------------------------
stack_path      <- system.file("extdata", "stack_1_12_crop.rds",
                               package = "maxentcpp")
example_rasters <- terra::unwrap(readRDS(stack_path))
g_bio1  <- maxent_grid_from_terra(example_rasters[[1]])
g_bio12 <- maxent_grid_from_terra(example_rasters[[2]])

# --- 2. Occurrence records ---------------------------------------------------
data(example_occ_df)   # columns: species, long, lat
info <- maxent_grid_info(g_bio1)
dim  <- maxent_dimension(info$nrows, info$ncols,
                         info$xll, info$yll, info$cellsize)
occ  <- maxent_read_occurrences(example_occ_df, dim,
                                lon_col = "long", lat_col = "lat")

# --- 3. Background points ----------------------------------------------------
bg <- maxent_background_indices(g_bio1, n = 10000, seed = 42)

# --- 4. Features -------------------------------------------------------------
all_rows <- c(bg$rows, occ$rows)
all_cols <- c(bg$cols, occ$cols)
n_total  <- length(all_rows)
sample_indices <- seq(length(bg$rows), n_total - 1L)

bio1_vals  <- sapply(seq_along(all_rows), function(i)
    grid_get_value(g_bio1,  all_rows[i], all_cols[i]))
bio12_vals <- sapply(seq_along(all_rows), function(i)
    grid_get_value(g_bio12, all_rows[i], all_cols[i]))

features <- maxent_generate_features(
    list(bio1 = bio1_vals, bio12 = bio12_vals),
    types = c("linear", "quadratic", "hinge"), n_hinges = 15)

# --- 5. Train ----------------------------------------------------------------
fs     <- maxent_featured_space(n_total, as.integer(sample_indices), features)
result <- maxent_fit(fs, max_iter = 500, convergence = 1e-5)
cat("AUC:", maxent_evaluate(
    maxent_extract_predictions_raw(fs, list(g_bio1, g_bio12),
                                   c("bio1", "bio12"), occ$rows, occ$cols),
    maxent_extract_predictions_raw(fs, list(g_bio1, g_bio12),
                                   c("bio1", "bio12"), bg$rows,  bg$cols))$auc, "\n")

# --- 6. Project and visualise ------------------------------------------------
pred_raster <- maxent_grid_to_terra(
    maxent_project_cloglog(fs, list(g_bio1, g_bio12), c("bio1", "bio12")))
terra::plot(pred_raster,
            main = "Predicted Habitat Suitability (cloglog)",
            col  = hcl.colors(50, "YlOrRd", rev = TRUE))
```

See
[`inst/examples/quickstart.R`](https://alrobles.github.io/maxentcpp/inst/examples/quickstart.R)
for the complete workflow including variable importance, response
curves, MESS analysis, and clamping.

### Complete workflow functions

    maxent_grid_from_terra()        --- Load raster layers (terra SpatRaster)
    maxent_read_occurrences()       --- Ingest presence records (data frame / CSV)
    maxent_background_indices()     --- Sample background points
    maxent_generate_features()      --- Build feature set
    maxent_featured_space()         --- Create model object
    maxent_fit()                    --- Train the MaxEnt model
    maxent_save_lambdas()           --- Persist model to disk
    maxent_project_cloglog()        --- Spatial prediction (cloglog output)
    maxent_grid_to_terra()          --- Convert output to terra SpatRaster
    maxent_evaluate()               --- Compute AUC + metrics
    maxent_response_curve()         --- Variable response plots
    maxent_permutation_importance() --- Variable ranking
    maxent_mess()                   --- Environmental novelty (MESS)
    maxent_clamp()                  --- Safe extrapolation

    --- Output layer (report / file artifacts) ---
    maxent_color_ramp()             --- Canonical Java-compatible colour ramp
    maxent_write_prediction_png()   --- Prediction map PNG with legend + dots
    maxent_plot_response_curves()   --- Response curve PNGs (full + thumbnail)
    maxent_plot_variable_importance()--- Variable importance bar chart PNG
    maxent_write_omission_csv()     --- Omission/threshold CSV (9 thresholds)
    maxent_write_sample_predictions()--- Sample predictions CSV
    maxent_print_results()          --- Print dismo-style performance metrics to console
    maxent_append_results_csv()     --- Append row to maxentResults.csv
    maxent_run()                    --- One-click full pipeline wrapper

## Development Status

This package is under active development. Current status:

Core data structures (Sample, Grid, GridDimension)

R bindings for core structures

Feature classes (Linear, Quadratic, Product, Threshold, Hinge)

Model training (FeaturedSpace, sequential coordinate ascent)

Lambda file I/O (model persistence)

Spatial data I/O (ESRI ASCII .asc read/write)

CSV reader/writer (occurrence data, SWD files)

Environmental layer metadata (Layer class)

Model evaluation (AUC, kappa, correlation, log-loss, metrics)

Spatial projection (raw, cloglog, logistic output)

Complete end-to-end workflow examples (`inst/examples/quickstart.R`)

Canonical color ramp
([`maxent_color_ramp()`](https://alrobles.github.io/maxentcpp/reference/maxent_color_ramp.md))
matching Java Maxent

Prediction map PNG writer
([`maxent_write_prediction_png()`](https://alrobles.github.io/maxentcpp/reference/maxent_write_prediction_png.md))

Response curve PNG writer
([`maxent_plot_response_curves()`](https://alrobles.github.io/maxentcpp/reference/maxent_plot_response_curves.md))

Variable importance bar chart
([`maxent_plot_variable_importance()`](https://alrobles.github.io/maxentcpp/reference/maxent_plot_variable_importance.md))

Omission/threshold CSV
([`maxent_write_omission_csv()`](https://alrobles.github.io/maxentcpp/reference/maxent_write_omission_csv.md))

Sample predictions CSV
([`maxent_write_sample_predictions()`](https://alrobles.github.io/maxentcpp/reference/maxent_write_sample_predictions.md))

Console results printer replicating dismo output
([`maxent_print_results()`](https://alrobles.github.io/maxentcpp/reference/maxent_print_results.md))

`maxentResults.csv` appender
([`maxent_append_results_csv()`](https://alrobles.github.io/maxentcpp/reference/maxent_append_results_csv.md))

High-level one-click wrapper
([`maxent_run()`](https://alrobles.github.io/maxentcpp/reference/maxent_run.md))

CRAN release

## Contributing

Contributions are welcome! This is a community-driven migration from the
Java implementation.

## License

MIT License - See LICENSE file for details

## Related Projects

- [Java Maxent](https://github.com/alrobles/Maxent) - Original Java
  implementation
- [maxnet](https://CRAN.R-project.org/package=maxnet) - R implementation
  using glmnet

## Acknowledgments

Based on the original Maxent software by Steven Phillips, Miro Dudík,
and Rob Schapire.
