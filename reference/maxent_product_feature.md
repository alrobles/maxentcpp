# Create a Product Feature

Creates an interaction feature between two environmental variables:
`eval(i) = norm(values1[i]) * norm(values2[i])`.

## Usage

``` r
maxent_product_feature(
  values1,
  values2,
  name,
  min1 = NULL,
  max1 = NULL,
  min2 = NULL,
  max2 = NULL
)
```

## Arguments

- values1:

  Numeric vector for the first environmental variable.

- values2:

  Numeric vector for the second environmental variable (must have the
  same length as `values1`).

- name:

  Character string: feature name/identifier.

- min1:

  Minimum of the first variable. If `NULL` (default), computed as
  `min(values1)`.

- max1:

  Maximum of the first variable. If `NULL` (default), computed as
  `max(values1)`.

- min2:

  Minimum of the second variable. If `NULL` (default), computed as
  `min(values2)`.

- max2:

  Maximum of the second variable. If `NULL` (default), computed as
  `max(values2)`.

## Value

External pointer to a ProductFeature C++ object.

## Examples

``` r
if (FALSE) { # \dontrun{
temp <- c(0, 5, 10)
prec <- c(100, 200, 150)
f <- maxent_product_feature(temp, prec, "temp_x_prec")
} # }
```
