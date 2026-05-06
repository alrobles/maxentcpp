# Create a HingeFeature object

Creates a piecewise-linear hinge feature. Forward hinge: eval(i) =
(values\[i\] \> min_knot) ? (values\[i\] - min_knot) / (max_knot -
min_knot) : 0. Reverse hinge: eval(i) = (values\[i\] \< max_knot) ?
(max_knot - values\[i\]) / (max_knot - min_knot) : 0.

## Usage

``` r
create_hinge_feature(values, name, min_knot, max_knot, is_reverse = FALSE)
```

## Arguments

- values:

  Numeric vector of environmental variable values

- name:

  Feature name/identifier

- min_knot:

  Lower knot of the hinge

- max_knot:

  Upper knot of the hinge (must be \> min_knot)

- is_reverse:

  If TRUE, use reverse hinge; if FALSE (default), use forward hinge

## Value

External pointer to HingeFeature object
