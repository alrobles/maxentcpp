# Create a ThresholdFeature object

Creates a binary step feature: eval(i) = 1.0 if values\[i\] \>
threshold, else 0.0.

## Usage

``` r
create_threshold_feature(values, name, threshold)
```

## Arguments

- values:

  Numeric vector of environmental variable values

- name:

  Feature name/identifier

- threshold:

  The threshold value

## Value

External pointer to ThresholdFeature object
