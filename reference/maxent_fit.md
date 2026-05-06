# Train a MaxEnt Model

Runs the sequential coordinate-ascent MaxEnt optimization on a
FeaturedSpace.

## Usage

``` r
maxent_fit(
  featured_space,
  max_iter = 500L,
  convergence = 1e-05,
  beta_multiplier = 1,
  min_deviation = 0.001
)
```

## Arguments

- featured_space:

  External pointer to a FeaturedSpace object (from
  [`maxent_featured_space()`](https://alrobles.github.io/maxentcpp/reference/maxent_featured_space.md)).

- max_iter:

  Maximum number of training iterations (default 500).

- convergence:

  Convergence threshold: stop when the per-20-iteration loss improvement
  is below this value (default 1e-5).

- beta_multiplier:

  Regularization multiplier (default 1.0). Higher values increase
  regularization strength.

- min_deviation:

  Minimum sample deviation floor used in regularization (default 0.001).

## Value

Named list with:

- loss:

  Final regularized loss (scalar).

- entropy:

  Shannon entropy of the trained distribution.

- iterations:

  Number of training iterations completed.

- converged:

  Logical: whether the convergence threshold was reached.

- lambdas:

  Numeric vector of final lambda (weight) values.

## Examples

``` r
if (FALSE) { # \dontrun{
result <- maxent_fit(fs, max_iter = 500, convergence = 1e-5)
cat("Final loss:", result$loss, "\n")
cat("Entropy:",    result$entropy, "\n")
} # }
```
