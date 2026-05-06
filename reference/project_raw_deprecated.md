# Project Model onto Grids (raw output)

Applies a trained FeaturedSpace model to environmental grids to produce
raw Gibbs scores.

## Usage

``` r
project_raw_deprecated(fs_ptr, grid_ptrs, feature_names)
```

## Arguments

- fs_ptr:

  External pointer to a FeaturedSpace object.

- grid_ptrs:

  List of external pointers to Grid\<float\> objects.

- feature_names:

  Character vector of environment variable names, matching the order of
  grid_ptrs.

## Value

External pointer to a Grid\<float\> with raw prediction scores.
