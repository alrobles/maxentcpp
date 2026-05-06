# Project Model onto Grids (Cloglog Output)

Applies the Java Maxent cloglog transform to grid predictions:
\$\$cloglog = 1 - exp(-exp(H) \cdot raw)\$\$

## Usage

``` r
maxent_project_cloglog(model, env_grids, feature_names)
```

## Arguments

- model:

  External pointer to a FeaturedSpace object.

- env_grids:

  List of external pointers to Grid\<float\> objects.

- feature_names:

  Character vector of environment variable names.

## Value

External pointer to a Grid\<float\> with cloglog scores in \[0, 1\].

## Details

where \\H\\ is the model entropy and \\raw\\ is the normalised
probability. This matches the cloglog output of Java Maxent and dismo,
and is the recommended output for reporting.

## See also

[`maxent_project_raw`](https://alrobles.github.io/maxentcpp/reference/maxent_project_raw.md),
[`maxent_project_logistic`](https://alrobles.github.io/maxentcpp/reference/maxent_project_logistic.md)
