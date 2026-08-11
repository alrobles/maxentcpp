# Evaluate a Feature at a Given Index

Evaluates the feature function at the specified index (1-based, as is
standard in R). Internally converts to 0-based indexing for C++.

## Usage

``` r
maxent_feature_eval(feature, index)
```

## Arguments

- feature:

  External pointer to a Feature C++ object.

- index:

  1-based integer index into the data vector.

## Value

Numeric scalar: the feature value at that index.

## Examples

``` r
if (FALSE) { # \dontrun{
vals <- c(0, 5, 10)
f <- maxent_linear_feature(vals, "temp")
maxent_feature_eval(f, 2)  # 5/10 = 0.5
} # }
```
