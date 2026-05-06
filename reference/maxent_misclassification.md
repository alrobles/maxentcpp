# Compute Misclassification Rate

Fraction of misclassified samples at threshold 0.5.

## Usage

``` r
maxent_misclassification(presence, absence)
```

## Arguments

- presence:

  Numeric vector of prediction scores at presence sites.

- absence:

  Numeric vector of prediction scores at absence sites.

## Value

Misclassification rate in \[0, 1\].

## Examples

``` r
maxent_misclassification(c(0.8, 0.9), c(0.1, 0.2))  # 0.0
#> [1] 0
```
