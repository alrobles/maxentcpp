# Run a Complete Maxent Species Distribution Modelling Workflow

Provides a single high-level entry point that mirrors running the Java
Maxent GUI with one click. Starting from raw environmental grids and
occurrence records, the function:

1.  Reads and validates occurrence records.

2.  Samples background points.

3.  Extracts environmental values and builds features.

4.  Trains the Maxent model.

5.  Projects the model onto the full landscape (cloglog output).

6.  Evaluates model performance (AUC).

7.  Computes percent contribution and permutation importance.

8.  Writes all standard output files (lambdas, prediction PNG, response
    curve PNGs, omission CSV, sample-predictions CSV, and
    `maxentResults.csv`).

9.  Prints a performance summary to the console.

## Usage

``` r
maxent_run(
  species,
  env_grids,
  occ_df,
  output_dir,
  lon_col = "long",
  lat_col = "lat",
  n_background = 10000L,
  types = c("linear", "quadratic", "hinge"),
  n_hinges = 15L,
  max_iter = 500L,
  seed = 42L,
  bias_weights = NULL,
  categorical = NULL,
  nodata_value = -9999,
  response_curves = TRUE,
  pictures = TRUE
)
```

## Arguments

- species:

  Character: species name (used in file names and the console report).

- env_grids:

  Named list of external pointers to Grid\<float\> objects. The *names*
  of the list are used as the environmental variable names.

- occ_df:

  A `data.frame` (or CSV path) with occurrence records.

- output_dir:

  Character: directory where all output files are written (created if it
  does not exist).

- lon_col:

  Character: longitude column name in `occ_df` (default `"long"`).

- lat_col:

  Character: latitude column name in `occ_df` (default `"lat"`).

- n_background:

  Integer: number of background points (default 10000).

- types:

  Character vector of feature types passed to
  [`maxent_generate_features`](https://alrobles.github.io/maxentcpp/reference/maxent_generate_features.md)
  (default `c("linear", "quadratic", "hinge")`).

- n_hinges:

  Integer: number of hinge knots (default 15).

- max_iter:

  Integer: maximum training iterations (default 500).

- seed:

  Integer: random seed for background sampling (default 42).

- bias_weights:

  Optional numeric vector of per-background-point bias weights. Must
  have length equal to `n_background` (the background points only, not
  including occurrence points). When supplied, the background density is
  weighted by `bias[i] * exp(lp[i] - lpn)`, mirroring Java Maxent's
  `biasFile`. Pass `NULL` (default) for uniform (unbiased) background.

- categorical:

  Character vector of variable names that should be treated as
  categorical. These variables produce binary indicator features (one
  per distinct level) instead of continuous feature types. Pass `NULL`
  (default) for all continuous.

- nodata_value:

  Numeric: sentinel value treated as missing data (default `-9999`).
  Samples with this value (or `NA`) in any variable are removed before
  training.

- response_curves:

  Logical: write response curve PNGs (default `TRUE`).

- pictures:

  Logical: write prediction map PNG (default `TRUE`).

## Value

A named list with:

- model:

  Trained FeaturedSpace external pointer.

- fit_result:

  List returned by
  [`maxent_fit`](https://alrobles.github.io/maxentcpp/reference/maxent_fit.md).

- evaluation:

  List returned by
  [`maxent_evaluate`](https://alrobles.github.io/maxentcpp/reference/maxent_evaluate.md).

- contributions:

  Data.frame of percent contributions.

- permutation_importance:

  Data.frame of permutation importances.

- output_dir:

  The output directory used.

## Examples

``` r
if (FALSE) { # \dontrun{
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
  output_dir = tempdir(),
  lon_col    = "long",
  lat_col    = "lat")

cat("AUC:", result$evaluation$auc, "\n")
} # }
```
