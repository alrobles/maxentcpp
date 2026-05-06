#' @useDynLib maxentcpp, .registration = TRUE
#' @importFrom Rcpp sourceCpp
NULL

#' Create a MaxEnt Sample Object
#'
#' Creates a sample point representing a species occurrence location.
#'
#' @param lon Longitude coordinate
#' @param lat Latitude coordinate
#' @param name Sample identifier/name
#' @param dim Optional GridDimension object to calculate row/col indices
#' @return Sample object (external pointer)
#' @export
#' @examples
#' sample <- maxent_sample(lon = -118.5, lat = 36.5, name = "site1")
maxent_sample <- function(lon, lat, name = "", dim = NULL) {
    if (is.null(dim)) {
        # Create sample with dummy row/col if no dimension provided
        create_sample(0, 0, 0, lat, lon, name)
    } else {
        rc <- coords_to_rowcol(dim, lon, lat)
        create_sample(0, rc[1], rc[2], lat, lon, name)
    }
}

#' Create a Grid Dimension Object
#'
#' Defines the spatial extent and resolution of a raster grid.
#'
#' @param nrows Number of rows
#' @param ncols Number of columns
#' @param xll X coordinate of lower-left corner
#' @param yll Y coordinate of lower-left corner
#' @param cellsize Cell size (square cells)
#' @return GridDimension object (external pointer)
#' @export
#' @examples
#' dim <- maxent_dimension(
#'   nrows = 100, ncols = 100,
#'   xll = -120.0, yll = 35.0,
#'   cellsize = 0.1
#' )
maxent_dimension <- function(nrows, ncols, xll, yll, cellsize) {
    create_grid_dimension(nrows, ncols, xll, yll, cellsize)
}

#' Create a Grid Object
#'
#' Creates a raster grid for storing environmental variable data.
#'
#' @param dim GridDimension object defining spatial extent
#' @param name Grid layer name
#' @param nodata_value Value representing missing data (default: -9999)
#' @return Grid object (external pointer)
#' @export
#' @examples
#' dim <- maxent_dimension(100, 100, -120, 35, 0.1)
#' grid <- maxent_grid(dim, "temperature")
maxent_grid <- function(dim, name = "", nodata_value = -9999) {
    create_grid_float(dim, name, nodata_value)
}

#' Get Grid Information
#'
#' Retrieves properties of a grid object.
#'
#' @param grid Grid object
#' @return List with grid properties
#' @keywords internal
grid_info <- function(grid) {
    # Get dimension info if available
    tryCatch({
        list(
            name = "grid",  # Would need to add getter for this
            rows = attr(grid, "rows"),
            cols = attr(grid, "cols")
        )
    }, error = function(e) {
        list(error = "Could not retrieve grid info")
    })
}

#' Convert Grid to Raster Matrix
#'
#' Extracts grid data as an R matrix.
#'
#' @param grid Grid object
#' @return Numeric matrix
#' @keywords internal
as_matrix <- function(grid) {
    grid_to_matrix(grid)
}

#' Set Grid from Matrix
#'
#' Populates grid with values from an R matrix.
#'
#' @param grid Grid object
#' @param mat Numeric matrix of values
#' @return Invisibly returns the grid object.
#' @keywords internal
set_grid_matrix <- function(grid, mat) {
    grid_from_matrix(grid, mat)
    invisible(grid)
}

#' Print Sample Information
#'
#' @param x Sample object
#' @param ... Additional arguments (ignored)
#' @return Invisibly returns \code{x}.
#' @export
print.maxent_sample <- function(x, ...) {
    info <- get_sample_info(x)
    cat("MaxEnt Sample\n")
    cat(sprintf("  Name: %s\n", info$name))
    cat(sprintf("  Location: (%.4f, %.4f)\n", info$lon, info$lat))
    cat(sprintf("  Grid indices: [%d, %d]\n", info$row, info$col))
    invisible(x)
}

