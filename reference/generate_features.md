# Generate features from a list of environmental variable vectors

Generates all configured feature types (linear, quadratic, product,
threshold, hinge) from the supplied data vectors. Categorical variables
are expanded into binary indicator features (one per distinct level)
instead of the continuous feature types.

## Usage

``` r
generate_features(
  data_list,
  feature_types = as.character(c("linear", "quadratic", "product", "threshold", "hinge")),
  n_thresholds = 10L,
  n_hinges = 10L,
  categorical_indices = as.integer(c())
)
```

## Arguments

- data_list:

  Named list of numeric vectors, one per environmental variable

- feature_types:

  Character vector of feature types to generate. Valid values: "linear",
  "quadratic", "product", "threshold", "hinge". Defaults to all types.

- n_thresholds:

  Number of threshold knots per variable (default: 10)

- n_hinges:

  Number of hinge knots per variable (default: 10)

- categorical_indices:

  Integer vector of 0-based indices identifying which variables in
  `data_list` are categorical (default: empty).

## Value

List of external pointers to Feature objects
