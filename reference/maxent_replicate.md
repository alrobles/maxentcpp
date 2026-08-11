# Replicate Runs for Maxent Models

Trains multiple replicate models using either bootstrap sampling or
subsample splitting of occurrence data. This mirrors Java Maxent's
`SampleSet.replicate()` method.

## Usage

``` r
maxent_replicate(
  env_vals,
  sample_indices,
  num_points,
  n_replicates = 5L,
  replicate_type = "bootstrap",
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

  Integer: total number of points.

- n_replicates:

  Integer: number of replicates (default 5).

- replicate_type:

  Character: `"bootstrap"` (default) samples with replacement,
  `"subsample"` uses a 75% random subsample.

- types:

  Character vector of feature types (default
  `c("linear", "quadratic", "hinge")`).

- n_hinges:

  Integer: number of hinge knots (default 15).

- max_iter:

  Integer: maximum training iterations (default 500).

- seed:

  Integer: random seed (default 42).

- categorical:

  Character vector of variable names that are categorical (default
  `NULL`).

- bias_weights:

  Optional numeric vector of per-point bias weights.

## Value

A named list with:

- replicate_results:

  List of per-replicate result lists.

- summary:

  A `data.frame` with mean and sd statistics.

## Examples

``` r
if (FALSE) { # \dontrun{
env <- list(temp = rnorm(110), precip = rnorm(110))
reps <- maxent_replicate(env, sample_indices = 100:109,
                          num_points = 110L, n_replicates = 5L)
print(reps$summary)
} # }
```
