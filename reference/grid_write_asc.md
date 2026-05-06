# Write a float Grid to an ESRI ASCII (.asc) file

Write a float Grid to an ESRI ASCII (.asc) file

## Usage

``` r
grid_write_asc(grid_ptr, filename, scientific = TRUE)
```

## Arguments

- grid_ptr:

  External pointer to a GridFloat object.

- filename:

  Output file path.

- scientific:

  Logical: use scientific notation (default TRUE).

## Value

Called for side effects; returns invisibly.
