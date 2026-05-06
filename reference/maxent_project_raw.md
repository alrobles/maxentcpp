# Project Model onto Grids (Raw Output)

Produces Java Maxent "raw" scores for every grid cell: \$\$raw =
\frac{exp(lp - lpNorm)}{densityNorm}\$\$

## Usage

``` r
maxent_project_raw(model, env_grids, feature_names)
```

## Arguments

- model:

  External pointer to a FeaturedSpace object.

- env_grids:

  List of external pointers to Grid\<float\> objects.

- feature_names:

  Character vector of environment variable names.

## Value

External pointer to a Grid\<float\> with Java raw scores.

## Details

This matches the raw output of the Java Maxent software and the dismo R
package. See `vignette("PREDICTION_SCALES")` or
`docs/PREDICTION_SCALES.md` for a full description of prediction scales.

## See also

[`maxent_project_cloglog`](https://alrobles.github.io/maxentcpp/reference/maxent_project_cloglog.md),
[`maxent_project_logistic`](https://alrobles.github.io/maxentcpp/reference/maxent_project_logistic.md)
