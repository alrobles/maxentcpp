#' Print Maxent Model Results
#'
#' Prints a summary of Maxent model performance metrics to the console,
#' replicating the style of the \pkg{dismo} package's MaxEnt output.  The
#' report includes sample counts, training (and optionally test) evaluation
#' statistics, and a ranked variable-contributions table.
#'
#' @param species         Character: species name.
#' @param eval_result     Named list returned by \code{\link{maxent_evaluate}}
#'   (training predictions vs background).
#' @param contributions_df Data.frame with columns \code{name} and
#'   \code{contribution} (from \code{\link{maxent_percent_contribution}}).
#' @param perm_imp_df     Data.frame with columns \code{name} and
#'   \code{permutation_importance} (from
#'   \code{\link{maxent_permutation_importance}}).
#' @param n_presence      Integer: number of training presence records.
#' @param n_background    Integer: number of background records.
#' @param test_eval_result Named list returned by \code{\link{maxent_evaluate}}
#'   for test data, or \code{NULL} (default).
#' @param n_test          Integer: number of test presence records
#'   (default \code{0L}).
#' @param fit_result      Named list returned by \code{\link{maxent_fit}} or
#'   \code{NULL}.  Used to report regularized training gain and entropy.
#' @return Invisibly returns a named list with all reported metrics.
#' @export
#' @examples
#' \donttest{
#' maxent_print_results(
#'   species          = "Sp1",
#'   eval_result      = maxent_evaluate(pres_preds, bg_preds),
#'   contributions_df = contrib,
#'   perm_imp_df      = perm_imp,
#'   n_presence       = length(pres_rows),
#'   n_background     = length(bg_rows))
#' }
maxent_print_results <- function(species,
                                 eval_result,
                                 contributions_df,
                                 perm_imp_df,
                                 n_presence,
                                 n_background,
                                 test_eval_result = NULL,
                                 n_test           = 0L,
                                 fit_result       = NULL) {

    # ---- Header -------------------------------------------------------------
    cat("class         : MaxEnt\n")
    cat(sprintf("species       : %s\n", species))

    # ---- Sample counts ------------------------------------------------------
    cat(sprintf("n presence    : %d\n", as.integer(n_presence)))
    cat(sprintf("n background  : %d\n", as.integer(n_background)))
    if (as.integer(n_test) > 0L) {
        cat(sprintf("n test        : %d\n", as.integer(n_test)))
    }

    # ---- Training statistics ------------------------------------------------
    cat("\nTraining statistics\n")
    if (!is.null(eval_result$auc)) {
        cat(sprintf("  AUC             : %.4f\n", eval_result$auc))
    }
    if (!is.null(fit_result$loss)) {
        # fit_result$loss is the regularized training gain (negative log-loss)
        cat(sprintf("  Gain            : %.4f\n", fit_result$loss))
    }
    entropy_val <- if (!is.null(fit_result$entropy))
        fit_result$entropy else NULL
    if (!is.null(entropy_val)) {
        cat(sprintf("  Entropy         : %.4f\n", entropy_val))
    }

    # ---- Test statistics ----------------------------------------------------
    if (!is.null(test_eval_result) && !is.null(test_eval_result$auc)) {
        cat("\nTest statistics\n")
        cat(sprintf("  AUC             : %.4f\n", test_eval_result$auc))
    }

    # ---- Variable contributions ---------------------------------------------
    if (!is.null(contributions_df) && nrow(contributions_df) > 0 &&
        !is.null(perm_imp_df)      && nrow(perm_imp_df) > 0) {

        merged <- merge(contributions_df, perm_imp_df, by = "name", all = TRUE)
        merged[is.na(merged)] <- 0
        merged <- merged[order(merged$contribution, decreasing = TRUE), ]

        cat("\nVariable contributions\n")
        cat(sprintf("  %-20s  %s  %s\n",
                    "Variable",
                    "Contribution (%)",
                    "Permutation importance (%)"))
        for (i in seq_len(nrow(merged))) {
            cat(sprintf("  %-20s  %16.1f  %25.1f\n",
                        merged$name[i],
                        merged$contribution[i],
                        merged$permutation_importance[i]))
        }
    }
    cat("\n")

    # ---- Return metrics invisibly -------------------------------------------
    invisible(list(
        species          = species,
        n_presence       = as.integer(n_presence),
        n_background     = as.integer(n_background),
        n_test           = as.integer(n_test),
        training_auc     = eval_result$auc,
        test_auc         = if (!is.null(test_eval_result))
                               test_eval_result$auc else NULL,
        gain             = fit_result$loss,  # regularized training gain
        entropy          = fit_result$entropy,
        contributions    = contributions_df,
        perm_importance  = perm_imp_df
    ))
}
