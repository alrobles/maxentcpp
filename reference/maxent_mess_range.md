# Compute MESS from Min/Max Ranges

Simplified MESS analysis using only the min/max of the reference data
rather than the full distribution.

## Usage

``` r
maxent_mess_range(env_grids, var_mins, var_maxs)
```

## Arguments

- env_grids:

  List of external pointers to Grid\<float\> objects.

- var_mins:

  Numeric vector of minimum reference values per variable.

- var_maxs:

  Numeric vector of maximum reference values per variable.

## Value

A named list with mess_grid and mod_grid (external pointers).
