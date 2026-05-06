# Extract Java-compatible Raw Predictions at Sample Locations

Gets Java Maxent raw scores (raw_java = exp(lp - lpNorm) / densityNorm)
at specific grid cell locations.

## Usage

``` r
extract_predictions_raw(fs_ptr, grid_ptrs, feature_names, rows, cols)
```

## Arguments

- fs_ptr:

  External pointer to a FeaturedSpace object.

- grid_ptrs:

  List of external pointers to Grid\<float\> objects.

- feature_names:

  Character vector of environment variable names.

- rows:

  Integer vector of row indices.

- cols:

  Integer vector of column indices.

## Value

Numeric vector of Java raw scores. NaN for NODATA cells.