#' Read Species Occurrence Data
#'
#' Reads species presence records from a CSV file or an R \code{data.frame}
#' and converts them to row/column indices suitable for
#' \code{\link{maxent_featured_space}}.
#'
#' @param file_or_df Either a character path to a CSV file, or a
#'   \code{data.frame} already loaded in R (e.g. from
#'   \code{rgbif::occ_data()}, GBIF download, or \code{read.csv()}).
#' @param dim  A GridDimension object (from \code{\link{maxent_dimension}})
#'   defining the study area grid.
#' @param lon_col Character: name of the longitude column
#'   (default \code{"longitude"}).
#' @param lat_col Character: name of the latitude column
#'   (default \code{"latitude"}).
#' @param name_col Character or \code{NULL}: column for sample names.
#'   If \code{NULL} (default), sequential names are generated.
#' @return A named list with:
#'   \describe{
#'     \item{samples}{List of Sample external pointers.}
#'     \item{rows}{Integer vector of row indices (0-based).}
#'     \item{cols}{Integer vector of column indices (0-based).}
#'     \item{indices}{Integer vector of 0-based flat indices
#'       (\code{row * ncols + col}), suitable for
#'       \code{\link{maxent_featured_space}}.}
#'   }
#' @export
#' @examples
#' dim <- maxent_dimension(100, 100, -120, 35, 0.1)
#' occ <- data.frame(longitude = c(-118.5, -119.0),
#'                   latitude  = c(36.5, 37.0))
#' result <- maxent_read_occurrences(occ, dim)
#' result$indices  # 0-based flat indices for FeaturedSpace
maxent_read_occurrences <- function(file_or_df, dim, lon_col = "longitude",
                                    lat_col = "latitude", name_col = NULL) {
    # Load data
    if (is.character(file_or_df) && length(file_or_df) == 1L) {
        df <- utils::read.csv(file_or_df, stringsAsFactors = FALSE)
    } else if (is.data.frame(file_or_df)) {
        df <- file_or_df
    } else {
        stop("'file_or_df' must be a file path (character) or a data.frame")
    }

    if (!lon_col %in% names(df)) {
        stop("Column '", lon_col, "' not found in data")
    }
    if (!lat_col %in% names(df)) {
        stop("Column '", lat_col, "' not found in data")
    }

    lons <- as.numeric(df[[lon_col]])
    lats <- as.numeric(df[[lat_col]])

    # Drop rows with missing coordinates
    valid <- !is.na(lons) & !is.na(lats)
    lons <- lons[valid]
    lats <- lats[valid]

    if (length(lons) == 0L) {
        stop("No valid occurrence records after removing NA coordinates")
    }

    # Generate names
    if (!is.null(name_col) && name_col %in% names(df)) {
        sample_names <- as.character(df[[name_col]][valid])
    } else {
        sample_names <- paste0("occ_", seq_along(lons))
    }

    # Get dimension info to compute flat indices
    dim_info <- get_grid_dimension_info(dim)
    ncols <- dim_info$ncols

    samples <- vector("list", length(lons))
    rows_vec <- integer(length(lons))
    cols_vec <- integer(length(lons))
    indices  <- integer(length(lons))

    for (i in seq_along(lons)) {
        rc <- coords_to_rowcol(dim, lons[i], lats[i])
        rows_vec[i] <- rc[1]
        cols_vec[i] <- rc[2]
        indices[i]  <- rc[1] * ncols + rc[2]
        samples[[i]] <- create_sample(0L, rc[1], rc[2], lats[i], lons[i],
                                      sample_names[i])
    }

    list(
        samples = samples,
        rows    = rows_vec,
        cols    = cols_vec,
        indices = indices
    )
}

#' Generate Background Sample Indices
#'
#' Randomly selects valid (non-NODATA) cells from a reference grid for use
#' as background points in MaxEnt modeling.
#'
#' @param grid External pointer to a GridFloat object used as a reference
#'   (e.g. an environmental layer). Only cells with valid data are eligible.
#' @param n  Integer: number of background points to sample
#'   (default \code{10000L}).
#' @param seed  Integer or \code{NULL}: random seed for reproducibility.
#'   If \code{NULL} (default), no seed is set.
#' @return A named list with:
#'   \describe{
#'     \item{rows}{Integer vector of row indices (0-based).}
#'     \item{cols}{Integer vector of column indices (0-based).}
#'     \item{indices}{Integer vector of 0-based flat indices
#'       (\code{row * ncols + col}), suitable for
#'       \code{\link{maxent_featured_space}}.}
#'   }
#' @export
#' @examples
#' \dontrun{
#' dim <- maxent_dimension(100, 100, -120, 35, 0.1)
#' grid <- maxent_grid(dim, "env1")
#' bg <- maxent_background_indices(grid, n = 5000, seed = 42)
#' bg$indices  # 0-based flat indices for FeaturedSpace
#' }
maxent_background_indices <- function(grid, n = 10000L, seed = NULL) {
    info <- maxent_grid_info(grid)
    nrows <- info$nrows
    ncols <- info$ncols

    mat <- maxent_grid_to_matrix(grid)

    # Identify valid (non-NA) cells
    valid_cells <- which(!is.na(mat), arr.ind = TRUE)
    if (nrow(valid_cells) == 0L) {
        stop("No valid (non-NODATA) cells in the grid")
    }

    n <- min(as.integer(n), nrow(valid_cells))
    if (!is.null(seed)) set.seed(seed)

    chosen <- sample.int(nrow(valid_cells), size = n)

    # valid_cells uses 1-based row/col; convert to 0-based
    rows_0 <- as.integer(valid_cells[chosen, 1] - 1L)
    cols_0 <- as.integer(valid_cells[chosen, 2] - 1L)
    flat   <- rows_0 * ncols + cols_0

    list(
        rows    = rows_0,
        cols    = cols_0,
        indices = flat
    )
}
