# Jackknife Variable Importance Analysis

Performs a leave-one-variable-out jackknife analysis following the
procedure in Java Maxent's `Runner.jackknifeGain()`. For each
environmental variable, two additional models are trained:

1.  **Leave-one-out**: the variable is excluded and the model is trained
    on all remaining variables.

2.  **Only-one**: the model is trained using *only* that single
    variable.

The resulting training gain and AUC are compared to the full model to
assess variable importance.

## Usage

``` r
maxent_jackknife(
  env_vals,
  sample_indices,
  num_points,
  types = c("linear", "quadratic", "hinge"),
  n_hinges = 15L,
  max_iter = 500L,
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

- types:

  Character vector of feature types (default
  `c("linear", "quadratic", "hinge")`).

- n_hinges:

  Integer: number of hinge knots (default 15).

- max_iter:

  Integer: maximum training iterations (default 500).

- categorical:

  Character vector of variable names that are categorical (default
  `NULL`).

- bias_weights:

  Optional numeric vector of per-point bias weights (default `NULL`).

## Value

A `data.frame` with columns:

- variable:

  Variable name.

- gain_without:

  Training gain of the model with this variable excluded.

- gain_only:

  Training gain of the model using only this variable.

- gain_full:

  Training gain of the full model (same for all rows).

## Examples

``` r
if (FALSE) { # \dontrun{
env <- list(
  temp  = rnorm(110),
  precip = rnorm(110),
  elev  = rnorm(110)
)
jk <- maxent_jackknife(env, sample_indices = 100:109,
                        num_points = 110L)
print(jk)
} # }
```
