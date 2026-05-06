/*
Copyright (c) 2025 Maxent Contributors

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#ifndef MAXENT_GRID_IO_HPP
#define MAXENT_GRID_IO_HPP

#include "grid.hpp"
#include "layer.hpp"

#include <fstream>
#include <sstream>
#include <string>
#include <stdexcept>
#include <algorithm>
#include <cmath>
#include <iomanip>
#include <memory>
#include <cctype>
#include <limits>

namespace maxent {

/**
 * @brief Read and write Grid objects in ESRI ASCII (.asc) format.
 *
 * Ported from density/GridIO.java (readASC) and density/GridWriter.java
 * (writeASC).
 *
 * The ASC (Arc/Info ASCII Grid) format consists of a 6-line header
 * followed by space-separated cell values in row-major order:
 *
 *     ncols         <ncols>
 *     nrows         <nrows>
 *     xllcorner     <xll>
 *     yllcorner     <yll>
 *     cellsize      <cellsize>
 *     NODATA_value  <nodata>
 *     <data row 1>
 *     <data row 2>
 *     ...
 */
class GridIO {
public:
    // =================================================================
    // Reading
    // =================================================================

    /**
     * @brief Read a float grid from an ESRI ASCII (.asc) file.
     *
     * The Java implementation tries short first and falls back to float.
     * This C++ version reads directly into a GridFloat for simplicity and
     * consistency with the Grid<float> template.
     *
     * @param filename  Path to the .asc file.
     * @return          A GridFloat populated with the data.
     */
    static GridFloat read_asc(const std::string& filename) {
        std::ifstream in(filename);
        if (!in.is_open()) {
            throw std::runtime_error("Cannot open ASC file: " + filename);
        }

        // -- header --
        int ncols = read_header_int(in);
        int nrows = read_header_int(in);
        double xllcorner = read_header_double(in);
        double yllcorner = read_header_double(in);
        double cellsize  = read_header_double(in);
        double nodata_d  = read_header_double(in);
        float  nodata    = static_cast<float>(nodata_d);

        GridDimension dim(nrows, ncols, xllcorner, yllcorner, cellsize);
        GridFloat grid(dim, extract_name(filename), nodata);

        // -- data --
        for (int i = 0; i < nrows; ++i) {
            for (int j = 0; j < ncols; ++j) {
                std::string token;
                if (!(in >> token)) {
                    throw std::runtime_error(
                        "Unexpected end of data in ASC file: " + filename +
                        " at row " + std::to_string(i) +
                        " col " + std::to_string(j));
                }
                float val = parse_float(token);
                if (std::isnan(val)) val = nodata;
                grid.setValue(i, j, val);
            }
        }

        return grid;
    }

    /**
     * @brief Read a double-precision grid from an ESRI ASCII (.asc) file.
     */
    static GridDouble read_asc_double(const std::string& filename) {
        std::ifstream in(filename);
        if (!in.is_open()) {
            throw std::runtime_error("Cannot open ASC file: " + filename);
        }

        int ncols       = read_header_int(in);
        int nrows       = read_header_int(in);
        double xllcorner = read_header_double(in);
        double yllcorner = read_header_double(in);
        double cellsize  = read_header_double(in);
        double nodata    = read_header_double(in);

        GridDimension dim(nrows, ncols, xllcorner, yllcorner, cellsize);
        GridDouble grid(dim, extract_name(filename), nodata);

        for (int i = 0; i < nrows; ++i) {
            for (int j = 0; j < ncols; ++j) {
                std::string token;
                if (!(in >> token)) {
                    throw std::runtime_error(
                        "Unexpected end of data in ASC file: " + filename);
                }
                double val = parse_double(token);
                if (std::isnan(val)) val = nodata;
                grid.setValue(i, j, val);
            }
        }

        return grid;
    }

    // =================================================================
    // Writing
    // =================================================================

    /**
     * @brief Write a GridFloat to an ESRI ASCII (.asc) file.
     *
     * Matches the Java GridWriter.writeASC format: scientific notation
     * for floating-point grids.
     *
     * @param grid      Grid to write.
     * @param filename  Output file path.
     * @param scientific  Use scientific notation for float values (default true).
     */
    static void write_asc(const GridFloat& grid, const std::string& filename,
                          bool scientific = true) {
        write_asc_impl(grid, filename, scientific);
    }

    /**
     * @brief Write a GridDouble to an ESRI ASCII (.asc) file.
     */
    static void write_asc(const GridDouble& grid, const std::string& filename,
                          bool scientific = true) {
        write_asc_impl(grid, filename, scientific);
    }

    /**
     * @brief Write a GridInt to an ESRI ASCII (.asc) file.
     *
     * Integer grids are written without fractional digits.
     */
    static void write_asc(const GridInt& grid, const std::string& filename) {
        write_asc_int_impl(grid, filename);
    }

    // =================================================================
    // Format detection
    // =================================================================

