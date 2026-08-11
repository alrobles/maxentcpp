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
if (FALSE) { # \dontrun{
# After training, predict on 5 new points with 2 features each
newdata <- matrix(runif(10), nrow = 5, ncol = 2)
preds <- maxent_predict_model(fs, newdata)
} # }
```
