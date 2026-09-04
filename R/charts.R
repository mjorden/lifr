# Site summary charts embedded in the report and exportable as PNGs.

#' Chart: maximum LIF response by boring
#'
#' One bar per boring at its peak %RE, filled with the emission colour
#' recorded at that depth (the product signature) when a `color` channel is
#' present. Borings whose peak is below the lowest threshold are drawn grey:
#' at that level the peak is background, so a product colour would imply a
#' signature that is not there.
#'
#' @param data A [lif_data] frame.
#' @param thresholds Screening thresholds (%RE); the lowest greys out bars.
#' @return A ggplot, or `NULL` when there is no signal data.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' chart_max_response(lif)
#' @export
chart_max_response <- function(data, thresholds = c(1, 5)) {
  if (!all(c("boring", "signal") %in% names(data))) return(NULL)
  pk <- .boring_peaks(data)
  pk <- pk[pk$sampled, , drop = FALSE]
  if (!nrow(pk)) return(NULL)
  floor_re <- if (length(thresholds)) min(thresholds) else 0
  pk$fill <- ifelse(pk$peak_signal < floor_re, .LIFR_GREY,
                    ifelse(is.na(pk$peak_color), .LIFR_FILL, pk$peak_color))
  pk <- pk[order(pk$boring), , drop = FALSE]
  pk$boring <- factor(pk$boring, levels = pk$boring)
  ggplot2::ggplot(pk, ggplot2::aes(x = .data$boring, y = .data$peak_signal)) +
    ggplot2::geom_col(fill = pk$fill, colour = "#00000022", linewidth = 0.15, width = 0.72) +
    ggplot2::labs(title = "Maximum LIF response by boring", x = NULL,
                  y = "Peak response (%RE)",
                  caption = paste0("Bar colour = emission colour at peak-signal depth; grey = peak below the ",
                                   format(floor_re), " %RE screening floor.\n",
                                   .wrap_note(.RE_PROXY_NOTE, 100))) +
    theme_lifr() +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, vjust = 0.5, hjust = 1, size = 7))
}

#' Chart: peak signal per boring as a lollipop
#'
#' Borings sorted by peak value, one dot and stem each: the quickest read of
#' which borings dominate the site.
#'
#' @inheritParams summarize_lif
#' @return A ggplot object.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' chart_peak_by_boring(lif)
#' @export
chart_peak_by_boring <- function(data, channel = "signal") {
  channel <- tolower(channel)
  .check_required_cols(data, c("boring", channel), source = "data")
  pk <- vapply(split(data[[channel]], data$boring), function(v) {
    m <- suppressWarnings(max(v, na.rm = TRUE)); if (is.finite(m)) m else NA_real_
  }, numeric(1))
  d <- data.frame(boring = names(pk), peak = unname(pk), stringsAsFactors = FALSE)
  d <- d[order(-d$peak, d$boring), , drop = FALSE]
  d$boring <- factor(d$boring, levels = rev(d$boring))
  unit <- .channel_units(channel)
  ggplot2::ggplot(d, ggplot2::aes(x = .data$peak, y = .data$boring)) +
    ggplot2::geom_segment(ggplot2::aes(x = 0, xend = .data$peak, yend = .data$boring),
                          colour = "grey75", linewidth = 0.4, na.rm = TRUE) +
    ggplot2::geom_point(colour = .LIFR_BLUE, size = 1.8, na.rm = TRUE) +
    ggplot2::labs(x = if (is.na(unit)) paste("Peak", channel)
                      else sprintf("Peak %s (%s)", channel, unit),
                  y = NULL, title = sprintf("Peak %s by boring", channel)) +
    theme_lifr()
}

#' Chart: distribution of hydraulic push pressure
#'
#' Pooled `hp` across all borings with the median marked. Readings above
#' ground surface (negative depth) are dropped.
#'
#' @param data A [lif_data] frame with an `hp` column.
#' @return A ggplot, or `NULL` with fewer than 10 readings.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' chart_hp_histogram(lif)
#' @export
chart_hp_histogram <- function(data) {
  if (!"hp" %in% names(data)) return(NULL)
  d <- data[is.finite(data$hp), , drop = FALSE]
  if ("depth" %in% names(d)) d <- d[!is.na(d$depth) & d$depth >= 0, , drop = FALSE]
  if (nrow(d) < 10) return(NULL)
  med <- stats::median(d$hp)
  ggplot2::ggplot(d, ggplot2::aes(x = .data$hp)) +
    ggplot2::geom_histogram(bins = 40, fill = .LIFR_FILL, colour = "white", linewidth = 0.15) +
    ggplot2::geom_vline(xintercept = med, colour = .LIFR_INK, linetype = "dashed", linewidth = 0.4) +
    ggplot2::annotate("text", x = med, y = Inf, label = sprintf(" median %.1f", med),
                      hjust = 0, vjust = 1.6, size = 2.6, colour = .LIFR_INK) +
    ggplot2::labs(title = sprintf("Distribution of HP pressure readings (n = %s, all borings)",
                                  format(nrow(d), big.mark = ",")),
                  x = "HP pressure (psi)", y = "Readings") +
    theme_lifr()
}

