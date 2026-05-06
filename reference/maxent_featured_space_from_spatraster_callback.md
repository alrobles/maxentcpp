# Create a FeaturedSpace from a terra SpatRaster callback stream

Same as
[`maxent_featured_space_from_callback()`](https://alrobles.github.io/maxentcpp/reference/maxent_featured_space_from_callback.md),
but also preserves the source `SpatRaster` S4 object for provider
lifetime safety and can enable streaming-eval mode immediately.

## Usage

``` r
maxent_featured_space_from_spatraster_callback(
  preserved_rast,
  rast_xptr,
  num_points,
  num_layers,
  layer_names,
  sample_indices,
  feature_types,
  n_thresholds,
  n_hinges,
  next_tile_fn,
  reset_fn,
  enable_streaming_eval = TRUE,
  use_cache = TRUE
)
```

## Arguments

- preserved_rast:

  A terra `SpatRaster` S4 object to preserve.

- rast_xptr:

  External pointer extracted from the raster object (used for contract
  validation).

- num_points:

  Integer; total number of finite background points.

- num_layers:

  Integer; number of environmental variables per row.

- layer_names:

  Character vector of layer names (length num_layers).

- sample_indices:

  Integer vector; 0-based indices of presence samples.

- feature_types:

  Character vector of feature types to generate.

- n_thresholds:

  Integer; number of threshold knots per variable.

- n_hinges:

  Integer; number of hinge knots per variable.

- next_tile_fn:

  R function returning the next tile or NULL/0-row matrix.

- reset_fn:

  R function (no args) that rewinds the underlying stream.

- enable_streaming_eval:

  Logical; whether to enable streaming eval mode.

- use_cache:

  Logical; wrap the stream in `CachingBackgroundProvider`.

## Value

External pointer to a FeaturedSpace object.
