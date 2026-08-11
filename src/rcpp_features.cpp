#include <Rcpp.h>

// Enable C++17
// [[Rcpp::plugins(cpp17)]]

// Link to Eigen
// [[Rcpp::depends(RcppEigen)]]

#include "cpp/include/maxent/feature.hpp"

using namespace Rcpp;
using namespace maxent;

//' Create a LinearFeature object
//'
//' Creates a linear (normalized) feature: eval(i) = (values[i] - min) / (max - min).
//' Returns 0 when min == max.
//'
//' @param values Numeric vector of environmental variable values
//' @param name Feature name/identifier
//' @param min_val Minimum value for normalization
//' @param max_val Maximum value for normalization
//' @return External pointer to LinearFeature object
//' @export
// [[Rcpp::export]]
SEXP create_linear_feature(NumericVector values, String name,
                           double min_val, double max_val) {
    auto sp = std::make_shared<std::vector<double>>(values.begin(), values.end());
    LinearFeature* f = new LinearFeature(sp, Rcpp::as<std::string>(Rcpp::wrap(name)), min_val, max_val);
    XPtr<Feature> ptr(f, true);
    return ptr;
}

//' Create a QuadraticFeature object
//'
//' Creates a quadratic feature: eval(i) = linear_val^2 where
//' linear_val = (values[i] - min) / (max - min).
//'
//' @param values Numeric vector of environmental variable values
//' @param name Feature name/identifier
//' @param min_val Minimum value for normalization
//' @param max_val Maximum value for normalization
//' @return External pointer to QuadraticFeature object
//' @export
// [[Rcpp::export]]
SEXP create_quadratic_feature(NumericVector values, String name,
                              double min_val, double max_val) {
    auto sp = std::make_shared<std::vector<double>>(values.begin(), values.end());
    QuadraticFeature* f = new QuadraticFeature(sp, Rcpp::as<std::string>(Rcpp::wrap(name)), min_val, max_val);
    XPtr<Feature> ptr(f, true);
    return ptr;
}

//' Create a ProductFeature object
//'
//' Creates a product (interaction) feature between two environmental variables:
//' eval(i) = norm(values1[i]) * norm(values2[i]).
//'
//' @param values1 Numeric vector for the first environmental variable
//' @param values2 Numeric vector for the second environmental variable
//' @param name Feature name/identifier
//' @param min1 Minimum of the first variable
//' @param max1 Maximum of the first variable
//' @param min2 Minimum of the second variable
//' @param max2 Maximum of the second variable
//' @return External pointer to ProductFeature object
//' @export
// [[Rcpp::export]]
SEXP create_product_feature(NumericVector values1, NumericVector values2,
                            String name,
                            double min1, double max1,
                            double min2, double max2) {
    auto sp1 = std::make_shared<std::vector<double>>(values1.begin(), values1.end());
    auto sp2 = std::make_shared<std::vector<double>>(values2.begin(), values2.end());
    ProductFeature* f = new ProductFeature(sp1, sp2, Rcpp::as<std::string>(Rcpp::wrap(name)),
                                           min1, max1, min2, max2);
    XPtr<Feature> ptr(f, true);
    return ptr;
}

//' Create a ThresholdFeature object
//'
//' Creates a binary step feature: eval(i) = 1.0 if values[i] > threshold, else 0.0.
//'
//' @param values Numeric vector of environmental variable values
//' @param name Feature name/identifier
//' @param threshold The threshold value
//' @return External pointer to ThresholdFeature object
//' @export
// [[Rcpp::export]]
SEXP create_threshold_feature(NumericVector values, String name, double threshold) {
    auto sp = std::make_shared<std::vector<double>>(values.begin(), values.end());
    ThresholdFeature* f = new ThresholdFeature(sp, Rcpp::as<std::string>(Rcpp::wrap(name)), threshold);
    XPtr<Feature> ptr(f, true);
    return ptr;
}

//' Create a HingeFeature object
//'
//' Creates a piecewise-linear hinge feature.
//' Forward hinge: eval(i) = (values[i] > min_knot) ? (values[i] - min_knot) / (max_knot - min_knot) : 0.
//' Reverse hinge: eval(i) = (values[i] < max_knot) ? (max_knot - values[i]) / (max_knot - min_knot) : 0.
//'
//' @param values Numeric vector of environmental variable values
//' @param name Feature name/identifier
//' @param min_knot Lower knot of the hinge
//' @param max_knot Upper knot of the hinge (must be > min_knot)
//' @param is_reverse If TRUE, use reverse hinge; if FALSE (default), use forward hinge
//' @return External pointer to HingeFeature object
//' @export
// [[Rcpp::export]]
SEXP create_hinge_feature(NumericVector values, String name,
                          double min_knot, double max_knot,
                          bool is_reverse = false) {
    auto sp = std::make_shared<std::vector<double>>(values.begin(), values.end());
    HingeFeature* f = new HingeFeature(sp, Rcpp::as<std::string>(Rcpp::wrap(name)),
                                       min_knot, max_knot, is_reverse);
    XPtr<Feature> ptr(f, true);
    return ptr;
}

