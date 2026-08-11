#' @importFrom methods slotNames slot
NULL

# Internal helper: plan row-wise blocks for streaming a SpatRaster.
#
# Returns a list with elements:
#   $n      integer, number of blocks
#   $row    integer vector of 1-based starting rows per block
#   $nrows  integer vector of row counts per block
#
# Tries `terra::blocks()` first (terra >= 1.6), falls back to
# `terra::blockSize()` (terra 1.5), and finally to a single-block plan
# that reads the entire raster in one shot.
.maxent_plan_blocks <- function(rast) {
    nr <- terra::nrow(rast)
    if (exists("blocks", where = asNamespace("terra"), inherits = FALSE)) {
        blocks_fn <- get("blocks", envir = asNamespace("terra"),
                         inherits = FALSE)
        bk <- tryCatch(blocks_fn(rast), error = function(e) NULL)
        if (!is.null(bk) && !is.null(bk$n) && bk$n > 0L) {
            return(list(n     = as.integer(bk$n),
                        row   = as.integer(bk$row),
                        nrows = as.integer(bk$nrows)))
        }
    }
    if (exists("blockSize", where = asNamespace("terra"), inherits = FALSE)) {
        block_size_fn <- get("blockSize", envir = asNamespace("terra"),
                             inherits = FALSE)
        bk <- tryCatch(block_size_fn(rast), error = function(e) NULL)
        if (!is.null(bk) && !is.null(bk$n) && bk$n > 0L) {
            return(list(n     = as.integer(bk$n),
                        row   = as.integer(bk$row),
                        nrows = as.integer(bk$nrows)))
        }
    }
    list(n = 1L, row = 1L, nrows = as.integer(nr))
}

.maxent_get_spatraster_xptr <- function(rast) {
    slots <- methods::slotNames(rast)
    for (nm in c("ptr", "pntr", "pnt")) {
        if (nm %in% slots) {
            xp <- methods::slot(rast, nm)
            if (typeof(xp) == "externalptr") return(xp)
            # terra >= 1.8: slot holds an Rcpp module object (S4) whose
            # .xData environment contains the real external pointer as
            # ".pointer".
            if (isS4(xp)) {
                env <- tryCatch(methods::slot(xp, ".xData"), error = function(e) NULL)
                if (is.environment(env) && exists(".pointer", envir = env, inherits = FALSE)) {
                    inner <- get(".pointer", envir = env, inherits = FALSE)
                    if (typeof(inner) == "externalptr") return(inner)
                }
            }
        }
    }
    stop("Could not locate SpatRaster external pointer slot ('ptr'/'pntr'/'pnt').")
}

.maxent_make_spatraster_stream <- function(rast) {
    blocks <- .maxent_plan_blocks(rast)
    n_layers <- terra::nlyr(rast)

    terra::readStart(rast)
    on.exit(try(terra::readStop(rast), silent = TRUE), add = TRUE)
    num_points <- 0L
    for (i in seq_len(blocks$n)) {
        m <- terra::readValues(rast,
                               row   = blocks$row[i],
                               nrows = blocks$nrows[i],
                               mat   = TRUE)
        num_points <- num_points + sum(stats::complete.cases(m))
    }
    terra::readStop(rast)

    state <- new.env(parent = emptyenv())
    state$block_idx <- 0L
    state$open      <- FALSE
    state$blocks    <- blocks

    open_stream <- function() {
        if (!state$open) {
            terra::readStart(rast)
            state$open <- TRUE
        }
    }
    close_stream <- function() {
        if (state$open) {
            try(terra::readStop(rast), silent = TRUE)
            state$open <- FALSE
        }
    }
    reset_fn <- function() {
        close_stream()
        state$block_idx <- 0L
        open_stream()
        invisible(NULL)
    }
    next_tile_fn <- function() {
        while (state$open && state$block_idx < state$blocks$n) {
            state$block_idx <- state$block_idx + 1L
            i <- state$block_idx
            m <- terra::readValues(rast,
                                   row   = state$blocks$row[i],
                                   nrows = state$blocks$nrows[i],
                                   mat   = TRUE)
            keep <- stats::complete.cases(m)
            if (any(keep)) return(m[keep, , drop = FALSE])
        }
        close_stream()
        matrix(numeric(0), nrow = 0L, ncol = n_layers)
    }

    list(
        num_points = as.integer(num_points),
        num_layers = as.integer(n_layers),
        layer_names = names(rast),
        next_tile_fn = next_tile_fn,
        reset_fn = reset_fn,
        close_stream = close_stream
    )
}

