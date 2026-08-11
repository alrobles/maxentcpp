#' Compute Permutation Importance
#'
#' Measures how much each environmental variable contributes to model
#' prediction quality by permuting each variable and measuring AUC drop.
#' Results are normalised so that all importances sum to 100%.
#'
#' @param model         External pointer to a FeaturedSpace object.
#' @param env_grids     List of external pointers to Grid<float> objects.
#' @param feature_names Character vector of environment variable names,
#'   matching the order of env_grids.
#' @param presence_rows Integer vector of presence site row indices (0-based).
#' @param presence_cols Integer vector of presence site column indices (0-based).
#' @param absence_rows  Integer vector of absence/background site row indices.
#' @param absence_cols  Integer vector of absence/background site column indices.
#' @param seed          Random seed for reproducibility (default 42).
#' @return A data.frame with columns:
#'   \describe{
#'     \item{name}{Variable name}
#'     \item{permutation_importance}{Normalised importance (\%)}
#'   }
#' @export
#' @examples
#' \dontrun{
#' imp <- maxent_permutation_importance(model, list(g1, g2),
#'          c("temp", "precip"),
#'          pres_rows, pres_cols, abs_rows, abs_cols)
#' imp  # data.frame with name and permutation_importance
#' }
maxent_permutation_importance <- function(model, env_grids, feature_names,
                                          presence_rows, presence_cols,
                                          absence_rows, absence_cols,
                                          seed = 42L) {
    compute_permutation_importance(
        model, env_grids, as.character(feature_names),
        as.integer(presence_rows), as.integer(presence_cols),
        as.integer(absence_rows), as.integer(absence_cols),
        as.integer(seed))
}

#' Compute Percent Contribution
#'
#' Computes variable contribution based on sum of absolute lambda values
#' for features derived from each variable. Results sum to 100%.
#'
#' @param model         External pointer to a FeaturedSpace object.
#' @param feature_names Character vector of base variable names.
#' @return A data.frame with columns:
#'   \describe{
#'     \item{name}{Variable name}
#'     \item{contribution}{Percent contribution}
#'   }
#' @export
#' @examples
#' \dontrun{
#' contrib <- maxent_percent_contribution(model, c("temp", "precip"))
#' contrib  # data.frame with name and contribution
#' }
maxent_percent_contribution <- function(model, feature_names) {
    compute_percent_contribution(model, as.character(feature_names))
}

#' Compute Marginal Response Curve
#'
#' Generates a response curve by varying one environmental variable from its
#' minimum to maximum value while holding all other variables at their mean.
#' Applies the Java Maxent cloglog transform, matching the output of Java
#' Maxent and \pkg{dismo}:
#' \deqn{cloglog = 1 - exp(-exp(H) \cdot raw)}
#'
#' @param model         External pointer to a FeaturedSpace object.
#' @param env_grids     List of external pointers to Grid<float> objects.
#' @param feature_names Character vector of environment variable names.
#' @param var_index     0-based index of the variable to vary.
#' @param n_steps       Number of steps across the variable range (default 100).
#' @return A data.frame with columns:
#'   \describe{
#'     \item{value}{Environmental variable value}
#'     \item{prediction}{Cloglog-transformed prediction}
#'   }
#' @export
#' @examples
#' \dontrun{
#' curve <- maxent_response_curve(model, list(g1, g2),
#'            c("temp", "precip"), var_index = 0)
#' plot(curve$value, curve$prediction, type = "l")
#' }
#' @seealso \code{\link{maxent_response_curve_fixed}}
maxent_response_curve <- function(model, env_grids, feature_names,
                                  var_index, n_steps = 100L) {
    compute_response_curve(
        model, env_grids, as.character(feature_names),
        as.integer(var_index), as.integer(n_steps))
}

