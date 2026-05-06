# Extract the data from a GridFloat as an R matrix

Extract the data from a GridFloat as an R matrix

## Usage

``` r
grid_float_to_matrix(grid_ptr)
```

## Arguments

- grid_ptr:

  External pointer to a GridFloat object.

## Value

Numeric matrix (nrows × ncols). NODATA cells are set to NA.
