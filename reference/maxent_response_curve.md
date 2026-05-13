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
set.seed(42)
n <- 50L; idx <- c(5L, 15L, 25L, 35L, 45L)
env <- list(temp = runif(n), precip = runif(n))
feats <- maxent_generate_features(env, types = "linear")
model <- maxent_featured_space(n, idx, feats)
maxent_fit(model, max_iter = 100)
#> $loss
#> [1] 3.781356
#> 
#> $entropy
#> [1] 3.887762
#> 
#> $iterations
#> [1] 100
#> 
#> $converged
#> [1] FALSE
#> 
#> $lambdas
#> [1] 0.6202339 0.4108689
#> 
g1 <- maxent_grid_from_matrix(matrix(env$temp, 5, 10),
        -120, 35, 1, name = "temp")
g2 <- maxent_grid_from_matrix(matrix(env$precip, 5, 10),
        -120, 35, 1, name = "precip")
curve <- maxent_response_curve(model, list(g1, g2),
           c("temp", "precip"), var_index = 0)
plot(curve$value, curve$prediction, type = "l")

# }
```
