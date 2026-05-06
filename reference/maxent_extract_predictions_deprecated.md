# Extract Predictions at Sample Locations (deprecated)

Gets model predictions at specific grid cell locations.

## Usage

``` r
maxent_extract_predictions_deprecated(
  model,
  env_grids,
  feature_names,
  rows,
  cols
)
```

## Arguments

- model:

  External pointer to a FeaturedSpace object.

- env_grids:

  List of external pointers to Grid\<float\> objects.

- feature_names:

  Character vector of environment variable names.

- rows:

  Integer vector of row indices.

- cols:

  Integer vector of column indices.

## Value

Numeric vector of raw prediction scores. NaN for NODATA cells.
