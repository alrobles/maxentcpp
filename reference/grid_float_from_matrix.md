# Create a GridFloat from an R matrix

Create a GridFloat from an R matrix

## Usage

``` r
grid_float_from_matrix(mat, xll, yll, cellsize, nodata = -9999, name = "")
```

## Arguments

- mat:

  Numeric matrix with grid data (NA becomes NODATA).

- xll:

  X coordinate of lower-left corner.

- yll:

  Y coordinate of lower-left corner.

- cellsize:

  Cell size.

- nodata:

  NODATA value (default -9999).

- name:

  Grid name (default "").

## Value

External pointer to a GridFloat object.
