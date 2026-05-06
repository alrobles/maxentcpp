# Generate Features from Environmental Variable Data

Automatically generates all configured feature types from one or more
environmental variable vectors.

## Usage

``` r
maxent_generate_features(
  data,
  types = c("linear", "quadratic", "product", "threshold", "hinge"),
  n_thresholds = 10L,
  n_hinges = 10L
)
```

## Arguments

- data:

  Named list of numeric vectors, one per environmental variable.

- types:

  Character vector of feature types to generate. Valid values:
  `"linear"`, `"quadratic"`, `"product"`, `"threshold"`, `"hinge"`.
  Defaults to all types.

- n_thresholds:

  Integer; number of threshold knots per variable (default: 10).

- n_hinges:

  Integer; number of hinge knots per variable (default: 10).

## Value

Named list of external pointers to Feature C++ objects.

## Examples

``` r
env_data <- list(
  temperature   = c(15, 20, 25, 18, 22),
  precipitation = c(100, 200, 150, 80, 300)
)
features <- maxent_generate_features(env_data, types = c("linear", "hinge"))
length(features)
#> [1] 42
```
