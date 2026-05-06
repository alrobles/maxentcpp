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

#ifndef MAXENT_CSV_READER_HPP
#define MAXENT_CSV_READER_HPP

#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <unordered_map>
#include <algorithm>
#include <stdexcept>
#include <cctype>
#include <cstdlib>

namespace maxent {

/**
 * @brief CSV file reader for species occurrence and SWD data.
 *
 * Ported from density/Csv.java. Supports:
 *   - Comma-separated (default) and semicolon-separated (European) formats
 *   - Quoted fields
 *   - First-line field names
 *   - Decimal-comma normalization in European mode
 */
class CsvReader {
public:
    // -----------------------------------------------------------------
    // Construction
    // -----------------------------------------------------------------

    /**
     * @brief Open a CSV file and read its header.
     *
     * @param filename       Path to the CSV file. If the file does not exist
     *                       and does not end with ".csv", ".csv" is appended.
     * @param has_header     If true (default) the first record is treated as
     *                       the column-name header.
     */
    explicit CsvReader(const std::string& filename, bool has_header = true)
        : filename_(filename), separator_(','), european_mode_(false),
          line_num_(0), initialized_(false) {
        // Try the given name first; append .csv if needed
        in_.open(filename_);
        if (!in_.is_open()) {
            if (filename_.size() < 4 ||
                (filename_.substr(filename_.size() - 4) != ".csv" &&
                 filename_.substr(filename_.size() - 4) != ".CSV")) {
                filename_ += ".csv";
                in_.open(filename_);
            }
        }
        if (!in_.is_open()) {
            throw std::runtime_error("Cannot open CSV file: " + filename_);
        }

        if (has_header) {
            auto hdr = read_tokens();
            if (hdr.empty()) {
                throw std::runtime_error("Empty header in CSV file: " + filename_);
            }
            process_header(hdr);
        }
    }

    ~CsvReader() {
        if (in_.is_open()) in_.close();
    }

    // Non-copyable
    CsvReader(const CsvReader&) = delete;
    CsvReader& operator=(const CsvReader&) = delete;

    // Movable
    CsvReader(CsvReader&&) = default;
    CsvReader& operator=(CsvReader&&) = default;

    // -----------------------------------------------------------------
    // Header access
    // -----------------------------------------------------------------

    const std::vector<std::string>& headers() const { return headers_; }

    bool has_field(const std::string& name) const {
        return header_map_.count(name) > 0;
    }

    int field_index(const std::string& name) const {
        auto it = header_map_.find(name);
        return (it != header_map_.end()) ? it->second : -1;
    }

    // -----------------------------------------------------------------
    // Record reading
    // -----------------------------------------------------------------

    /**
     * @brief Read the next data record.
     *
     * Skips records whose field count does not match the header.
     *
     * @return true if a record was read successfully, false on EOF.
     */
    bool next_record() {
        while (true) {
            auto tokens = read_tokens();
            if (tokens.empty()) return false;  // EOF

            if (european_mode_) {
                for (auto& t : tokens)
                    std::replace(t.begin(), t.end(), ',', '.');
            }

            if (static_cast<int>(tokens.size()) == static_cast<int>(headers_.size())) {
                current_ = std::move(tokens);
                return true;
            }
            // Skip malformed lines (matching Java behaviour)
        }
    }

    // -----------------------------------------------------------------
    // Field access (current record)
    // -----------------------------------------------------------------

    const std::string& get(int index) const { return current_.at(index); }

    std::string get(const std::string& field) const {
        int idx = field_index(field);
        if (idx < 0) {
            throw std::runtime_error("Field not found: " + field);
        }
        return current_[idx];
    }

    double get_double(int index) const {
        return parse_double(current_.at(index));
    }

    double get_double(const std::string& field) const {
        return parse_double(get(field));
    }

    const std::vector<std::string>& current_record() const { return current_; }

    // -----------------------------------------------------------------
    // Convenience: read an entire column as doubles
    // -----------------------------------------------------------------

