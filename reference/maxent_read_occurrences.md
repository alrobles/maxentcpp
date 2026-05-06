# Read Species Occurrence Data

Reads species presence records from a CSV file or an R `data.frame` and
converts them to row/column indices suitable for
[`maxent_featured_space`](https://alrobles.github.io/maxentcpp/reference/maxent_featured_space.md).

## Usage

``` r
maxent_read_occurrences(
  file_or_df,
  dim,
  lon_col = "longitude",
  lat_col = "latitude",
  name_col = NULL
)
```

## Arguments

- file_or_df:

  Either a character path to a CSV file, or a `data.frame` already
  loaded in R (e.g. from `rgbif::occ_data()`, GBIF download, or
  [`read.csv()`](https://rdrr.io/r/utils/read.table.html)).

- dim:

  A GridDimension object (from
  [`maxent_dimension`](https://alrobles.github.io/maxentcpp/reference/maxent_dimension.md))
  defining the study area grid.

- lon_col:

  Character: name of the longitude column (default `"longitude"`).

- lat_col:

  Character: name of the latitude column (default `"latitude"`).

- name_col:

  Character or `NULL`: column for sample names. If `NULL` (default),
  sequential names are generated.

## Value

A named list with:

- samples:

  List of Sample external pointers.

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
dim <- maxent_dimension(100, 100, -120, 35, 0.1)
occ <- data.frame(longitude = c(-118.5, -119.0),
                  latitude  = c(36.5, 37.0))
result <- maxent_read_occurrences(occ, dim)
result$indices  # 0-based flat indices for FeaturedSpace
#> [1] 8515 8010
```
