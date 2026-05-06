# Train MaxEnt directly from a terra SpatRaster

High-level convenience wrapper that builds a streaming FeaturedSpace
from `rast`, maps occurrence locations to finite-stream sample indices,
and trains with
[`maxent_fit`](https://alrobles.github.io/maxentcpp/reference/maxent_fit.md).

## Usage

``` r
maxent_train_terra(
  rast,
  occurrences,
  lon_col = "longitude",
  lat_col = "latitude",
  feature_types = c("linear", "quadratic", "product", "threshold", "hinge"),
  n_thresholds = 10L,
  n_hinges = 10L,
  max_iter = 500L,
  convergence = 1e-05,
  beta_multiplier = 1,
  min_deviation = 0.001
)
```

## Arguments

- rast:

  A
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html).

- occurrences:

  Either a two-column matrix/data.frame (x,y) or a vector of 1-based
  raster cell indices.

- lon_col:

  Longitude column name when `occurrences` is a data.frame.

- lat_col:

  Latitude column name when `occurrences` is a data.frame.

- feature_types:

  Feature type set passed to feature generation.

- n_thresholds:

  Number of threshold knots.

- n_hinges:

  Number of hinge knots.

- max_iter:

  Maximum training iterations.

- convergence:

  Convergence threshold.

- beta_multiplier:

  Regularization multiplier.

- min_deviation:

  Minimum deviation floor.

## Value

A named list with training results plus `model` and `sample_indices`.
