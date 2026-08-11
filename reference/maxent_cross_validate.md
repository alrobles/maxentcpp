# Cross-Validation for Maxent Models

Splits occurrence data into `k` folds and trains one model per fold
using the remaining folds for training and the held-out fold for
testing. This mirrors Java Maxent's `SampleSet.splitForCV()`.

## Usage

``` r
maxent_cross_validate(
  env_vals,
  sample_indices,
  num_points,
  k = 5L,
  types = c("linear", "quadratic", "hinge"),
  n_hinges = 15L,
  max_iter = 500L,
  seed = 42L,
  categorical = NULL,
  bias_weights = NULL
)
```

## Arguments

- env_vals:

  Named list of numeric vectors (one per environmental variable, length
  = total points: background + occurrences).

- sample_indices:

  Integer vector: 0-based indices of occurrence samples within
  `env_vals`.

- num_points:

  Integer: total number of points (background + occurrences).

- k:

  Integer: number of folds (default 5).

- types:

  Character vector of feature types (default
  `c("linear", "quadratic", "hinge")`).

- n_hinges:

  Integer: number of hinge knots (default 15).

- max_iter:

  Integer: maximum training iterations (default 500).

- seed:

  Integer: random seed for fold assignment (default 42).

- categorical:

  Character vector of variable names that are categorical (default
  `NULL`).

- bias_weights:

  Optional numeric vector of per-point bias weights (default `NULL`).

## Value

A named list with:

- fold_results:

  A list of per-fold result lists, each containing `fold`, `train_gain`,
  `n_train`, `n_test`, and `lambdas`.

- summary:

  A `data.frame` with per-fold and overall mean/sd statistics.

## Examples

``` r
if (FALSE) { # \dontrun{
env <- list(temp = rnorm(110), precip = rnorm(110))
cv <- maxent_cross_validate(env, sample_indices = 100:109,
                             num_points = 110L, k = 5L)
print(cv$summary)
} # }
```