#' Create a FeaturedSpace directly from a terra SpatRaster
#'
#' Streams a \code{terra::SpatRaster} block-by-block into the C++
#' \code{FeaturedSpace} streaming constructor, filtering NA cells on the fly
#' and handing the concatenated (\code{num_points} x \code{nlyr(rast)})
#' matrix to \code{\link{maxent_generate_features}} so feature objects are
#' built inside C++ without the R caller having to materialise the full
#' raster stack first.
#'
#' This is the Phase E.2 entry point described in
#' \code{docs/ARCHITECTURE_terra_raster.md} (sections 3.1 and 3.2). The
#' result is bit-for-bit identical to the dense path
#' (\code{\link{maxent_generate_features}} -> \code{\link{maxent_featured_space}})
#' when the same data, sample indices, and feature configuration are used.
#'
#' @param rast A \code{terra::SpatRaster} with one layer per environmental
#'   variable. Layers must be named; names are passed through to
#'   \code{\link{maxent_generate_features}} so generated features carry the
#'   same identifiers as the layer names (e.g. \code{bio1^2}, \code{bio1*bio2}).
#' @param sample_indices Integer vector: 0-based indices of occurrence
#'   samples in the concatenated stream of finite background cells. See
#'   \code{\link{maxent_raster_sample_indices}} for a helper that converts
#'   occurrence \code{data.frame}s into these indices.
#' @param feature_types Character vector of feature types to generate.
#'   Any subset of \code{c("linear", "quadratic", "product", "threshold",
#'   "hinge")}. Defaults to all types.
#' @param n_thresholds Integer; number of threshold knots per variable.
#' @param n_hinges Integer; number of hinge knots per variable.
#' @param enable_streaming_eval Logical; when \code{TRUE}, enables
#'   streaming-evaluation mode after object construction.
#' @return External pointer to a \code{FeaturedSpace} object.
#' @seealso \code{\link{maxent_featured_space}},
#'   \code{\link{maxent_featured_space_from_callback}},
#'   \code{\link{maxent_generate_features}}.
#' @export
#' @examples
#' \dontrun{
#' library(terra)
#' r <- rast(system.file("ex/elev.tif", package = "terra"))
#' # Pretend the first 3 finite cells are presences:
#' fs <- maxent_featured_space_from_rast(
#'     r,
#'     sample_indices = c(0L, 1L, 2L),
#'     feature_types  = c("linear", "quadratic")
#' )
#' res <- maxent_train(fs)
#' }
maxent_featured_space_from_rast <- function(
    rast,
    sample_indices,
    feature_types = c("linear", "quadratic", "product", "threshold", "hinge"),
    n_thresholds  = 10L,
    n_hinges      = 10L,
    enable_streaming_eval = TRUE)
{
    if (!requireNamespace("terra", quietly = TRUE)) {
        stop("maxent_featured_space_from_rast requires the 'terra' package.")
    }
    if (!inherits(rast, "SpatRaster")) {
        stop("`rast` must be a terra::SpatRaster.")
    }

    layer_names <- names(rast)
    n_layers    <- length(layer_names)
    if (n_layers == 0L) {
        stop("`rast` has 0 layers.")
    }

    stream <- .maxent_make_spatraster_stream(rast)
    num_points <- stream$num_points

    if (num_points == 0L) {
        stop("`rast` contains no finite background cells.")
    }

    sample_indices <- as.integer(sample_indices)
    if (length(sample_indices) == 0L) {
        stop("`sample_indices` must contain at least one occurrence index.")
    }
    if (any(sample_indices < 0L | sample_indices >= num_points)) {
        stop(sprintf(
            "All sample_indices must lie in [0, %d); got range [%d, %d].",
            num_points, min(sample_indices), max(sample_indices)))
    }

    on.exit(stream$close_stream(), add = TRUE)
    maxent_featured_space_from_spatraster_callback(
        preserved_rast  = rast,
        rast_xptr       = .maxent_get_spatraster_xptr(rast),
        num_points      = stream$num_points,
        num_layers      = stream$num_layers,
        layer_names     = stream$layer_names,
        sample_indices  = sample_indices,
        feature_types   = as.character(feature_types),
        n_thresholds    = as.integer(n_thresholds),
        n_hinges        = as.integer(n_hinges),
        next_tile_fn    = stream$next_tile_fn,
        reset_fn        = stream$reset_fn,
        enable_streaming_eval = isTRUE(enable_streaming_eval),
        use_cache = TRUE)
}

