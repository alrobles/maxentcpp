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
if (FALSE) { # \dontrun{
maxent_load_lambdas(fs2, "mymodel.lambdas")
} # }
```
