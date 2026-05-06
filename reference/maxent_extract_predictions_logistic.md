# Extract Logistic Predictions at Sample Locations

Gets Java Maxent logistic scores at specific grid cell locations:
\$\$logistic = \frac{exp(H) \cdot raw}{1 + exp(H) \cdot raw}\$\$

## Usage

``` r
maxent_extract_predictions_logistic(
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

Numeric vector of logistic scores in \[0, 1\]. NaN for NODATA cells.

## See also

[`maxent_extract_predictions_raw`](https://alrobles.github.io/maxentcpp/reference/maxent_extract_predictions_raw.md),
[`maxent_project_logistic`](https://alrobles.github.io/maxentcpp/reference/maxent_project_logistic.md)
