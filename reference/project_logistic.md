# Project Model onto Grids (Java-compatible logistic output)

Applies the Java Maxent logistic formula: logistic_java = (exp(H) \*
raw_java) / (1 + exp(H) \* raw_java)

## Usage

``` r
project_logistic(fs_ptr, grid_ptrs, feature_names)
```

## Arguments

- fs_ptr:

  External pointer to a FeaturedSpace object.

- grid_ptrs:

  List of external pointers to Grid\<float\> objects.

- feature_names:

  Character vector of environment variable names.

## Value

External pointer to a Grid\<float\> with Java logistic scores in \[0,
1\].

## Details

where H is the model entropy and raw_java is the normalised probability.
This matches the logistic output of Java Maxent and dismo.
