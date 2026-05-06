# Compute Java-compatible Marginal Response Curve

Like compute_response_curve() but applies the Java Maxent cloglog:
cloglog_java = 1 - exp(-exp(H) \* raw_java)

## Usage

``` r
compute_response_curve(
  fs_ptr,
  grid_ptrs,
  feature_names,
  var_index,
  n_steps = 100L
)
```

## Arguments

- fs_ptr:

  External pointer to a FeaturedSpace object.

- grid_ptrs:

  List of external pointers to Grid\<float\> objects.

- feature_names:

  Character vector of environment variable names.

- var_index:

  0-based index of the variable to vary.

- n_steps:

  Number of steps across the variable range.

## Value

A data.frame with columns: value, prediction.

## Details

This matches the response curves produced by Java Maxent and dismo.
