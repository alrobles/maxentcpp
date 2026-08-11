# Replace Missing Values with Variable Means

For each environmental variable, replaces `NA`, `NaN`, and NODATA
sentinel values with the mean of the valid values. This mirrors the Java
Maxent partial-data handling where
`FeaturedSpace.setSampleExpectations()` uses mean substitution for
samples with missing feature values.

## Usage

``` r
maxent_impute_means(env_vals, nodata_value = -9999)
```

## Arguments

- env_vals:

  Named list of numeric vectors (one per variable).

- nodata_value:

  Numeric: sentinel value treated as missing (default `-9999`).

## Value

Named list of numeric vectors with missing values replaced.

## Examples

``` r
env <- list(
  temp  = c(15, NA, 25, 18, -9999),
  precip = c(100, 200, 150, 80, 300)
)
filled <- maxent_impute_means(env)
filled$temp[2]  # mean of valid values replaces NA
#> [1] 19.33333
```
