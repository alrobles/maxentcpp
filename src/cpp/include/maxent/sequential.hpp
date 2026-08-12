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

#ifndef MAXENT_SEQUENTIAL_HPP
#define MAXENT_SEQUENTIAL_HPP

// =============================================================================
// maxent::Sequential
//
// Direct port of Java density/Sequential.java (the "real" Maxent optimiser,
// as opposed to the `goodAlpha`-only shortcut that previously lived in
// FeaturedSpace::train()).
//
// Algorithmic structure (mirrors Java, line-by-line where practical):
//
//   run():
//     for iteration = 0 .. max_iter:
//       if iteration > 0 and iteration % parallelUpdateFrequency == 0:
//           doParallelUpdate()            // one Newton step along
//                                         // alpha[j] = lambda[j] - previousLambda[j]
//       else:
//           j = getBestFeature()          // argmin_j deltaLossBound(feature_j)
//           doSequentialUpdate(j)         // newtonStep + optional undo + searchAlpha
//       if terminationTest(newLoss): break
//
//   doSequentialUpdate(j):
//     ensure feature j's expectation is fresh
//     alpha = reduceAlpha( newtonStep(j) )
//     newLoss = increaseLambda(j, alpha, toUpdate)
//     if newLoss - oldLoss > deltaLossBound(j):
//         undo the alpha step
//         alpha  = reduceAlpha( searchAlpha(j, goodAlpha(j)) )
//         newLoss = increaseLambda(j, alpha, toUpdate)
//
//   doParallelUpdate():
//     alpha[j] = lambda[j] - previousLambda[j]  (0 if feature binary or lambda == 0)
//     previousLambda[j] = lambda[j]
//     stepSize = newtonStep(alpha)
//     alpha *= stepSize
//     lossnow = increaseLambdaBatch(alpha, toUpdate)
//     if lossnow > losswas:
//         apply -alpha (undo)
//     else:
//         accumulate per-feature contribution
//
// Trajectory observer hook mirrors the TrajectorySequential subclass in
// maxentcppCompTest/inst/java/MaxentRefRunner.java: a callback is invoked
// after each iteration (using the same 1-based "completed = iteration+1"
// accounting as Java) with (iteration, loss, entropy, lambdas).  Setting
// `params.disable_convergence_test = true` suppresses early termination so
// the full trajectory is deterministic.
//
// Numerical-parity contract: this class is expected to match the Java
// trajectory (loss, entropy, lambdas) to at least 1e-6 on ||λ||∞ at every
// iteration on the linear-features-only mock fixtures in
// maxentcppCompTest/inst/extdata/{,asym/}.  See docs/FIDELITY_BASELINE_REPORT.md
// and tools/compare_trajectories.py in that repo for the acceptance gate.
// =============================================================================

#include "featured_space.hpp"

#include <algorithm>
#include <cmath>
#include <functional>
#include <limits>
#include <numeric>
#include <stdexcept>
#include <vector>

