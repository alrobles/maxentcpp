# Full Model Evaluation

Computes all evaluation metrics at once: AUC, correlation, log-loss,
squared error, misclassification, max kappa, and prevalence.

## Usage

``` r
eval_model(presence, absence)
```

## Arguments

- presence:

  Numeric vector of prediction scores at presence sites.

- absence:

  Numeric vector of prediction scores at absence sites.

## Value

A named list with: auc, max_kappa, max_kappa_thresh, correlation,
square_error, logloss, misclassification, prevalence.
