# Open a CSV file for writing

Open a CSV file for writing

## Usage

``` r
csv_writer_open(filename, append = FALSE, precision = 4L)
```

## Arguments

- filename:

  Path to the output CSV file.

- append:

  Logical: append to existing file (default FALSE).

- precision:

  Number of decimal places for doubles (default 4).

## Value

External pointer to a CsvWriter object.
