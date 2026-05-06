# Compute Variable Ranges from Grids

Scans all valid cells to determine min/max of each variable.

## Usage

``` r
compute_variable_ranges(grid_ptrs)
```

## Arguments

- grid_ptrs:

  List of external pointers to Grid\<float\> objects.

## Value

A data.frame with columns: min, max.
