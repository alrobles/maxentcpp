# Load Model Lambdas from File

Reads model coefficients from a .lambdas file and applies them to a
FeaturedSpace that was created with the same features.

## Usage

``` r
maxent_load_lambdas(featured_space, file)
```

## Arguments

- featured_space:

  External pointer to a FeaturedSpace object (must have features with
  the same names as those in the file).

- file:

  Character: path to the lambdas file.

## Value

Invisibly returns the FeaturedSpace external pointer (updated in-place).

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
f <- tempfile(fileext = ".lambdas")
maxent_save_lambdas(fs, f)
maxent_load_lambdas(fs, f)
# }
```
