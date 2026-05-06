# Create a Grid from an R Matrix

Builds a GridFloat from a numeric matrix and spatial parameters. `NA`
values in the matrix are stored as the `nodata` value.

## Usage

``` r
maxent_grid_from_matrix(mat, xll, yll, cellsize, nodata = -9999, name = "")
```

## Arguments

- mat:

  Numeric matrix.

- xll:

  X coordinate of lower-left corner.

- yll:

  Y coordinate of lower-left corner.

- cellsize:

  Cell size.

- nodata:

  NODATA sentinel value (default `-9999`).

- name:

  Grid name (default `""`).

## Value

External pointer to a GridFloat C++ object.
