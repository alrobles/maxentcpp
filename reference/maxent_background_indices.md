# Generate Background Sample Indices

Randomly selects valid (non-NODATA) cells from a reference grid for use
as background points in MaxEnt modeling.

## Usage

``` r
maxent_background_indices(grid, n = 10000L, seed = NULL)
```

## Arguments

- grid:

  External pointer to a GridFloat object used as a reference (e.g. an
  environmental layer). Only cells with valid data are eligible.

- n:

  Integer: number of background points to sample (default `10000L`).

- seed:

  Integer or `NULL`: random seed for reproducibility. If `NULL`
  (default), no seed is set.

## Value

A named list with:

- rows:

  Integer vector of row indices (0-based).

- cols:

  Integer vector of column indices (0-based).

- indices:

  Integer vector of 0-based flat indices (`row * ncols + col`), suitable
  for
  [`maxent_featured_space`](https://alrobles.github.io/maxentcpp/reference/maxent_featured_space.md).

## Examples

``` r
# \donttest{
g <- maxent_grid_from_matrix(matrix(runif(100), 10, 10),
        -120, 35, 0.1, name = "env1")
bg <- maxent_background_indices(g, n = 50, seed = 42)
bg$indices  # 0-based flat indices for FeaturedSpace
#>  [1] 84 46 42 37 71 99 64 32  7 88 63 91 52 20  4 62 53 40 33 68 75 14 29 92 24
#> [26] 41 12 97 70 38 76 59 30 94 49 78 66 50 26 10 15  8 35  2  6 45 73 90 93 28
# }
```
