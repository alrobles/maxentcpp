# Create a Threshold Feature

Creates a binary step feature: `eval(i) = 1` if `values[i] > threshold`,
else `0`.

## Usage

``` r
maxent_threshold_feature(values, name, threshold)
```

## Arguments

- values:

  Numeric vector of environmental variable values.

- name:

  Character string: feature name/identifier.

- threshold:

  The threshold value.

## Value

External pointer to a ThresholdFeature C++ object.

## Examples

``` r
if (FALSE) { # \dontrun{
vals <- c(1, 5, 10, 3)
f <- maxent_threshold_feature(vals, "temperature_threshold", threshold = 5)
maxent_feature_eval(f, 3)  # values[2] = 10 > 5 → 1
} # }
```
