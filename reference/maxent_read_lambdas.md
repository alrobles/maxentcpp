# Read feature lambdas from a file

Restores model coefficients from a .lambdas file. The FeaturedSpace must
have been created with the same features (same names and order).

## Usage

``` r
maxent_read_lambdas(fs_ptr, filename)
```

## Arguments

- fs_ptr:

  External pointer to a FeaturedSpace object.

- filename:

  Character: path to the lambdas file.

## Value

Called for side effects; returns invisibly.
