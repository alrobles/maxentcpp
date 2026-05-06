# Create a FeaturedSpace Object

Constructs a MaxEnt FeaturedSpace from background point data, occurrence
sample indices, and a list of pre-built Feature objects.

## Usage

``` r
maxent_featured_space(
  num_points,
  sample_indices,
  features,
  bias_weights = NULL
)
```

## Arguments

- num_points:

  Integer: total number of background points.

- sample_indices:

  Integer vector: 0-based indices (into the background array) of the
  occurrence sample locations.

- features:

  List of external pointers to Feature objects, as returned by
  [`maxent_linear_feature()`](https://alrobles.github.io/maxentcpp/reference/maxent_linear_feature.md),
  [`maxent_hinge_feature()`](https://alrobles.github.io/maxentcpp/reference/maxent_hinge_feature.md),
  [`maxent_generate_features()`](https://alrobles.github.io/maxentcpp/reference/maxent_generate_features.md),
  etc.

- bias_weights:

  Optional numeric vector of per-point bias weights (length
  `num_points`). When supplied, background density is computed as
  `bias[i] * exp(lp[i] - lpn)` instead of the standard
  `exp(lp[i] - lpn)`. This mirrors Java Maxent's `biasFile` parameter.
  Pass `NULL` (default) for uniform (unbiased) background.

## Value

External pointer to a FeaturedSpace C++ object.

## Examples

``` r
n   <- 100L
idx <- 90:99  # 0-based sample indices
env <- seq(0, 1, length.out = n)
f   <- maxent_linear_feature(env, "env1")
fs  <- maxent_featured_space(n, idx, list(f))
```
