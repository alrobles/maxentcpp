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
if (FALSE) { # \dontrun{
library(maxentcpp)
library(terra)

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
} # }
```
