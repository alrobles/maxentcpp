# Create a Grid Dimension Object

Defines the spatial extent and resolution of a raster grid.

## Usage

``` r
maxent_dimension(nrows, ncols, xll, yll, cellsize)
```

## Arguments

- nrows:

  Number of rows

- ncols:

  Number of columns

- xll:

  X coordinate of lower-left corner

- yll:

  Y coordinate of lower-left corner

- cellsize:

  Cell size (square cells)

## Value

GridDimension object (external pointer)

## Examples

``` r
dim <- maxent_dimension(
  nrows = 100, ncols = 100,
  xll = -120.0, yll = 35.0,
  cellsize = 0.1
)
```
