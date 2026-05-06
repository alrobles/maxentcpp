# Write a Variable Importance Bar Chart PNG

Creates a horizontal bar chart comparing percent contribution and
permutation importance for each environmental variable, replicating
`density/Runner.java::makeJackknifePlots()`.

## Usage

``` r
maxent_plot_variable_importance(
  contributions_df,
  perm_imp_df,
  species,
  output_dir
)
```

## Arguments

- contributions_df:

  A data.frame with columns `name` and `contribution` (from
  [`maxent_percent_contribution`](https://alrobles.github.io/maxentcpp/reference/maxent_percent_contribution.md)).

- perm_imp_df:

  A data.frame with columns `name` and `permutation_importance` (from
  [`maxent_permutation_importance`](https://alrobles.github.io/maxentcpp/reference/maxent_permutation_importance.md)).

- species:

  Character: species name (used in the filename).

- output_dir:

  Character: directory under which a `plots/` sub-directory will be
  created.

## Value

Invisibly returns the path to the PNG file.

## Examples

``` r
# \donttest{
maxent_plot_variable_importance(contrib, perm_imp,
  species = "Sp1", output_dir = tempdir())
#> Error: object 'contrib' not found
# }
```
