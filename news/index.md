# Changelog

## maxentcpp 1.0.0

CRAN release: 2026-05-18

- Initial CRAN release.
- C++17 implementation of the Maximum Entropy (MaxEnt) species
  distribution modeling algorithm with R bindings via Rcpp.
- Core features: linear, quadratic, product, hinge, and threshold
  feature transformations.
- Categorical variable support via `BinaryFeature` class — one binary
  indicator per distinct level, matching Java Maxent’s
  `BinaryFeature.java`. Use the `categorical` parameter in
  [`maxent_generate_features()`](https://alrobles.github.io/maxentcpp/reference/maxent_generate_features.md)
  and
  [`maxent_run()`](https://alrobles.github.io/maxentcpp/reference/maxent_run.md).
- Missing data handling:
  [`maxent_complete_cases()`](https://alrobles.github.io/maxentcpp/reference/maxent_complete_cases.md)
  filters samples with NA, NaN, or NODATA sentinel values (-9999);
  [`maxent_impute_means()`](https://alrobles.github.io/maxentcpp/reference/maxent_impute_means.md)
  provides mean-substitution.
  [`maxent_run()`](https://alrobles.github.io/maxentcpp/reference/maxent_run.md)
  now automatically removes NODATA samples.
- Cross-validation via
  [`maxent_cross_validate()`](https://alrobles.github.io/maxentcpp/reference/maxent_cross_validate.md)
  — stratified k-fold partitioning matching Java Maxent’s
  `SampleSet.splitForCV()`.
- Replicate runs via
  [`maxent_replicate()`](https://alrobles.github.io/maxentcpp/reference/maxent_replicate.md)
  — bootstrap or subsample resampling matching Java Maxent’s
  `SampleSet.replicate()`.
- Jackknife variable importance via
  [`maxent_jackknife()`](https://alrobles.github.io/maxentcpp/reference/maxent_jackknife.md)
  — leave-one-out and only-one variable importance analysis matching
  Java Maxent’s `Runner.jackknifeGain()`.
- Spatial projection in raw, logistic, and complementary log-log
  (cloglog) scales.
- Terra-native raster I/O with streaming evaluation for low memory
  usage.
- Model diagnostics: AUC, variable importance (percent contribution and
  permutation importance), response curves, and MESS maps.
- Lambda file I/O compatible with the original Java MaxEnt software.
- Fixed duplicate C++ and R function definitions that caused compilation
  errors in certain build configurations.
