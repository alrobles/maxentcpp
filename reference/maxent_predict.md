# Predict with a trained FeaturedSpace model

Computes raw Gibbs distribution scores for new environmental data.

## Usage

``` r
maxent_predict(fs_ptr, new_data)
```

## Arguments

- fs_ptr:

  External pointer to a trained FeaturedSpace object.

- new_data:

  Numeric matrix with one row per new point and one column per feature
  (values must be pre-evaluated, i.e., the feature transformation
  already applied).

## Value

Numeric vector of raw scores (unnormalized).
