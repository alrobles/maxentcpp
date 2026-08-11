# Convert a terra SpatRaster to a maxentcpp GridFloat

Converts a single-layer
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
into a maxentcpp GridFloat external pointer. The raster must have
exactly one layer and square cells (equal x and y resolution).

## Usage

``` r
maxent_grid_from_terra(r, name = NULL)
```

## Arguments

- r:

  A single-layer
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  object.

- name:

  Character: grid name (default: layer name from the raster).

## Value

External pointer to a GridFloat C++ object.

## Details

`NA` values in the raster are stored as NODATA (sentinel `-9999`).

Requires the terra package (listed in Suggests).

For the raster package, an equivalent workflow is:


      library(raster)
      r <- raster("bio1.tif")
      mat <- as.matrix(r)
      e <- extent(r)
      g <- maxent_grid_from_matrix(mat, xll = e@xmin, yll = e@ymin,
                                   cellsize = res(r)[1],
                                   name = names(r))

## Examples

``` r
if (FALSE) { # \dontrun{
library(terra)
r <- rast("bio1.tif")
g <- maxent_grid_from_terra(r)
maxent_grid_info(g)
} # }
```