namespace maxent {

// -----------------------------------------------------------------------------
// Per-feature state that Sequential tracks across iterations.
// Java keeps these on density.Feature directly; in the port we keep them
// parallel to FeaturedSpace::features() so that the Feature hierarchy stays
// stateless with respect to optimisation bookkeeping.
// -----------------------------------------------------------------------------
struct FeatureState {
    double previous_lambda        = 0.0;
    double contribution           = 0.0;
    double previous_contribution  = 0.0;
    int    last_change            = -1;
    int    last_expectation_update = -1;
};

// -----------------------------------------------------------------------------
// Snapshot passed to the trajectory observer.  Iteration numbering uses
// Java's "completed iteration" convention: `iteration = k` means k iterations
// of the outer loop have finished (i.e. it matches the row label in the
// committed trajectory_java.csv goldens).
// -----------------------------------------------------------------------------
struct SequentialSnapshot {
    int                 iteration; ///< 1-based iteration index (matches Java completed)
    double              loss;      ///< getLoss() == X.getLoss() + reg
    double              entropy;   ///< X.getEntropy()
    std::vector<double> lambdas;   ///< copy of each feature's lambda()
};

using TrajectoryObserver = std::function<void(const SequentialSnapshot&)>;

// -----------------------------------------------------------------------------
// Tuneable parameters.  Defaults exactly match density.Sequential.java
// (parallelUpdateFrequency=10, convergenceTestFrequency=20, updateCycle=20,
// recentChange=10, topSelect=5, eps=1e-6).
// -----------------------------------------------------------------------------
struct SequentialParams {
    int    max_iter                  = 500;
    double convergence_threshold     = 1e-5;
    double beta_multiplier           = 1.0;
    double min_deviation             = 0.001;
    int    parallel_update_frequency = 10;
    int    convergence_test_frequency= 20;
    int    update_cycle              = 20;
    int    recent_change             = 10;
    int    top_select                = 5;
    /// When true, terminationTest() never returns early based on loss
    /// convergence; the loop runs until max_iter.  Used by the trajectory
    /// CLI so the per-iteration CSV is deterministic across implementations.
    bool   disable_convergence_test  = false;
};

// -----------------------------------------------------------------------------
// Sequential optimiser.  Holds a non-owning reference to a FeaturedSpace
// constructed by the caller.  FeaturedSpace provides the dense density,
// linear predictor, and feature-expectation storage; Sequential drives the
// optimisation loop and holds the per-iteration FeatureState array.
// -----------------------------------------------------------------------------
class Sequential {
public:
    Sequential(FeaturedSpace& X, const SequentialParams& params = {})
        : X_(X)
        , params_(params)
        , state_(static_cast<std::size_t>(X.num_features()))
    {
        // Java Sequential constructor (Sequential.java:48..60) initialises
        // lastChange / lastExpectationUpdate = -1 and previousLambda = lambda.
        // The FeatureState default constructor gives -1 for the former; we
        // fill previousLambda manually here.
        const auto& feats = X_.features();
        for (std::size_t j = 0; j < feats.size(); ++j)
            state_[j].previous_lambda = feats[j]->lambda();
    }

    /// Install a trajectory observer called after every iteration.
    /// Semantics match TrajectorySequential in MaxentRefRunner.java:
    /// snapshot.iteration is 1-based and equals (Java's iteration + 1),
    /// i.e. the number of iterations completed.
    void set_observer(TrajectoryObserver obs) { observer_ = std::move(obs); }

    /// Run the optimisation.  Returns the final regularised loss.
    double run() {
        // Java Runner sets sample expectations *before* constructing
        // Sequential.  In the C++ TrainResult wrapper (and in the Rcpp
        // bridge) we fold that into run() so callers just hand us a
        // freshly-constructed FeaturedSpace.
        X_.set_sample_expectations(params_.beta_multiplier,
                                   params_.min_deviation);
        set_reg();

        double new_loss = get_loss();

        // Emit the initial-state snapshot (iteration = 0) so observers can
        // anchor against Java's iter-0 loss.  Not present in committed
        // goldens but useful for debugging.
        emit_initial_snapshot();

        for (iteration_ = 0; iteration_ < params_.max_iter; ++iteration_) {
            old_loss_ = new_loss;

            const bool parallel_iter =
                (iteration_ > 0)
                && (params_.parallel_update_frequency > 0)
                && (iteration_ % params_.parallel_update_frequency == 0);

            if (parallel_iter) {
                new_loss = do_parallel_update();
            } else {
                int j = get_best_feature();
                if (j < 0) break;
                new_loss = do_sequential_update(j);
            }

            emit_snapshot(new_loss);

            if (termination_test(new_loss)) {
                ++iteration_;               // mirror Java (loop would have incremented)
                converged_ = !params_.disable_convergence_test;
                break;
            }
        }

        final_loss_ = new_loss;
        return new_loss;
    }

    // --- accessors -----------------------------------------------------------
    double          final_loss() const { return final_loss_; }
    bool            converged()  const { return converged_; }
    int             iterations() const { return iteration_; }
    const std::vector<FeatureState>& state() const { return state_; }
    FeaturedSpace&  featured_space()     { return X_; }

    TrainResult result() const {
        TrainResult r;
        r.loss       = final_loss_;
        r.entropy    = X_.get_entropy();
        r.iterations = iteration_;
        r.converged  = converged_;
        r.lambdas.reserve(static_cast<std::size_t>(X_.num_features()));
        for (const auto& f : X_.features())
            r.lambdas.push_back(f->lambda());
        return r;
    }

private:
    // =========================================================================
    // Loss helpers -- mirror Sequential.getLoss() + FeaturedSpace.getLoss()
    // =========================================================================

