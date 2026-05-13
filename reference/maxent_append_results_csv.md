# Append a Row to maxentResults.csv

Appends one row of species-level summary statistics to a
`maxentResults.csv` file, creating the file (with a header) if it does
not yet exist. Column names match the Java Maxent output for cross-tool
compatibility.

## Usage

``` r
maxent_append_results_csv(
  results_file,
  species,
  n_training,
  n_test = 0L,
  training_gain,
  training_auc,
  test_gain = NA_real_,
  test_auc = NA_real_,
  entropy,
  contributions_df,
  perm_imp_df
)
```

## Arguments

- results_file:

  Character: path to the results CSV file.

- species:

  Character: species name.

- n_training:

  Integer: number of training presence points.

- n_test:

  Integer: number of test presence points (default 0).

- training_gain:

  Numeric: regularized training gain.

- training_auc:

  Numeric: training AUC.

- test_gain:

  Numeric or `NA`: regularized test gain.

- test_auc:

  Numeric or `NA`: test AUC.

- entropy:

  Numeric: model entropy.

- contributions_df:

  A data.frame with columns `name` and `contribution` (from
  [`maxent_percent_contribution`](https://alrobles.github.io/maxentcpp/reference/maxent_percent_contribution.md)).

- perm_imp_df:

  A data.frame with columns `name` and `permutation_importance` (from
  [`maxent_permutation_importance`](https://alrobles.github.io/maxentcpp/reference/maxent_permutation_importance.md)).

## Value

Invisibly returns `results_file`.

## Examples

``` r
# \donttest{
contrib <- data.frame(name = c("bio1", "bio12"),
                      contribution = c(60, 40))
perm_imp <- data.frame(name = c("bio1", "bio12"),
                       permutation_importance = c(55, 45))
maxent_append_results_csv(
  file.path(tempdir(), "maxentResults.csv"),
  species = "Sp1", n_training = 50L, training_gain = 1.23,
  training_auc = 0.95, entropy = 6.7,
  contributions_df = contrib, perm_imp_df = perm_imp)
# }
```
