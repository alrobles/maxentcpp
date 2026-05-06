# Compute Percent Contribution

Computes variable contribution based on sum of absolute lambda values
for features derived from each variable. Results sum to 100

## Usage

``` r
maxent_percent_contribution(model, feature_names)
```

## Arguments

- model:

  External pointer to a FeaturedSpace object.

- feature_names:

  Character vector of base variable names.

## Value

A data.frame with columns:

- name:

  Variable name

- contribution:

  Percent contribution

## Examples

``` r
if (FALSE) { # \dontrun{
contrib <- maxent_percent_contribution(model, c("temp", "precip"))
contrib  # data.frame with name and contribution
} # }
```
