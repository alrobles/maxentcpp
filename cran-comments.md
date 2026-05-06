## Test environments

- local: Ubuntu 22.04, R 4.x
- GitHub Actions: ubuntu-latest (R-release, R-devel), macOS-latest (R-release),
  windows-latest (R-release)

## R CMD check results

0 errors | 0 warnings | 1 note

NOTE: New submission.

## Comments

This is a new submission. The package provides a C++17 implementation of the
Maximum Entropy (MaxEnt) species distribution modeling algorithm with R bindings
via Rcpp. It is a ground-up reimplementation of the original Java MaxEnt
software (Phillips et al. 2006, doi:10.1016/j.ecolmodel.2005.03.026).
