# Create a Layer Metadata Object

Create a Layer Metadata Object

## Usage

``` r
maxent_layer(name, type = "Continuous")
```

## Arguments

- name:

  Character: layer name.

- type:

  Character: layer type. One of `"Continuous"`, `"Categorical"`,
  `"Bias"`, `"Mask"`, `"Probability"`, `"Cumulative"`, `"DebiasAvg"`, or
  `"Unknown"`.

## Value

External pointer to a Layer C++ object.
