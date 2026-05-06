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
n   <- 50L
idx <- c(5L, 15L, 25L, 35L, 45L)
env <- list(temp = runif(n), precip = runif(n))
feats <- maxent_generate_features(env, types = "linear")
model <- maxent_featured_space(n, idx, feats)
maxent_fit(model, max_iter = 100, convergence = 1e-3)
#> $loss
#> [1] 3.912023
#> 
#> $entropy
#> [1] 3.912023
#> 
#> $iterations
#> [1] 21
#> 
#> $converged
#> [1] TRUE
#> 
#> $lambdas
#> [1] 0 0
#> 
contrib <- maxent_percent_contribution(model, c("temp", "precip"))
contrib  # data.frame with name and contribution
#>     name contribution
#> 1   temp            0
#> 2 precip            0
```