//' Evaluate a feature at a given index
//'
//' @param feature_ptr External pointer to a Feature object
//' @param index 0-based index into the data vector
//' @return Feature value at that index (double)
//' @export
// [[Rcpp::export]]
double feature_eval(SEXP feature_ptr, int index) {
    XPtr<Feature> f(feature_ptr);
    if (index < 0 || index >= f->size()) {
        Rcpp::stop("feature_eval: index %d out of range [0, %d)",
                   index, f->size());
    }
    return f->eval(index);
}

//' Get feature metadata
//'
//' Returns a list with name, type, lambda, min, and max values.
//'
//' @param feature_ptr External pointer to a Feature object
//' @return Named list with feature properties
//' @export
// [[Rcpp::export]]
List feature_get_info(SEXP feature_ptr) {
    XPtr<Feature> f(feature_ptr);
    return List::create(
        Named("name")   = f->name(),
        Named("type")   = f->type(),
        Named("lambda") = f->lambda(),
        Named("min")    = f->min_val(),
        Named("max")    = f->max_val(),
        Named("size")   = f->size()
    );
}

//' Generate features from a list of environmental variable vectors
//'
//' Generates all configured feature types (linear, quadratic, product,
//' threshold, hinge) from the supplied data vectors.  Categorical variables
//' are expanded into binary indicator features (one per distinct level)
//' instead of the continuous feature types.
//'
//' @param data_list Named list of numeric vectors, one per environmental variable
//' @param feature_types Character vector of feature types to generate.
//'   Valid values: "linear", "quadratic", "product", "threshold", "hinge".
//'   Defaults to all types.
//' @param n_thresholds Number of threshold knots per variable (default: 10)
//' @param n_hinges Number of hinge knots per variable (default: 10)
//' @param categorical_indices Integer vector of 0-based indices identifying
//'   which variables in \code{data_list} are categorical (default: empty).
//' @return List of external pointers to Feature objects
//' @export
// [[Rcpp::export]]
List generate_features(List data_list,
                       CharacterVector feature_types =
                           CharacterVector::create("linear", "quadratic",
                                                   "product", "threshold", "hinge"),
                       int n_thresholds = 10,
                       int n_hinges = 10,
                       IntegerVector categorical_indices = IntegerVector::create()) {
    // Build data vector
    std::vector<std::pair<std::string, std::vector<double>>> data;
    CharacterVector names = data_list.names();
    for (int i = 0; i < data_list.size(); ++i) {
        NumericVector v = data_list[i];
        std::string nm = as<std::string>(names[i]);
        data.emplace_back(nm, std::vector<double>(v.begin(), v.end()));
    }

    // Build config
    FeatureConfig cfg;
    cfg.linear    = false;
    cfg.quadratic = false;
    cfg.product   = false;
    cfg.threshold = false;
    cfg.hinge     = false;
    cfg.n_thresholds = n_thresholds;
    cfg.n_hinges     = n_hinges;

    for (int i = 0; i < feature_types.size(); ++i) {
        std::string t = as<std::string>(feature_types[i]);
        if (t == "linear")    cfg.linear    = true;
        if (t == "quadratic") cfg.quadratic = true;
        if (t == "product")   cfg.product   = true;
        if (t == "threshold") cfg.threshold = true;
        if (t == "hinge")     cfg.hinge     = true;
    }

    // Convert categorical indices
    std::vector<int> cat_idx(categorical_indices.begin(), categorical_indices.end());

    auto features = FeatureGenerator::generate(data, cfg, cat_idx);

    List result(features.size());
    CharacterVector result_names(features.size());
    for (std::size_t i = 0; i < features.size(); ++i) {
        result_names[i] = features[i]->name();
        // Transfer ownership to XPtr
        Feature* raw = features[i].release();
        XPtr<Feature> ptr(raw, true);
        result[i] = ptr;
    }
    result.attr("names") = result_names;
    return result;
}

//' Create a BinaryFeature object (categorical indicator)
//'
//' Creates a binary feature that evaluates to 1.0 when the underlying
//' value equals the target category value, 0.0 otherwise.
//'
//' @param values Numeric vector of categorical variable values
//' @param name Feature name/identifier
//' @param target The category value to test for
//' @return External pointer to BinaryFeature object
//' @export
// [[Rcpp::export]]
SEXP create_binary_feature(NumericVector values, String name, double target) {
    auto sp = std::make_shared<std::vector<double>>(values.begin(), values.end());
    BinaryFeature* f = new BinaryFeature(sp, Rcpp::as<std::string>(Rcpp::wrap(name)), target);
    XPtr<Feature> ptr(f, true);
    return ptr;
}
