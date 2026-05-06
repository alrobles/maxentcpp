# Extract multiple values from a Grid at given row/col indices (batch)

Extract multiple values from a Grid at given row/col indices (batch)

## Usage

``` r
grid_get_values_batch(grid_ptr, rows, cols)
```

## Arguments

- grid_ptr:

  External pointer to a Grid\<float\>.

- rows:

  Integer vector of 0-based row indices.

- cols:

  Integer vector of 0-based column indices.

## Value

Numeric vector of extracted values (NA for NODATA cells).
