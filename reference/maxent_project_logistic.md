# Project Model onto Grids (Logistic Output)

Applies the Java Maxent logistic transform to grid predictions:
\$\$logistic = \frac{exp(H) \cdot raw}{1 + exp(H) \cdot raw}\$\$

## Usage

``` r
maxent_project_logistic(model, env_grids, feature_names)
```

## Arguments

- model:

  External pointer to a FeaturedSpace object.

- env_grids:

  List of external pointers to Grid\<float\> objects.

- feature_names:

  Character vector of environment variable names.

## Value

External pointer to a Grid\<float\> with logistic scores in \[0, 1\].

## Details

where \\H\\ is the model entropy and \\raw\\ is the normalised
probability. This matches the logistic output of Java Maxent and dismo.

## See also

[`maxent_project_raw`](https://alrobles.github.io/maxentcpp/reference/maxent_project_raw.md),
[`maxent_project_cloglog`](https://alrobles.github.io/maxentcpp/reference/maxent_project_cloglog.md)
