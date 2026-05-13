#' Read an ESRI ASCII Grid File
#'
#' Reads a \code{.asc} raster file into a GridFloat object.
#'
#' @param filename  Character: path to the \code{.asc} file.
#' @return External pointer to a GridFloat C++ object.
#' @export
#' @examples
#' \donttest{
#' g <- maxent_read_asc("bio1.asc")
#' info <- maxent_grid_info(g)
#' print(info)
#' }
maxent_read_asc <- function(filename) {
    grid_read_asc(as.character(filename))
}

#' Read a Grid File (Auto-Detect Format)
#'
#' Reads a raster grid file. The format is detected from the file extension.
#' Currently supports \code{.asc} (ESRI ASCII Grid).
#'
#' @param filename  Character: path to the grid file.
#' @return External pointer to a GridFloat C++ object.
#' @export
maxent_read_grid <- function(filename) {
    grid_read_file(as.character(filename))
}

#' Write a Grid to ESRI ASCII Format
#'
#' Writes a GridFloat to a \code{.asc} file.
#'
#' @param grid       External pointer to a GridFloat object.
#' @param filename   Character: output file path.
#' @param scientific Logical: use scientific notation for floating-point
#'   values (default \code{TRUE}).
#' @return Invisibly returns the output file path.
#' @export
#' @examples
#' \donttest{
#' maxent_write_asc(g, tempfile(fileext = ".asc"))
#' }
maxent_write_asc <- function(grid, filename, scientific = TRUE) {
    grid_write_asc(grid, as.character(filename), as.logical(scientific))
    invisible(filename)
}

#' Get Grid Information
#'
#' Returns metadata about a GridFloat object read from a file.
#'
#' @param grid  External pointer to a GridFloat object.
#' @return Named list with: \code{nrows}, \code{ncols}, \code{xll},
#'   \code{yll}, \code{cellsize}, \code{nodata}, \code{name},
#'   \code{count_data}.
#' @export
maxent_grid_info <- function(grid) {
    grid_float_info(grid)
}

#' Convert Grid to R Matrix
#'
#' Extracts the data from a GridFloat as an R numeric matrix.
#' NODATA cells are converted to \code{NA}.
#'
#' @param grid  External pointer to a GridFloat object.
#' @return Numeric matrix (\code{nrows} \eqn{\times} \code{ncols}).
#' @export
maxent_grid_to_matrix <- function(grid) {
    grid_float_to_matrix(grid)
}

#' Create a Grid from an R Matrix
#'
#' Builds a GridFloat from a numeric matrix and spatial parameters.
#' \code{NA} values in the matrix are stored as the \code{nodata} value.
#'
#' @param mat       Numeric matrix.
#' @param xll       X coordinate of lower-left corner.
#' @param yll       Y coordinate of lower-left corner.
#' @param cellsize  Cell size.
#' @param nodata    NODATA sentinel value (default \code{-9999}).
#' @param name      Grid name (default \code{""}).
#' @return External pointer to a GridFloat C++ object.
#' @export
maxent_grid_from_matrix <- function(mat, xll, yll, cellsize,
                                    nodata = -9999, name = "") {
    grid_float_from_matrix(as.matrix(mat),
                           as.double(xll), as.double(yll),
                           as.double(cellsize), as.double(nodata),
                           as.character(name))
}