    /// getLoss == X.getLoss() + reg  (Sequential.java:62..64)
    double get_loss() const { return X_.get_loss() + reg_; }

    /// reg = X.getL1reg()  (Sequential.java:241..243)
    void set_reg() { reg_ = X_.get_l1_reg(); }

    // =========================================================================
    // goodAlpha / deltaLossBound
    // Mirrors Sequential.java:294..342 (single-feature closed-form step).
    // =========================================================================

    double good_alpha(int j) const {
        const Feature& h  = *X_.features()[j];
        const double N1   = h.sample_expectation();
        const double W1   = h.expectation();
        const double W0   = 1.0 - W1;
        const double N0   = 1.0 - N1;
        const double lam  = h.lambda();
        const double beta1= h.sample_deviation();
        const double eps  = kEps;

        if (W0 < eps || W1 < eps) return 0.0;

        double alpha;
        const bool pos_branch = (N1 - beta1 > eps);
        const bool neg_branch = (N0 - beta1 > eps);

        if (pos_branch) {
            alpha = std::log((N1 - beta1) * W0 / ((N0 + beta1) * W1));
            if (std::isfinite(alpha) && alpha + lam > 0.0) return alpha;
        }
        if (neg_branch) {
            alpha = std::log((N1 + beta1) * W0 / ((N0 - beta1) * W1));
            if (std::isfinite(alpha) && alpha + lam < 0.0) return alpha;
        }
        return -lam;
    }

    double delta_loss_bound(int j) const {
        const Feature& h = *X_.features()[j];
        const double N1  = h.sample_expectation();
        if (N1 == -1.0) return 0.0;

        const double W1   = h.expectation();
        const double W0   = 1.0 - W1;
        const double lam  = h.lambda();
        const double alpha= good_alpha(j);
        const double beta1= h.sample_deviation();
        if (!std::isfinite(alpha)) return 0.0;

        const double bound =
            -N1 * alpha
            + std::log(W0 + W1 * std::exp(alpha))
            + beta1 * (std::abs(lam + alpha) - std::abs(lam));
        return std::isnan(bound) ? 0.0 : bound;
    }

    // =========================================================================
    // deriv / newtonStep — Sequential.java:144..239
    // =========================================================================

    double derivative(int j) const {
        const Feature& h = *X_.features()[j];
        const double N1 = h.sample_expectation();
        const double W1 = h.expectation();
        const double beta1 = h.sample_deviation();
        const double unreg = W1 - N1;
        const double lam = h.lambda();
        if (lam > 0.0) return unreg + beta1;
        if (lam < 0.0) return unreg - beta1;
        if (unreg + beta1 > 0.0) return unreg + beta1;
        if (unreg - beta1 < 0.0) return unreg - beta1;
        return 0.0;
    }

    /// Single-feature Newton step.  Mirrors Sequential.java:223..239.
    double newton_step_feature(int j) const {
        const Feature& h = *X_.features()[j];
        const double uTY = h.expectation();
        const double dn  = X_.get_density_normalizer();
        const auto& F    = X_.feature_matrix();
        const auto& d    = X_.density_vector();
        double uThu;
        if (F.size() > 0) {
            uThu = (d.array() * F.col(j).array().square()).sum();
        } else {
            const int n = X_.num_points();
            uThu = 0.0;
            for (int i = 0; i < n; ++i) {
                const double v = h.eval(i);
                uThu += X_.get_density(i) * v * v;
            }
        }
        uThu = uThu / dn - uTY * uTY;
        if (uThu < kEps * kEps) return 0.0;

        double step = -derivative(j) / uThu;
        const double lam = h.lambda();
        if ((step + lam) * lam < 0.0) step = -lam;
        return step;
    }

