# Convert Grid to R Matrix

Extracts the data from a GridFloat as an R numeric matrix. NODATA cells
are converted to `NA`.

## Usage

``` r
maxent_grid_to_matrix(grid)
```

## Arguments

- grid:

  External pointer to a GridFloat object.

## Value

Numeric matrix (`nrows` \\\times\\ `ncols`).