#' Convert a terra SpatRaster to a maxentcpp GridFloat
#'
#' Converts a single-layer \code{terra::SpatRaster} into a maxentcpp
#' GridFloat external pointer. The raster must have exactly one layer and
#' square cells (equal x and y resolution).
#'
#' @param r A single-layer \code{terra::SpatRaster} object.
#' @param name Character: grid name (default: layer name from the raster).
#' @return External pointer to a GridFloat C++ object.
#' @details
#' \code{NA} values in the raster are stored as NODATA (sentinel \code{-9999}).
#'
#' Requires the \pkg{terra} package (listed in Suggests).
#'
#' For the \pkg{raster} package, an equivalent workflow is:
#' \preformatted{
#'   library(raster)
#'   r <- raster("bio1.tif")
#'   mat <- as.matrix(r)
#'   e <- extent(r)
#'   g <- maxent_grid_from_matrix(mat, xll = e@@xmin, yll = e@@ymin,
#'                                cellsize = res(r)[1],
#'                                name = names(r))
#' }
#' @export
#' @examples
#' \donttest{
#' stack_path <- system.file("extdata", "stack_1_12_crop.rds",
#'                          package = "maxentcpp")
#' r <- terra::unwrap(readRDS(stack_path))
#' g <- maxent_grid_from_terra(r[[1]])
#' maxent_grid_info(g)
#' }
maxent_grid_from_terra <- function(r, name = NULL) {
    if (!requireNamespace("terra", quietly = TRUE)) {
        stop("Package 'terra' is required. Install it with install.packages('terra').")
    }
    if (!inherits(r, "SpatRaster")) {
        stop("'r' must be a terra::SpatRaster object")
    }
    if (terra::nlyr(r) != 1L) {
        stop("'r' must have exactly one layer; got ", terra::nlyr(r))
    }

    res_xy <- terra::res(r)
    if (abs(res_xy[1] - res_xy[2]) > 1e-10 * max(res_xy)) {
        stop("Grid cells must be square (equal x and y resolution)")
    }
    cellsize <- res_xy[1]

    e <- terra::ext(r)
    xll <- e[1]  # xmin
    yll <- e[3]  # ymin

    if (is.null(name)) {
        name <- names(r)[1]
    }

    # terra stores values top-to-bottom (row 1 = northernmost) which matches
    # the ESRI ASCII / maxentcpp convention.
    mat <- terra::as.matrix(r, wide = TRUE)

    maxent_grid_from_matrix(mat, xll = xll, yll = yll, cellsize = cellsize,
                            nodata = -9999, name = name)
}

#' Convert a maxentcpp GridFloat to a terra SpatRaster
#'
#' Creates a \code{terra::SpatRaster} from a maxentcpp GridFloat external
#' pointer.
#'
#' @param grid  External pointer to a GridFloat C++ object.
#' @param crs   Character: coordinate reference system string
#'   (default \code{"EPSG:4326"}, i.e. WGS 84 longitude/latitude).
#' @return A single-layer \code{terra::SpatRaster}.
#' @details
#' Requires the \pkg{terra} package (listed in Suggests).
#'
#' For the \pkg{raster} package, an equivalent workflow is:
#' \preformatted{
#'   library(raster)
#'   info <- maxent_grid_info(grid)
#'   mat  <- maxent_grid_to_matrix(grid)
#'   r <- raster(mat,
#'               xmn = info$xll,
#'               xmx = info$xll + info$ncols * info$cellsize,
#'               ymn = info$yll,
#'               ymx = info$yll + info$nrows * info$cellsize,
#'               crs = "+proj=longlat +datum=WGS84")
#' }
#' @export
#' @examples
#' \donttest{
#' stack_path <- system.file("extdata", "stack_1_12_crop.rds",
#'                          package = "maxentcpp")
#' r <- terra::unwrap(readRDS(stack_path))
#' g <- maxent_grid_from_terra(r[[1]])
#' r2 <- maxent_grid_to_terra(g)
#' }
maxent_grid_to_terra <- function(grid, crs = "EPSG:4326") {
    if (!requireNamespace("terra", quietly = TRUE)) {
        stop("Package 'terra' is required. Install it with install.packages('terra').")
    }

    info <- maxent_grid_info(grid)
    mat  <- maxent_grid_to_matrix(grid)

    xmin <- info$xll
    xmax <- info$xll + info$ncols * info$cellsize
    ymin <- info$yll
    ymax <- info$yll + info$nrows * info$cellsize

    r <- terra::rast(
        nrows = info$nrows,
        ncols = info$ncols,
        xmin  = xmin,
        xmax  = xmax,
        ymin  = ymin,
        ymax  = ymax,
        crs   = crs
    )
    names(r) <- info$name

    # terra::values() expects a vector in row-major order (top-to-bottom),
    # which is what as.vector(t(mat)) produces.
    terra::values(r) <- as.vector(t(mat))

    r
}

#' Open a CSV File for Reading
#'
#' Opens a CSV file and reads column headers.
#'
#' @param filename    Character: path to the CSV file.
#' @param has_header  Logical: first line is header (default \code{TRUE}).
#' @return External pointer to a CsvReader C++ object.
#' @export
maxent_csv_open <- function(filename, has_header = TRUE) {
    csv_open(as.character(filename), as.logical(has_header))
}

#' Get CSV Column Headers
#'
#' @param reader  External pointer to a CsvReader object.
#' @return Character vector of column names.
#' @export
maxent_csv_headers <- function(reader) {
    csv_headers(reader)
}

