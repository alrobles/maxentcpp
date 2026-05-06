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

#ifndef MAXENT_GRID_DIMENSION_HPP
#define MAXENT_GRID_DIMENSION_HPP

#include <array>
#include <cmath>

namespace maxent {

/**
 * @brief Represents the spatial dimensions and georeference of a raster grid
 * 
 * This class stores the number of rows and columns, cell size, and corner
 * coordinates, providing methods to convert between geographic coordinates
 * and grid indices.
 */
class GridDimension {
public:
    int nrows;        ///< Number of rows in the grid
    int ncols;        ///< Number of columns in the grid
    double xll;       ///< X coordinate of lower-left corner
    double yll;       ///< Y coordinate of lower-left corner
    double cellsize;  ///< Size of each cell (assumed square)

    /**
     * @brief Default constructor
     */
    GridDimension()
        : nrows(0), ncols(0), xll(0.0), yll(0.0), cellsize(0.0) {}

    /**
     * @brief Construct a GridDimension with specified parameters
     * 
     * @param nrows Number of rows
     * @param ncols Number of columns
     * @param xll X coordinate of lower-left corner
     * @param yll Y coordinate of lower-left corner
     * @param cellsize Cell size
     */
    GridDimension(int nrows, int ncols, double xll, double yll, double cellsize)
        : nrows(nrows), ncols(ncols), xll(xll), yll(yll), cellsize(cellsize) {}

    /**
     * @brief Convert latitude to row index
     * 
     * @param lat Latitude coordinate
     * @return Row index (0-based)
     */
    int toRow(double lat) const {
        return static_cast<int>((yll + nrows * cellsize - lat) / cellsize);
    }

    /**
     * @brief Convert longitude to column index
     * 
     * @param lon Longitude coordinate
     * @return Column index (0-based)
     */
    int toCol(double lon) const {
        return static_cast<int>((lon - xll) / cellsize);
    }

    /**
     * @brief Convert geographic coordinates to row/col indices
     * 
     * @param lon Longitude
     * @param lat Latitude
     * @return Array containing [row, col]
     */
    std::array<int, 2> toRowCol(double lon, double lat) const {
        return {toRow(lat), toCol(lon)};
    }

    /**
     * @brief Convert row index to latitude (center of cell)
     * 
     * @param row Row index
     * @return Latitude coordinate
     */
    double toLat(int row) const {
        return yll + (nrows - row - 0.5) * cellsize;
    }

    /**
     * @brief Convert column index to longitude (center of cell)
     * 
     * @param col Column index
     * @return Longitude coordinate
     */
    double toLon(int col) const {
        return xll + (col + 0.5) * cellsize;
    }

    /**
     * @brief Check if row and column indices are within bounds
     * 
     * @param row Row index
     * @param col Column index
     * @return true if indices are valid, false otherwise
     */
    bool isValid(int row, int col) const {
        return row >= 0 && row < nrows && col >= 0 && col < ncols;
    }

    /**
     * @brief Get the total number of cells in the grid
     * 
     * @return Total number of cells
     */
    int size() const {
        return nrows * ncols;
    }

    /**
     * @brief Calculate linear index from row and column
     * 
     * @param row Row index
     * @param col Column index
     * @return Linear index
     */
    int toIndex(int row, int col) const {
        return row * ncols + col;
    }
};

} // namespace maxent

#endif // MAXENT_GRID_DIMENSION_HPP
