# Create a MaxEnt Sample Object

Creates a sample point representing a species occurrence location.

## Usage

``` r
maxent_sample(lon, lat, name = "", dim = NULL)
```

## Arguments

- lon:

  Longitude coordinate

- lat:

  Latitude coordinate

- name:

  Sample identifier/name

- dim:

  Optional GridDimension object to calculate row/col indices

## Value

Sample object (external pointer)

## Examples

``` r
if (FALSE) { # \dontrun{
sample <- maxent_sample(lon = -118.5, lat = 36.5, name = "site1")
} # }
```
