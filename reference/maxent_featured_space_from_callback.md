# Create a FeaturedSpace from a streaming background provider

Builds a `FeaturedSpace` by draining a callback-style background
provider (typically backed by a
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
block loop) one tile at a time, then constructing features from the
concatenated `(num_points x num_layers)` matrix via
[`generate_features`](https://alrobles.github.io/maxentcpp/reference/generate_features.md).

## Usage

``` r
maxent_featured_space_from_callback(
  num_points,
  num_layers,
  layer_names,
  sample_indices,
  feature_types,
  n_thresholds,
  n_hinges,
  next_tile_fn,
  reset_fn,
  use_cache = TRUE
)
```

## Arguments

- num_points:

  Integer: total number of finite background points the provider will
  emit (sum of
  [`nrow()`](https://rspatial.github.io/terra/reference/dimensions.html)
  across tiles).

- num_layers:

  Integer: number of environmental variables / raster layers per tile
  row.

- layer_names:

  Character vector of length `num_layers` giving the name for each layer
  / column (used when generating feature names such as `bio1^2`,
  `bio1*bio2`).

- sample_indices:

  Integer vector: 0-based indices of occurrence samples in the
  concatenated background stream.

- feature_types:

  Character vector of feature types to generate. See
  [`maxent_generate_features`](https://alrobles.github.io/maxentcpp/reference/maxent_generate_features.md).

- n_thresholds:

  Number of threshold knots per variable.

- n_hinges:

  Number of hinge knots per variable.

- next_tile_fn:

  R function returning the next tile as a numeric matrix (nrow x
  num_layers), or a 0-row matrix / `NULL` when the stream is exhausted.
  The function is responsible for filtering out rows containing NAs.

- reset_fn:

  R function (no arguments) that rewinds the underlying stream to the
  beginning.

- use_cache:

  Logical; wrap the callback stream in `CachingBackgroundProvider`.

## Value

External pointer to a `FeaturedSpace` object.

## Details

This is the C++ entry point used by
[`maxent_featured_space_from_rast`](https://alrobles.github.io/maxentcpp/reference/maxent_featured_space_from_rast.md);
end users should prefer that R-level wrapper.
