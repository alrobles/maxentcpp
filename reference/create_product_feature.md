# Create a ProductFeature object

Creates a product (interaction) feature between two environmental
variables: eval(i) = norm(values1\[i\]) \* norm(values2\[i\]).

## Usage

``` r
create_product_feature(values1, values2, name, min1, max1, min2, max2)
```

## Arguments

- values1:

  Numeric vector for the first environmental variable

- values2:

  Numeric vector for the second environmental variable

- name:

  Feature name/identifier

- min1:

  Minimum of the first variable

- max1:

  Maximum of the first variable

- min2:

  Minimum of the second variable

- max2:

  Maximum of the second variable

## Value

External pointer to ProductFeature object
