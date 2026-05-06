# Set sample expectations for a FeaturedSpace

Computes sample expectations and regularization deviations for each
feature. Called automatically by
[`maxent_train()`](https://alrobles.github.io/maxentcpp/reference/maxent_train.md),
but exposed for advanced use.

## Usage

``` r
maxent_set_sample_expectations(
  fs_ptr,
  beta_multiplier = 1,
  min_deviation = 0.001
)
```

## Arguments

- fs_ptr:

  External pointer to a FeaturedSpace object.

- beta_multiplier:

  Regularization multiplier (default 1.0).

- min_deviation:

  Minimum sample deviation (default 0.001).

## Value

Called for side effects; returns invisibly.
