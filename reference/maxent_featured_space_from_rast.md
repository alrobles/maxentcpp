# Create a FeaturedSpace directly from a terra SpatRaster

Streams a
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
block-by-block into the C++ `FeaturedSpace` streaming constructor,
filtering NA cells on the fly and handing the concatenated (`num_points`
x `nlyr(rast)`) matrix to
[`maxent_generate_features`](https://alrobles.github.io/maxentcpp/reference/maxent_generate_features.md)
so feature objects are built inside C++ without the R caller having to
materialise the full raster stack first.

## Usage

``` r
maxent_featured_space_from_rast(
  rast,
  sample_indices,
  feature_types = c("linear", "quadratic", "product", "threshold", "hinge"),
  n_thresholds = 10L,
  n_hinges = 10L,
  enable_streaming_eval = TRUE
)
```

## Arguments

- rast:

  A
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  with one layer per environmental variable. Layers must be named; names
  are passed through to
  [`maxent_generate_features`](https://alrobles.github.io/maxentcpp/reference/maxent_generate_features.md)
  so generated features carry the same identifiers as the layer names
  (e.g. `bio1^2`, `bio1*bio2`).

- sample_indices:

  Integer vector: 0-based indices of occurrence samples in the
  concatenated stream of finite background cells. See
  [`maxent_raster_sample_indices`](https://alrobles.github.io/maxentcpp/reference/maxent_raster_sample_indices.md)
  for a helper that converts occurrence `data.frame`s into these
  indices.

- feature_types:

  Character vector of feature types to generate. Any subset of
  `c("linear", "quadratic", "product", "threshold", "hinge")`. Defaults
  to all types.

- n_thresholds:

  Integer; number of threshold knots per variable.

- n_hinges:

  Integer; number of hinge knots per variable.

- enable_streaming_eval:

  Logical; when `TRUE`, enables streaming-evaluation mode after object
  construction.

## Value

External pointer to a `FeaturedSpace` object.

## Details

This is the Phase E.2 entry point described in
`docs/ARCHITECTURE_terra_raster.md` (sections 3.1 and 3.2). The result
is bit-for-bit identical to the dense path
([`maxent_generate_features`](https://alrobles.github.io/maxentcpp/reference/maxent_generate_features.md)
-\>
[`maxent_featured_space`](https://alrobles.github.io/maxentcpp/reference/maxent_featured_space.md))
when the same data, sample indices, and feature configuration are used.

## See also

[`maxent_featured_space`](https://alrobles.github.io/maxentcpp/reference/maxent_featured_space.md),
[`maxent_featured_space_from_callback`](https://alrobles.github.io/maxentcpp/reference/maxent_featured_space_from_callback.md),
[`maxent_generate_features`](https://alrobles.github.io/maxentcpp/reference/maxent_generate_features.md).

## Examples

``` r
# \donttest{
if (requireNamespace("terra", quietly = TRUE)) {
  stack_path <- system.file("extdata", "stack_1_12_crop.rds",
                           package = "maxentcpp")
  r <- terra::unwrap(readRDS(stack_path))
  fs <- maxent_featured_space_from_rast(
      r,
      sample_indices = c(0L, 1L, 2L),
      feature_types  = c("linear", "quadratic")
  )
}
# }
```
