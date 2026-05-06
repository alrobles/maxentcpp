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

#ifndef MAXENT_MODEL_EVALUATION_HPP
#define MAXENT_MODEL_EVALUATION_HPP

#include <vector>
#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <numeric>

namespace maxent {

// ============================================================================
// EvalResult – aggregate container for all evaluation metrics
// ============================================================================

/**
 * @brief Container for model evaluation metrics.
 */
struct EvalResult {
    double auc              = 0.0;
    double max_kappa        = 0.0;
    double max_kappa_thresh = 0.0;
    double correlation      = 0.0;
    double square_error     = 0.0;
    double logloss          = 0.0;
    double misclassification = 0.0;
    double prevalence       = 0.0;
};

// ============================================================================
// ModelEvaluation – statistical evaluation of model predictions
// Ported from density/tools/Stats.java and density/tools/Eval.java
// ============================================================================

/**
 * @brief Static methods for evaluating Maxent model predictions.
 *
 * Ports the core evaluation metrics from the Java Maxent implementation:
 * - AUC (Area Under the ROC Curve) from Stats.auc()
 * - Cohen's Kappa from Stats.kappa()
 * - Pearson correlation from Stats.correlation()
 * - Log-loss, squared error, misclassification from Eval.java
 */
class ModelEvaluation {
public:

    // -----------------------------------------------------------------------
    // Basic statistics
    // -----------------------------------------------------------------------

    /**
     * @brief Compute the mean of a vector.
     */
    static double mean(const std::vector<double>& x) {
        if (x.empty()) return 0.0;
        double sum = 0.0;
        for (double v : x) sum += v;
        return sum / static_cast<double>(x.size());
    }

    /**
     * @brief Compute the variance of a vector (population variance).
     */
    static double variance(const std::vector<double>& x) {
        if (x.empty()) return 0.0;
        double m = mean(x);
        double sum_sq = 0.0;
        for (double v : x) sum_sq += v * v;
        double var = sum_sq / static_cast<double>(x.size()) - m * m;
        return (var < 0.0) ? 0.0 : var;
    }

    /**
     * @brief Compute the standard deviation of a vector.
     */
    static double stddev(const std::vector<double>& x) {
        return std::sqrt(variance(x));
    }

    // -----------------------------------------------------------------------
    // Cohen's Kappa
    // -----------------------------------------------------------------------

    /**
     * @brief Compute Cohen's Kappa statistic.
     * @param np  Number of positive examples classified as positive (so far).
     * @param nn  Number of negative examples classified as negative (so far).
     * @param tp  Total positive examples.
     * @param tn  Total negative examples.
     * Ported from Stats.kappa() in the Java Maxent.
     */
    static double kappa(int np, int nn, int tp, int tn) {
        double observed = nn + tp - np;
        double all = tn + tp;
        if (all == 0.0) return 0.0;
        double expected = static_cast<double>(nn + np) * tn / all
                        + (all - nn - np) * tp / all;
        double denom = all - expected;
        if (denom == 0.0) return 0.0;
        return (observed - expected) / denom;
    }

    // -----------------------------------------------------------------------
    // AUC (Area Under the ROC Curve)
    // -----------------------------------------------------------------------

    /**
     * @brief Compute AUC (Area Under the ROC Curve).
     *
     * Takes prediction scores for presence (positive) and absence (negative)
     * sites, and computes the Wilcoxon–Mann–Whitney AUC statistic.
     * Also computes max-kappa and its threshold as side products.
     *
     * Ported from Stats.auc() in Java Maxent.
     *
     * @param presence  Prediction scores at presence sites.
     * @param absence   Prediction scores at absence sites.
     * @param[out] max_kappa       Best Kappa value found (optional).
     * @param[out] max_kappa_thresh Threshold at best Kappa (optional).
     * @return AUC value in [0, 1].
     */
    static double auc(std::vector<double> presence,
                      std::vector<double> absence,
                      double* max_kappa = nullptr,
                      double* max_kappa_thresh = nullptr) {
        if (presence.empty() || absence.empty()) {
            if (max_kappa) *max_kappa = 0.0;
            if (max_kappa_thresh) *max_kappa_thresh = 0.0;
            return 0.5;
        }

        std::sort(presence.begin(), presence.end());
        std::sort(absence.begin(), absence.end());

        int tp = static_cast<int>(presence.size());
        int tn = static_cast<int>(absence.size());

        double mk = 0.0;  // max kappa
        double mkt = absence[0] - 1.0;  // max kappa threshold

        long long auc_sum = 0;
        int j = 0;

        for (int i = 0; i < tp; ) {
            // Advance j past absence values strictly less than presence[i]
            while (j < tn && absence[j] < presence[i]) ++j;

            double k = kappa(i, j, tp, tn);
            int less = j;
            int icnt = 1;
            int jcnt = 0;

            // Count tied absence values
            while (j < tn && absence[j] == presence[i]) {
                ++j;
                ++jcnt;
            }

            // Count tied presence values
            while (i < tp - 1 && presence[i + 1] == presence[i]) {
                ++i;
                ++icnt;
            }

            auc_sum += static_cast<long long>(2 * less + jcnt) * icnt;

            if (k > mk) {
                mk = k;
                mkt = presence[i];
            }

            ++i;
        }

        if (max_kappa) *max_kappa = mk;
        if (max_kappa_thresh) *max_kappa_thresh = mkt;

        return static_cast<double>(auc_sum)
             / (2.0 * static_cast<double>(tp) * static_cast<double>(tn));
    }

