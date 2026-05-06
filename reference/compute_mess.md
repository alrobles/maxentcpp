# Compute MESS (Multivariate Environmental Similarity Surface)

Measures how similar each cell is to the training environment. Negative
values indicate novel (non-analog) conditions.

## Usage

``` r
compute_mess(grid_ptrs, reference_values, feature_names)
```

## Arguments

- grid_ptrs:

  List of external pointers to Grid\<float\> objects.

- reference_values:

  List of numeric vectors with reference values for each variable (e.g.
  values at training sites).

- feature_names:

  Character vector of variable names.

## Value

A named list with:

- mess_grid:

  External pointer to Grid\<float\> with MESS values

- mod_grid:

  External pointer to Grid\<float\> with MoD variable index (1-based)
