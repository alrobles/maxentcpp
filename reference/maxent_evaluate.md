# Full Model Evaluation

Computes all evaluation metrics at once: AUC, correlation, log-loss,
squared error, misclassification, max Kappa, and prevalence.

## Usage

``` r
maxent_evaluate(presence, absence)
```

## Arguments

- presence:

  Numeric vector of prediction scores at presence sites.

- absence:

  Numeric vector of prediction scores at absence sites.

## Value

A named list with:

- auc:

  AUC value

- max_kappa:

  Best Cohen's Kappa

- max_kappa_thresh:

  Threshold at best Kappa

- correlation:

  Pearson correlation with labels

- square_error:

  Mean squared error

- logloss:

  Cross-entropy log-loss

- misclassification:

  Misclassification rate

- prevalence:

  Fraction of presence sites

## Examples

``` r
if (FALSE) { # \dontrun{
res <- maxent_evaluate(c(0.9, 0.85, 0.95), c(0.1, 0.15, 0.2))
res$auc          # 1.0
res$correlation  # > 0
} # }
```
