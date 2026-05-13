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
g1 <- maxent_grid_from_matrix(matrix(runif(50), 5, 10),
        -120, 35, 1, name = "temp")
g2 <- maxent_grid_from_matrix(matrix(runif(50, 50, 200), 5, 10),
        -120, 35, 1, name = "precip")
temp_train_vals <- runif(20)
precip_train_vals <- runif(20, 50, 200)
result <- maxent_mess(list(g1, g2),
            list(temp_train_vals, precip_train_vals),
            c("temp", "precip"))
mess_mat <- maxent_grid_to_matrix(result$mess_grid)
mod_mat  <- maxent_grid_to_matrix(result$mod_grid)
# }
```
