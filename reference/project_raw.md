# Project Model onto Grids (Java-compatible raw output)

Applies a trained FeaturedSpace model to produce Java Maxent "raw"
scores: raw_java = exp(lp - lpNorm) / densityNorm

## Usage

``` r
project_raw(fs_ptr, grid_ptrs, feature_names)
```

## Arguments

- fs_ptr:

  External pointer to a FeaturedSpace object.

- grid_ptrs:

  List of external pointers to Grid\<float\> objects.

- feature_names:

  Character vector of environment variable names.

## Value

External pointer to a Grid\<float\> with Java raw scores.

## Details

This matches the raw output of the Java Maxent software and the dismo R
package.
