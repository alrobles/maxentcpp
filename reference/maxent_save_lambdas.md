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
if (FALSE) { # \dontrun{
maxent_save_lambdas(fs, tempfile(fileext = ".lambdas"))
} # }
```
