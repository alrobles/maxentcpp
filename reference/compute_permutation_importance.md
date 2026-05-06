# Compute Permutation Importance

Measures how much each environmental variable contributes to model
prediction quality by permuting each variable and measuring AUC drop.

## Usage

``` r
compute_permutation_importance(
  fs_ptr,
  grid_ptrs,
  feature_names,
  presence_rows,
  presence_cols,
  absence_rows,
  absence_cols,
  seed = 42L
)
```

## Arguments

- fs_ptr:

  External pointer to a FeaturedSpace object.

- grid_ptrs:

  List of external pointers to Grid\<float\> objects.

- feature_names:

  Character vector of environment variable names.

- presence_rows:

  Integer vector of presence site row indices.

- presence_cols:

  Integer vector of presence site column indices.

- absence_rows:

  Integer vector of absence site row indices.

- absence_cols:

  Integer vector of absence site column indices.

- seed:

  Random seed for reproducibility.

## Value

A data.frame with columns: name, permutation_importance.
