# Site summary charts embedded in the report and exportable as PNGs.

#' Chart: maximum LIF response by boring
#'
#' One bar per boring at its peak %RE. Each bar has one of three kinds, and
#' the caption names only the ones actually drawn:
#'
#' * **filled with the emission colour** recorded at the peak depth -- the
#'   product signature -- when the frame carries a valid colour for that
#'   boring;
#' * **hollow** (no fill, ink outline) when the peak is above the screening
#'   floor but the delivery carried no usable colour. A coloured fallback
#'   would read as a real signature, so the bar carries none, following the
#'   non-detect marker convention;
#' * **grey** when the peak is below the lowest threshold: at that level the
#'   peak is background, so a product colour would imply a signature that is
#'   not there.
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
  pk <- .boring_peaks(data, warn = FALSE)
  pk <- pk[pk$sampled, , drop = FALSE]
  if (!nrow(pk)) return(NULL)
  floor_re <- if (length(thresholds)) min(thresholds) else 0
  # Three bar kinds (#33). The caption used to claim "bar colour = emission
  # colour at peak-signal depth" over every chart, and filled the
  # colour-less bars .LIFR_FILL -- a muted olive, a plausible fluorescence
  # hue -- so a delivery that carried no colour channel at all shipped a
  # false caption over bars that read as real signatures.
  pk$kind <- ifelse(pk$peak_signal < floor_re, "grey",
                    ifelse(is.na(pk$peak_color), "hollow", "hex"))
  pk$fill <- ifelse(pk$kind == "grey", .LIFR_GREY,
                    ifelse(pk$kind == "hollow", NA_character_, pk$peak_color))
  pk$outline   <- ifelse(pk$kind == "hollow", .LIFR_INK, "#00000022")
  pk$linewidth <- ifelse(pk$kind == "hollow", 0.4, 0.15)
  pk <- pk[order(pk$boring), , drop = FALSE]
  pk$boring <- factor(pk$boring, levels = pk$boring)

  n_all <- nrow(pk)
  n_hex <- sum(pk$kind == "hex"); n_hollow <- sum(pk$kind == "hollow")
  # One clause per line: the joined form overran the 7 in report PNG.
  cap <- c(
    if (n_hex) "Bar colour = emission colour at peak-signal depth.",
    if (n_hollow) sprintf(
      "Hollow = no emission colour recorded (%d of %d boring%s).",
      n_hollow, n_all, if (n_all == 1L) "" else "s"),
    # always: this is the screening rule, not a description of a bar
    sprintf("Grey = peak below the %s %%RE screening floor.", format(floor_re)),
    .wrap_note(.RE_PROXY_NOTE, 100))

  ggplot2::ggplot(pk, ggplot2::aes(x = .data$boring, y = .data$peak_signal)) +
    ggplot2::geom_col(ggplot2::aes(fill = .data$fill, colour = .data$outline,
                                   linewidth = .data$linewidth), width = 0.72) +
    # na.value = NA keeps a hollow bar unfilled; the default would paint it
    # grey50, too close to the below-floor grey.
    ggplot2::scale_fill_identity(na.value = NA) +
    ggplot2::scale_colour_identity() +
    ggplot2::scale_linewidth_identity() +
    ggplot2::labs(title = "Maximum LIF response by boring", x = NULL,
                  y = "Peak response (%RE)",
                  caption = paste(cap, collapse = "\n")) +
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
#' caption; the axis is bounded at a round value just above the 99th
#' percentile (capped at five times the median) so a few conductive spikes
#' cannot bury the bulk of the distribution. Readings beyond the bound are
#' left out of the histogram and their count and maximum are stated in the
#' caption.
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
  # Axis bound: a round value just above the 99th percentile, capped at a
  # multiple of the median so a site where more than 1 % of readings are
  # conductive spikes still shows the bulk of the distribution.
  p99 <- stats::quantile(d$ec, 0.99, names = FALSE)
  cap <- min(p99, 5 * stats::median(d$ec)) * 1.1
  step <- if (cap > 100) 50 else if (cap > 20) 10 else 5
  bound <- max(step, ceiling(cap / step) * step)
  ec_max <- max(d$ec)
  n_over <- sum(d$ec > bound)
  # Readings beyond the bound are disclosed in the caption, not drawn: a
  # clamped bar at the bound would read as a real spike there (#17).
  d <- d[d$ec <= bound, , drop = FALSE]
  notes <- c(if (n_over) sprintf("%s reading(s) above %g mS/m (to %.0f) not drawn",
                                 format(n_over, big.mark = ","), bound, ec_max),
             if (n_null) sprintf("%s depth(s) with no EC recorded excluded",
                                 format(n_null, big.mark = ",")))
  ggplot2::ggplot(d, ggplot2::aes(x = .data$ec)) +
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
#' @return Character vector of written paths, invisibly, carrying a
#'   `"failed"` attribute: a data frame of `chart`, `stage` (`"build"` or
#'   `"save"`) and `error` for every chart that could not be produced, or
#'   `NULL` when all of them were. [process_site()] logs it.
#' @section Failures are reported, not skipped:
#' A builder returns `NULL` when the site has no data for that chart (no
#' `hp` channel, say), and that is a silent, expected skip. An **error**
#' inside a builder, or a `ggsave()` that cannot write the file, is
#' different: each raises a warning naming the chart and is recorded in the
#' `"failed"` attribute, and the remaining charts still render. Previously
#' both paths returned `NULL` and a thrown builder was indistinguishable
#' from an absent channel, so the report embedded the previous run's PNG and
#' the step log called the survivors the complete set. A stale file left at
#' the path of a chart that failed is deleted, so nothing downstream reads
#' it as current.
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
  failed <- list()
  # ggsave's cli errors are multi-line; flatten so one failure is one line in
  # the warning and in the step log.
  flat <- function(e) gsub("\\s+", " ", paste(conditionMessage(e), collapse = " "))
  fail <- function(nm, stage, f, e) {
    failed[[length(failed) + 1L]] <<- data.frame(
      chart = nm, stage = stage, error = flat(e), stringsAsFactors = FALSE)
    # Never leave last run's PNG where this run's chart belongs (#34).
    if (!is.null(f) && file.exists(f)) unlink(f)
    warning(sprintf("export_site_charts: chart '%s' failed to %s and was skipped: %s",
                    nm, stage, flat(e)), call. = FALSE)
  }
  for (nm in names(specs)) {
    f <- file.path(output_dir, paste0(prefix, "_chart_", nm, ".png"))
    # NULL is the documented "the site has no data for this chart" return and
    # is a silent skip; an error is a failure and is reported (#34).
    p <- tryCatch(specs[[nm]](), error = function(e) { fail(nm, "build", f, e); NULL })
    if (is.null(p)) next
    ok <- tryCatch({
      suppressMessages(ggplot2::ggsave(f, p, width = width, height = height, dpi = dpi))
      TRUE
    }, error = function(e) { fail(nm, "save", f, e); FALSE })
    if (ok) { out <- c(out, f); if (!quiet) message("Wrote: ", f) }
  }
  if (length(failed)) attr(out, "failed") <- do.call(rbind, failed)
  invisible(out)
}
