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

#ifndef MAXENT_GRID_HPP
#define MAXENT_GRID_HPP

#include <vector>
#include <string>
#include <memory>
#include <stdexcept>
#include "grid_dimension.hpp"

namespace maxent {

/**
 * @brief Abstract base class for raster grids
 * 
 * Grid represents environmental variable layers as 2D raster grids.
 * This template-based design allows for different data types (float, int, byte, etc.)
 * while providing a uniform interface.
 */
template<typename T>
class Grid {
public:
    /// Grid data types
    enum DataType {
        SHORT = 0,
        FLOAT = 1,
        BYTE = 2,
        INT = 3,
        DOUBLE = 4,
        UBYTE = 5
    };

protected:
    std::vector<T> data_;          ///< Grid data stored in row-major order
    GridDimension dimension_;       ///< Spatial dimensions and georeference
    T nodata_value_;               ///< Value representing missing data
    std::string name_;             ///< Grid layer name
    bool interpolate_samples_;     ///< Whether to interpolate sample values

public:
    /**
     * @brief Construct an empty grid
     */
    Grid() 
        : nodata_value_(static_cast<T>(-9999)), 
          interpolate_samples_(false) {}

    /**
     * @brief Construct a grid with specified dimensions
     * 
     * @param dim Grid dimensions
     * @param name Grid layer name
     * @param nodata_value Value representing no data
     */
    Grid(const GridDimension& dim, const std::string& name = "", 
         T nodata_value = static_cast<T>(-9999))
        : dimension_(dim), nodata_value_(nodata_value), name_(name),
          interpolate_samples_(false) {
        data_.resize(dim.size(), nodata_value);
    }

    /**
     * @brief Virtual destructor
     */
    virtual ~Grid() = default;

    /**
     * @brief Get grid value at row, col
     * 
     * @param row Row index
     * @param col Column index
     * @return Grid value
     */
    T getValue(int row, int col) const {
        if (!dimension_.isValid(row, col)) {
            throw std::out_of_range("Grid indices out of bounds");
        }
        return data_[dimension_.toIndex(row, col)];
    }

    /**
     * @brief Set grid value at row, col
     * 
     * @param row Row index
     * @param col Column index
     * @param value Value to set
     */
    void setValue(int row, int col, T value) {
        if (!dimension_.isValid(row, col)) {
            throw std::out_of_range("Grid indices out of bounds");
        }
        data_[dimension_.toIndex(row, col)] = value;
    }

    /**
     * @brief Check if cell has valid data
     * 
     * @param row Row index
     * @param col Column index
     * @return true if cell has valid data, false otherwise
     */
    bool hasData(int row, int col) const {
        if (!dimension_.isValid(row, col)) {
            return false;
        }
        T val = data_[dimension_.toIndex(row, col)];
        return val != nodata_value_;
    }

    /**
     * @brief Evaluate grid at geographic coordinates
     * 
     * @param lon Longitude
     * @param lat Latitude
     * @return Grid value at that location
     */
    T eval(double lon, double lat) const {
        auto rc = dimension_.toRowCol(lon, lat);
        return getValue(rc[0], rc[1]);
    }

    /**
     * @brief Check if geographic coordinates have valid data
     * 
     * @param lon Longitude
     * @param lat Latitude
     * @return true if location has valid data
     */
    bool hasData(double lon, double lat) const {
        auto rc = dimension_.toRowCol(lon, lat);
        return hasData(rc[0], rc[1]);
    }

    /**
     * @brief Get grid dimensions
     * @return Grid dimensions
     */
    const GridDimension& getDimension() const { return dimension_; }

    /**
     * @brief Set grid dimensions
     * @param dim New dimensions
     */
    void setDimension(const GridDimension& dim) { 
        dimension_ = dim;
        data_.resize(dim.size(), nodata_value_);
    }

    /**
     * @brief Get grid name
     * @return Grid name
     */
    const std::string& getName() const { return name_; }

    /**
     * @brief Set grid name
     * @param name New name
     */
    void setName(const std::string& name) { name_ = name; }

    /**
     * @brief Get no-data value
     * @return No-data value
     */
    T getNodataValue() const { return nodata_value_; }

    /**
     * @brief Set no-data value
     * @param value New no-data value
     */
    void setNodataValue(T value) { nodata_value_ = value; }

    /**
     * @brief Get number of rows
     * @return Number of rows
     */
    int getRows() const { return dimension_.nrows; }

    /**
     * @brief Get number of columns
     * @return Number of columns
     */
    int getCols() const { return dimension_.ncols; }

    /**
     * @brief Get total number of cells
     * @return Total number of cells
     */
    int size() const { return dimension_.size(); }

    /**
     * @brief Count cells with valid data
     * @return Number of cells with valid data
     */
    int countData() const {
        int count = 0;
        for (int i = 0; i < dimension_.nrows; i++) {
            for (int j = 0; j < dimension_.ncols; j++) {
                if (hasData(i, j)) {
                    count++;
                }
            }
        }
        return count;
    }

    /**
     * @brief Get direct access to data vector
     * @return Reference to data vector
     */
    std::vector<T>& data() { return data_; }

    /**
     * @brief Get const access to data vector
     * @return Const reference to data vector
     */
    const std::vector<T>& data() const { return data_; }

    /**
     * @brief Bilinear interpolation at geographic coordinates
     * 
     * @param lon Longitude
     * @param lat Latitude
     * @return Interpolated value
     */
    double interpolate(double lon, double lat) const {
        // Get fractional row/col positions
        double row_f = (dimension_.yll + dimension_.nrows * dimension_.cellsize - lat) / dimension_.cellsize;
        double col_f = (lon - dimension_.xll) / dimension_.cellsize;
        
        int row0 = static_cast<int>(row_f);
        int col0 = static_cast<int>(col_f);
        int row1 = row0 + 1;
        int col1 = col0 + 1;

        // Check bounds
        if (row0 < 0 || row1 >= dimension_.nrows || 
            col0 < 0 || col1 >= dimension_.ncols) {
            return static_cast<double>(nodata_value_);
        }

        // Get fractional parts
        double row_frac = row_f - row0;
        double col_frac = col_f - col0;

        // Get four corner values
        T v00 = getValue(row0, col0);
        T v01 = getValue(row0, col1);
        T v10 = getValue(row1, col0);
        T v11 = getValue(row1, col1);

        // Check if any corner is nodata
        if (v00 == nodata_value_ || v01 == nodata_value_ ||
            v10 == nodata_value_ || v11 == nodata_value_) {
            return static_cast<double>(nodata_value_);
        }

        // Bilinear interpolation
        double v0 = v00 * (1 - col_frac) + v01 * col_frac;
        double v1 = v10 * (1 - col_frac) + v11 * col_frac;
        return v0 * (1 - row_frac) + v1 * row_frac;
    }
};

// Type aliases for common grid types
using GridFloat = Grid<float>;
using GridDouble = Grid<double>;
using GridInt = Grid<int>;
using GridShort = Grid<short>;
using GridByte = Grid<signed char>;
using GridUbyte = Grid<unsigned char>;

} // namespace maxent

#endif // MAXENT_GRID_HPP
