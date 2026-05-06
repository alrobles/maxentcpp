# Clamp Environmental Grids

Restricts environmental variable values to the range observed during
training. Values below min are set to min, values above max are set to
max. A clamping grid records the total absolute clamping at each cell.

## Usage

``` r
maxent_clamp(env_grids, var_mins, var_maxs)
```

## Arguments

- env_grids:

  List of external pointers to Grid\<float\> objects.

- var_mins:

  Numeric vector of minimum training values per variable.

- var_maxs:

  Numeric vector of maximum training values per variable.

## Value

A named list with:

- clamped_grids:

  List of external pointers to clamped grids

- clamp_grid:

  External pointer to clamping magnitude grid

## Examples

``` r
if (FALSE) { # \dontrun{
result <- maxent_clamp(list(g1, g2), c(0, 50), c(30, 200))
clamped <- result$clamped_grids
clamp_mat <- maxent_grid_to_matrix(result$clamp_grid)
} # }
```
