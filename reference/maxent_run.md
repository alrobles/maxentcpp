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
# \donttest{
if (requireNamespace("terra", quietly = TRUE)) {
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

  result$evaluation$auc
}
#> class         : MaxEnt
#> species       : Abeillia_abeillei
#> n presence    : 73
#> n background  : 2371
#> 
#> Training statistics
#>   AUC             : 0.8033
#>   Gain            : 7.2290
#>   Entropy         : 7.3714
#> 
#> Variable contributions
#>   Variable              Contribution (%)  Permutation importance (%)
#>   bio1                              61.3                       54.0
#>   bio12                             38.7                       46.0
#> 
#> [1] 0.8033487
# }
```
