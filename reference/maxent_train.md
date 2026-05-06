# Train a FeaturedSpace model

Runs the sequential coordinate-ascent MaxEnt optimization.

## Usage

``` r
maxent_train(
  fs_ptr,
  max_iter = 500L,
  convergence = 1e-05,
  beta_multiplier = 1,
  min_deviation = 0.001
)
```

## Arguments

- fs_ptr:

  External pointer to a FeaturedSpace object.

- max_iter:

  Maximum number of training iterations (default 500).

- convergence:

  Convergence threshold (default 1e-5).

- beta_multiplier:

  Regularization multiplier (default 1.0).

- min_deviation:

  Minimum sample deviation floor (default 0.001).

## Value

Named list with elements: `loss`, `entropy`, `iterations`, `converged`,
`lambdas`.
