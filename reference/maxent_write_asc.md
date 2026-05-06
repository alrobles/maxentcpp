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
if (FALSE) { # \dontrun{
maxent_write_asc(g, tempfile(fileext = ".asc"))
} # }
```
