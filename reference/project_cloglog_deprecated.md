# Project Model onto Grids (cloglog output)

cloglog(x) = 1 - exp(-x). Recommended output format for Maxent v3.4+.

## Usage

``` r
project_cloglog_deprecated(fs_ptr, grid_ptrs, feature_names)
```

## Arguments

- fs_ptr:

  External pointer to a FeaturedSpace object.

- grid_ptrs:

  List of external pointers to Grid\<float\> objects.

- feature_names:

  Character vector of environment variable names.

## Value

External pointer to a Grid\<float\> with cloglog scores in \[0, 1\].
