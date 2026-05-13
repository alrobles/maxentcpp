# Save Model Lambdas to File

Writes the trained model coefficients (lambdas) to a CSV file in the
standard Maxent .lambdas format.

## Usage

``` r
maxent_save_lambdas(featured_space, file)
```

## Arguments

- featured_space:

  External pointer to a trained FeaturedSpace object.

- file:

  Character: path to the output file.

## Value

Invisibly returns the output file path.

## Examples

``` r
# \donttest{
n   <- 50L
idx <- c(5L, 15L, 25L, 35L, 45L)
env <- list(bio1 = runif(n), bio12 = runif(n))
feats <- maxent_generate_features(env, types = "linear")
fs  <- maxent_featured_space(n, idx, feats)
maxent_fit(fs, max_iter = 100)
#> $loss
#> [1] 3.767277
#> 
#> $entropy
#> [1] 3.873463
#> 
#> $iterations
#> [1] 81
#> 
#> $converged
#> [1] TRUE
#> 
#> $lambdas
#> [1] 0.0000000 0.9002707
#> 
maxent_save_lambdas(fs, tempfile(fileext = ".lambdas"))
# }
```
