# Train a MaxEnt Model with the Java-Equivalent Sequential Optimizer

Runs the full `density.Sequential` optimizer ported from the original
Java Maxent 3.4.4 on a FeaturedSpace. Unlike
[`maxent_fit()`](https://alrobles.github.io/maxentcpp/reference/maxent_fit.md),
which uses the historical `goodAlpha`-only loop, this trainer reproduces
the real Java optimizer: feature selection via `deltaLossBound`, Newton
step with 1-D line search (`searchAlpha`), every-10-iteration
`doParallelUpdate` with undo on loss-violating batch steps, and
per-feature state tracking.

## Usage

``` r
maxent_sequential_fit(
  featured_space,
  max_iter = 500L,
  convergence = 1e-05,
  beta_multiplier = 1,
  min_deviation = 0.001,
  parallel_update_frequency = 10L,
  disable_convergence_test = FALSE,
  trajectory_iterations = integer(0)
)
```

## Arguments

- featured_space:

  External pointer to a FeaturedSpace object (from
  [`maxent_featured_space()`](https://alrobles.github.io/maxentcpp/reference/maxent_featured_space.md)).

- max_iter:

  Maximum number of iterations (default `500L`).

- convergence:

  Convergence threshold on the per-20-iteration loss improvement
  (default `1e-5`). Ignored when `disable_convergence_test = TRUE`.

- beta_multiplier:

  Regularization multiplier (default `1.0`).

- min_deviation:

  Minimum sample-deviation floor used in regularization (default
  `0.001`).

- parallel_update_frequency:

  Iteration frequency at which `doParallelUpdate` runs (default `10L`,
  matching Java).

- disable_convergence_test:

  Logical: when `TRUE`, the loop runs a fixed `max_iter` iterations with
  no early stop. This is required for deterministic per-iteration
  trajectory comparisons against the Java oracle. Default `FALSE`.

- trajectory_iterations:

  Integer vector of 1-based iteration indices at which to capture
  `(loss, entropy, lambdas)` snapshots. May be empty. Snapshots outside
  `[1, max_iter]` are silently dropped.

## Value

Named list with:

- loss:

  Final regularized loss (scalar).

- entropy:

  Shannon entropy of the trained distribution.

- iterations:

  Number of training iterations completed.

- converged:

  Logical: whether the convergence threshold was reached (always `FALSE`
  when `disable_convergence_test = TRUE`).

- lambdas:

  Numeric vector of final lambda values.

- trajectory:

  A `data.frame` with one row per captured checkpoint and columns
  `iteration, loss, entropy, lambda_0, lambda_1, ..., lambda_{J-1}`.

## Details

The lambda trajectory produced by this trainer matches the Java oracle's
to \\10^{-6}\\ on \\\left\\\Delta\lambda\right\\\_\infty\\ at every
checkpoint, on both the symmetric and asymmetric fixtures in
`maxentcppCompTest` — see `docs/ARCHITECTURE_xtensor_openmp.md` and the
Phase C baseline report for details.

## See also

[`maxent_fit`](https://alrobles.github.io/maxentcpp/reference/maxent_fit.md),
[`maxent_featured_space`](https://alrobles.github.io/maxentcpp/reference/maxent_featured_space.md).

## Examples

``` r
# \donttest{
n   <- 100L
idx <- 90:99
env <- seq(0, 1, length.out = n)
f   <- maxent_linear_feature(env, "env1")
fs  <- maxent_featured_space(n, idx, list(f))
res <- maxent_sequential_fit(
    fs,
    max_iter                 = 500L,
    disable_convergence_test = TRUE,
    trajectory_iterations    = c(1L, 2L, 5L, 10L, 50L, 100L, 500L))
print(res$trajectory)
#>   iteration     loss  entropy   lambda_0
#> 1         1 4.411687 4.596430  0.4546303
#> 2         2 4.244694 4.572560  0.8845613
#> 3         5 3.868155 4.444896  2.0417866
#> 4        10 3.500539 4.185875  3.6185653
#> 5        50 2.783462 2.783462 16.6570831
#> 6       100 2.783462 2.783462 16.6570831
#> 7       500 2.783462 2.783462 16.6570831
# }
```