    // -----------------------------------------------------------------------
    // Pearson correlation
    // -----------------------------------------------------------------------

    /**
     * @brief Compute Pearson correlation coefficient between two vectors.
     *
     * Ported from Stats.correlation() in Java Maxent.
     *
     * @param x First vector.
     * @param y Second vector.
     * @return Correlation in [-1, 1].
     */
    static double correlation(const std::vector<double>& x,
                              const std::vector<double>& y) {
        if (x.size() != y.size())
            throw std::invalid_argument(
                "correlation: vectors have different lengths");
        if (x.empty()) return 0.0;

        double n = static_cast<double>(x.size());
        double sum_xy = 0.0;
        for (size_t i = 0; i < x.size(); ++i)
            sum_xy += x[i] * y[i];

        double sx = stddev(x);
        double sy = stddev(y);
        if (sx == 0.0 || sy == 0.0) return 0.0;

        return (sum_xy / n - mean(x) * mean(y)) / (sx * sy);
    }

    // -----------------------------------------------------------------------
    // Log-loss
    // -----------------------------------------------------------------------

    /**
     * @brief Compute log-loss (cross-entropy) for model predictions.
     *
     * For presence sites: -log(pred)
     * For absence sites:  -log(1 - pred)
     *
     * Ported from Eval.computeLogloss() in Java Maxent.
     *
     * @param presence Prediction scores at presence sites.
     * @param absence  Prediction scores at absence sites.
     * @return Average log-loss.
     */
    static double logloss(const std::vector<double>& presence,
                          const std::vector<double>& absence) {
        double error = 0.0;
        int cnt = 0;
        const double floor = std::exp(-20.0);

        for (double p : presence) {
            if (!std::isfinite(p)) {
                throw std::invalid_argument(
                    "logloss: presence predictions must be finite");
            }
            double bounded = std::clamp(p, 0.0, 1.0);
            error += std::log(std::max(bounded, floor));
            ++cnt;
        }
        for (double a : absence) {
            if (!std::isfinite(a)) {
                throw std::invalid_argument(
                    "logloss: absence predictions must be finite");
            }
            double bounded = std::clamp(a, 0.0, 1.0);
            error += std::log(std::max(1.0 - bounded, floor));
            ++cnt;
        }
        if (cnt == 0) return 0.0;
        return -error / cnt;
    }

    // -----------------------------------------------------------------------
    // Squared error
    // -----------------------------------------------------------------------

    /**
     * @brief Compute mean squared error.
     *
     * Presence sites contribute (1 - pred)^2, absence sites contribute pred^2.
     *
     * Ported from Eval.computeSquareError() in Java Maxent.
     *
     * @param presence Prediction scores at presence sites.
     * @param absence  Prediction scores at absence sites.
     * @return Mean squared error.
     */
    static double square_error(const std::vector<double>& presence,
                               const std::vector<double>& absence) {
        double error = 0.0;
        for (double p : presence)
            error += (1.0 - p) * (1.0 - p);
        for (double a : absence)
            error += a * a;
        int n = static_cast<int>(presence.size() + absence.size());
        if (n == 0) return 0.0;
        return error / n;
    }

    // -----------------------------------------------------------------------
    // Misclassification rate
    // -----------------------------------------------------------------------

    /**
     * @brief Compute misclassification rate at threshold 0.5.
     *
     * Ported from Eval.computeMisClassification() in Java Maxent.
     *
     * @param presence Prediction scores at presence sites.
     * @param absence  Prediction scores at absence sites.
     * @return Fraction of misclassified samples.
     */
    static double misclassification(const std::vector<double>& presence,
                                    const std::vector<double>& absence) {
        double error = 0.0;
        for (double p : presence)
            if (p < 0.5) error += 1.0;
        for (double a : absence)
            if (a >= 0.5) error += 1.0;
        int n = static_cast<int>(presence.size() + absence.size());
        if (n == 0) return 0.0;
        return error / n;
    }

    // -----------------------------------------------------------------------
    // Full evaluation
    // -----------------------------------------------------------------------

    /**
     * @brief Compute all evaluation metrics at once.
     *
     * @param presence Prediction scores at presence sites.
     * @param absence  Prediction scores at absence sites.
     * @return EvalResult struct with all metrics populated.
     */
    static EvalResult evaluate(const std::vector<double>& presence,
                               const std::vector<double>& absence) {
        EvalResult result;

        // AUC + kappa
        result.auc = auc(presence, absence,
                         &result.max_kappa, &result.max_kappa_thresh);

        // Correlation: combine predictions and labels
        std::vector<double> pred, truth;
        pred.reserve(presence.size() + absence.size());
        truth.reserve(presence.size() + absence.size());
        for (double p : presence) { pred.push_back(p); truth.push_back(1.0); }
        for (double a : absence)  { pred.push_back(a); truth.push_back(0.0); }
        result.correlation = correlation(pred, truth);

        result.square_error      = square_error(presence, absence);
        result.logloss           = logloss(presence, absence);
        result.misclassification = misclassification(presence, absence);

        int n = static_cast<int>(presence.size() + absence.size());
        result.prevalence = (n > 0)
            ? static_cast<double>(presence.size()) / n
            : 0.0;

        return result;
    }
};

} // namespace maxent

#endif // MAXENT_MODEL_EVALUATION_HPP
