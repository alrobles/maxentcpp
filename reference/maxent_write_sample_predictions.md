# Write Sample Predictions CSV

Computes model predictions at presence (and optionally test) locations
and writes `<output_dir>/<species>_samplePredictions.csv`.

## Usage

``` r
maxent_write_sample_predictions(
  model,
  env_grids,
  feature_names,
  presence_rows,
  presence_cols,
  output_dir,
  species,
  test_rows = NULL,
  test_cols = NULL
)
```

## Arguments

- model:

  External pointer to a trained FeaturedSpace object.

- env_grids:

  List of external pointers to Grid\<float\> objects.

- feature_names:

  Character vector of environment variable names.

- presence_rows:

  Integer vector of presence row indices (0-based).

- presence_cols:

  Integer vector of presence column indices (0-based).

- output_dir:

  Character: directory for the output file.

- species:

  Character: species name (used in the filename).

- test_rows:

  Integer vector of test row indices (0-based) or `NULL` (default).

- test_cols:

  Integer vector of test column indices (0-based) or `NULL` (default).

## Value

Invisibly returns the path to the written CSV.

## Examples

``` r
if (FALSE) { # \dontrun{
maxent_write_sample_predictions(model, list(g1, g2), c("bio1", "bio12"),
  pres_rows, pres_cols, output_dir = tempdir(), species = "Sp1")
} # }
```
