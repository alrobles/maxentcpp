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

#ifndef MAXENT_CSV_WRITER_HPP
#define MAXENT_CSV_WRITER_HPP

#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <unordered_map>
#include <stdexcept>
#include <iomanip>

namespace maxent {

/**
 * @brief Column-based CSV writer.
 *
 * Ported from density/CsvWriter.java. Values are added by column name;
 * the header line is emitted automatically when the first row is flushed.
 */
class CsvWriter {
public:
    /**
     * @brief Construct a CSV writer.
     *
     * @param filename  Path to the output file.
     * @param append    If true, existing content is preserved and new rows
     *                  are appended (column order is read from the existing
     *                  header).
     * @param precision Number of decimal places for floating-point output
     *                  (default 4, matching Java CsvWriter.java).
     */
    explicit CsvWriter(const std::string& filename,
                       bool append = false,
                       int precision = 4)
        : filename_(filename),
          precision_(precision),
          is_first_row_(true),
          is_empty_row_(true) {

        if (append) {
            // Read existing column names from the file
            std::ifstream probe(filename);
            if (probe.is_open()) {
                std::string header_line;
                if (std::getline(probe, header_line)) {
                    parse_header(header_line);
                    is_first_row_ = false;
                }
                probe.close();
            }
        }

        auto mode = append ? (std::ios::out | std::ios::app)
                           : std::ios::out;
        out_.open(filename, mode);
        if (!out_.is_open()) {
            throw std::runtime_error("Cannot open CSV file for writing: " + filename);
        }
    }

    ~CsvWriter() {
        if (out_.is_open()) out_.close();
    }

    // Non-copyable
    CsvWriter(const CsvWriter&) = delete;
    CsvWriter& operator=(const CsvWriter&) = delete;

    // -----------------------------------------------------------------
    // Add values to the current row
    // -----------------------------------------------------------------

    void print(const std::string& column, int value) {
        print(column, std::to_string(value));
    }

    void print(const std::string& column, double value) {
        std::ostringstream oss;
        oss << std::fixed << std::setprecision(precision_) << value;
        print(column, oss.str());
    }

    void print(const std::string& column, const std::string& value) {
        if (column_map_.find(column) == column_map_.end()) {
            // New column
            columns_.push_back(column);
            column_map_[column] = "";
        }
        column_map_[column] = value;
        is_empty_row_ = false;
    }

    // -----------------------------------------------------------------
    // Flush the current row
    // -----------------------------------------------------------------

    /**
     * @brief Write the current row to disk and reset for the next row.
     */
    void println() {
        if (is_empty_row_) return;

        // Emit header on first real row (or if new columns were added)
        if (is_first_row_) {
            write_header();
            is_first_row_ = false;
        }

        // Write values in column order
        for (int i = 0; i < static_cast<int>(columns_.size()); ++i) {
            if (i > 0) out_ << ',';
            auto it = column_map_.find(columns_[i]);
            if (it != column_map_.end() && !it->second.empty()) {
                out_ << protect(it->second);
                it->second.clear();
            }
        }
        out_ << '\n';
        out_.flush();
        is_empty_row_ = true;
    }

    // -----------------------------------------------------------------
    // Lifecycle
    // -----------------------------------------------------------------

    void close() {
        if (out_.is_open()) out_.close();
    }

    const std::string& file_name() const { return filename_; }
    const std::vector<std::string>& columns() const { return columns_; }

private:
    void write_header() {
        for (int i = 0; i < static_cast<int>(columns_.size()); ++i) {
            if (i > 0) out_ << ',';
            out_ << protect(columns_[i]);
        }
        out_ << '\n';
    }

    void parse_header(const std::string& line) {
        std::istringstream ss(line);
        std::string field;
        while (std::getline(ss, field, ',')) {
            // Trim whitespace
            auto s = field.find_first_not_of(" \t\r\n");
            auto e = field.find_last_not_of(" \t\r\n");
            if (s != std::string::npos)
                field = field.substr(s, e - s + 1);
            columns_.push_back(field);
            column_map_[field] = "";
        }
    }

    static std::string protect(const std::string& s) {
        if (s.find(',') != std::string::npos &&
            !(s.front() == '"' && s.back() == '"')) {
            return "\"" + s + "\"";
        }
        return s;
    }

    std::string filename_;
    std::ofstream out_;
    int precision_;
    bool is_first_row_;
    bool is_empty_row_;
    std::vector<std::string> columns_;
    std::unordered_map<std::string, std::string> column_map_;
};

} // namespace maxent

#endif // MAXENT_CSV_WRITER_HPP
