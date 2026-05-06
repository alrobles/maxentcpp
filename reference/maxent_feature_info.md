# Get Feature Properties

Returns a list of metadata for a feature object.

## Usage

``` r
maxent_feature_info(feature)
```

## Arguments

- feature:

  External pointer to a Feature C++ object.

## Value

Named list with elements: `name`, `type`, `lambda`, `min`, `max`,
`size`.

## Examples

``` r
if (FALSE) { # \dontrun{
vals <- c(0, 5, 10)
f <- maxent_linear_feature(vals, "temp")
maxent_feature_info(f)
} # }
```
