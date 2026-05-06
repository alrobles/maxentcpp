# Project Model onto Grids (Raw Output, deprecated)

Applies a trained FeaturedSpace model to environmental grids to produce
raw Gibbs scores for every cell.

## Usage

``` r
maxent_project_raw_deprecated(model, env_grids, feature_names)
```

## Arguments

- model:

  External pointer to a FeaturedSpace object.

- env_grids:

  List of external pointers to Grid\<float\> objects.

- feature_names:

  Character vector of environment variable names, matching the order of
  env_grids.

## Value

External pointer to a Grid\<float\> with raw prediction scores.