    /**
     * @brief Read a grid from file, auto-detecting the format from
     *        the file extension.
     *
     * Currently only ".asc" is supported.
     */
    static GridFloat read_grid(const std::string& filename) {
        std::string lower = filename;
        std::transform(lower.begin(), lower.end(), lower.begin(),
                       [](unsigned char c) { return std::tolower(c); });

        if (ends_with(lower, ".asc")) {
            return read_asc(filename);
        }
        throw std::runtime_error(
            "Unsupported grid format: " + filename +
            " (currently only .asc is supported)");
    }

private:
    // -----------------------------------------------------------------
    // Header parsing helpers
    // -----------------------------------------------------------------

    static int read_header_int(std::ifstream& in) {
        std::string key, val;
        if (!(in >> key >> val)) {
            throw std::runtime_error("Failed to read ASC header field");
        }
        return std::stoi(val);
    }

    static double read_header_double(std::ifstream& in) {
        std::string key, val;
        if (!(in >> key >> val)) {
            throw std::runtime_error("Failed to read ASC header field");
        }
        return parse_double(val);
    }

    // -----------------------------------------------------------------
    // Number parsing (handles decimal commas)
    // -----------------------------------------------------------------

    static double parse_double(const std::string& s) {
        size_t pos = 0;
        double val = 0.0;
        try {
            val = std::stod(s, &pos);
        } catch (const std::exception&) {
            std::string fixed = s;
            std::replace(fixed.begin(), fixed.end(), ',', '.');
            return std::stod(fixed);
        }
        if (pos == s.size()) return val;
        // Partial parse — likely a decimal comma
        std::string fixed = s;
        std::replace(fixed.begin(), fixed.end(), ',', '.');
        return std::stod(fixed);
    }

    static float parse_float(const std::string& s) {
        // First try standard parsing
        size_t pos = 0;
        float val = 0.0f;
        try {
            val = std::stof(s, &pos);
        } catch (const std::exception&) {
            // Completely invalid — try replacing comma
            std::string fixed = s;
            std::replace(fixed.begin(), fixed.end(), ',', '.');
            return std::stof(fixed);
        }
        // If the whole string was consumed, we're good
        if (pos == s.size()) return val;
        // Partial parse — likely a decimal comma (e.g. "1,5")
        std::string fixed = s;
        std::replace(fixed.begin(), fixed.end(), ',', '.');
        return std::stof(fixed);
    }

    // -----------------------------------------------------------------
    // Name extraction
    // -----------------------------------------------------------------

    static std::string extract_name(const std::string& path) {
        return Layer::name_from_path(path);
    }

    // -----------------------------------------------------------------
    // Writing helpers
    // -----------------------------------------------------------------

    template<typename T>
    static void write_header(std::ofstream& out, const Grid<T>& grid) {
        const auto& dim = grid.getDimension();
        out << "ncols         " << dim.ncols << '\n';
        out << "nrows         " << dim.nrows << '\n';
        out << std::setprecision(17);
        out << "xllcorner     " << dim.xll << '\n';
        out << "yllcorner     " << dim.yll << '\n';
        out << "cellsize      " << dim.cellsize << '\n';
        out << "NODATA_value  " << static_cast<int>(grid.getNodataValue()) << '\n';
    }

    template<typename T>
    static void write_asc_impl(const Grid<T>& grid, const std::string& filename,
                               bool scientific) {
        std::ofstream out(filename);
        if (!out.is_open()) {
            throw std::runtime_error("Cannot open file for writing: " + filename);
        }
        write_header(out, grid);

        const auto& dim = grid.getDimension();
        T nodata = grid.getNodataValue();

        if (scientific) {
            out << std::scientific;
        } else {
            out << std::fixed << std::setprecision(4);
        }

        for (int i = 0; i < dim.nrows; ++i) {
            for (int j = 0; j < dim.ncols; ++j) {
                if (j > 0) out << ' ';
                T val = grid.getValue(i, j);
                if (val == nodata) {
                    out << static_cast<int>(nodata);
                } else {
                    out << val;
                }
            }
            out << '\n';
        }
    }

    template<typename T>
    static void write_asc_int_impl(const Grid<T>& grid,
                                   const std::string& filename) {
        std::ofstream out(filename);
        if (!out.is_open()) {
            throw std::runtime_error("Cannot open file for writing: " + filename);
        }
        write_header(out, grid);

        const auto& dim = grid.getDimension();
        T nodata = grid.getNodataValue();

        for (int i = 0; i < dim.nrows; ++i) {
            for (int j = 0; j < dim.ncols; ++j) {
                if (j > 0) out << ' ';
                out << static_cast<int>(grid.getValue(i, j));
            }
            out << '\n';
        }
    }

    // -----------------------------------------------------------------
    // String helpers
    // -----------------------------------------------------------------

    static bool ends_with(const std::string& str, const std::string& suffix) {
        if (suffix.size() > str.size()) return false;
        return str.compare(str.size() - suffix.size(), suffix.size(), suffix) == 0;
    }
};

} // namespace maxent

#endif // MAXENT_GRID_IO_HPP
