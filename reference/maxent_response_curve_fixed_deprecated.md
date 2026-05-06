# Compute Response Curve with Fixed Values (deprecated)

Like `maxent_response_curve_deprecated` but the user supplies explicit
fixed values for the non-target variables.

## Usage

``` r
maxent_response_curve_fixed_deprecated(
  model,
  fixed_values,
  feature_names,
  var_index,
  var_min,
  var_max,
  n_steps = 100L
)
```

## Arguments

- model:

  External pointer to a FeaturedSpace object.

- fixed_values:

  Numeric vector of fixed values for each variable.

- feature_names:

  Character vector of environment variable names.

- var_index:

  0-based index of the variable to vary.

- var_min:

  Minimum value of the target variable.

- var_max:

  Maximum value of the target variable.

- n_steps:

  Number of steps (default 100).

## Value

A data.frame with columns: value, prediction.
