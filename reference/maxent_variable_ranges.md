# Compute Variable Ranges from Grids

Scans all valid cells in the grids to determine the \[min, max\] range
of each environmental variable.

Scans all valid cells in the grids to determine the \[min, max\] range
of each environmental variable.

## Usage

``` r
maxent_variable_ranges(env_grids)

maxent_variable_ranges(env_grids)
```

## Arguments

- env_grids:

  List of external pointers to Grid\<float\> objects.

## Value

A data.frame with columns: min, max (one row per variable).

A data.frame with columns: min, max (one row per variable).
