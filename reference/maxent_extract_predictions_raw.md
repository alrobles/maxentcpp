# Extract Raw Predictions at Sample Locations

Gets Java Maxent raw scores at specific grid cell locations: \$\$raw =
\frac{exp(lp - lpNorm)}{densityNorm}\$\$

## Usage

``` r
maxent_extract_predictions_raw(model, env_grids, feature_names, rows, cols)
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

Numeric vector of Java raw scores. NaN for NODATA cells.

## Details

This matches the raw output of Java Maxent and dismo.

## See also

[`maxent_project_raw`](https://alrobles.github.io/maxentcpp/reference/maxent_project_raw.md)
