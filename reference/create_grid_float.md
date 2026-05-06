# Create a float Grid object

Creates a raster grid for environmental variables

## Usage

``` r
create_grid_float(dim_ptr, name, nodata_value = -9999)
```

## Arguments

- dim_ptr:

  External pointer to GridDimension

- name:

  Grid layer name

- nodata_value:

  Value representing missing data

## Value

External pointer to Grid\<float\> object