    /// Newton step along direction u (length num_features).  Mirrors
    /// Sequential.java:175..219.  Also refreshes the expectations of
    /// every feature with u[j] != 0 (the Java impl does this by side
    /// effect inside the uTHu loop).
    double newton_step_direction(const std::vector<double>& u) {
        const int nf = X_.num_features();
        std::vector<int> idx;   idx.reserve(nf);
        std::vector<double> uu; uu.reserve(nf);
        for (int j = 0; j < nf; ++j) {
            if (u[j] != 0.0) {
                idx.push_back(j);
                uu.push_back(u[j]);
            }
        }
        const int nh = static_cast<int>(idx.size());
        if (nh == 0) return 0.0;

        const int n = X_.num_points();
        const double dn = X_.get_density_normalizer();

        std::vector<double> sum(nh, 0.0);
        double uThu = 0.0;
        double uTY  = 0.0;
        const auto& feats = X_.features();
        const auto& F = X_.feature_matrix();
        const auto& d = X_.density_vector();
        if (F.size() > 0) {
            // Gather selected columns into a dense n×nh matrix and use BLAS
            // for the two matrix-vector products and the weighted dot products.
            Eigen::MatrixXd Fsub(n, nh);
            for (int jj = 0; jj < nh; ++jj)
                Fsub.col(jj) = F.col(idx[jj]);
            Eigen::Map<const Eigen::VectorXd> uu_vec(uu.data(), nh);
            Eigen::VectorXd FTu = Fsub * uu_vec;
            Eigen::VectorXd sum_vec = Fsub.transpose() * d;
            uThu = d.dot(FTu.array().square().matrix());
            uTY  = d.dot(FTu);
            for (int jj = 0; jj < nh; ++jj)
                sum[jj] = sum_vec(jj);
        } else {
            for (int i = 0; i < n; ++i) {
                double FTu = 0.0;
                const double density_i = X_.get_density(i);
                for (int jj = 0; jj < nh; ++jj) {
                    const double val = feats[idx[jj]]->eval(i);
                    FTu    += uu[jj] * val;
                    sum[jj] += density_i * val;
                }
                uThu += density_i * FTu * FTu;
                uTY  += density_i * FTu;
            }
        }
        for (int jj = 0; jj < nh; ++jj) {
            feats[idx[jj]]->set_expectation(sum[jj] / dn);
            state_[idx[jj]].last_expectation_update = iteration_;
        }
        uTY  /= dn;
        uThu  = uThu / dn - uTY * uTY;
        if (uThu < kEps * kEps) return 0.0;

        double dot = 0.0;
        for (int j = 0; j < nf; ++j)
            dot += derivative(j) * u[j];
        double step = -dot / uThu;

        // Don't let any individual lambda flip sign — see Sequential.java:210..216.
        for (int j = 0; j < nf; ++j) {
            const double lam = feats[j]->lambda();
            if ((step * u[j] + lam) * lam < 0.0) {
                step = -lam / u[j];
            }
        }
        return step;
    }

    // =========================================================================
    // searchAlpha / newLossChange — Sequential.java:104..142
    // =========================================================================

    double new_loss_change(int j, double alpha, int square = 0) const {
        // square parameter unused in C++ implementation but kept for ABI
        // compatibility with the Java Sequential.java:104..142 interface.
        (void) square;
        const Feature& h = *X_.features()[j];
        const auto& F = X_.feature_matrix();
        const auto& d = X_.density_vector();
        double Z;
        if (F.size() > 0) {
            Z = (d.array() * (alpha * F.col(j).array()).exp()).sum();
        } else {
            const int n = X_.num_points();
            Z = 0.0;
            for (int i = 0; i < n; ++i)
                Z += X_.get_density(i) * std::exp(alpha * h.eval(i));
        }
        const double lam  = h.lambda();
        const double beta1= h.sample_deviation();
        return -alpha * h.sample_expectation()
             + std::log(Z)
             + (std::abs(lam + alpha) - std::abs(lam)) * beta1;
    }

    double search_alpha(int j, double alpha) const {
        double current = new_loss_change(j, alpha);
        while (true) {
            const double trial = new_loss_change(j, alpha * 4.0, 2);
            if (trial >= current) break;
            if (!std::isfinite(trial)) break;
            current = trial;
            alpha  *= 4.0;
        }
        // One more aggressive halving of the quadrupling step
        // (Sequential.java:116..119).
        const double trial2 = new_loss_change(j, alpha * 2.0);
        if (trial2 < current && std::isfinite(trial2)) alpha *= 2.0;
        return alpha;
    }

