# Write an Omission / Threshold CSV

Computes cumulative predictions at all background + presence locations
and derives nine standard threshold statistics, writing the result to
`<output_dir>/<species>_omission.csv`. The output format mirrors
`density/Runner.java::writeCumulativeIndex()`.

## Usage

``` r
maxent_write_omission_csv(
  model,
  env_grids,
  feature_names,
  presence_rows,
  presence_cols,
  output_dir,
  species,
  test_rows = NULL,
  test_cols = NULL
)
```

## Arguments

- model:

  External pointer to a trained FeaturedSpace object.

- env_grids:

  List of external pointers to Grid\<float\> objects.

- feature_names:

  Character vector of environment variable names.

- presence_rows:

  Integer vector of presence row indices (0-based).

- presence_cols:

  Integer vector of presence column indices (0-based).

- output_dir:

  Character: directory for output files.

- species:

  Character: species name (used in the filename).

- test_rows:

  Integer vector of test row indices (0-based) or `NULL` (default).

- test_cols:

  Integer vector of test column indices (0-based) or `NULL` (default).

## Value

Invisibly returns the path to the written CSV file.

## Examples

``` r
# \donttest{
set.seed(42)
n <- 50L; idx <- c(5L, 15L, 25L, 35L, 45L)
env <- list(bio1 = runif(n), bio12 = runif(n))
feats <- maxent_generate_features(env, types = "linear")
model <- maxent_featured_space(n, idx, feats)
maxent_fit(model, max_iter = 100)
#> $loss
#> [1] 3.781356
#> 
#> $entropy
#> [1] 3.887762
#> 
#> $iterations
#> [1] 100
#> 
#> $converged
#> [1] FALSE
#> 
#> $lambdas
#> [1] 0.6202339 0.4108689
#> 
g1 <- maxent_grid_from_matrix(matrix(env$bio1, 5, 10),
        -120, 35, 1, name = "bio1")
g2 <- maxent_grid_from_matrix(matrix(env$bio12, 5, 10),
        -120, 35, 1, name = "bio12")
pres_rows <- c(0L, 1L, 2L); pres_cols <- c(0L, 1L, 2L)
maxent_write_omission_csv(model, list(g1, g2), c("bio1", "bio12"),
  pres_rows, pres_cols, output_dir = tempdir(), species = "Sp1")
# }
```
