#' Train a MaxEnt Model with the Java-Equivalent Sequential Optimizer
#'
#' Runs the full \code{density.Sequential} optimizer ported from the
#' original Java Maxent 3.4.4 on a FeaturedSpace.  Unlike
#' \code{maxent_fit()}, which uses the historical \code{goodAlpha}-only
#' loop, this trainer reproduces the real Java optimizer: feature
#' selection via \code{deltaLossBound}, Newton step with 1-D line search
#' (\code{searchAlpha}), every-10-iteration \code{doParallelUpdate} with
#' undo on loss-violating batch steps, and per-feature state tracking.
#'
#' The lambda trajectory produced by this trainer matches the Java
#' oracle's to \eqn{10^{-6}} on \eqn{\left\|\Delta\lambda\right\|_\infty}
#' at every checkpoint, on both the symmetric and asymmetric fixtures in
#' \code{maxentcppCompTest} — see
#' \code{docs/ARCHITECTURE_xtensor_openmp.md} and the Phase C baseline
#' report for details.
#'
#' @param featured_space External pointer to a FeaturedSpace object (from
#'   \code{maxent_featured_space()}).
#' @param max_iter Maximum number of iterations (default \code{500L}).
#' @param convergence Convergence threshold on the per-20-iteration loss
#'   improvement (default \code{1e-5}).  Ignored when
#'   \code{disable_convergence_test = TRUE}.
#' @param beta_multiplier Regularization multiplier (default \code{1.0}).
#' @param min_deviation Minimum sample-deviation floor used in
#'   regularization (default \code{0.001}).
#' @param parallel_update_frequency Iteration frequency at which
#'   \code{doParallelUpdate} runs (default \code{10L}, matching Java).
#' @param disable_convergence_test Logical: when \code{TRUE}, the loop
#'   runs a fixed \code{max_iter} iterations with no early stop.  This
#'   is required for deterministic per-iteration trajectory comparisons
#'   against the Java oracle.  Default \code{FALSE}.
#' @param trajectory_iterations Integer vector of 1-based iteration
#'   indices at which to capture \code{(loss, entropy, lambdas)}
#'   snapshots.  May be empty.  Snapshots outside
#'   \code{[1, max_iter]} are silently dropped.
#' @return Named list with:
#'   \describe{
#'     \item{loss}{Final regularized loss (scalar).}
#'     \item{entropy}{Shannon entropy of the trained distribution.}
#'     \item{iterations}{Number of training iterations completed.}
#'     \item{converged}{Logical: whether the convergence threshold was
#'       reached (always \code{FALSE} when
#'       \code{disable_convergence_test = TRUE}).}
#'     \item{lambdas}{Numeric vector of final lambda values.}
#'     \item{trajectory}{A \code{data.frame} with one row per captured
#'       checkpoint and columns \code{iteration, loss, entropy,
#'       lambda_0, lambda_1, ..., lambda_{J-1}}.}
#'   }
#' @seealso \code{\link{maxent_fit}}, \code{\link{maxent_featured_space}}.
#' @export
#' @examples
#' \donttest{
#' fs  <- maxent_featured_space(100L, 90:99, list(f))
#' res <- maxent_sequential_fit(
#'     fs,
#'     max_iter                 = 500L,
#'     disable_convergence_test = TRUE,
#'     trajectory_iterations    = c(1L, 2L, 5L, 10L, 50L, 100L, 500L))
#' print(res$trajectory)
#' }
maxent_sequential_fit <- function(featured_space,
                                  max_iter                  = 500L,
                                  convergence               = 1e-5,
                                  beta_multiplier           = 1.0,
                                  min_deviation             = 0.001,
                                  parallel_update_frequency = 10L,
                                  disable_convergence_test  = FALSE,
                                  trajectory_iterations     = integer(0)) {
    maxent_sequential_train(
        featured_space,
        as.integer(max_iter),
        as.double(convergence),
        as.double(beta_multiplier),
        as.double(min_deviation),
        as.integer(parallel_update_frequency),
        isTRUE(disable_convergence_test),
        as.integer(trajectory_iterations)
    )
}
