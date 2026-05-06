# Create a Linear Feature

Creates a linear (normalized) feature that evaluates to
`(values[i] - min) / (max - min)`. Returns 0 when `min == max`.

## Usage

``` r
maxent_linear_feature(values, name, min_val = NULL, max_val = NULL)
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

External pointer to a LinearFeature C++ object.

## Examples

``` r
if (FALSE) { # \dontrun{
vals <- c(0, 5, 10, 3)
f <- maxent_linear_feature(vals, "temperature")
maxent_feature_eval(f, 1)  # index 1 (R) → 0-based index 0
} # }
```
