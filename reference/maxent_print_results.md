# Print Maxent Model Results

Prints a summary of Maxent model performance metrics to the console,
replicating the style of the dismo package's MaxEnt output. The report
includes sample counts, training (and optionally test) evaluation
statistics, and a ranked variable-contributions table.

## Usage

``` r
maxent_print_results(
  species,
  eval_result,
  contributions_df,
  perm_imp_df,
  n_presence,
  n_background,
  test_eval_result = NULL,
  n_test = 0L,
  fit_result = NULL
)
```

## Arguments

- species:

  Character: species name.

- eval_result:

  Named list returned by
  [`maxent_evaluate`](https://alrobles.github.io/maxentcpp/reference/maxent_evaluate.md)
  (training predictions vs background).

- contributions_df:

  Data.frame with columns `name` and `contribution` (from
  [`maxent_percent_contribution`](https://alrobles.github.io/maxentcpp/reference/maxent_percent_contribution.md)).

- perm_imp_df:

  Data.frame with columns `name` and `permutation_importance` (from
  [`maxent_permutation_importance`](https://alrobles.github.io/maxentcpp/reference/maxent_permutation_importance.md)).

- n_presence:

  Integer: number of training presence records.

- n_background:

  Integer: number of background records.

- test_eval_result:

  Named list returned by
  [`maxent_evaluate`](https://alrobles.github.io/maxentcpp/reference/maxent_evaluate.md)
  for test data, or `NULL` (default).

- n_test:

  Integer: number of test presence records (default `0L`).

- fit_result:

  Named list returned by
  [`maxent_fit`](https://alrobles.github.io/maxentcpp/reference/maxent_fit.md)
  or `NULL`. Used to report regularized training gain and entropy.

## Value

Invisibly returns a named list with all reported metrics.

## Examples

``` r
# \donttest{
maxent_print_results(
  species          = "Sp1",
  eval_result      = maxent_evaluate(pres_preds, bg_preds),
  contributions_df = contrib,
  perm_imp_df      = perm_imp,
  n_presence       = length(pres_rows),
  n_background     = length(bg_rows))
#> class         : MaxEnt
#> species       : Sp1
#> Error: object 'pres_rows' not found
# }
```
