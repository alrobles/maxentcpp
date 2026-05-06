# Extract Cloglog Predictions at Sample Locations

Gets Java Maxent cloglog scores at specific grid cell locations:
\$\$cloglog = 1 - exp(-exp(H) \cdot raw)\$\$

## Usage

``` r
maxent_extract_predictions_cloglog(model, env_grids, feature_names, rows, cols)
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

Numeric vector of cloglog scores in \[0, 1\]. NaN for NODATA cells.

## See also

[`maxent_extract_predictions_raw`](https://alrobles.github.io/maxentcpp/reference/maxent_extract_predictions_raw.md),
[`maxent_project_cloglog`](https://alrobles.github.io/maxentcpp/reference/maxent_project_cloglog.md)
