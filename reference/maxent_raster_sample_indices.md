# Convert occurrence coordinates to 0-based stream indices

Maps occurrence cell indices (as produced by
[`terra::cellFromXY`](https://rspatial.github.io/terra/reference/xyCellFrom.html))
into 0-based indices within the concatenated stream of finite (non-NA)
background cells emitted by
[`maxent_featured_space_from_rast`](https://alrobles.github.io/maxentcpp/reference/maxent_featured_space_from_rast.md).

## Usage

``` r
maxent_raster_sample_indices(rast, cells)
```

## Arguments

- rast:

  A
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html).

- cells:

  Integer vector of 1-based cell indices (as returned by
  [`terra::cellFromXY`](https://rspatial.github.io/terra/reference/xyCellFrom.html)).

## Value

Integer vector of 0-based indices within the finite-cell stream.
Occurrence cells that fall on NA raster values (and therefore never
appear in the stream) are silently dropped and a warning is emitted.