#' Compute Response Curve with Fixed Values
#'
#' Like \code{maxent_response_curve} but the user supplies explicit fixed
#' values for the non-target variables. Applies the Java Maxent cloglog
#' transform, matching the output of Java Maxent and \pkg{dismo}:
#' \deqn{cloglog = 1 - exp(-exp(H) \cdot raw)}
#'
#' @param model         External pointer to a FeaturedSpace object.
#' @param fixed_values  Numeric vector of fixed values for each variable.
#' @param feature_names Character vector of environment variable names.
#' @param var_index     0-based index of the variable to vary.
#' @param var_min       Minimum value of the target variable.
#' @param var_max       Maximum value of the target variable.
#' @param n_steps       Number of steps (default 100).
#' @return A data.frame with columns: value, prediction.
#' @export
#' @seealso \code{\link{maxent_response_curve}}
maxent_response_curve_fixed <- function(model, fixed_values, feature_names,
                                        var_index, var_min, var_max,
                                        n_steps = 100L) {
    compute_response_curve_fixed(
        model, as.numeric(fixed_values), as.character(feature_names),
        as.integer(var_index), as.numeric(var_min), as.numeric(var_max),
        as.integer(n_steps))
}

#' Clamp Environmental Grids
#'
#' Restricts environmental variable values to the range observed during
#' training. Values below min are set to min, values above max are set to max.
#' A clamping grid records the total absolute clamping at each cell.
#'
#' @param env_grids List of external pointers to Grid<float> objects.
#' @param var_mins  Numeric vector of minimum training values per variable.
#' @param var_maxs  Numeric vector of maximum training values per variable.
#' @return A named list with:
#'   \describe{
#'     \item{clamped_grids}{List of external pointers to clamped grids}
#'     \item{clamp_grid}{External pointer to clamping magnitude grid}
#'   }
#' @export
#' @examples
#' \dontrun{
#' result <- maxent_clamp(list(g1, g2), c(0, 50), c(30, 200))
#' clamped <- result$clamped_grids
#' clamp_mat <- maxent_grid_to_matrix(result$clamp_grid)
#' }
maxent_clamp <- function(env_grids, var_mins, var_maxs) {
    clamp_grids(env_grids, as.numeric(var_mins), as.numeric(var_maxs))
}

#' Compute Variable Ranges from Grids
#'
#' Scans all valid cells in the grids to determine the [min, max] range
#' of each environmental variable.
#'
#' @param env_grids List of external pointers to Grid<float> objects.
#' @return A data.frame with columns: min, max (one row per variable).
#' @export
maxent_variable_ranges <- function(env_grids) {
    compute_variable_ranges(env_grids)
}

#' Compute MESS (Multivariate Environmental Similarity Surface)
#'
#' Measures how similar each cell is to the training environment using the
#' full distribution of reference values. Negative MESS values indicate
#' novel (non-analog) environments.
#'
#' @param env_grids        List of external pointers to Grid<float> objects.
#' @param reference_values List of numeric vectors with reference values
#'   for each variable (e.g. values at training sites).
#' @param feature_names    Character vector of variable names.
#' @return A named list with:
#'   \describe{
#'     \item{mess_grid}{External pointer to Grid<float> with MESS values}
#'     \item{mod_grid}{External pointer to Grid<float> with Most Dissimilar
#'       Variable index (1-based)}
#'   }
#' @export
#' @examples
#' \dontrun{
#' result <- maxent_mess(list(g1, g2),
#'             list(temp_train_vals, precip_train_vals),
#'             c("temp", "precip"))
#' mess_mat <- maxent_grid_to_matrix(result$mess_grid)
#' mod_mat  <- maxent_grid_to_matrix(result$mod_grid)
#' }
maxent_mess <- function(env_grids, reference_values, feature_names) {
    compute_mess(env_grids, reference_values, as.character(feature_names))
}