    /// Mirrors Sequential.java:467..472.
    double reduce_alpha(double alpha) const {
        if (iteration_ < 10) return alpha / 50.0;
        if (iteration_ < 20) return alpha / 10.0;
        if (iteration_ < 50) return alpha /  3.0;
        return alpha;
    }

    // =========================================================================
    // Feature selection: getBestFeature + featuresToUpdate
    // Mirrors Sequential.java:66..102, :396..417.
    // =========================================================================

    int get_best_feature() const {
        const int nf = X_.num_features();
        double best_lb = 1.0;   // Java initial: bestLb = 1.0
        int    best_j  = -1;
        for (int j = 0; j < nf; ++j) {
            // The C++ port has no Feature::isActive() or isGenerated() flags
            // yet — every feature is active & non-generated.  This matches
            // the state Runner ends up in for linear-features-only fits.
            const double lb = delta_loss_bound(j);
            if (lb < best_lb) { best_lb = lb; best_j = j; }
        }
        return best_j;
    }

    std::vector<int> features_to_update() const {
        const int nf = X_.num_features();
        std::vector<int> out;
        out.reserve(nf);

        // Pass 1: recent-change OR cyclic slot.
        for (int j = 0; j < nf; ++j) {
            const int last = state_[j].last_change;
            const bool recent = (iteration_ < last + params_.recent_change);
            const bool cyclic = (j % params_.update_cycle
                                 == iteration_ % params_.update_cycle);
            if (recent || cyclic) out.push_back(j);
        }

        // Pass 2: top-`top_select` features by deltaLossBound (ascending).
        // Use a simple O(nf * top_select) partial selection instead of a
        // full sort to match Java's DoubleIndexSort stability on small nf.
        std::vector<double> dlb(nf);
        for (int j = 0; j < nf; ++j) dlb[j] = delta_loss_bound(j);
        const int k = std::min(params_.top_select, nf);
        std::vector<bool> taken(nf, false);
        for (int j : out) taken[j] = true;
        std::vector<int>  order(nf);
        std::iota(order.begin(), order.end(), 0);
        std::stable_sort(order.begin(), order.end(),
            [&](int a, int b){ return dlb[a] < dlb[b]; });
        // Java Sequential.java:409 — iterate exactly the top `topSelect`
        // entries of orderedDlb and add those not already in toUpdate.
        // (Do NOT keep scanning past topSelect to find `added == k` new
        // ones; that would over-grow toUpdate when Pass 1 already covers
        // some of the top-K.)
        for (int idx = 0; idx < k; ++idx) {
            const int j = order[idx];
            if (!taken[j]) { out.push_back(j); taken[j] = true; }
        }
        return out;
    }

    // =========================================================================
    // Expectation refresh — matches Java's FeaturedSpace.setDensity(toUpdate)
    // semantics for a subset of features.  Assumes density_[] is already
    // up-to-date (i.e. increase_lambda has just been called and internally
    // ran set_density()).  We overwrite only the requested features'
    // expectations to stamp last_expectation_update correctly.
    // =========================================================================

    void refresh_expectations_for(const std::vector<int>& j_to_update) {
        const double dn = X_.get_density_normalizer();
        if (dn <= 0.0) return;
        const auto& feats = X_.features();
        const auto& F = X_.feature_matrix();
        const auto& d = X_.density_vector();
        if (F.size() > 0) {
            for (int j : j_to_update) {
                const double sum = d.dot(F.col(j));
                feats[j]->set_expectation(sum / dn);
                state_[j].last_expectation_update = iteration_;
            }
        } else {
            const int n = X_.num_points();
            for (int j : j_to_update) {
                double sum = 0.0;
                const Feature& h = *feats[j];
                for (int i = 0; i < n; ++i)
                    sum += X_.get_density(i) * h.eval(i);
                feats[j]->set_expectation(sum / dn);
                state_[j].last_expectation_update = iteration_;
            }
        }
    }

    void set_feature_expectation(int j) {
        const double dn = X_.get_density_normalizer();
        if (dn <= 0.0) return;
        const auto& F = X_.feature_matrix();
        const auto& d = X_.density_vector();
        double sum;
        if (F.size() > 0) {
            sum = d.dot(F.col(j));
        } else {
            const int n = X_.num_points();
            sum = 0.0;
            const Feature& h = *X_.features()[j];
            for (int i = 0; i < n; ++i)
                sum += X_.get_density(i) * h.eval(i);
        }
        X_.features()[j]->set_expectation(sum / dn);
        state_[j].last_expectation_update = iteration_;
    }

