# Remove Samples with Missing Environmental Data

Filters out samples (occurrence or background points) that have `NA`,
`NaN`, or a designated NODATA sentinel value in any of their
environmental variable values. This mirrors the Java Maxent
`hasAllData()` check in `FeaturedSpace.java` and the
`NODATA_value = -9999` sentinel used throughout the Java code.

## Usage

``` r
maxent_complete_cases(env_vals, nodata_value = -9999)
```

## Arguments

- env_vals:

  Named list of numeric vectors (one per environmental variable). All
  vectors must have the same length.

- nodata_value:

  Numeric: sentinel value treated as missing (default `-9999`).

## Value

An integer vector of 1-based indices of samples that have valid
(non-missing) values for *all* environmental variables.

## Examples

``` r
env <- list(
  temp  = c(15, NA, 25, 18, -9999),
  precip = c(100, 200, 150, 80, 300)
)
valid <- maxent_complete_cases(env)
# Returns c(1, 3, 4) -- indices 2 (NA) and 5 (-9999) are removed
```
