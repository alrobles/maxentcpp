# Write a Numeric Value to the Current CSV Row

Adds a `column = value` pair (as a double) to the current row buffer.
Call
[`maxent_csv_write_row`](https://alrobles.github.io/maxentcpp/reference/maxent_csv_write_row.md)
to flush the row.

## Usage

``` r
maxent_csv_write_num(writer, column, value)
```

## Arguments

- writer:

  External pointer to a CsvWriter object.

- column:

  Character: column name.

- value:

  Numeric: value to write.

## Value

Invisibly returns the writer object.
