# Write feature lambdas to a file

Saves the trained model coefficients in CSV format compatible with the
original Java Maxent .lambdas file format.

## Usage

``` r
maxent_write_lambdas(fs_ptr, filename)
```

## Arguments

- fs_ptr:

  External pointer to a trained FeaturedSpace object.

- filename:

  Character: path to the output file.

## Value

Called for side effects; returns invisibly.
