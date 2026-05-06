# Clamp Environmental Grids

Restricts environmental variable values to the training range. Returns
clamped grids and a clamping indicator grid.

## Usage

``` r
clamp_grids(grid_ptrs, var_mins, var_maxs)
```

## Arguments

- grid_ptrs:

  List of external pointers to Grid\<float\> objects.

- var_mins:

  Numeric vector of minimum training values per variable.

- var_maxs:

  Numeric vector of maximum training values per variable.

## Value

A named list with:

- clamped_grids:

  List of external pointers to clamped Grid\<float\>

- clamp_grid:

  External pointer to Grid\<float\> with clamping magnitudes
