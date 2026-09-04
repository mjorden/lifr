# Processing helpers: hydrostatic pressure correction, RE-feet integration,
# and depth downsampling. Each records itself in the edit history.

#' Remove the hydrostatic component from hydraulic push pressure
#'
#' Raw `hp` rises with depth from the weight of the water column alone.
#' Subtracting `gradient * max(0, depth - water_table)` leaves the pressure
#' the formation itself exerts, which is the quantity that reflects
#' permeability.
#'
#' @param data A data frame with `depth` and `hp` columns.
#' @param gradient Hydrostatic gradient in psi/ft. Default 0.433 (fresh
#'   water).
#' @param water_table Depth to water (ft below ground surface): one value
#'   applied site-wide, or a named vector of per-boring depths such as
#'   `c("LIF-01" = 12, "LIF-02" = 14.5)`. Default 0 applies the correction
#'   from the ground surface and prints a reminder to supply a real value.
#' @return `data` with `hp` corrected in place and one audit row recording
#'   the parameters.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' lif <- hp_correction(lif, water_table = 6)
#' edit_history(lif)
#' @export
hp_correction <- function(data, gradient = 0.433, water_table = 0) {
  .check_data_arg(data, "hp_correction")
  .check_required_cols(data, c("depth", "hp"), source = "data")
  if (nrow(data) == 0L || all(is.na(data$hp))) {
    message("hp_correction: no hp readings to correct; returning unchanged.")
    return(data)
  }
  wt <- unlist(water_table)
  if (!is.numeric(wt) || !length(wt) || anyNA(wt) || any(wt < 0))
    stop("`water_table` must be non-negative numeric (ft bgs): a single value ",
         "or a named per-boring vector.", call. = FALSE)
  if (is.null(names(wt))) {
    if (length(wt) != 1L)
      stop("Unnamed `water_table` must be a single site-wide value; use a ",
           "named vector for per-boring depths.", call. = FALSE)
    if (missing(water_table))
      message("hp_correction: water_table not supplied -- correction applied ",
              "from the ground surface. Supply water_table (ft bgs) to avoid ",
              "over-correcting the unsaturated zone.")
    wt_row <- rep(wt, nrow(data))
    wt_note <- sprintf("%g", wt)
  } else {
    .check_required_cols(data, "boring", source = "data")
    miss <- setdiff(unique(data$boring), names(wt))
    if (length(miss))
      stop("`water_table` has no entry for boring(s): ",
           paste(miss, collapse = ", "), call. = FALSE)
    wt_row <- unname(wt[data$boring])
    wt_note <- paste(sprintf("%s=%g", names(wt), wt), collapse = "|")
  }
  data$hp <- data$hp - gradient * pmax(0, data$depth - wt_row)
  .record_edit(data, "hp_correction", NA, NA, NA, NA, sum(!is.na(data$hp)),
               notes = sprintf("gradient=%g; water_table=%s", gradient, wt_note))
}

# Trapezoidal integral of y over x (x need not be sorted).
.trapz <- function(x, y) {
  o <- order(x); x <- x[o]; y <- y[o]
  ok <- !is.na(x) & !is.na(y)
  x <- x[ok]; y <- y[ok]
  if (length(x) < 2L) return(0)
  sum(diff(x) * (utils::head(y, -1) + utils::tail(y, -1)) / 2)
}

#' Integrate LIF signal over depth per boring (RE-feet)
#'
#' The trapezoidal integral of `signal` against `depth` for each boring, a
#' single number summarising how much fluorescence a boring encountered.
#' Like %RE itself it is a screening quantity, not a mass or concentration.
#'
#' @param data A [lif_data] frame.
#' @return One row per boring with `boring`, `re_feet`, `peak_signal`,
#'   `peak_depth`, and the boring's `easting`, `northing`, `msl` when
#'   present.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' re_feet(lif)
#' @export
re_feet <- function(data) {
  .check_data_arg(data, "re_feet")
  .check_required_cols(data, c("boring", "depth", "signal"), source = "data")
  loc_cols <- intersect(c("easting", "northing", "msl"), names(data))
  rows <- lapply(split(data, data$boring), function(d) {
    n_neg <- sum(d$signal < 0, na.rm = TRUE)
    if (n_neg)
      warning(sprintf("re_feet: boring '%s' has %d negative signal value(s); ",
                      d$boring[1], n_neg),
              "RE-feet may be underestimated.", call. = FALSE)
    i <- if (all(is.na(d$signal))) NA_integer_ else which.max(d$signal)
    out <- data.frame(boring = d$boring[1],
                      re_feet = .trapz(d$depth, d$signal),
                      peak_signal = if (is.na(i)) NA_real_ else d$signal[i],
                      peak_depth  = if (is.na(i)) NA_real_ else d$depth[i],
                      stringsAsFactors = FALSE)
    for (cc in loc_cols) out[[cc]] <- d[[cc]][1]
    out
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Thin a LIF frame to a coarser depth spacing
#'
#' Keeps one reading every `target_interval` feet per boring, always
#' retaining readings whose `signal` exceeds `preserve_above` so peaks are
#' never thinned away. Row deletion is an edit: one audit row records the
#' parameters and the number of rows removed.
#'
#' @param data A [lif_data] frame.
#' @param target_interval Target spacing (ft). Default 1.
#' @param preserve_above Signal threshold above which every reading is kept.
#'   `NULL` (default) thins uniformly.
#' @return The thinned frame, sorted by depth within each boring.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' thin <- lif_downsample(lif, target_interval = 1, preserve_above = 5)
#' nrow(lif); nrow(thin)
#' @export
lif_downsample <- function(data, target_interval = 1, preserve_above = NULL) {
  .check_data_arg(data, "lif_downsample")
  .check_required_cols(data, c("boring", "depth", "signal"), source = "data")
  if (!is.numeric(target_interval) || length(target_interval) != 1L ||
      !is.finite(target_interval) || target_interval <= 0)
    stop("target_interval must be a single positive number", call. = FALSE)
  parts <- lapply(unique(data$boring), function(b) {
    sub <- data[data$boring == b, , drop = FALSE]
    sub <- sub[order(sub$depth), , drop = FALSE]
    n <- nrow(sub)
    if (!n) return(sub)
    keep <- logical(n); last <- -Inf
    for (i in seq_len(n)) {
      pres <- !is.null(preserve_above) && !is.na(sub$signal[i]) &&
              sub$signal[i] > preserve_above
      if (pres || (sub$depth[i] - last) >= target_interval - 1e-9) {
        keep[i] <- TRUE
        if (!pres) last <- sub$depth[i]
      }
    }
    sub[keep, , drop = FALSE]
  })
  n_in <- nrow(data)
  out <- do.call(rbind, parts)
  if (is.null(out)) out <- data[0, , drop = FALSE]
  rownames(out) <- NULL
  n_out <- nrow(out)
  message(sprintf("lif_downsample: %d -> %d rows (%.0f%% retained, target_interval=%g ft)",
                  n_in, n_out, 100 * n_out / max(n_in, 1), target_interval))
  attr(out, "edits") <- attr(data, "edits")
  .record_edit(out, "lif_downsample", NA, NA, NA, NA, n_in - n_out,
               notes = sprintf("target_interval=%g; preserve_above=%s; n_in=%d; n_out=%d",
                               target_interval,
                               if (is.null(preserve_above)) "none" else format(preserve_above),
                               n_in, n_out))
}
