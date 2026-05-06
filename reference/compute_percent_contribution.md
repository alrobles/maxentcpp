# Compute Percent Contribution

Computes variable contribution based on sum of absolute lambda values
for features derived from each variable.

## Usage

``` r
compute_percent_contribution(fs_ptr, feature_names)
```

## Arguments

- fs_ptr:

  External pointer to a FeaturedSpace object.

- feature_names:

  Character vector of base variable names.

## Value

A data.frame with columns: name, contribution.
