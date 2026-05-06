# Read an entire named column as doubles

Reads from the current position to EOF.

## Usage

``` r
csv_read_double_column(reader_ptr, field)
```

## Arguments

- reader_ptr:

  External pointer to a CsvReader object.

- field:

  Column name.

## Value

Numeric vector.
