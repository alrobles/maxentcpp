# Write a Grid to ESRI ASCII Format

Writes a GridFloat to a `.asc` file.

## Usage

``` r
maxent_write_asc(grid, filename, scientific = TRUE)
```

## Arguments

- grid:

  External pointer to a GridFloat object.

- filename:

  Character: output file path.

- scientific:

  Logical: use scientific notation for floating-point values (default
  `TRUE`).

## Value

Invisibly returns the output file path.

## Examples

``` r
# \donttest{
g <- maxent_grid_from_matrix(matrix(runif(50), 5, 10),
        -120, 35, 0.1, name = "bio1")
maxent_write_asc(g, tempfile(fileext = ".asc"))
# }
```
