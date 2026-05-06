# Create a Hinge Feature

Creates a piecewise-linear hinge feature.

## Usage

``` r
maxent_hinge_feature(values, name, min_knot, max_knot, reverse = FALSE)
```

## Arguments

- values:

  Numeric vector of environmental variable values.

- name:

  Character string: feature name/identifier.

- min_knot:

  Lower knot of the hinge.

- max_knot:

  Upper knot of the hinge (must be strictly greater than `min_knot`).

- reverse:

  Logical; if `TRUE`, use reverse hinge. Default is `FALSE` (forward
  hinge).

## Value

External pointer to a HingeFeature C++ object.

## Details

**Forward hinge** (`reverse = FALSE`):
`eval(i) = max(0, (values[i] - min_knot) / (max_knot - min_knot))`

**Reverse hinge** (`reverse = TRUE`):
`eval(i) = max(0, (max_knot - values[i]) / (max_knot - min_knot))`

## Examples

``` r
vals <- c(0, 5, 10, 3)
f <- maxent_hinge_feature(vals, "temperature_hinge", min_knot = 2, max_knot = 8)
maxent_feature_eval(f, 2)  # values[2] = 5 -> (5-2)/(8-2) = 0.5
#> [1] 0.5
```
