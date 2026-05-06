# Compute AUC (Area Under the ROC Curve)

Computes the Wilcoxon-Mann-Whitney AUC statistic from prediction scores
at presence and absence sites.

## Usage

``` r
eval_auc(presence, absence)
```

## Arguments

- presence:

  Numeric vector of prediction scores at presence sites.

- absence:

  Numeric vector of prediction scores at absence sites.

## Value

A named list with elements: auc, max_kappa, max_kappa_thresh.
