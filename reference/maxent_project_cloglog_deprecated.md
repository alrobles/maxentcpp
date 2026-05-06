# Project Model onto Grids (Cloglog Output, deprecated)

cloglog(x) = 1 - exp(-x). Produces values in \[0, 1\].

## Usage

``` r
maxent_project_cloglog_deprecated(model, env_grids, feature_names)
```

## Arguments

- model:

  External pointer to a FeaturedSpace object.

- env_grids:

  List of external pointers to Grid\<float\> objects.

- feature_names:

  Character vector of environment variable names.

## Value

External pointer to a Grid\<float\> with cloglog scores.
