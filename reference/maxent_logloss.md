# Compute Log-Loss

Computes the average cross-entropy log-loss from predictions at presence
and absence sites.

## Usage

``` r
maxent_logloss(presence, absence)
```

## Arguments

- presence:

  Numeric vector of prediction scores at presence sites.

- absence:

  Numeric vector of prediction scores at absence sites.

## Value

Average log-loss value (lower is better).

## Examples

``` r
maxent_logloss(c(0.9, 0.8), c(0.1, 0.2))
#> [1] 0.164252
```
