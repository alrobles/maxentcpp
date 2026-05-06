#include <Rcpp.h>

// Enable C++17
// [[Rcpp::plugins(cpp17)]]

// Link to Eigen
// [[Rcpp::depends(RcppEigen)]]

#include "cpp/include/maxent/grid_io.hpp"
#include "cpp/include/maxent/csv_reader.hpp"
#include "cpp/include/maxent/csv_writer.hpp"
#include "cpp/include/maxent/layer.hpp"

using namespace Rcpp;
using namespace maxent;

// =========================================================================
// GridIO
// =========================================================================

//' Read an ESRI ASCII grid (.asc) file
//'
//' Reads an ASC raster file and returns a float Grid external pointer.
//'
//' @param filename Path to the .asc file.
//' @return External pointer to a GridFloat object.
//' @export
// [[Rcpp::export]]
SEXP grid_read_asc(std::string filename) {
    GridFloat* g = new GridFloat(GridIO::read_asc(filename));
    XPtr<GridFloat> ptr(g, true);
    return ptr;
}

//' Write a float Grid to an ESRI ASCII (.asc) file
//'
//' @param grid_ptr   External pointer to a GridFloat object.
//' @param filename   Output file path.
//' @param scientific Logical: use scientific notation (default TRUE).
//' @return Called for side effects; returns invisibly.
//' @export
// [[Rcpp::export]]
void grid_write_asc(SEXP grid_ptr, std::string filename,
                    bool scientific = true) {
    XPtr<GridFloat> g(grid_ptr);
    GridIO::write_asc(*g, filename, scientific);
}

//' Read a grid from file (auto-detect format)
//'
//' Currently supports .asc format. Returns a float Grid.
//'
//' @param filename Path to the grid file.
//' @return External pointer to a GridFloat object.
//' @export
// [[Rcpp::export]]
SEXP grid_read_file(std::string filename) {
    GridFloat* g = new GridFloat(GridIO::read_grid(filename));
    XPtr<GridFloat> ptr(g, true);
    return ptr;
}

//' Get grid information for an ASC-loaded grid
//'
//' Returns metadata and basic statistics for a GridFloat.
//'
//' @param grid_ptr External pointer to a GridFloat object.
//' @return Named list with nrows, ncols, xll, yll, cellsize, nodata,
//'   name, count_data.
//' @export
// [[Rcpp::export]]
List grid_float_info(SEXP grid_ptr) {
    XPtr<GridFloat> g(grid_ptr);
    const auto& dim = g->getDimension();
    return List::create(
        Named("nrows")      = dim.nrows,
        Named("ncols")      = dim.ncols,
        Named("xll")        = dim.xll,
        Named("yll")        = dim.yll,
        Named("cellsize")   = dim.cellsize,
        Named("nodata")     = static_cast<double>(g->getNodataValue()),
        Named("name")       = g->getName(),
        Named("count_data") = g->countData()
    );
}

//' Extract the data from a GridFloat as an R matrix
//'
//' @param grid_ptr External pointer to a GridFloat object.
//' @return Numeric matrix (nrows × ncols). NODATA cells are set to NA.
//' @export
// [[Rcpp::export]]
NumericMatrix grid_float_to_matrix(SEXP grid_ptr) {
    XPtr<GridFloat> g(grid_ptr);
    int nr = g->getRows();
    int nc = g->getCols();
    float nodata = g->getNodataValue();
    NumericMatrix mat(nr, nc);
    for (int i = 0; i < nr; ++i) {
        for (int j = 0; j < nc; ++j) {
            float v = g->getValue(i, j);
            mat(i, j) = (v == nodata) ? NA_REAL : static_cast<double>(v);
        }
    }
    return mat;
}

//' Create a GridFloat from an R matrix
//'
//' @param mat       Numeric matrix with grid data (NA becomes NODATA).
//' @param xll       X coordinate of lower-left corner.
//' @param yll       Y coordinate of lower-left corner.
//' @param cellsize  Cell size.
//' @param nodata    NODATA value (default -9999).
//' @param name      Grid name (default "").
//' @return External pointer to a GridFloat object.
//' @export
// [[Rcpp::export]]
SEXP grid_float_from_matrix(NumericMatrix mat,
                            double xll, double yll, double cellsize,
                            double nodata = -9999.0,
                            std::string name = "") {
    int nr = mat.nrow();
    int nc = mat.ncol();
    GridDimension dim(nr, nc, xll, yll, cellsize);
    GridFloat* g = new GridFloat(dim, name, static_cast<float>(nodata));
    for (int i = 0; i < nr; ++i) {
        for (int j = 0; j < nc; ++j) {
            double v = mat(i, j);
            g->setValue(i, j, NumericVector::is_na(v)
                              ? static_cast<float>(nodata)
                              : static_cast<float>(v));
        }
    }
    XPtr<GridFloat> ptr(g, true);
    return ptr;
}

// =========================================================================
// CsvReader
// =========================================================================

//' Open a CSV file for reading
//'
//' @param filename   Path to the CSV file.
//' @param has_header Logical: first line contains column names (default TRUE).
//' @return External pointer to a CsvReader object.
//' @export
// [[Rcpp::export]]
SEXP csv_open(std::string filename, bool has_header = true) {
    CsvReader* reader = new CsvReader(filename, has_header);
    XPtr<CsvReader> ptr(reader, true);
    return ptr;
}

