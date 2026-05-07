## Resubmission

Fixes from initial CRAN pre-test feedback (2026-05-07):

* Java validation tests now skip gracefully when the runtime Java version
  cannot load the companion JAR (compiled with Java 17). The JAR is excluded
  from the CRAN tarball via `.Rbuildignore`; it is only used during
  development to verify numerical parity with the reference Java Maxent.
* Added `inst/WORDLIST` for legitimate technical terms flagged as misspelled
  (Maxent, cloglog, reimplementation, et al.).
* Removed `VignetteBuilder: knitr` (articles are pkgdown-only, not R vignettes).
* Added `README.Rmd` to `.Rbuildignore`.

## Test environments

- local: Ubuntu 22.04, R 4.x
- GitHub Actions: ubuntu-latest (R-release, R-devel), macOS-latest (R-release),
  windows-latest (R-release)
- win-builder: R-devel (2026-05-07)

## R CMD check results

0 errors | 0 warnings | 1 note

NOTE: New submission. "Maxent", "cloglog", "reimplementation", and
"et al." flagged as misspelled are technical terms and a standard
citation form; they are listed in `inst/WORDLIST`.

## Comments

This is a new submission. The package provides a C++17 implementation of the
Maximum Entropy (MaxEnt) species distribution modeling algorithm with R bindings
via Rcpp. It is a ground-up reimplementation of the original Java MaxEnt
software (Phillips et al. 2006, doi:10.1016/j.ecolmodel.2005.03.026).
