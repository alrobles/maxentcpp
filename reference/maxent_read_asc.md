# Read an ESRI ASCII Grid File

Reads a `.asc` raster file into a GridFloat object.

## Usage

``` r
maxent_read_asc(filename)
```

## Arguments

- filename:

  Character: path to the `.asc` file.

## Value

External pointer to a GridFloat C++ object.

## Examples

``` r
if (FALSE) { # \dontrun{
g <- maxent_read_asc("bio1.asc")
info <- maxent_grid_info(g)
print(info)
} # }
```
