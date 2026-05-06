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

#ifndef MAXENT_SAMPLE_HPP
#define MAXENT_SAMPLE_HPP

#include <string>
#include <unordered_map>
#include "grid_dimension.hpp"

namespace maxent {

/**
 * @brief Represents a species occurrence sample point
 * 
 * A sample contains geographic coordinates, grid indices, and optional
 * environmental variable values associated with the location.
 */
class Sample {
public:
    int point;      ///< Point identifier
    int row;        ///< Row index in grid
    int col;        ///< Column index in grid
    double lat;     ///< Latitude coordinate
    double lon;     ///< Longitude coordinate
    std::string name; ///< Sample name/identifier

    /// Map of feature/variable names to their values
    std::unordered_map<std::string, double> feature_map;

    /**
     * @brief Construct a Sample with coordinates and grid indices
     * 
     * @param point Point identifier
     * @param row Row index
     * @param col Column index
     * @param lat Latitude
     * @param lon Longitude
     * @param name Sample name
     */
    Sample(int point, int row, int col, double lat, double lon, 
           const std::string& name = "")
        : point(point), row(row), col(col), lat(lat), lon(lon), name(name) {}

    /**
     * @brief Construct a Sample with coordinates and feature map
     * 
     * @param point Point identifier
     * @param row Row index
     * @param col Column index
     * @param lat Latitude
     * @param lon Longitude
     * @param name Sample name
     * @param features Map of feature names to values
     */
    Sample(int point, int row, int col, double lat, double lon,
           const std::string& name,
           const std::unordered_map<std::string, double>& features)
        : point(point), row(row), col(col), lat(lat), lon(lon), 
          name(name), feature_map(features) {}

    /**
     * @brief Get point identifier
     * @return Point identifier
     */
    int getPoint() const { return point; }

    /**
     * @brief Get row index
     * @return Row index
     */
    int getRow() const { return row; }

    /**
     * @brief Get column index
     * @return Column index
     */
    int getCol() const { return col; }

    /**
     * @brief Get row index for a specific grid dimension
     * @param dim Grid dimension
     * @return Row index in that dimension
     */
    int getRow(const GridDimension& dim) const {
        return dim.toRow(lat);
    }

    /**
     * @brief Get column index for a specific grid dimension
     * @param dim Grid dimension
     * @return Column index in that dimension
     */
    int getCol(const GridDimension& dim) const {
        return dim.toCol(lon);
    }

    /**
     * @brief Get latitude
     * @return Latitude coordinate
     */
    double getLat() const { return lat; }

    /**
     * @brief Get longitude
     * @return Longitude coordinate
     */
    double getLon() const { return lon; }

    /**
     * @brief Get sample name
     * @return Sample name
     */
    const std::string& getName() const { return name; }

    /**
     * @brief Get feature value by name
     * 
     * @param feature_name Name of the feature
     * @param default_val Default value if feature not found
     * @return Feature value or default
     */
    double getFeature(const std::string& feature_name, 
                     double default_val = 0.0) const {
        auto it = feature_map.find(feature_name);
        if (it != feature_map.end()) {
            return it->second;
        }
        return default_val;
    }

    /**
     * @brief Set feature value
     * 
     * @param feature_name Name of the feature
     * @param value Feature value
     */
    void setFeature(const std::string& feature_name, double value) {
        feature_map[feature_name] = value;
    }

    /**
     * @brief Check if feature exists
     * 
     * @param feature_name Name of the feature
     * @return true if feature exists, false otherwise
     */
    bool hasFeature(const std::string& feature_name) const {
        return feature_map.find(feature_name) != feature_map.end();
    }
};

} // namespace maxent

#endif // MAXENT_SAMPLE_HPP
