# QA summary statistics.

.channel_units <- function(channel) {
  switch(tolower(channel),
         signal = "%RE", hp = "psi", ec = "mS/m", NA_character_)
}

.default_thresholds_for <- function(channel) {
  switch(tolower(channel),
         signal = c(1, 2, 5, 10, 50),
         hp = c(1, 5, 10, 25),
         ec = c(10, 50, 100, 500),
         c(1, 2, 5, 10, 50))
}

# Geometric mean over positive values only; zeros have no log-domain image.
.geom_mean <- function(x) {
  pos <- x[x > 0]
  if (!length(pos)) NA_real_ else exp(mean(log(pos)))
}

#' Summarise a LIF channel for QA reporting
#'
#' Standard site-level, per-boring, per-threshold, and per-depth-zone
#' statistics for `signal` (or another numeric channel), returned as a list
#' of data frames so reports and dashboards render the same numbers.
#'
#' @param data A [lif_data] frame.
#' @param channel Column to summarise. Default `"signal"`; `"ec"` and `"hp"`
#'   also work.
#' @param thresholds Threshold values for `$by_threshold`. `NULL` uses a
#'   unit-appropriate default (`c(1, 2, 5, 10, 50)` %RE for signal).
#' @param depth_bins Break points (ft) for `$by_depth_zone`; the last may be
#'   `Inf`.
#' @param quantiles Probabilities for `$quantiles`.
#' @param detection_limit Minimum value counted as a detection in
#'   `pct_detect`. Default 0.
#' @param sort_by Order of `$by_boring`: `"peak"` (descending, default) or
#'   `"input"` (first-appearance order).
#' @param plot Logical. Also print a lollipop chart of peak signal per boring
#'   (see [chart_peak_by_boring()]).
#' @return A list: `overview` (one row: `n_borings`, `n_samples`, `min`,
#'   `mean`, `geom_mean`, `geom_mean_n_excluded`, `median`, `max`,
#'   `pct_detect`), `by_boring` (`boring`, `n`, `peak`, `peak_depth`,
#'   `mean`, `geom_mean`, `geom_mean_n_excluded`, `p50`, `p95`),
#'   `by_threshold` (`threshold`, `units`, `n_samples_above`,
#'   `pct_samples_above`, `n_borings_above`, `pct_borings_above`),
#'   `by_depth_zone` (`depth_zone`, `n`, `pct_detect`, `p50`, `p95`), and
#'   `quantiles` (one row, `channel` plus one column per probability).
#' @section Geometric mean:
#' LIF response is right-skewed, so the geometric mean is reported beside
#' the arithmetic mean. It is defined over positive values only;
#' `geom_mean_n_excluded` counts the zeros and negatives left out.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' qa <- summarize_lif(lif)
#' qa$overview
#' qa$by_boring
#' qa$by_threshold
#' @export
summarize_lif <- function(data, channel = "signal", thresholds = NULL,
                          depth_bins = c(0, 5, 10, 15, 20, Inf),
                          quantiles = c(0.05, 0.25, 0.5, 0.75, 0.95),
                          detection_limit = 0, sort_by = c("peak", "input"),
                          plot = FALSE) {
  sort_by <- match.arg(sort_by)
  .check_data_arg(data, "summarize_lif")
  channel <- tolower(channel)
  .check_required_cols(data, c("boring", "depth", channel), source = "data")
  if (is.null(thresholds)) thresholds <- .default_thresholds_for(channel)

  x <- data[[channel]]; depth <- data$depth; bore <- data$boring
  xv <- x[!is.na(x)]; n_samp <- length(xv)
  borings <- unique(bore); n_bores <- length(borings)

  overview <- data.frame(
    n_borings = n_bores, n_samples = n_samp,
    min = if (n_samp) min(xv) else NA_real_,
    mean = if (n_samp) mean(xv) else NA_real_,
    geom_mean = .geom_mean(xv), geom_mean_n_excluded = sum(xv <= 0),
    median = if (n_samp) stats::median(xv) else NA_real_,
    max = if (n_samp) max(xv) else NA_real_,
    pct_detect = if (n_samp) mean(xv > detection_limit) * 100 else NA_real_)

  by_boring <- do.call(rbind, lapply(borings, function(b) {
    sel <- bore == b & !is.na(x)
    xb <- x[sel]; nb <- length(xb)
    data.frame(
      boring = b, n = nb,
      peak = if (nb) max(xb) else NA_real_,
      peak_depth = if (nb) depth[sel][which.max(xb)] else NA_real_,
      mean = if (nb) mean(xb) else NA_real_,
      geom_mean = .geom_mean(xb), geom_mean_n_excluded = sum(xb <= 0),
      p50 = if (nb) stats::quantile(xb, 0.5, names = FALSE) else NA_real_,
      p95 = if (nb) stats::quantile(xb, 0.95, names = FALSE) else NA_real_,
      stringsAsFactors = FALSE)
  }))
  if (sort_by == "peak")
    by_boring <- by_boring[order(-by_boring$peak, by_boring$boring), , drop = FALSE]
  rownames(by_boring) <- NULL

  by_threshold <- do.call(rbind, lapply(thresholds, function(thr) {
    n_above <- sum(xv >= thr)
    b_above <- sum(vapply(borings, function(b) any(x[bore == b] >= thr, na.rm = TRUE),
                          logical(1)))
    data.frame(threshold = thr, units = .channel_units(channel),
               n_samples_above = n_above,
               pct_samples_above = if (n_samp) n_above / n_samp * 100 else NA_real_,
               n_borings_above = b_above,
               pct_borings_above = if (n_bores) b_above / n_bores * 100 else NA_real_,
               stringsAsFactors = FALSE)
  }))
  rownames(by_threshold) <- NULL

  n_zones <- length(depth_bins) - 1L
  zone_labels <- vapply(seq_len(n_zones), function(i) {
    lo <- depth_bins[i]; hi <- depth_bins[i + 1L]
    if (is.infinite(hi)) sprintf("%g+", lo) else sprintf("%g-%g", lo, hi)
  }, character(1))
  zones <- cut(depth, breaks = depth_bins, labels = zone_labels,
               include.lowest = TRUE, right = FALSE)
  by_depth_zone <- do.call(rbind, lapply(zone_labels, function(z) {
    xz <- x[!is.na(zones) & zones == z & !is.na(x)]; nz <- length(xz)
    data.frame(depth_zone = z, n = nz,
               pct_detect = if (nz) mean(xz > detection_limit) * 100 else NA_real_,
               p50 = if (nz) stats::quantile(xz, 0.5, names = FALSE) else NA_real_,
               p95 = if (nz) stats::quantile(xz, 0.95, names = FALSE) else NA_real_,
               stringsAsFactors = FALSE)
  }))
  rownames(by_depth_zone) <- NULL

  q <- if (n_samp) stats::quantile(xv, probs = quantiles, names = FALSE)
       else rep(NA_real_, length(quantiles))
  names(q) <- paste0("p", round(quantiles * 100))
  qdf <- cbind(data.frame(channel = channel, stringsAsFactors = FALSE),
               as.data.frame(as.list(q), check.names = FALSE))

  result <- list(overview = overview, by_boring = by_boring,
                 by_threshold = by_threshold, by_depth_zone = by_depth_zone,
                 quantiles = qdf)
  if (isTRUE(plot)) print(chart_peak_by_boring(data, channel = channel))
  result
}
