# Compute Permutation Importance

Measures how much each environmental variable contributes to model
prediction quality by permuting each variable and measuring AUC drop.
Results are normalised so that all importances sum to 100

## Usage

``` r
maxent_permutation_importance(
  model,
  env_grids,
  feature_names,
  presence_rows,
  presence_cols,
  absence_rows,
  absence_cols,
  seed = 42L
)
```

## Arguments

- model:

  External pointer to a FeaturedSpace object.

- env_grids:

  List of external pointers to Grid\<float\> objects.

- feature_names:

  Character vector of environment variable names, matching the order of
  env_grids.

- presence_rows:

  Integer vector of presence site row indices (0-based).

- presence_cols:

  Integer vector of presence site column indices (0-based).

- absence_rows:

  Integer vector of absence/background site row indices.

- absence_cols:

  Integer vector of absence/background site column indices.

- seed:

  Random seed for reproducibility (default 42).

## Value

A data.frame with columns:

- name:

  Variable name

- permutation_importance:

  Normalised importance (%)

## Examples

``` r
# \donttest{
set.seed(42)
n <- 50L; idx <- c(5L, 15L, 25L, 35L, 45L)
env <- list(temp = runif(n), precip = runif(n))
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
g1 <- maxent_grid_from_matrix(matrix(env$temp, 5, 10),
        -120, 35, 1, name = "temp")
g2 <- maxent_grid_from_matrix(matrix(env$precip, 5, 10),
        -120, 35, 1, name = "precip")
pres_rows <- c(0L, 1L, 2L); pres_cols <- c(0L, 1L, 2L)
abs_rows  <- c(3L, 4L, 0L); abs_cols  <- c(5L, 6L, 7L)
imp <- maxent_permutation_importance(model, list(g1, g2),
         c("temp", "precip"),
         pres_rows, pres_cols, abs_rows, abs_cols)
imp
#>     name permutation_importance
#> 1   temp                      0
#> 2 precip                      0
# }
```
