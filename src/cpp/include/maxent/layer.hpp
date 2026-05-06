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

#ifndef MAXENT_LAYER_HPP
#define MAXENT_LAYER_HPP

#include <string>
#include <algorithm>
#include <array>

namespace maxent {

/**
 * @brief Represents an environmental layer's metadata.
 *
 * Ported from density/Layer.java.  A Layer has a name (typically derived
 * from the file name, minus the extension) and a type describing how
 * MaxEnt should interpret it (continuous, categorical, bias, etc.).
 */
class Layer {
public:
    /// Layer type constants (matching Java Layer.java)
    enum Type {
        UNKNOWN     = 0,
        CONTINUOUS  = 1,
        CATEGORICAL = 2,
        BIAS        = 3,
        MASK        = 4,
        PROBABILITY = 5,
        CUMULATIVE  = 6,
        DEBIAS_AVG  = 7
    };

    /// Human-readable type names (index matches Type enum)
    static constexpr int NUM_TYPES = 8;

    static std::string type_name(int t) {
        static const std::array<std::string, NUM_TYPES> names = {{
            "Unknown", "Continuous", "Categorical", "Bias",
            "Mask", "Probability", "Cumulative", "DebiasAvg"
        }};
        if (t >= 0 && t < NUM_TYPES) return names[t];
        return "Unknown";
    }

    // -----------------------------------------------------------------
    // Construction
    // -----------------------------------------------------------------

    Layer() : name_(), type_(UNKNOWN) {}

    Layer(const std::string& name, int type)
        : name_(name), type_(type) {}

    Layer(const std::string& name, const std::string& type_str)
        : name_(name), type_(UNKNOWN) {
        set_type(type_str);
    }

    // -----------------------------------------------------------------
    // Accessors
    // -----------------------------------------------------------------

    const std::string& name() const { return name_; }
    void set_name(const std::string& n) { name_ = n; }

    int type() const { return type_; }
    std::string type_name() const { return type_name(type_); }

    void set_type(int t) { type_ = t; }

    /**
     * @brief Set type from a string (case-insensitive).
     *
     * Matches the Java behaviour: compares lower-cased input against
     * each known type name.
     */
    void set_type(const std::string& s) {
        std::string lower = s;
        std::transform(lower.begin(), lower.end(), lower.begin(),
                       [](unsigned char c) { return std::tolower(c); });
        for (int i = 0; i < NUM_TYPES; ++i) {
            std::string tname = type_name(i);
            std::transform(tname.begin(), tname.end(), tname.begin(),
                           [](unsigned char c) { return std::tolower(c); });
            if (lower == tname) {
                type_ = i;
                return;
            }
        }
        type_ = UNKNOWN;
    }

    // -----------------------------------------------------------------
    // Utility – extract layer name from a file path
    // -----------------------------------------------------------------

    /**
     * @brief Derive a layer name from a file path.
     *
     * Strips the directory prefix and any extension from the path.
     * e.g.  "/data/bio1.asc" -> "bio1"
     */
    static std::string name_from_path(const std::string& path) {
        // Find last separator
        auto sep = path.find_last_of("/\\");
        std::string base = (sep == std::string::npos) ? path : path.substr(sep + 1);
        // Strip extension
        auto dot = base.find_last_of('.');
        if (dot != std::string::npos) {
            base = base.substr(0, dot);
        }
        return base;
    }

private:
    std::string name_;
    int type_;
};

} // namespace maxent

#endif // MAXENT_LAYER_HPP
