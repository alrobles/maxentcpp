# Extract environmental values for occurrences from a terra SpatRaster

Streams finite raster rows through the same callback-backed provider
path used by
[`maxent_featured_space_from_rast`](https://alrobles.github.io/maxentcpp/reference/maxent_featured_space_from_rast.md),
then returns values at occurrence locations.

## Usage

``` r
maxent_extract_occurrence_env_terra(
  rast,
  occurrences,
  lon_col = "longitude",
  lat_col = "latitude"
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

## Value

Numeric matrix with one row per retained occurrence and one column per
raster layer.