#' Read the Next CSV Record
#'
#' @param reader  External pointer to a CsvReader object.
#' @return Character vector of field values, or \code{NULL} on EOF.
#' @export
maxent_csv_next <- function(reader) {
    csv_next_record(reader)
}

#' Read an Entire Column as Doubles
#'
#' Reads from the current file position to EOF.
#'
#' @param reader  External pointer to a CsvReader object.
#' @param field   Character: column name.
#' @return Numeric vector.
#' @export
maxent_csv_read_column <- function(reader, field) {
    csv_read_double_column(reader, as.character(field))
}

#' Close a CSV Reader
#'
#' @param reader  External pointer to a CsvReader object.
#' @return Invisibly returns \code{NULL}.
#' @export
maxent_csv_close <- function(reader) {
    csv_close(reader)
    invisible(NULL)
}

#' Create a Layer Metadata Object
#'
#' @param name      Character: layer name.
#' @param type      Character: layer type. One of \code{"Continuous"},
#'   \code{"Categorical"}, \code{"Bias"}, \code{"Mask"},
#'   \code{"Probability"}, \code{"Cumulative"}, \code{"DebiasAvg"},
#'   or \code{"Unknown"}.
#' @return External pointer to a Layer C++ object.
#' @export
maxent_layer <- function(name, type = "Continuous") {
    create_layer(as.character(name), as.character(type))
}

#' Get Layer Metadata
#'
#' @param layer  External pointer to a Layer object.
#' @return Named list with \code{name} and \code{type}.
#' @export
maxent_layer_info <- function(layer) {
    get_layer_info(layer)
}

#' Extract Layer Name from a File Path
#'
#' Strips directory prefix and extension.
#'
#' @param path  Character: file path.
#' @return Character: layer name (e.g., \code{"/data/bio1.asc"} → \code{"bio1"}).
#' @export
maxent_layer_name <- function(path) {
    layer_name_from_path(as.character(path))
}

#' Open a CSV File for Writing
#'
#' Opens a CSV file and returns a writer object. Use \code{\link{maxent_csv_write}},
#' \code{\link{maxent_csv_write_num}}, \code{\link{maxent_csv_write_row}}, and
#' \code{\link{maxent_csv_write_close}} to write data and close the file.
#'
#' @param filename   Character: output file path.
#' @param append     Logical: append to an existing file (default \code{FALSE}).
#' @param precision  Integer: number of decimal places for numeric values
#'   (default \code{4}).
#' @return External pointer to a CsvWriter C++ object.
#' @export
maxent_csv_write_open <- function(filename, append = FALSE, precision = 4L) {
    csv_writer_open(as.character(filename), as.logical(append),
                    as.integer(precision))
}

#' Write a String Value to the Current CSV Row
#'
#' Adds a \code{column = value} pair (as a character string) to the current
#' row buffer. Call \code{\link{maxent_csv_write_row}} to flush the row.
#'
#' @param writer  External pointer to a CsvWriter object.
#' @param column  Character: column name.
#' @param value   Character: value to write.
#' @return Invisibly returns the writer object.
#' @export
maxent_csv_write <- function(writer, column, value) {
    csv_writer_print(writer, as.character(column), as.character(value))
    invisible(writer)
}

#' Write a Numeric Value to the Current CSV Row
#'
#' Adds a \code{column = value} pair (as a double) to the current row buffer.
#' Call \code{\link{maxent_csv_write_row}} to flush the row.
#'
#' @param writer  External pointer to a CsvWriter object.
#' @param column  Character: column name.
#' @param value   Numeric: value to write.
#' @return Invisibly returns the writer object.
#' @export
maxent_csv_write_num <- function(writer, column, value) {
    csv_writer_print_double(writer, as.character(column), as.double(value))
    invisible(writer)
}

#' Flush the Current Row to the CSV File
#'
#' Writes all buffered column values as a single CSV row and starts a new
#' row buffer.
#'
#' @param writer  External pointer to a CsvWriter object.
#' @return Invisibly returns the writer object.
#' @export
maxent_csv_write_row <- function(writer) {
    csv_writer_println(writer)
    invisible(writer)
}

#' Close a CSV Writer
#'
#' Flushes any pending data and closes the CSV file.
#'
#' @param writer  External pointer to a CsvWriter object.
#' @return Invisibly returns \code{NULL}.
#' @export
maxent_csv_write_close <- function(writer) {
    csv_writer_close(writer)
    invisible(NULL)
}
