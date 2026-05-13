# Write Response Curve PNGs for All Variables

Generates response curve plots for each environmental variable and saves
them as PNG files, replicating `density/ResponsePlot.java::makeplot()`.
A full-size PNG and an optional thumbnail are written for every
variable.

## Usage

``` r
maxent_plot_response_curves(
  model,
  env_grids,
  feature_names,
  output_dir,
  species,
  var_indices = NULL,
  n_steps = 100L,
  thumbnail = TRUE,
  write_dat = FALSE
)
```

## Arguments

- model:

  External pointer to a trained FeaturedSpace object.

- env_grids:

  List of external pointers to Grid\<float\> objects.

- feature_names:

  Character vector of environment variable names (one entry per element
  of `env_grids`).

- output_dir:

  Character: directory under which a `plots/` sub-directory will be
  created.

- species:

  Character: species name (used in file names).

- var_indices:

  Integer vector of 0-based variable indices to plot. Defaults to all
  variables.

- n_steps:

  Integer: number of steps in each curve (default 100).

- thumbnail:

  Logical: also write a 210 × 140 pixel thumbnail PNG (default `TRUE`).

- write_dat:

  Logical: also write a tab-delimited `.dat` file of the curve data
  (default `FALSE`).

## Value

Invisibly returns a named list of file paths written.

## Examples

``` r
# \donttest{
maxent_plot_response_curves(
  model, list(g1, g2), c("bio1", "bio12"),
  output_dir = tempdir(), species = "Sp1")
#> Error: object 'model' not found
# }
```