    /**
     * @brief Read all values in a named column as doubles.
     *
     * Reads from the current file position to EOF. The reader will be
     * at EOF after this call.
     */
    std::vector<double> read_double_column(const std::string& field) {
        int idx = field_index(field);
        if (idx < 0) {
            throw std::runtime_error("Field not found: " + field);
        }
        std::vector<double> result;
        while (next_record()) {
            result.push_back(parse_double(current_[idx]));
        }
        return result;
    }

    /**
     * @brief Read all remaining records as a matrix of doubles.
     *
     * @param start_col  First column index to include (default 0).
     * @return  Vector-of-vectors: result[row][col - start_col].
     */
    std::vector<std::vector<double>> read_all_doubles(int start_col = 0) {
        int ncols = static_cast<int>(headers_.size()) - start_col;
        if (ncols <= 0) return {};

        std::vector<std::vector<double>> result;
        while (next_record()) {
            std::vector<double> row(ncols);
            for (int j = start_col; j < static_cast<int>(headers_.size()); ++j) {
                row[j - start_col] = parse_double(current_[j]);
            }
            result.push_back(std::move(row));
        }
        return result;
    }

    // -----------------------------------------------------------------
    // State
    // -----------------------------------------------------------------

    int line_number() const { return line_num_; }
    const std::string& file_name() const { return filename_; }

    void close() {
        if (in_.is_open()) in_.close();
    }

private:
    // -----------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------

    void process_header(std::vector<std::string>& hdr) {
        headers_ = hdr;
        for (int i = 0; i < static_cast<int>(hdr.size()); ++i) {
            header_map_[hdr[i]] = i;
        }
    }

    /**
     * @brief Read one line and tokenize using the separator.
     *
     * Handles quoted fields that may span multiple lines (matching Java
     * Csv.getTokens behaviour). Returns an empty vector on EOF.
     */
    std::vector<std::string> read_tokens() {
        std::vector<std::string> tokens;
        std::string token;
        bool in_quote = false;
        const char quote = '"';

        while (true) {
            std::string line;
            if (!std::getline(in_, line)) {
                // EOF reached
                if (tokens.empty()) return {};
                if (in_quote) {
                    throw std::runtime_error(
                        "End of file reached while parsing " + filename_);
                }
                tokens.push_back(trim(token));
                return tokens;
            }
            ++line_num_;

            // Auto-detect European mode on the very first line
            if (!initialized_) {
                check_european(line);
                initialized_ = true;
            }

            for (size_t i = 0; i < line.size(); ++i) {
                char c = line[i];
                if (c == quote) {
                    in_quote = !in_quote;
                } else if (c == separator_ && !in_quote) {
                    tokens.push_back(trim(token));
                    token.clear();
                } else {
                    token += c;
                }
            }

            if (in_quote) {
                token += '\n';  // field spans multiple lines
            } else {
                tokens.push_back(trim(token));
                token.clear();
                if (tokens.size() == 1 && tokens[0].empty()) return {};
                return tokens;
            }
        }
    }

    void check_european(const std::string& line) {
        if (line.find(separator_) == std::string::npos &&
            line.find(';') != std::string::npos) {
            european_mode_ = true;
            separator_ = ';';
        }
    }

    static std::string trim(const std::string& s) {
        auto start = s.find_first_not_of(" \t\r\n");
        if (start == std::string::npos) return "";
        auto end = s.find_last_not_of(" \t\r\n");
        return s.substr(start, end - start + 1);
    }

    static double parse_double(const std::string& s) {
        try {
            return std::stod(s);
        } catch (const std::exception&) {
            // Handle decimal commas
            std::string fixed = s;
            std::replace(fixed.begin(), fixed.end(), ',', '.');
            return std::stod(fixed);
        }
    }

    // -----------------------------------------------------------------
    // Data members
    // -----------------------------------------------------------------
    std::string filename_;
    std::ifstream in_;
    char separator_;
    bool european_mode_;
    int line_num_;
    bool initialized_;

    std::vector<std::string> headers_;
    std::unordered_map<std::string, int> header_map_;
    std::vector<std::string> current_;
};

} // namespace maxent

#endif // MAXENT_CSV_READER_HPP
