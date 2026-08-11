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
if (FALSE) { # \dontrun{
imp <- maxent_permutation_importance(model, list(g1, g2),
         c("temp", "precip"),
         pres_rows, pres_cols, abs_rows, abs_cols)
imp  # data.frame with name and permutation_importance
} # }
```