    // =========================================================================
    // increaseLambda — thin wrappers around FeaturedSpace::increase_lambda
    // that preserve Java's getLoss() return semantics (inc. reg update).
    // =========================================================================

    double increase_lambda(int j, double alpha,
                           const std::vector<int>& to_update) {
        const Feature& h = *X_.features()[j];
        reg_ += (std::abs(h.lambda() + alpha) - std::abs(h.lambda()))
              * h.sample_deviation();
        // Selective-refresh: only the features in `to_update` get fresh
        // expectations after the lp update, matching Java's
        // FeaturedSpace.increaseLambda(h, alpha, updateFeatures).
        X_.increase_lambda(j, alpha, to_update);
        for (int jj : to_update) state_[jj].last_expectation_update = iteration_;
        return get_loss();
    }

    double increase_lambda_batch(const std::vector<double>& alpha,
                                 const std::vector<int>& to_update) {
        X_.increase_lambda(alpha, to_update);
        set_reg();                             // recompute full reg after batch
        for (int jj : to_update) state_[jj].last_expectation_update = iteration_;
        return get_loss();
    }

    // =========================================================================
    // doSequentialUpdate — Sequential.java:419..465
    // =========================================================================

    double do_sequential_update(int j) {
        const Feature& h = *X_.features()[j];
        const double old_lambda = h.lambda();

        // Ensure feature j's expectation is fresh (Java:421..422).
        if (state_[j].last_expectation_update != iteration_ - 1)
            set_feature_expectation(j);
        state_[j].last_change = iteration_;

        const std::vector<int> to_update = features_to_update();
        const double dlb = delta_loss_bound(j);

        double alpha;
        double new_loss;
        if (h.is_binary()) {
            // Binary features (e.g. ThresholdFeature) use the closed-form
            // goodAlpha solution — mirrors Sequential.java:427..430.  No
            // newton fallback and no searchAlpha: the goodAlpha step is
            // already the KKT-consistent λ for a 0/1 indicator under an
            // L1-regularised MaxEnt objective.
            alpha = good_alpha(j);
            alpha = reduce_alpha(alpha);
            new_loss = increase_lambda(j, alpha, to_update);
        } else {
            // Linear / continuous path — mirrors Sequential.java:432..444.
            alpha = newton_step_feature(j);
            alpha = reduce_alpha(alpha);
            new_loss = increase_lambda(j, alpha, to_update);

            if (new_loss - old_loss_ > dlb) {
                // Undo and line-search using goodAlpha as the seed.
                increase_lambda(j, -alpha, { j });
                alpha = search_alpha(j, good_alpha(j));
                alpha = reduce_alpha(alpha);
                new_loss = increase_lambda(j, alpha, to_update);
            }
        }

        // Contribution bookkeeping (Sequential.java:447..462).
        const bool undoing = (alpha * old_lambda < 0.0);
        if (undoing) {
            state_[j].contribution += (new_loss - old_loss_);
            if (state_[j].contribution < 0.0) state_[j].contribution = 0.0;
        } else {
            state_[j].contribution += (old_loss_ - new_loss);
        }
        return new_loss;
    }

    // =========================================================================
    // doParallelUpdate — Sequential.java:245..292
    // =========================================================================

