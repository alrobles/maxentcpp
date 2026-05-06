# Create a Layer metadata object

Create a Layer metadata object

## Usage

``` r
create_layer(name, type_str)
```

## Arguments

- name:

  Layer name.

- type_str:

  Type string: "Continuous", "Categorical", "Bias", "Mask",
  "Probability", "Cumulative", "DebiasAvg", or "Unknown".

## Value

External pointer to a Layer object.
