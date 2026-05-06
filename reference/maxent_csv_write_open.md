# Open a CSV File for Writing

Opens a CSV file and returns a writer object. Use
[`maxent_csv_write`](https://alrobles.github.io/maxentcpp/reference/maxent_csv_write.md),
[`maxent_csv_write_num`](https://alrobles.github.io/maxentcpp/reference/maxent_csv_write_num.md),
[`maxent_csv_write_row`](https://alrobles.github.io/maxentcpp/reference/maxent_csv_write_row.md),
and
[`maxent_csv_write_close`](https://alrobles.github.io/maxentcpp/reference/maxent_csv_write_close.md)
to write data and close the file.

## Usage

``` r
maxent_csv_write_open(filename, append = FALSE, precision = 4L)
```

## Arguments

- filename:

  Character: output file path.

- append:

  Logical: append to an existing file (default `FALSE`).

- precision:

  Integer: number of decimal places for numeric values (default `4`).

## Value

External pointer to a CsvWriter C++ object.
