# Extract occurrence environmental values from a callback stream

Drains a callback background stream once and returns the rows at the
requested 0-based finite-stream indices.

## Usage

``` r
maxent_extract_occurrence_from_callback(
  num_points,
  num_layers,
  occurrence_indices,
  next_tile_fn,
  reset_fn,
  preserved_rast = NULL
)
```

## Arguments

- num_points:

  Integer; total finite background rows in stream.

- num_layers:

  Integer; number of environmental variables per row.

- occurrence_indices:

  Integer vector of 0-based finite-stream indices.

- next_tile_fn:

  R function returning the next tile or NULL/0-row matrix.

- reset_fn:

  R function (no args) that rewinds the underlying stream.

- preserved_rast:

  Optional SpatRaster object to preserve during read.

## Value

Numeric matrix with one row per requested occurrence index.
