# Why maxentcpp? From Java Maxent to Modern C++

## The Legacy of Java Maxent

Since its introduction by [Phillips, Anderson & Schapire
(2006)](https://doi.org/10.1016/j.ecolmodel.2005.03.026), the Maximum
Entropy algorithm (Maxent) has become one of the most widely used tools
in ecology. With over **13 000 citations**, Maxent is the *de facto*
standard for modelling species geographic distributions from
presence-only occurrence data.

The original software was written in **Java** and released as a
standalone desktop application (`maxent.jar`) by the [American Museum of
Natural
History](https://biodiversityinformatics.amnh.org/open_source/maxent/).
Subsequent R integration came through the
[dismo](https://CRAN.R-project.org/package=dismo) package, which calls
the Java JAR via [rJava](https://CRAN.R-project.org/package=rJava). This
approach has served the community well for nearly two decades.

But science evolves, and so must its tools.

## The Problem with Java in 2026

The Java Maxent codebase has remained essentially unchanged since
version 3.4.4 (released November 2020). While the algorithm itself is
mathematically sound, the **engineering infrastructure** surrounding it
creates friction for modern ecological research:

| Issue | Impact |
|----|----|
| **Java Runtime dependency** | Users must install and configure a compatible JDK. Version conflicts between Java 8/11/17/21 cause silent failures. |
| **rJava configuration** | `install.packages("rJava")` is one of the most common sources of installation errors in the R ecosystem, particularly on macOS and HPC clusters. |
| **No native R integration** | Data must be serialized to disk (SWD files, ASC grids) and read back by the JAR. There is no in-memory bridge between R objects and the Java optimizer. |
| **Single-threaded** | The Java implementation uses a single thread. Modern hardware with 8–128 cores is underutilized. |
| **GUI-centric design** | The software was designed around a Swing GUI. Scripting and batch processing require command-line flags and file system I/O. |
| **Maintenance** | Only 2 contributors; last meaningful code change was in 2020. |

For individual analyses these issues are manageable. For large-scale
studies — thousands of species, multiple climate scenarios, ensemble
modelling pipelines — they become a bottleneck.

## Why Rewrite in C++17?

`maxentcpp` is a **ground-up C++17 reimplementation** of the Maxent
3.4.4 algorithm, with R bindings through
[Rcpp](https://CRAN.R-project.org/package=Rcpp) and
[RcppEigen](https://CRAN.R-project.org/package=RcppEigen).

### 1. Zero external runtime dependencies

No Java, no JVM, no rJava. If you can compile an R package with C++
support — which every modern R installation provides — `maxentcpp`
works. Installation is a single call:

``` r

install.packages("maxentcpp")
```

### 2. Native R objects, no file I/O bottleneck

Environmental rasters flow directly from
[terra](https://CRAN.R-project.org/package=terra) `SpatRaster` objects
into the C++ optimizer. No temporary `.asc` files, no SWD exports, no
disk round-trips:

``` r

library(maxentcpp)
library(terra)

env <- rast("bioclim_stack.tif")
model <- maxent_train_terra(env, occurrences)
prediction <- maxent_predict(model, env)
```

### 3. Streaming raster evaluation

`maxentcpp` processes rasters **block-by-block** through terra’s
streaming API. A 100 GB climate stack never needs to fit in memory — the
C++ engine reads tiles, scores them, and writes results incrementally.
This makes continental- and global-scale projections feasible on a
standard workstation.

### 4. Bit-identical numerical fidelity

Every C++ class is an **explicit port** of the corresponding Java class:

| C++ class | Java original | Purpose |
|----|----|----|
| `LinearFeature` | `density.LinearFeature` | `(v - min) / (max - min)` |
| `QuadraticFeature` | `density.SquareFeature` | Squared linear value |
| `ProductFeature` | `density.ProductFeature` | Pairwise interaction |
| `HingeFeature` | `density.HingeFeature` | Piecewise linear |
| `ThresholdFeature` | `density.ThresholdFeature` | Binary step |
| `FeaturedSpace` | `density.FeaturedSpace` | Gibbs distribution + trainer |
| `Sequential::train()` | `density.Sequential.run()` | Coordinate-ascent optimizer |

The C++ output has been validated against Java Maxent to **\< 10⁻¹⁴
relative error** on standardized test fixtures. When you switch from
`dismo::maxent()` to `maxentcpp`, your predictions do not change.

### 5. Reproducible, scriptable, versionable

Models are fully defined by their lambda files, which are
**format-compatible** with Java Maxent:

``` r

# Save
maxent_save_lambdas(model, "species_model.lambdas")

# Load (even lambdas produced by Java Maxent)
model <- maxent_load_lambdas("species_model.lambdas")
```

Every step of the pipeline is an R function call. There is no hidden
state, no GUI, no side effects. Your entire analysis is a script that
can be version-controlled, reviewed, and reproduced.

## What maxentcpp Provides

The package covers the **complete Maxent workflow** as a set of
composable R functions:

    maxent_grid_from_terra()        --- Load raster layers
    maxent_read_occurrences()       --- Ingest presence records
    maxent_background_indices()     --- Sample background points
    maxent_generate_features()      --- Build feature set
    maxent_featured_space()         --- Create model object
    maxent_fit()                    --- Train the MaxEnt model
    maxent_save_lambdas()           --- Persist model to disk
    maxent_project_cloglog()        --- Spatial prediction (cloglog)
    maxent_project_logistic()       --- Spatial prediction (logistic)
    maxent_project_raw()            --- Spatial prediction (raw)
    maxent_grid_to_terra()          --- Convert output to SpatRaster
    maxent_evaluate()               --- AUC, kappa, log-loss
    maxent_response_curve()         --- Variable response plots
    maxent_permutation_importance() --- Variable ranking
    maxent_mess()                   --- Environmental novelty (MESS)
    maxent_clamp()                  --- Safe extrapolation
    maxent_run()                    --- One-click full pipeline

Plus a complete **output layer** matching Java Maxent’s file artifacts:
prediction PNGs, response curve plots, omission CSVs,
`maxentResults.csv`, and sample prediction tables.

## The Path Forward

Java Maxent was a landmark contribution to ecology. `maxentcpp` is not a
criticism of that work — it is a **continuation**.

By translating the algorithm into modern C++17 with native R
integration, we enable:

- **Scalability**: Continental projections on commodity hardware.
- **Reproducibility**: Every analysis is a script, not a GUI session.
- **Extensibility**: Adding new feature types, regularization
  strategies, or output formats requires modifying a well-structured C++
  codebase, not reverse-engineering a monolithic Java application.
- **Community ownership**: The code is MIT-licensed, hosted on GitHub,
  and open to contributions from the ecology community.
- **CRAN distribution**: Install with one command, no JDK required.

The science deserves modern tools. `maxentcpp` delivers the same trusted
algorithm in a package built for 2026 and beyond.

## References

Phillips, S.J., Anderson, R.P. & Schapire, R.E. (2006). Maximum entropy
modeling of species geographic distributions. *Ecological Modelling*,
190(3–4), 231–259.
[doi:10.1016/j.ecolmodel.2005.03.026](https://doi.org/10.1016/j.ecolmodel.2005.03.026)

Phillips, S.J., Anderson, R.P., Dudík, M., Schapire, R.E. & Blair, M.E.
(2017). Opening the black box: an open-source release of Maxent.
*Ecography*, 40(7), 887–893.
[doi:10.1111/ecog.03049](https://doi.org/10.1111/ecog.03049)