//' Get CSV column headers
//'
//' @param reader_ptr External pointer to a CsvReader object.
//' @return Character vector of header names.
//' @export
// [[Rcpp::export]]
CharacterVector csv_headers(SEXP reader_ptr) {
    XPtr<CsvReader> r(reader_ptr);
    const auto& h = r->headers();
    CharacterVector result(h.size());
    for (size_t i = 0; i < h.size(); ++i) result[i] = h[i];
    return result;
}

//' Read the next CSV record
//'
//' @param reader_ptr External pointer to a CsvReader object.
//' @return Character vector of field values, or NULL on EOF.
//' @export
// [[Rcpp::export]]
SEXP csv_next_record(SEXP reader_ptr) {
    XPtr<CsvReader> r(reader_ptr);
    if (!r->next_record()) return R_NilValue;
    const auto& rec = r->current_record();
    CharacterVector result(rec.size());
    for (size_t i = 0; i < rec.size(); ++i) result[i] = rec[i];
    return result;
}

//' Read an entire named column as doubles
//'
//' Reads from the current position to EOF.
//'
//' @param reader_ptr External pointer to a CsvReader object.
//' @param field      Column name.
//' @return Numeric vector.
//' @export
// [[Rcpp::export]]
NumericVector csv_read_double_column(SEXP reader_ptr, std::string field) {
    XPtr<CsvReader> r(reader_ptr);
    auto vals = r->read_double_column(field);
    return NumericVector(vals.begin(), vals.end());
}

//' Close a CsvReader
//'
//' @param reader_ptr External pointer to a CsvReader object.
//' @return Called for side effects; returns invisibly.
//' @export
// [[Rcpp::export]]
void csv_close(SEXP reader_ptr) {
    XPtr<CsvReader> r(reader_ptr);
    r->close();
}

// =========================================================================
// CsvWriter
// =========================================================================

//' Open a CSV file for writing
//'
//' @param filename  Path to the output CSV file.
//' @param append    Logical: append to existing file (default FALSE).
//' @param precision Number of decimal places for doubles (default 4).
//' @return External pointer to a CsvWriter object.
//' @export
// [[Rcpp::export]]
SEXP csv_writer_open(std::string filename, bool append = false,
                     int precision = 4) {
    CsvWriter* w = new CsvWriter(filename, append, precision);
    XPtr<CsvWriter> ptr(w, true);
    return ptr;
}

//' Write a value into the current row of a CSV
//'
//' @param writer_ptr External pointer to a CsvWriter object.
//' @param column     Column name.
//' @param value      Value to write (character).
//' @return Called for side effects; returns invisibly.
//' @export
// [[Rcpp::export]]
void csv_writer_print(SEXP writer_ptr, std::string column,
                      std::string value) {
    XPtr<CsvWriter> w(writer_ptr);
    w->print(column, value);
}

//' Write a numeric value into the current row of a CSV
//'
//' @param writer_ptr External pointer to a CsvWriter object.
//' @param column     Column name.
//' @param value      Numeric value.
//' @return Called for side effects; returns invisibly.
//' @export
// [[Rcpp::export]]
void csv_writer_print_double(SEXP writer_ptr, std::string column,
                             double value) {
    XPtr<CsvWriter> w(writer_ptr);
    w->print(column, value);
}

//' Flush the current CSV row to disk
//'
//' @param writer_ptr External pointer to a CsvWriter object.
//' @return Called for side effects; returns invisibly.
//' @export
// [[Rcpp::export]]
void csv_writer_println(SEXP writer_ptr) {
    XPtr<CsvWriter> w(writer_ptr);
    w->println();
}

//' Close a CsvWriter
//'
//' @param writer_ptr External pointer to a CsvWriter object.
//' @return Called for side effects; returns invisibly.
//' @export
// [[Rcpp::export]]
void csv_writer_close(SEXP writer_ptr) {
    XPtr<CsvWriter> w(writer_ptr);
    w->close();
}

// =========================================================================
// Layer
// =========================================================================

//' Create a Layer metadata object
//'
//' @param name      Layer name.
//' @param type_str  Type string: "Continuous", "Categorical", "Bias",
//'   "Mask", "Probability", "Cumulative", "DebiasAvg", or "Unknown".
//' @return External pointer to a Layer object.
//' @export
// [[Rcpp::export]]
SEXP create_layer(std::string name, std::string type_str) {
    Layer* l = new Layer(name, type_str);
    XPtr<Layer> ptr(l, true);
    return ptr;
}

//' Get layer metadata
//'
//' @param layer_ptr External pointer to a Layer object.
//' @return Named list with name and type (string).
//' @export
// [[Rcpp::export]]
List get_layer_info(SEXP layer_ptr) {
    XPtr<Layer> l(layer_ptr);
    return List::create(
        Named("name") = l->name(),
        Named("type") = l->type_name()
    );
}

//' Extract a layer name from a file path
//'
//' Strips directory and extension, e.g. "/data/bio1.asc" → "bio1".
//'
//' @param path File path.
//' @return Character: layer name.
//' @export
// [[Rcpp::export]]
std::string layer_name_from_path(std::string path) {
    return Layer::name_from_path(path);
}
