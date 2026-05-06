# Create a GridDimension object

Creates a grid dimension specifying the spatial extent and resolution

## Usage

``` r
create_grid_dimension(nrows, ncols, xll, yll, cellsize)
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

  Cell size (assumed square cells)

## Value

External pointer to GridDimension object
