# Create a Binary (Categorical Indicator) Feature

Creates a binary feature that evaluates to 1.0 when the underlying value
equals the target category, 0.0 otherwise. This is the building block
for categorical variable support, matching Java Maxent's `BinaryFeature`
class.

## Usage

``` r
maxent_binary_feature(values, name, target)
```

## Arguments

- values:

  Numeric vector of categorical variable values.

- name:

  Character string: feature name/identifier.

- target:

  The category value to test for.

## Value

External pointer to a BinaryFeature C++ object.

## Examples

``` r
if (FALSE) { # \dontrun{
vals <- c(1, 2, 3, 1, 2)
f <- maxent_binary_feature(vals, "(landcover=1)", target = 1)
maxent_feature_eval(f, 1)  # 1.0 (values[1] == 1)
maxent_feature_eval(f, 2)  # 0.0 (values[2] == 2)
} # }
```
