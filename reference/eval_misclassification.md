# Compute Misclassification Rate

Fraction of misclassified samples at threshold 0.5.

## Usage

``` r
eval_misclassification(presence, absence)
```

## Arguments

- presence:

  Numeric vector of prediction scores at presence sites.

- absence:

  Numeric vector of prediction scores at absence sites.

## Value

Misclassification rate in \[0, 1\].
