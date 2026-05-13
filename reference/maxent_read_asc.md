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
# \donttest{
g <- maxent_grid_from_matrix(matrix(runif(50), 5, 10),
        -120, 35, 0.1, name = "bio1")
f <- tempfile(fileext = ".asc")
maxent_write_asc(g, f)
g2 <- maxent_read_asc(f)
maxent_grid_info(g2)
#> $nrows
#> [1] 5
#> 
#> $ncols
#> [1] 10
#> 
#> $xll
#> [1] -120
#> 
#> $yll
#> [1] 35
#> 
#> $cellsize
#> [1] 0.1
#> 
#> $nodata
#> [1] -9999
#> 
#> $name
#> [1] "file21e952df9c73"
#> 
#> $count_data
#> [1] 50
#> 
# }
```
