# Create a Quadratic Feature

Creates a quadratic feature that evaluates to `linear_val^2` where
`linear_val = (values[i] - min) / (max - min)`.

## Usage

``` r
maxent_quadratic_feature(values, name, min_val = NULL, max_val = NULL)
```

## Arguments

- values:

  Numeric vector of environmental variable values.

- name:

  Character string: feature name/identifier.

- min_val:

  Minimum value for normalization. If `NULL` (default), computed as
  `min(values)`.

- max_val:

  Maximum value for normalization. If `NULL` (default), computed as
  `max(values)`.

## Value

External pointer to a QuadraticFeature C++ object.

## Examples

``` r
if (FALSE) { # \dontrun{
vals <- c(0, 5, 10)
f <- maxent_quadratic_feature(vals, "temperature_sq")
maxent_feature_eval(f, 2)  # evaluates at index 2 (1-based → 0-based: 1)
} # }
```
