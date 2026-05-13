# Predict with a Trained MaxEnt Model

Computes raw Gibbs distribution scores for new environmental data, using
the feature lambdas stored in the trained FeaturedSpace.

## Usage

``` r
maxent_predict_model(featured_space, newdata)
```

## Arguments

- featured_space:

  External pointer to a trained FeaturedSpace object.

- newdata:

  Numeric matrix: one row per new point, one column per feature. Column
  values must be the *already-evaluated* feature values (e.g., from
  running
  [`maxent_feature_eval()`](https://alrobles.github.io/maxentcpp/reference/maxent_feature_eval.md)
  for each feature and each point).

## Value

Numeric vector of raw (unnormalized) prediction scores.

## Examples

``` r
# \donttest{
n   <- 50L
idx <- c(5L, 15L, 25L, 35L, 45L)
env <- list(bio1 = runif(n), bio12 = runif(n))
feats <- maxent_generate_features(env, types = "linear")
fs  <- maxent_featured_space(n, idx, feats)
maxent_fit(fs, max_iter = 100)
#> $loss
#> [1] 3.912023
#> 
#> $entropy
#> [1] 3.912023
#> 
#> $iterations
#> [1] 21
#> 
#> $converged
#> [1] TRUE
#> 
#> $lambdas
#> [1] 0 0
#> 
newdata <- matrix(runif(10), nrow = 5, ncol = 2)
preds <- maxent_predict_model(fs, newdata)
# }
```
