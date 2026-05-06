# Create a QuadraticFeature object

Creates a quadratic feature: eval(i) = linear_val^2 where linear_val =
(values\[i\] - min) / (max - min).

## Usage

``` r
create_quadratic_feature(values, name, min_val, max_val)
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

External pointer to QuadraticFeature object
