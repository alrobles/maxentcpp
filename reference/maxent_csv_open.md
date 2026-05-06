# Open a CSV File for Reading

Opens a CSV file and reads column headers.

## Usage

``` r
maxent_csv_open(filename, has_header = TRUE)
```

## Arguments

- filename:

  Character: path to the CSV file.

- has_header:

  Logical: first line is header (default `TRUE`).

## Value

External pointer to a CsvReader C++ object.
