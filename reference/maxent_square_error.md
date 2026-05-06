# Compute Mean Squared Error

Presence sites contribute (1 - pred)^2, absence sites contribute pred^2.

## Usage

``` r
maxent_square_error(presence, absence)
```

## Arguments

- presence:

  Numeric vector of prediction scores at presence sites.

- absence:

  Numeric vector of prediction scores at absence sites.

## Value

Mean squared error.

## Examples

``` r
maxent_square_error(c(1.0, 1.0), c(0.0, 0.0))  # 0.0
#> [1] 0
```
