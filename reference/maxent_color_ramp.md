# Generate the Maxent Canonical Color Ramp

Produces a vector of hex color strings matching the color ramp used by
the Java Maxent software (`density/Display.java::showColor()`). The
default palette cycles Red → Yellow → Green → Cyan → Blue across 1020
steps, with higher values rendered as red and lower values as blue.

## Usage

``` r
maxent_color_ramp(n = 1020L, mode = "plain")
```

## Arguments

- n:

  Integer: number of colors to generate (default 1020, matching the Java
  implementation).

- mode:

  Character: one of `"plain"` (default), `"log"` (logarithmic spacing),
  `"blackandwhite"` (greyscale, white = high, black = low), or
  `"redandyellow"` (red–yellow ramp).

## Value

Character vector of `n` hex color strings of the form `"#RRGGBB"`.

## Examples

``` r
pal <- maxent_color_ramp(1020)
pal[1]     # "#FF0000"  (max value → red)
#> [1] "#FF0000"
pal[510]   # near "#00FF00" (mid-point → green)
#> [1] "#00FF00"
pal[1020]  # "#0000FF"  (min value → blue)
#> [1] "#0000FF"
```
