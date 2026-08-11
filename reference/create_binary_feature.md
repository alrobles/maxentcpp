# Create a BinaryFeature object (categorical indicator)

Creates a binary feature that evaluates to 1.0 when the underlying value
equals the target category value, 0.0 otherwise.

## Usage

``` r
create_binary_feature(values, name, target)
```

## Arguments

- values:

  Numeric vector of categorical variable values

- name:

  Feature name/identifier

- target:

  The category value to test for

## Value

External pointer to BinaryFeature object
