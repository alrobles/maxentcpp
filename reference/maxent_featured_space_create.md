# Create a FeaturedSpace object

Constructs a MaxEnt FeaturedSpace from background point count,
occurrence sample indices, and a list of Feature objects.

## Usage

``` r
maxent_featured_space_create(
  num_points,
  sample_indices,
  feature_ptrs,
  bias_weights = numeric(0)
)
```

## Arguments

- num_points:

  Integer: number of background points.

- sample_indices:

  Integer vector: 0-based indices of occurrence samples in the
  background array.

- feature_ptrs:

  List of external pointers to Feature objects (from
  [`create_linear_feature()`](https://alrobles.github.io/maxentcpp/reference/create_linear_feature.md)
  etc.).

- bias_weights:

  Optional numeric vector of per-point bias weights (length
  `num_points`). When supplied, background density is computed as
  `bias[i] * exp(lp[i] - lpn)` instead of the standard
  `exp(lp[i] - lpn)`. Pass an empty vector (default) for uniform
  (unbiased) background.

## Value

External pointer to a FeaturedSpace object.