#' Convert occurrence coordinates to 0-based stream indices
#'
#' Maps occurrence cell indices (as produced by \code{terra::cellFromXY})
#' into 0-based indices within the concatenated stream of finite
#' (non-NA) background cells emitted by
#' \code{\link{maxent_featured_space_from_rast}}.
#'
#' @param rast A \code{terra::SpatRaster}.
#' @param cells Integer vector of 1-based cell indices
#'   (as returned by \code{terra::cellFromXY}).
#' @return Integer vector of 0-based indices within the finite-cell stream.
#'   Occurrence cells that fall on NA raster values (and therefore never
#'   appear in the stream) are silently dropped and a warning is emitted.
#' @export
maxent_raster_sample_indices <- function(rast, cells) {
    if (!requireNamespace("terra", quietly = TRUE)) {
        stop("maxent_raster_sample_indices requires the 'terra' package.")
    }
    if (!inherits(rast, "SpatRaster")) {
        stop("`rast` must be a terra::SpatRaster.")
    }
    cells <- as.integer(cells)
    # Build the finite-cell mask by streaming blocks once.
    blocks <- .maxent_plan_blocks(rast)
    terra::readStart(rast)
    on.exit(try(terra::readStop(rast), silent = TRUE), add = TRUE)
    n_cells <- as.integer(terra::ncell(rast))
    is_finite <- logical(n_cells)
    row_offset <- 0L
    ncol_r <- terra::ncol(rast)
    for (i in seq_len(blocks$n)) {
        m <- terra::readValues(rast,
                               row   = blocks$row[i],
                               nrows = blocks$nrows[i],
                               mat   = TRUE)
        block_finite <- stats::complete.cases(m)
        start <- (blocks$row[i] - 1L) * ncol_r + 1L
        end   <- start + length(block_finite) - 1L
        is_finite[start:end] <- block_finite
    }
    terra::readStop(rast)

    # Convert 1-based full-grid cell index -> 0-based finite-cell-stream index.
    finite_prefix <- cumsum(is_finite) - 1L   # 0-based position within finite stream
    valid <- !is.na(cells) & cells >= 1L & cells <= n_cells
    valid[valid] <- is_finite[cells[valid]]
    if (!all(valid)) {
        warning(sprintf(
            "%d occurrence cell(s) fall on NA raster values; they are dropped.",
            sum(!valid)))
    }
    finite_prefix[cells[valid]]
}

