# Extract Lambda Values from a Maxent Run Result

Retrieves the trained lambda (weight) coefficients from the output of
[`maxent_run`](https://alrobles.github.io/maxentcpp/reference/maxent_run.md),
returning them as a named numeric vector. Each element is the lambda
value for the corresponding feature, and the name of each element is the
feature name (e.g. `"bio1"`, `"bio1^2"`, `"bio1'1"`).

## Usage

``` r
maxent_extract_lambdas(run_result)
```

## Arguments

- run_result:

  A named list as returned by
  [`maxent_run`](https://alrobles.github.io/maxentcpp/reference/maxent_run.md).
  Must contain an element `model` holding the trained FeaturedSpace
  external pointer.

## Value

A named numeric vector of lambda values, one per feature. Names are the
feature names as stored in the model.

## Details

The function reads lambdas directly from the trained model object, so it
also works correctly after reloading coefficients with
[`maxent_load_lambdas`](https://alrobles.github.io/maxentcpp/reference/maxent_load_lambdas.md).

## Examples

``` r
# \donttest{
if (requireNamespace("terra", quietly = TRUE)) {
  stack_path      <- system.file("extdata", "stack_1_12_crop.rds",
                                 package = "maxentcpp")
  example_rasters <- terra::unwrap(readRDS(stack_path))
  grids <- list(
    bio1  = maxent_grid_from_terra(example_rasters[[1]]),
    bio12 = maxent_grid_from_terra(example_rasters[[2]])
  )
  data(example_occ_df)

  result <- maxent_run(
    species    = "Abeillia_abeillei",
    env_grids  = grids,
    occ_df     = example_occ_df,
    output_dir = tempdir(),
    lon_col    = "long",
    lat_col    = "lat")

  lambdas <- maxent_extract_lambdas(result)
  print(lambdas)
}
#> class         : MaxEnt
#> species       : Abeillia_abeillei
#> n presence    : 73
#> n background  : 2371
#> 
#> Training statistics
#>   AUC             : 0.8033
#>   Gain            : 7.2290
#>   Entropy         : 7.3714
#> 
#> Variable contributions
#>   Variable              Contribution (%)  Permutation importance (%)
#>   bio1                              61.3                       54.0
#>   bio12                             38.7                       46.0
#> 
#>        bio1_linear     bio1_quadratic   bio1_hinge_fwd_1   bio1_hinge_rev_1 
#>         0.00000000         0.00000000         0.00000000         0.00000000 
#>   bio1_hinge_fwd_2   bio1_hinge_rev_2   bio1_hinge_fwd_3   bio1_hinge_rev_3 
#>         0.00000000         0.00000000         0.00000000         0.00000000 
#>   bio1_hinge_fwd_4   bio1_hinge_rev_4   bio1_hinge_fwd_5   bio1_hinge_rev_5 
#>         0.00000000         0.00000000         0.00000000        -2.92570617 
#>   bio1_hinge_fwd_6   bio1_hinge_rev_6   bio1_hinge_fwd_7   bio1_hinge_rev_7 
#>         0.00000000        -4.54172243         0.00000000         0.00000000 
#>   bio1_hinge_fwd_8   bio1_hinge_rev_8   bio1_hinge_fwd_9   bio1_hinge_rev_9 
#>         0.00000000         0.00000000         0.00000000         0.00000000 
#>  bio1_hinge_fwd_10  bio1_hinge_rev_10  bio1_hinge_fwd_11  bio1_hinge_rev_11 
#>        -1.48324905         0.00000000        -2.30675721         0.00000000 
#>  bio1_hinge_fwd_12  bio1_hinge_rev_12  bio1_hinge_fwd_13  bio1_hinge_rev_13 
#>         0.00000000         0.00000000         0.00000000         0.00000000 
#>  bio1_hinge_fwd_14  bio1_hinge_rev_14  bio1_hinge_fwd_15  bio1_hinge_rev_15 
#>         0.00000000         0.00000000         0.00000000         0.00000000 
#>       bio12_linear    bio12_quadratic  bio12_hinge_fwd_1  bio12_hinge_rev_1 
#>         0.00000000         0.00000000         0.00000000        -2.17821403 
#>  bio12_hinge_fwd_2  bio12_hinge_rev_2  bio12_hinge_fwd_3  bio12_hinge_rev_3 
#>         0.00000000        -2.63658197         0.00000000         0.00000000 
#>  bio12_hinge_fwd_4  bio12_hinge_rev_4  bio12_hinge_fwd_5  bio12_hinge_rev_5 
#>         0.00000000         0.00000000         0.00000000         0.00000000 
#>  bio12_hinge_fwd_6  bio12_hinge_rev_6  bio12_hinge_fwd_7  bio12_hinge_rev_7 
#>         0.00000000        -0.52763351         0.00000000         0.00000000 
#>  bio12_hinge_fwd_8  bio12_hinge_rev_8  bio12_hinge_fwd_9  bio12_hinge_rev_9 
#>         0.00000000         0.00000000         0.00000000         0.00000000 
#> bio12_hinge_fwd_10 bio12_hinge_rev_10 bio12_hinge_fwd_11 bio12_hinge_rev_11 
#>         0.00000000         0.00000000         0.00000000         0.00000000 
#> bio12_hinge_fwd_12 bio12_hinge_rev_12 bio12_hinge_fwd_13 bio12_hinge_rev_13 
#>         0.00000000         0.00000000         0.00000000        -0.25879782 
#> bio12_hinge_fwd_14 bio12_hinge_rev_14 bio12_hinge_fwd_15 bio12_hinge_rev_15 
#>        -1.48631046        -0.01083494         0.00000000         0.00000000 
# }
```
