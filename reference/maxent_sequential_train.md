# Train a FeaturedSpace with the Sequential optimizer (trajectory-capable)

Runs the full `density.Sequential` optimizer ported from the original
Java Maxent, with optional per-iteration trajectory snapshots. Unlike
[`maxent_train()`](https://alrobles.github.io/maxentcpp/reference/maxent_train.md)
which uses a `goodAlpha`-only loop, this trainer reproduces the real
Java optimizer's feature-selection (`deltaLossBound`), Newton step, 1-D
line search, and every-10-iter `doParallelUpdate` with undo on
loss-violating batch steps.

## Usage

``` r
maxent_sequential_train(
  fs_ptr,
  max_iter = 500L,
  convergence = 1e-05,
  beta_multiplier = 1,
  min_deviation = 0.001,
  parallel_update_frequency = 10L,
  disable_convergence_test = FALSE,
  trajectory_iterations = as.integer(c())
)
```

## Arguments

- fs_ptr:

  External pointer to a FeaturedSpace object.

- max_iter:

  Maximum number of iterations (default 500).

- convergence:

  Convergence threshold on `newLoss - oldLoss` (default `1e-5`). Ignored
  when `disable_convergence_test=TRUE`.

- beta_multiplier:

  Regularization multiplier (default 1.0).

- min_deviation:

  Minimum sample deviation floor (default 0.001).

- parallel_update_frequency:

  Iteration frequency at which `doParallelUpdate` runs (default 10,
  matching Java).

- disable_convergence_test:

  When `TRUE`, the loop runs a fixed `max_iter` iterations with no early
  stop. Needed for deterministic per-iteration trajectory comparisons
  against the Java oracle.

- trajectory_iterations:

  Integer vector of 1-based iteration indices at which to capture
  `(loss, entropy, lambdas)` snapshots. May be empty. Snapshots outside
  `[1, max_iter]` are silently dropped.

## Value

Named list with elements: `loss`, `entropy`, `iterations`, `converged`,
`lambdas`, and `trajectory` — a data.frame with columns
`iteration, loss, entropy, lambda_0, ..., lambda_{J-1}` holding one row
per requested checkpoint that was actually reached.