#' Compute MESS from Min/Max Ranges
#'
#' Simplified MESS analysis using only the min/max of the reference data
#' rather than the full distribution.
#'
#' @param env_grids List of external pointers to Grid<float> objects.
#' @param var_mins  Numeric vector of minimum reference values per variable.
#' @param var_maxs  Numeric vector of maximum reference values per variable.
#' @return A named list with mess_grid and mod_grid (external pointers).
#' @export
maxent_mess_range <- function(env_grids, var_mins, var_maxs) {
    compute_mess_range(env_grids, as.numeric(var_mins), as.numeric(var_maxs))
}
#' Compute Marginal Response Curve (deprecated)
#'
#' Generates a response curve by varying one environmental variable from its
#' minimum to maximum value while holding all other variables at their mean.
#' Predictions are cloglog-transformed ([0, 1]).
#'
#' @param model         External pointer to a FeaturedSpace object.
#' @param env_grids     List of external pointers to Grid<float> objects.
#' @param feature_names Character vector of environment variable names.
#' @param var_index     0-based index of the variable to vary.
#' @param n_steps       Number of steps across the variable range (default 100).
#' @return A data.frame with columns:
#'   \describe{
#'     \item{value}{Environmental variable value}
#'     \item{prediction}{Cloglog-transformed prediction}
#'   }
#' @keywords internal
maxent_response_curve_deprecated <- function(model, env_grids, feature_names,
                                             var_index, n_steps = 100L) {
    compute_response_curve_deprecated(
        model, env_grids, as.character(feature_names),
        as.integer(var_index), as.integer(n_steps))
}

#' Compute Response Curve with Fixed Values (deprecated)
#'
#' Like \code{maxent_response_curve_deprecated} but the user supplies explicit
#' fixed values for the non-target variables.
#'
#' @param model         External pointer to a FeaturedSpace object.
#' @param fixed_values  Numeric vector of fixed values for each variable.
#' @param feature_names Character vector of environment variable names.
#' @param var_index     0-based index of the variable to vary.
#' @param var_min       Minimum value of the target variable.
#' @param var_max       Maximum value of the target variable.
#' @param n_steps       Number of steps (default 100).
#' @return A data.frame with columns: value, prediction.
#' @keywords internal
maxent_response_curve_fixed_deprecated <- function(model, fixed_values,
                                                   feature_names,
                                                   var_index, var_min, var_max,
                                                   n_steps = 100L) {
    compute_response_curve_fixed_deprecated(
        model, as.numeric(fixed_values), as.character(feature_names),
        as.integer(var_index), as.numeric(var_min), as.numeric(var_max),
        as.integer(n_steps))
}

#' Compute Marginal Response Curve
#'
#' Generates a response curve by varying one environmental variable from its
#' minimum to maximum value while holding all other variables at their mean.
#' Applies the Java Maxent cloglog transform, matching the output of Java
#' Maxent and \pkg{dismo}:
#' \deqn{cloglog = 1 - exp(-exp(H) \cdot raw)}
#'
#' @param model         External pointer to a FeaturedSpace object.
#' @param env_grids     List of external pointers to Grid<float> objects.
#' @param feature_names Character vector of environment variable names.
#' @param var_index     0-based index of the variable to vary.
#' @param n_steps       Number of steps across the variable range (default 100).
#' @return A data.frame with columns:
#'   \describe{
#'     \item{value}{Environmental variable value}
#'     \item{prediction}{Cloglog-transformed prediction}
#'   }
#' @export
#' @examples
#' \dontrun{
#' curve <- maxent_response_curve(model, list(g1, g2),
#'            c("temp", "precip"), var_index = 0)
#' plot(curve$value, curve$prediction, type = "l")
#' }
#' @seealso \code{\link{maxent_response_curve_fixed}}
maxent_response_curve <- function(model, env_grids, feature_names,
                                  var_index, n_steps = 100L) {
    compute_response_curve(
        model, env_grids, as.character(feature_names),
        as.integer(var_index), as.integer(n_steps))
}

