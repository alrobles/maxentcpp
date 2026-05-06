# Compute Marginal Response Curve

Generates a response curve by varying one environmental variable from
its minimum to maximum value while holding all other variables at their
mean. Applies the Java Maxent cloglog transform, matching the output of
Java Maxent and dismo: \$\$cloglog = 1 - exp(-exp(H) \cdot raw)\$\$

## Usage

``` r
maxent_response_curve(
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

## See also

[`maxent_response_curve_fixed`](https://alrobles.github.io/maxentcpp/reference/maxent_response_curve_fixed.md)

## Examples

``` r
# \donttest{
curve <- maxent_response_curve(model, list(g1, g2),
           c("temp", "precip"), var_index = 0)
#> Error: object 'model' not found
plot(curve$value, curve$prediction, type = "l")
#> Error in curve$value: object of type 'closure' is not subsettable
# }
```
