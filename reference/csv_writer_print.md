# Write a value into the current row of a CSV

Write a value into the current row of a CSV

## Usage

``` r
csv_writer_print(writer_ptr, column, value)
```

## Arguments

- writer_ptr:

  External pointer to a CsvWriter object.

- column:

  Column name.

- value:

  Value to write (character).

## Value

Called for side effects; returns invisibly.