#' Compute Response Curve with Fixed Values
#'
#' Like \code{maxent_response_curve} but the user supplies explicit fixed
#' values for the non-target variables. Applies the Java Maxent cloglog
#' transform, matching the output of Java Maxent and \pkg{dismo}:
#' \deqn{cloglog = 1 - exp(-exp(H) \cdot raw)}
#'
#' @param model         External pointer to a FeaturedSpace object.
#' @param fixed_values  Numeric vector of fixed values for each variable.
#' @param feature_names Character vector of environment variable names.
#' @param var_index     0-based index of the variable to vary.
#' @param var_min       Minimum value of the target variable.
#' @param var_max       Maximum value of the target variable.
#' @param n_steps       Number of steps (default 100).
#' @return A data.frame with columns: value, prediction.
#' @export
#' @seealso \code{\link{maxent_response_curve}}
maxent_response_curve_fixed <- function(model, fixed_values, feature_names,
                                        var_index, var_min, var_max,
                                        n_steps = 100L) {
    compute_response_curve_fixed(
        model, as.numeric(fixed_values), as.character(feature_names),
        as.integer(var_index), as.numeric(var_min), as.numeric(var_max),
        as.integer(n_steps))
}

#' Clamp Environmental Grids
#'
#' Restricts environmental variable values to the range observed during
#' training. Values below min are set to min, values above max are set to max.
#' A clamping grid records the total absolute clamping at each cell.
#'
#' @param env_grids List of external pointers to Grid<float> objects.
#' @param var_mins  Numeric vector of minimum training values per variable.
#' @param var_maxs  Numeric vector of maximum training values per variable.
#' @return A named list with:
#'   \describe{
#'     \item{clamped_grids}{List of external pointers to clamped grids}
#'     \item{clamp_grid}{External pointer to clamping magnitude grid}
#'   }
#' @export
#' @examples
#' \dontrun{
#' result <- maxent_clamp(list(g1, g2), c(0, 50), c(30, 200))
#' clamped <- result$clamped_grids
#' clamp_mat <- maxent_grid_to_matrix(result$clamp_grid)
#' }
maxent_clamp <- function(env_grids, var_mins, var_maxs) {
    clamp_grids(env_grids, as.numeric(var_mins), as.numeric(var_maxs))
}

#' Compute Variable Ranges from Grids
#'
#' Scans all valid cells in the grids to determine the [min, max] range
#' of each environmental variable.
#'
#' @param env_grids List of external pointers to Grid<float> objects.
#' @return A data.frame with columns: min, max (one row per variable).
#' @export
maxent_variable_ranges <- function(env_grids) {
    compute_variable_ranges(env_grids)
}

#' Compute MESS (Multivariate Environmental Similarity Surface)
#'
#' Measures how similar each cell is to the training environment using the
#' full distribution of reference values. Negative MESS values indicate
#' novel (non-analog) environments.
#'
#' @param env_grids        List of external pointers to Grid<float> objects.
#' @param reference_values List of numeric vectors with reference values
#'   for each variable (e.g. values at training sites).
#' @param feature_names    Character vector of variable names.
#' @return A named list with:
#'   \describe{
#'     \item{mess_grid}{External pointer to Grid<float> with MESS values}
#'     \item{mod_grid}{External pointer to Grid<float> with Most Dissimilar
#'       Variable index (1-based)}
#'   }
#' @export
#' @examples
#' \dontrun{
#' result <- maxent_mess(list(g1, g2),
#'             list(temp_train_vals, precip_train_vals),
#'             c("temp", "precip"))
#' mess_mat <- maxent_grid_to_matrix(result$mess_grid)
#' mod_mat  <- maxent_grid_to_matrix(result$mod_grid)
#' }
maxent_mess <- function(env_grids, reference_values, feature_names) {
    compute_mess(env_grids, reference_values, as.character(feature_names))
}

#' Compute MESS from Min/Max Ranges
#'
#' Simplified MESS analysis using only the min/max of the reference data
#' rather than the full distribution.
#'
#' @param env_grids List of external pointers to Grid<float> objects.
#' @param var_mins  Numeric vector of minimum reference values per variable.
#' @param var_maxs  Numeric vector of maximum reference values per variable.
#' @return A named list with mess_grid and mod_grid (external pointers).
#' @export
maxent_mess_range <- function(env_grids, var_mins, var_maxs) {
    compute_mess_range(env_grids, as.numeric(var_mins), as.numeric(var_maxs))
}
