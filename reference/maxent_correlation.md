# Compute Pearson Correlation

Computes the Pearson correlation coefficient between two numeric
vectors.

## Usage

``` r
maxent_correlation(x, y)
```

## Arguments

- x:

  Numeric vector.

- y:

  Numeric vector (same length as x).

## Value

Correlation coefficient in \[-1, 1\].

## Examples

``` r
maxent_correlation(c(1, 2, 3), c(2, 4, 6))  # 1.0
#> [1] 1
```
