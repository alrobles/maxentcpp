# Compute MESS (Multivariate Environmental Similarity Surface)

Measures how similar each cell is to the training environment using the
full distribution of reference values. Negative MESS values indicate
novel (non-analog) environments.

## Usage

``` r
maxent_mess(env_grids, reference_values, feature_names)
```

## Arguments

- env_grids:

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

  External pointer to Grid\<float\> with Most Dissimilar Variable index
  (1-based)

## Examples

``` r
# \donttest{
result <- maxent_mess(list(g1, g2),
            list(temp_train_vals, precip_train_vals),
            c("temp", "precip"))
#> Error: object 'g1' not found
mess_mat <- maxent_grid_to_matrix(result$mess_grid)
#> Error: object 'result' not found
mod_mat  <- maxent_grid_to_matrix(result$mod_grid)
#> Error: object 'result' not found
# }
```