#' Extract environmental values for occurrences from a terra SpatRaster
#'
#' Streams finite raster rows through the same callback-backed provider path
#' used by \code{\link{maxent_featured_space_from_rast}}, then returns values
#' at occurrence locations.
#'
#' @param rast A \code{terra::SpatRaster}.
#' @param occurrences Either a two-column matrix/data.frame (x,y) or a vector
#'   of 1-based raster cell indices.
#' @param lon_col Longitude column name when \code{occurrences} is a data.frame.
#' @param lat_col Latitude column name when \code{occurrences} is a data.frame.
#' @return Numeric matrix with one row per retained occurrence and one column
#'   per raster layer.
#' @export
maxent_extract_occurrence_env_terra <- function(
    rast,
    occurrences,
    lon_col = "longitude",
    lat_col = "latitude") {
    if (!requireNamespace("terra", quietly = TRUE)) {
        stop("maxent_extract_occurrence_env_terra requires the 'terra' package.")
    }
    if (!inherits(rast, "SpatRaster")) {
        stop("`rast` must be a terra::SpatRaster.")
    }
    cells <- NULL
    if (is.numeric(occurrences) || is.integer(occurrences)) {
        cells <- as.integer(occurrences)
    } else if (is.matrix(occurrences) && ncol(occurrences) >= 2L) {
        cells <- terra::cellFromXY(rast, occurrences[, 1:2, drop = FALSE])
    } else if (is.data.frame(occurrences)) {
        if (!(lon_col %in% names(occurrences) && lat_col %in% names(occurrences))) {
            stop("occurrences data.frame must contain lon_col and lat_col.")
        }
        xy <- cbind(occurrences[[lon_col]], occurrences[[lat_col]])
        cells <- terra::cellFromXY(rast, xy)
    } else {
        stop("`occurrences` must be cells, a 2-column matrix, or a data.frame.")
    }

    idx <- maxent_raster_sample_indices(rast, cells)
    if (length(idx) == 0L) {
        return(matrix(numeric(0), nrow = 0L, ncol = terra::nlyr(rast)))
    }
    stream <- .maxent_make_spatraster_stream(rast)
    on.exit(stream$close_stream(), add = TRUE)
    out <- maxent_extract_occurrence_from_callback(
        num_points = stream$num_points,
        num_layers = stream$num_layers,
        occurrence_indices = idx,
        next_tile_fn = stream$next_tile_fn,
        reset_fn = stream$reset_fn,
        preserved_rast = rast)
    colnames(out) <- names(rast)
    out
}

#' Train MaxEnt directly from a terra SpatRaster
#'
#' High-level convenience wrapper that builds a streaming FeaturedSpace from
#' \code{rast}, maps occurrence locations to finite-stream sample indices, and
#' trains with \code{\link{maxent_fit}}.
#'
#' @param rast A \code{terra::SpatRaster}.
#' @param occurrences Either a two-column matrix/data.frame (x,y) or a vector
#'   of 1-based raster cell indices.
#' @param lon_col Longitude column name when \code{occurrences} is a data.frame.
#' @param lat_col Latitude column name when \code{occurrences} is a data.frame.
#' @param feature_types Feature type set passed to feature generation.
#' @param n_thresholds Number of threshold knots.
#' @param n_hinges Number of hinge knots.
#' @param max_iter Maximum training iterations.
#' @param convergence Convergence threshold.
#' @param beta_multiplier Regularization multiplier.
#' @param min_deviation Minimum deviation floor.
#' @return A named list with training results plus \code{model} and
#'   \code{sample_indices}.
#' @export
maxent_train_terra <- function(
    rast,
    occurrences,
    lon_col = "longitude",
    lat_col = "latitude",
    feature_types = c("linear", "quadratic", "product", "threshold", "hinge"),
    n_thresholds = 10L,
    n_hinges = 10L,
    max_iter = 500L,
    convergence = 1e-5,
    beta_multiplier = 1.0,
    min_deviation = 0.001) {
    cells <- NULL
    if (is.numeric(occurrences) || is.integer(occurrences)) {
        cells <- as.integer(occurrences)
    } else if (is.matrix(occurrences) && ncol(occurrences) >= 2L) {
        cells <- terra::cellFromXY(rast, occurrences[, 1:2, drop = FALSE])
    } else if (is.data.frame(occurrences)) {
        if (!(lon_col %in% names(occurrences) && lat_col %in% names(occurrences))) {
            stop("occurrences data.frame must contain lon_col and lat_col.")
        }
        xy <- cbind(occurrences[[lon_col]], occurrences[[lat_col]])
        cells <- terra::cellFromXY(rast, xy)
    } else {
        stop("`occurrences` must be cells, a 2-column matrix, or a data.frame.")
    }
    sample_indices <- maxent_raster_sample_indices(rast, cells)
    if (length(sample_indices) == 0L) {
        stop("No valid occurrence points remain after finite-cell filtering.")
    }
    fs <- maxent_featured_space_from_rast(
        rast = rast,
        sample_indices = sample_indices,
        feature_types = feature_types,
        n_thresholds = n_thresholds,
        n_hinges = n_hinges,
        enable_streaming_eval = TRUE)
    fit <- maxent_fit(
        featured_space = fs,
        max_iter = max_iter,
        convergence = convergence,
        beta_multiplier = beta_multiplier,
        min_deviation = min_deviation)
    fit$model <- fs
    fit$sample_indices <- sample_indices
    fit
}
