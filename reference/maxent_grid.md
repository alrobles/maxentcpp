# Create a Grid Object

Creates a raster grid for storing environmental variable data.

## Usage

``` r
maxent_grid(dim, name = "", nodata_value = -9999)
```

## Arguments

- dim:

  GridDimension object defining spatial extent

- name:

  Grid layer name

- nodata_value:

  Value representing missing data (default: -9999)

## Value

Grid object (external pointer)

## Examples

``` r
if (FALSE) { # \dontrun{
dim <- maxent_dimension(100, 100, -120, 35, 0.1)
grid <- maxent_grid(dim, "temperature")
} # }
```
