# Read a Grid File (Auto-Detect Format)

Reads a raster grid file. The format is detected from the file
extension. Currently supports `.asc` (ESRI ASCII Grid).

## Usage

``` r
maxent_read_grid(filename)
```

## Arguments

- filename:

  Character: path to the grid file.

## Value

External pointer to a GridFloat C++ object.