#' Chart: distribution of electrical conductivity
#'
#' Pooled `ec` across all borings. Exact-zero readings are treated as not
#' recorded rather than as 0 mS/m and are excluded with their count in the
#' caption; the axis is bounded at a round value at or above the 99th
#' percentile so a few conductive spikes cannot bury the bulk of the
#' distribution, and readings beyond it are disclosed.
#'
#' @param data A [lif_data] frame with an `ec` column.
#' @return A ggplot, or `NULL` with fewer than 10 positive readings.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' chart_ec_histogram(lif)
#' @export
chart_ec_histogram <- function(data) {
  if (!"ec" %in% names(data)) return(NULL)
  d <- data[is.finite(data$ec) & data$ec >= 0, , drop = FALSE]
  if ("depth" %in% names(d)) d <- d[!is.na(d$depth) & d$depth >= 0, , drop = FALSE]
  n_null <- sum(d$ec == 0)
  d <- d[d$ec > 0, , drop = FALSE]
  if (nrow(d) < 10) return(NULL)
  p99 <- stats::quantile(d$ec, 0.99, names = FALSE)
  step <- if (p99 > 100) 50 else if (p99 > 20) 10 else 5
  bound <- max(step, ceiling(p99 * 1.1 / step) * step)
  n_over <- sum(d$ec > bound)
  d$ec_shown <- pmin(d$ec, bound)
  notes <- c(if (n_over) sprintf("%s reading(s) above %g mS/m (to %.0f) beyond the axis",
                                 format(n_over, big.mark = ","), bound, max(d$ec)),
             if (n_null) sprintf("%s depth(s) with no EC recorded excluded",
                                 format(n_null, big.mark = ",")))
  ggplot2::ggplot(d, ggplot2::aes(x = .data$ec_shown)) +
    ggplot2::geom_histogram(bins = 40, fill = .LIFR_FILL, colour = "white", linewidth = 0.15) +
    ggplot2::coord_cartesian(xlim = c(0, bound)) +
    ggplot2::labs(title = sprintf("Distribution of recorded EC readings (n = %s)",
                                  format(nrow(d), big.mark = ",")),
                  x = "EC (mS/m)", y = "Readings",
                  caption = if (length(notes)) paste0(paste(notes, collapse = "; "), ".")) +
    theme_lifr()
}

#' Write the site summary charts as PNG files
#'
#' Writes whichever of [chart_max_response()], [chart_peak_by_boring()],
#' [chart_hp_histogram()], and [chart_ec_histogram()] the data supports as
#' `<prefix>_chart_<name>.png`.
#'
#' @param data A [lif_data] frame.
#' @param output_dir Directory to write into (created if missing).
#' @param prefix Filename prefix. Default `"site"`.
#' @param thresholds Passed to [chart_max_response()].
#' @param width,height,dpi `ggsave()` geometry.
#' @param quiet Suppress the per-file message.
#' @return Character vector of written paths, invisibly.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' out <- tempfile("charts")
#' export_site_charts(lif, out, quiet = TRUE)
#' list.files(out)
#' @export
export_site_charts <- function(data, output_dir = ".", prefix = "site",
                               thresholds = c(1, 5), width = 7, height = 3.4,
                               dpi = 150, quiet = FALSE) {
  specs <- list(
    max_response   = function() chart_max_response(data, thresholds),
    peak_by_boring = function() chart_peak_by_boring(data),
    hp_histogram   = function() chart_hp_histogram(data),
    ec_histogram   = function() chart_ec_histogram(data))
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  out <- character(0)
  for (nm in names(specs)) {
    p <- tryCatch(specs[[nm]](), error = function(e) NULL)
    if (is.null(p)) next
    f <- file.path(output_dir, paste0(prefix, "_chart_", nm, ".png"))
    ok <- tryCatch({
      suppressMessages(ggplot2::ggsave(f, p, width = width, height = height, dpi = dpi))
      TRUE
    }, error = function(e) FALSE)
    if (ok) { out <- c(out, f); if (!quiet) message("Wrote: ", f) }
  }
  invisible(out)
}
