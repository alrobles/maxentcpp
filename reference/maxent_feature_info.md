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
vals <- c(0, 5, 10)
f <- maxent_linear_feature(vals, "temp")
maxent_feature_info(f)
#> $name
#> [1] "temp"
#> 
#> $type
#> [1] "linear"
#> 
#> $lambda
#> [1] 0
#> 
#> $min
#> [1] 0
#> 
#> $max
#> [1] 10
#> 
#> $size
#> [1] 3
#> 
```
