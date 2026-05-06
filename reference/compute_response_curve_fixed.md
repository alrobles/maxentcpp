# Compute Java-compatible Response Curve with Fixed Values

Like compute_response_curve_fixed() but applies the Java Maxent cloglog:
cloglog_java = 1 - exp(-exp(H) \* raw_java)

## Usage

``` r
compute_response_curve_fixed(
  fs_ptr,
  fixed_values,
  feature_names,
  var_index,
  var_min,
  var_max,
  n_steps = 100L
)
```

## Arguments

- fs_ptr:

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

  Number of steps.

## Value

A data.frame with columns: value, prediction.
