# Compute AUC (Area Under the ROC Curve)

Computes the Wilcoxon-Mann-Whitney AUC statistic from prediction scores
at presence and absence sites. Also returns max-Kappa and its threshold.

## Usage

``` r
maxent_auc(presence, absence)
```

## Arguments

- presence:

  Numeric vector of prediction scores at presence sites.

- absence:

  Numeric vector of prediction scores at absence sites.

## Value

A named list with elements:

- auc:

  AUC value in \[0, 1\]

- max_kappa:

  Best Cohen's Kappa found

- max_kappa_thresh:

  Threshold at best Kappa

## Examples

``` r
if (FALSE) { # \dontrun{
result <- maxent_auc(c(0.8, 0.9, 1.0), c(0.1, 0.2, 0.3))
result$auc  # 1.0
} # }
```
