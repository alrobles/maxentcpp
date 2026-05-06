# Shared helpers for tests that depend on terra / PROJ.

skip_if_no_terra <- function() {
    testthat::skip_if_not_installed("terra")
}

# Skip when the PROJ database is not available (e.g. macOS CI runners
# where proj.db is not installed).  Without proj.db, terra cannot resolve
# CRS strings like "EPSG:4326" and throws "[rast] empty srs".
skip_if_no_proj <- function() {
    skip_if_no_terra()
    has_proj <- tryCatch({
        r <- terra::rast(nrows = 1L, ncols = 1L, crs = "EPSG:4326")
        nchar(terra::crs(r)) > 0L
    }, warning = function(w) {
        if (grepl("proj", conditionMessage(w), ignore.case = TRUE))
            return(FALSE)
        TRUE
    }, error = function(e) FALSE)
    if (!has_proj) testthat::skip("PROJ database (proj.db) not available")
}