    double do_parallel_update() {
        const int nf = X_.num_features();
        std::vector<double> alpha(nf, 0.0);
        std::vector<double> contrib_delta(nf, 0.0);
        const auto& feats = X_.features();

        for (int j = 0; j < nf; ++j) {
            const double lam = feats[j]->lambda();
            // Java Sequential.java:250 — skip binary features in the
            // parallel-direction newton step.  Binary indicators have
            // zero curvature along a ±1 update direction (f² == f for
            // 0/1 features), which breaks the uTHu computation, so we
            // leave their λ fixed at whatever the sequential pass set.
            if (feats[j]->is_binary() || lam == 0.0) alpha[j] = 0.0;
            else            alpha[j] = lam - state_[j].previous_lambda;
            state_[j].previous_lambda = lam;
            contrib_delta[j] = state_[j].contribution
                             - state_[j].previous_contribution;
            if (contrib_delta[j] < 0.0) contrib_delta[j] = 0.0;
            state_[j].previous_contribution = state_[j].contribution;
        }

        const double step = newton_step_direction(alpha);
        for (int j = 0; j < nf; ++j) {
            const double lam = feats[j]->lambda();
            alpha[j] *= step;
            if (alpha[j] != -lam && std::abs(alpha[j] + lam) < kEps)
                alpha[j] = -lam;   // zero-out a tiny residue
        }

        const double loss_was = get_loss();
        const std::vector<int> to_update = features_to_update();
        double loss_now = increase_lambda_batch(alpha, to_update);

        if (loss_now > loss_was) {
            // Undo the whole batch.
            std::vector<double> undo(alpha.size());
            for (std::size_t j = 0; j < alpha.size(); ++j) undo[j] = -alpha[j];
            loss_now = increase_lambda_batch(undo, to_update);
        } else {
            const double delta_loss = loss_was - loss_now;
            double contrib_sum = 0.0;
            for (int j = 0; j < nf; ++j)
                if (alpha[j] != 0.0) contrib_sum += contrib_delta[j];
            if (contrib_sum > 0.0) {
                for (int j = 0; j < nf; ++j) {
                    if (alpha[j] != 0.0)
                        state_[j].contribution
                            += delta_loss * contrib_delta[j] / contrib_sum;
                }
            }
        }
        return loss_now;
    }

    // =========================================================================
    // terminationTest — Sequential.java:474..495
    // =========================================================================

    bool termination_test(double new_loss) {
        if (params_.disable_convergence_test) return false;

        if (iteration_ == 0) {
            previous_loss_ = new_loss;
            return false;
        }
        if (iteration_ % params_.convergence_test_frequency != 0) return false;
        if (previous_loss_ - new_loss < params_.convergence_threshold)
            return true;
        previous_loss_ = new_loss;
        return false;
    }

    // =========================================================================
    // Observer plumbing
    // =========================================================================

    void emit_initial_snapshot() {
        if (!observer_) return;
        SequentialSnapshot s;
        s.iteration = 0;
        s.loss      = get_loss();
        s.entropy   = X_.get_entropy();
        s.lambdas.reserve(static_cast<std::size_t>(X_.num_features()));
        for (const auto& f : X_.features()) s.lambdas.push_back(f->lambda());
        observer_(s);
    }

    void emit_snapshot(double new_loss) {
        if (!observer_) return;
        // Java's TrajectorySequential.terminationTest uses
        //     completed = iteration + 1
        // We match that convention so our CSV labels line up with the
        // committed trajectory_java.csv goldens.
        SequentialSnapshot s;
        s.iteration = iteration_ + 1;
        s.loss      = new_loss;
        // Match TrajectorySequential.java:237 — reset cached entropy so
        // each snapshot reports the freshly-recomputed value.
        // FeaturedSpace caches entropy lazily; calling set_density() to
        // invalidate is heavy.  Instead, just invoke get_entropy() which
        // itself recomputes when dirty.  We also explicitly mark dirty
        // whenever increase_lambda ran (which it always has by this point)
        // because FeaturedSpace::set_density() resets entropy_ to -1.
        s.entropy   = X_.get_entropy();
        s.lambdas.reserve(static_cast<std::size_t>(X_.num_features()));
        for (const auto& f : X_.features()) s.lambdas.push_back(f->lambda());
        observer_(s);
    }

    // =========================================================================
    // Data
    // =========================================================================

    FeaturedSpace&             X_;
    SequentialParams           params_;
    std::vector<FeatureState>  state_;
    TrajectoryObserver         observer_;

    int    iteration_     = 0;
    double reg_           = 0.0;
    double old_loss_      = 0.0;
    double previous_loss_ = std::numeric_limits<double>::infinity();
    double final_loss_    = std::numeric_limits<double>::infinity();
    bool   converged_     = false;

    static constexpr double kEps = 1e-6;   // matches Sequential.java:36
};

} // namespace maxent

#endif // MAXENT_SEQUENTIAL_HPP
