# Project Model onto Grids (logistic output)

logistic(x) = x / (1 + x).

## Usage

``` r
project_logistic_deprecated(fs_ptr, grid_ptrs, feature_names)
```

## Arguments

- fs_ptr:

  External pointer to a FeaturedSpace object.

- grid_ptrs:

  List of external pointers to Grid\<float\> objects.

- feature_names:

  Character vector of environment variable names.

## Value

External pointer to a Grid\<float\> with logistic scores in \[0, 1\].
