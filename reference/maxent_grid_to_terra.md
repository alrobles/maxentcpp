# Convert a maxentcpp GridFloat to a terra SpatRaster

Creates a
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
from a maxentcpp GridFloat external pointer.

## Usage

``` r
maxent_grid_to_terra(grid, crs = "EPSG:4326")
```

## Arguments

- grid:

  External pointer to a GridFloat C++ object.

- crs:

  Character: coordinate reference system string (default `"EPSG:4326"`,
  i.e. WGS 84 longitude/latitude).

## Value

A single-layer
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html).

## Details

Requires the terra package (listed in Suggests).

For the raster package, an equivalent workflow is:


      library(raster)
      info <- maxent_grid_info(grid)
      mat  <- maxent_grid_to_matrix(grid)
      r <- raster(mat,
                  xmn = info$xll,
                  xmx = info$xll + info$ncols * info$cellsize,
                  ymn = info$yll,
                  ymx = info$yll + info$nrows * info$cellsize,
                  crs = "+proj=longlat +datum=WGS84")

## Examples

``` r
if (FALSE) { # \dontrun{
# Round-trip: terra → maxentcpp → terra
library(terra)
r <- rast("bio1.tif")
g <- maxent_grid_from_terra(r)
r2 <- maxent_grid_to_terra(g)
plot(r2)
} # }
```
