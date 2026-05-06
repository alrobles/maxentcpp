# Compute Marginal Response Curve (deprecated)

Generates a response curve by varying one environmental variable from
its minimum to maximum value while holding all other variables at their
mean. Predictions are cloglog-transformed (\[0, 1\]).

## Usage

``` r
maxent_response_curve_deprecated(
  model,
  env_grids,
  feature_names,
  var_index,
  n_steps = 100L
)
```

## Arguments

- model:

  External pointer to a FeaturedSpace object.

- env_grids:

  List of external pointers to Grid\<float\> objects.

- feature_names:

  Character vector of environment variable names.

- var_index:

  0-based index of the variable to vary.

- n_steps:

  Number of steps across the variable range (default 100).

## Value

A data.frame with columns:

- value:

  Environmental variable value

- prediction:

  Cloglog-transformed prediction
