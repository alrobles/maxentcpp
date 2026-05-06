# Compute MESS from Min/Max Ranges

Simplified MESS using only the min/max of reference data.

## Usage

``` r
compute_mess_range(grid_ptrs, var_mins, var_maxs)
```

## Arguments

- grid_ptrs:

  List of external pointers to Grid\<float\> objects.

- var_mins:

  Numeric vector of minimum reference values.

- var_maxs:

  Numeric vector of maximum reference values.

## Value

A named list with mess_grid and mod_grid (external pointers).
