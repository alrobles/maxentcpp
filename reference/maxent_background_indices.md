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
if (FALSE) { # \dontrun{
dim <- maxent_dimension(100, 100, -120, 35, 0.1)
grid <- maxent_grid(dim, "env1")
bg <- maxent_background_indices(grid, n = 5000, seed = 42)
bg$indices  # 0-based flat indices for FeaturedSpace
} # }
```
