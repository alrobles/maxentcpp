# Create a LinearFeature object

Creates a linear (normalized) feature: eval(i) = (values\[i\] - min) /
(max - min). Returns 0 when min == max.

## Usage

``` r
create_linear_feature(values, name, min_val, max_val)
```

## Arguments

- values:

  Numeric vector of environmental variable values

- name:

  Feature name/identifier

- min_val:

  Minimum value for normalization

- max_val:

  Maximum value for normalization

## Value

External pointer to LinearFeature object
