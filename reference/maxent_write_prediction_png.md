# Write a Maxent Prediction Grid as a PNG Image

Converts a `GridFloat` prediction grid to a colour PNG image using the
canonical Maxent colour ramp (red = high, blue = low). Optionally
overlays presence and test-point locations, and renders a small legend.

## Usage

``` r
maxent_write_prediction_png(
  grid,
  filename,
  presence_rows = NULL,
  presence_cols = NULL,
  test_rows = NULL,
  test_cols = NULL,
  mode = "plain",
  legend = TRUE,
  width = 800L,
  height = 600L
)
```

## Arguments

- grid:

  External pointer to a GridFloat prediction grid (e.g. from
  [`maxent_project_cloglog`](https://alrobles.github.io/maxentcpp/reference/maxent_project_cloglog.md)).

- filename:

  Character: path for the output PNG file.

- presence_rows:

  Integer vector of presence row indices (0-based) or `NULL` (default).

- presence_cols:

  Integer vector of presence column indices (0-based) or `NULL`
  (default).

- test_rows:

  Integer vector of test-set row indices (0-based) or `NULL` (default).

- test_cols:

  Integer vector of test-set column indices (0-based) or `NULL`
  (default).

- mode:

  Colour mode passed to
  [`maxent_color_ramp`](https://alrobles.github.io/maxentcpp/reference/maxent_color_ramp.md):
  one of `"plain"` (default), `"log"`, `"blackandwhite"`, or
  `"redandyellow"`.

- legend:

  Logical: draw a colour-bar legend (default `TRUE`).

- width:

  Integer: PNG width in pixels (default 800).

- height:

  Integer: PNG height in pixels (default 600).

## Value

Invisibly returns `filename`.

## Examples

``` r
if (FALSE) { # \dontrun{
pred <- maxent_project_cloglog(model, list(g1, g2), c("bio1", "bio12"))
maxent_write_prediction_png(pred, "prediction.png")
} # }
```
