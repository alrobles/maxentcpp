# Get grid information for an ASC-loaded grid

Returns metadata and basic statistics for a GridFloat.

## Usage

``` r
grid_float_info(grid_ptr)
```

## Arguments

- grid_ptr:

  External pointer to a GridFloat object.

## Value

Named list with nrows, ncols, xll, yll, cellsize, nodata, name,
count_data.
