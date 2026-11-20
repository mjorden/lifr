# Depth-profile plots, the input-vs-edited QC comparison, and plan-view maps.
#
# Depth profiles put depth on the x aesthetic, flip the coordinates, and
# reverse the axis so depth reads top-to-bottom like a log.

# geom_area() that breaks at NA, as geom_line() does (daktools #796).
#
# Since ggplot2 3.4 geom_area() defaults to stat_align, which drops NA rows
# and then runs the polygon straight across the gap, so an interval deleted
# with `value = NA` was painted as signal while the line over it broke.
# Verified on ggplot2 4.0.3: the default draws one 10-vertex polygon
# spanning the whole range; stat = "identity" draws two, leaving the gap
# empty. `na.rm = TRUE` is still passed by the callers -- with
# stat = "identity" it changes no geometry (GeomRibbon splits on the NA
# either way) and only suppresses the "Removed n rows" warning, which would
# otherwise fire once per panel in a report. With no NA the look is
# unchanged.
#
# position = "identity" goes with it. geom_area() stacks by default, which
# is a no-op for the single series every lifr area layer draws -- but once
# the NA rows survive the stat, PositionStack's cumulative sum poisons them
# and hands the geom x = NA, y = 0 instead of a gap, which drew a spurious
# polygon pinned to the axis. Stacking has nothing to add here, so it goes.
.geom_area_gaps <- function(...)
  ggplot2::geom_area(..., stat = "identity", position = "identity")

# Value-axis floor for the non-LIF depth panels (daktools #661).
#
# coord_flip(ylim = ) zooms rather than drops: every row stays in the layer
# data and ggplot emits no "Removed n rows" warning, so a reading below the
# floor is drawn on or under the panel edge and reads as zero. That matters
# here because negative `hp` is the DOCUMENTED default output of
# hp_correction(): with `water_table = 0` it subtracts the full hydrostatic
# column from the ground surface, which over-corrects the unsaturated zone
# (the function says so in a message). A 0 floor turned that into a flat
# trace pinned to the axis, which reads as "very permeable" rather than
# "correction artifact".
#
# `.lif_panel()` keeps its own 0 floor on purpose: negative %RE is not a
# quantity, and the colour strip already occupies the space below zero.
#
# Returns list(ymin, n_below, caption). `ymin = NULL` auto-floors at
# min(0, 1.05 * min(values)): never above 0, and it follows the single
# lowest reading -- a spike is a reading the chart must not hide, and a bad
# sample is the editors' job (they record provenance), not a plot bound.
# The condition is classed so a caller drawing several panels can muffle the
# per-panel ones and re-emit one total.
.y_floor <- function(values, ymin, ymax, what, hint = TRUE) {
  if (!is.null(ymin) &&
      !(is.numeric(ymin) && length(ymin) == 1L && is.finite(ymin)))
    stop(sprintf("%s: `ymin` must be NULL or a single finite number; got %s",
                 what, deparse(ymin)[1]), call. = FALSE)
  v <- values[is.finite(values)]
  floor <- if (is.null(ymin)) {
    if (length(v)) min(0, 1.05 * min(v)) else 0
  } else ymin
  if (is.numeric(ymax) && length(ymax) == 1L && is.finite(ymax) && floor >= ymax)
    stop(sprintf("%s: the value-axis floor (%s) must be below its ceiling (%s)",
                 what, format(floor, digits = 3, trim = TRUE),
                 format(ymax, digits = 3, trim = TRUE)), call. = FALSE)
  n <- sum(v < floor)
  caption <- NULL
  if (n > 0L) {
    rdg <- if (n == 1L) "reading" else "readings"
    caption <- sprintf("%d %s below %s", n, rdg,
                       format(floor, digits = 3, trim = TRUE))
    rlang::inform(
      sprintf("%s: %d %s below the axis floor (%s); %s", what, n, rdg,
              format(floor, digits = 3, trim = TRUE),
              if (isTRUE(hint)) "pass ymin = NULL to show them"
              else "pass ymin = NULL to the plotting call to show them"),
      class = "lifr_below_floor", n_below = n, y_floor = floor)
  }
  list(ymin = floor, n_below = n, caption = caption)
}

# The zero reference a panel gains once its floor goes negative: a line at
# value 0 after the flip, so the reader can see where 0 sits. A floor at or
# above 0 adds nothing (daktools #661).
.zero_ref <- function(floor)
  if (floor < 0) ggplot2::geom_hline(yintercept = 0, colour = .LIFR_INK,
                                     linewidth = 0.3) else NULL

# One boring's LIF panel: filled signal trace, optional emission-colour
# bars and a colour strip left of zero.
.lif_panel <- function(d, borename, xmax, ymax, show_y_axis = TRUE, title = NULL) {
  d <- d[order(d$depth), , drop = FALSE]
  if (is.null(ymax)) ymax <- .axis_cap(d$signal, 200)
  has_color <- "color" %in% names(d) && any(!is.na(d$color))
  if (has_color) d$color <- .norm_hex(d$color)
  d$depth_step <- if (nrow(d) >= 2L) c(diff(d$depth), utils::tail(diff(d$depth), 1))
                  else rep(1, nrow(d))
  y_min <- if (has_color) -ymax * 0.12 else 0
  strip_lo <- y_min * 0.85; strip_hi <- y_min * 0.25

  p <- ggplot2::ggplot()
  if (has_color) {
    dc <- d[!is.na(d$color), , drop = FALSE]
    p <- p +
      ggplot2::geom_rect(data = d,
                         ggplot2::aes(xmin = .data$depth - .data$depth_step / 2,
                                      xmax = .data$depth + .data$depth_step / 2,
                                      ymin = 0, ymax = .data$signal,
                                      fill = ifelse(is.na(.data$color), .LIFR_AREA,
                                                    .data$color))) +
      ggplot2::scale_fill_identity() +
      ggplot2::geom_segment(data = dc,
                            ggplot2::aes(x = .data$depth, xend = .data$depth,
                                         colour = .data$color),
                            y = strip_lo, yend = strip_hi, linewidth = 3) +
      ggplot2::scale_colour_identity()
  } else {
    p <- p + .geom_area_gaps(data = d,
                             ggplot2::aes(x = .data$depth, y = .data$signal),
                             fill = .LIFR_AREA, alpha = 0.8, na.rm = TRUE)
  }
  p <- p +
    ggplot2::geom_line(data = d, ggplot2::aes(x = .data$depth, y = .data$signal),
                       colour = "black", linewidth = 0.6) +
    ggplot2::coord_flip(xlim = c(0, xmax), ylim = c(y_min, ymax)) +
    ggplot2::scale_x_reverse(expand = c(0, 0)) +
    ggplot2::scale_y_continuous(expand = c(0, 0)) +
    ggplot2::labs(title = title %||% paste(borename, "LIF response"),
                  x = "Depth (ft)", y = "LIF signal (%RE)") +
    theme_lifr()
  if (!show_y_axis)
    p <- p + ggplot2::theme(axis.title.y = ggplot2::element_blank(),
                            axis.text.y  = ggplot2::element_blank())
  p
}

# A generic single-channel panel (EC, HP) sharing the LIF panel's geometry.
# `ymin` floors the value axis and discloses what falls below it; see
# .y_floor() for why a silent 0 floor is a bug here and not on the LIF panel.
.channel_panel <- function(d, channel, label, xmax, colour = "steelblue",
                           fill = NULL, show_y_axis = TRUE, ymax = NULL,
                           title = NULL, ymin = 0, what = "panel",
                           hint = FALSE) {
  d <- d[order(d$depth), , drop = FALSE]
  if (is.null(ymax)) ymax <- .axis_cap(d[[channel]], 1)
  fl <- .y_floor(d[[channel]], ymin, ymax, what, hint)
  p <- ggplot2::ggplot(d, ggplot2::aes(x = .data$depth, y = .data[[channel]]))
  if (!is.null(fill))
    p <- p + .geom_area_gaps(fill = fill, alpha = 0.6, na.rm = TRUE)
  p <- p +
    ggplot2::geom_line(colour = colour, linewidth = 0.6, na.rm = TRUE) +
    .zero_ref(fl$ymin) +
    ggplot2::coord_flip(xlim = c(0, xmax), ylim = c(fl$ymin, ymax)) +
    ggplot2::scale_x_reverse(expand = c(0, 0)) +
    ggplot2::scale_y_continuous(expand = c(0, 0)) +
    ggplot2::labs(title = title %||% label, x = "Depth (ft)", y = label) +
    theme_lifr()
  if (!is.null(fl$caption)) p <- p + ggplot2::labs(caption = fl$caption)
  if (!show_y_axis)
    p <- p + ggplot2::theme(axis.title.y = ggplot2::element_blank(),
                            axis.text.y  = ggplot2::element_blank())
  p
}

#' Plot the LIF depth profile of one boring
#'
#' Signal against depth, filled with the instrument's emission colour at
#' each depth when a `color` channel is present (with a colour strip left of
#' zero), or a single fill otherwise.
#'
#' @param data A [lif_data] frame.
#' @param borename Boring to plot.
#' @param xmax Maximum depth shown (ft). Default: the deepest reading in
#'   `data`, so every boring shares one depth axis.
#' @param ymax Signal axis cap. `NULL` (default) auto-scales to 5% above the
#'   boring's maximum.
#' @return A ggplot object.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' lif_plot(lif, "LIF-05")
#' lif_plot(lif, "LIF-05", ymax = 100)
#' @export
lif_plot <- function(data, borename, xmax = NULL, ymax = NULL) {
  .check_data_arg(data, "lif_plot")
  .check_required_cols(data, c("boring", "depth", "signal"), source = "data")
  .check_borename(data, borename)
  d <- data[data$boring == borename, , drop = FALSE]
  if (nrow(d) == 0L || all(is.na(d$signal)))
    message(sprintf("lif_plot('%s'): no signal readings -- plot will be empty.",
                    borename))
  xmax <- xmax %||% suppressWarnings(max(data$depth, na.rm = TRUE))
  if (!is.finite(xmax) || xmax <= 0) xmax <- 1
  .lif_panel(d, borename, xmax, ymax)
}

#' Plot LIF depth profiles for every boring
#'
#' Both layouts draw the per-reading emission-colour fill and the colour
#' strip left of zero when the frame carries a `color` channel, so a
#' small-multiples sheet shows which borings share a fluorescence signature.
#' Colour is decided per boring: a boring with a colour at any depth gets the
#' colour layers, the rest get the flat fill. All panels share one signal
#' axis, so a colour-less panel on a mixed sheet shows an empty strip band.
#'
#' @inheritParams lif_plot
#' @param ymax Signal axis cap shared by all borings. `NULL` uses 5% above
#'   the site maximum so panels are comparable.
#' @param layout `"facet"` (default) returns one ggplot with a small
#'   multiple per boring; `"list"` returns a named list of single-boring
#'   plots from [lif_plot()].
#' @param ncol Facet columns for `layout = "facet"`; `NULL` lets ggplot2
#'   choose.
#' @param output_file Optional PNG path for the facet plot.
#' @param width,height,dpi Passed to `ggplot2::ggsave()` when saving.
#' @return A ggplot (facet) or a named list of ggplots (list), invisibly
#'   when saved.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' lif_plot_all(lif, ncol = 4)
#' @export
lif_plot_all <- function(data, xmax = NULL, ymax = NULL,
                         layout = c("facet", "list"), ncol = NULL,
                         output_file = NULL, width = 12, height = 8, dpi = 200) {
  layout <- match.arg(layout)
  .check_data_arg(data, "lif_plot_all")
  .check_required_cols(data, c("boring", "depth", "signal"), source = "data")
  xmax <- xmax %||% suppressWarnings(max(data$depth, na.rm = TRUE))
  if (!is.finite(xmax) || xmax <= 0) xmax <- 1
  ymax <- ymax %||% .axis_cap(data$signal, 200)
  if (layout == "list") {
    borings <- sort(unique(data$boring))
    return(stats::setNames(lapply(borings, function(b)
      lif_plot(data, b, xmax = xmax, ymax = ymax)), borings))
  }
  d <- data[order(data$boring, data$depth), , drop = FALSE]
  if (nrow(d) == 0L) {
    message("lif_plot_all: no rows -- empty plot returned.")
    return(ggplot2::ggplot())
  }
  # The sheet draws the same per-reading emission-colour fill and colour
  # strip as the single-boring panel (daktools #666). It used to ignore `color`
  # entirely -- every panel was the flat area -- so the comparison a
  # small-multiples sheet exists for, which borings share a fluorescence
  # signature, was the one thing it could not show, while layout = "list"
  # showed it. Colour is decided per boring, as the list layout decides it
  # by calling .lif_panel() once per boring: borings with a colour at any
  # depth get the colour layers, the rest get the flat area, on one sheet
  # with one signal-axis floor (so a colour-less panel on a mixed sheet
  # shows the empty strip band -- the price of a shared axis). A frame with
  # no colour at all renders exactly as before.
  has_color <- "color" %in% names(d) && any(!is.na(d$color))
  y_min <- if (has_color) -ymax * 0.12 else 0
  p <- ggplot2::ggplot(d, ggplot2::aes(x = .data$depth, y = .data$signal))
  if (has_color) {
    d$color <- .norm_hex(d$color)
    # Each reading's rect spans its own boring's sample interval, so a
    # boring logged at a different step is not drawn at its neighbour's.
    d$depth_step <- NA_real_
    for (ii in split(seq_len(nrow(d)), d$boring)) {
      dep <- d$depth[ii]
      d$depth_step[ii] <- if (length(dep) >= 2L)
        c(diff(dep), utils::tail(diff(dep), 1)) else 1
    }
    coloured <- names(which(vapply(split(!is.na(d$color), d$boring), any, logical(1))))
    d_col  <- d[d$boring %in% coloured, , drop = FALSE]
    d_flat <- d[!d$boring %in% coloured, , drop = FALSE]
    strip_lo <- y_min * 0.85; strip_hi <- y_min * 0.25
    p <- p +
      ggplot2::geom_rect(data = d_col,
                         ggplot2::aes(xmin = .data$depth - .data$depth_step / 2,
                                      xmax = .data$depth + .data$depth_step / 2,
                                      ymin = 0, ymax = .data$signal,
                                      fill = ifelse(is.na(.data$color), .LIFR_AREA,
                                                    .data$color))) +
      ggplot2::scale_fill_identity() +
      ggplot2::geom_segment(data = d_col[!is.na(d_col$color), , drop = FALSE],
                            ggplot2::aes(x = .data$depth, xend = .data$depth,
                                         colour = .data$color),
                            y = strip_lo, yend = strip_hi, linewidth = 1.2) +
      ggplot2::scale_colour_identity()
    if (nrow(d_flat))
      p <- p + .geom_area_gaps(data = d_flat, fill = .LIFR_AREA, alpha = 0.7,
                               na.rm = TRUE)
  } else {
    p <- p + .geom_area_gaps(fill = .LIFR_AREA, alpha = 0.7, na.rm = TRUE)
  }
  p <- p +
    ggplot2::geom_line(colour = "black", linewidth = 0.4, na.rm = TRUE) +
    ggplot2::coord_flip(xlim = c(0, xmax), ylim = c(y_min, ymax)) +
    ggplot2::scale_x_reverse(expand = c(0, 0)) +
    ggplot2::scale_y_continuous(expand = c(0, 0)) +
    ggplot2::facet_wrap(ggplot2::vars(.data$boring), ncol = ncol) +
    ggplot2::labs(x = "Depth (ft)", y = "LIF signal (%RE)",
                  title = "LIF response by boring",
                  caption = .wrap_note(.RE_PROXY_NOTE, 120)) +
    theme_lifr() +
    ggplot2::theme(strip.background = ggplot2::element_rect(fill = "#f3f1ec", colour = NA),
                   strip.text = ggplot2::element_text(size = 8, colour = "#333333"))
  if (!is.null(output_file)) {
    dir.create(dirname(output_file), showWarnings = FALSE, recursive = TRUE)
    ggplot2::ggsave(output_file, p, width = width, height = height, dpi = dpi)
    message("Written: ", output_file)
    return(invisible(p))
  }
  p
}

#' Multi-channel overview of one boring
#'
#' LIF signal beside whichever of `ec` and `hp` the boring recorded, on a
#' shared depth axis.
#'
#' @inheritParams lif_plot
#' @param channels Channels to draw after the LIF panel, in order. Default
#'   `c("ec", "hp")`; channels absent or all-`NA` for the boring are
#'   skipped.
#' @param depth_max Shared depth limit (ft). Default: the boring's deepest
#'   reading.
#' @param ymin Value-axis floor for the `channels` panels (the LIF panel
#'   keeps its own 0 floor: negative %RE is not a quantity). Default `0`,
#'   so no existing figure changes shape. Readings below the floor are left
#'   out of view by the coordinate limits, not dropped, so nothing warns on
#'   its own; when any are, a message of class `"lifr_below_floor"` and a
#'   panel caption say how many. `NULL` floors at
#'   `min(0, 1.05 * min(value))` and marks 0 with a thin line, which is how
#'   to see the negative `hp` that [hp_correction()] produces by default
#'   through the unsaturated zone.
#' @return A patchwork object (prints like a ggplot).
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' lif_overview(lif, "LIF-05")
#' @export
lif_overview <- function(data, borename, channels = c("ec", "hp"),
                         depth_max = NULL, ymax = NULL, ymin = 0) {
  .check_data_arg(data, "lif_overview")
  .check_required_cols(data, c("boring", "depth", "signal"), source = "data")
  .check_borename(data, borename)
  d <- data[data$boring == borename, , drop = FALSE]
  depth_max <- depth_max %||% suppressWarnings(max(d$depth, na.rm = TRUE))
  if (!is.finite(depth_max) || depth_max <= 0) depth_max <- 1
  panels <- list(lif = .lif_panel(d, borename, depth_max, ymax, title = "LIF (%RE)"))
  meta <- list(ec = list(label = "EC (mS/m)", colour = "darkgreen", fill = "#8fbc8f"),
               hp = list(label = "HP (psi)",  colour = "steelblue", fill = NULL))
  for (ch in tolower(channels)) {
    if (!ch %in% names(d) || all(is.na(d[[ch]]))) next
    m <- meta[[ch]] %||% list(label = ch, colour = "grey40", fill = NULL)
    # Each panel resolves its own floor from its own channel: EC and HP do
    # not share units, so one shared floor would be meaningless. The
    # condition names the channel so a two-panel disclosure is readable.
    panels[[ch]] <- .channel_panel(d, ch, m$label, depth_max, colour = m$colour,
                                   fill = m$fill, show_y_axis = FALSE,
                                   ymin = ymin,
                                   what = sprintf("lif_overview('%s', %s)",
                                                  borename, ch),
                                   hint = TRUE)
  }
  patchwork::wrap_plots(panels, nrow = 1) +
    patchwork::plot_annotation(title = paste("Boring", borename, "overview"),
                               theme = theme_lifr())
}

#' Side-by-side comparison of input and edited profiles
#'
#' For every boring whose `signal` differs between `raw` and `edited`,
#' builds a two-panel plot (input | edited) with changed depths marked in
#' red. Unchanged borings are skipped and counted in a message.
#'
#' A reading set to `NA` (what `lif_editor(value = NA)` writes), an `NA`
#' filled in, and a depth present in only one of the two frames all count as
#' edits; `NA` on both sides counts as unchanged. A depth with no reading
#' left in `edited` has no value to put a dot on, so it is marked with a red
#' cross just above the panel floor, where the fill and line break
#' (daktools #795).
#'
#' @param raw The frame before editing.
#' @param edited The frame after editing. Rows are matched on `boring` and
#'   `depth`.
#' @param channel Column to compare. Default `"signal"`.
#' @param output_dir Optional directory; when supplied one PNG per changed
#'   boring is written there.
#' @param ymin Value-axis floor, default `0`, or `NULL` to floor at
#'   `min(0, 1.05 * min(value))` and mark 0 with a thin line. Readings below
#'   the floor are left out of view, not dropped; when any are, a message of
#'   class `"lifr_below_floor"` and a caption say how many. This is a QC view
#'   of what an edit changed, so the floor applies to every channel,
#'   `signal` included -- unlike the LIF log panels, which keep a 0 floor
#'   (daktools #661).
#' @return A named list of ggplots (one per changed boring), invisibly.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' raw <- lif_import(demo, verbose = FALSE)
#' ed  <- lif_editor_bulk(raw, top = 0, bottom = 3, verbose = FALSE)
#' plots <- qc_compare(raw, ed)
#' plots[[1]]
#' @export
qc_compare <- function(raw, edited, channel = "signal", output_dir = NULL,
                       ymin = 0) {
  .check_data_arg(raw, "qc_compare"); .check_data_arg(edited, "qc_compare")
  channel <- tolower(channel)
  .check_required_cols(raw, c("boring", "depth", channel), source = "raw")
  .check_required_cols(edited, c("boring", "depth", channel), source = "edited")
  if (!is.null(output_dir)) dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  only_raw <- setdiff(unique(raw$boring), unique(edited$boring))
  only_ed  <- setdiff(unique(edited$boring), unique(raw$boring))
  if (length(only_raw))
    warning("qc_compare: boring(s) in 'raw' but not 'edited' (skipped): ",
            paste(sort(only_raw), collapse = ", "), call. = FALSE)
  if (length(only_ed))
    warning("qc_compare: boring(s) in 'edited' but not 'raw' (skipped): ",
            paste(sort(only_ed), collapse = ", "), call. = FALSE)
  borings <- sort(intersect(unique(raw$boring), unique(edited$boring)))
  plots <- list(); n_skip <- 0L
  for (b in borings) {
    rb <- raw[raw$boring == b, , drop = FALSE]
    eb <- edited[edited$boring == b, , drop = FALSE]
    # Readings that share a depth are paired by their order within that
    # depth; merging on depth alone made a cartesian product and reported
    # identical frames as changed (#14).
    rb <- rb[order(rb$depth), , drop = FALSE]; eb <- eb[order(eb$depth), , drop = FALSE]
    rb$.k <- stats::ave(seq_len(nrow(rb)), rb$depth, FUN = seq_along)
    eb$.k <- stats::ave(seq_len(nrow(eb)), eb$depth, FUN = seq_along)
    # Outer merge (daktools #795): the inner merge dropped a depth present on
    # one side only -- what lif_downsample() leaves behind -- so a reading
    # that disappeared from `edited` entirely was not reported as a change.
    rs <- rb[, c("depth", ".k", channel)]; rs$.in_raw <- TRUE
    es <- eb[, c("depth", ".k", channel)]; es$.in_ed  <- TRUE
    m <- merge(rs, es, by = c("depth", ".k"), suffixes = c("_raw", "_ed"),
               all = TRUE)
    vr <- m[[paste0(channel, "_raw")]]; ve <- m[[paste0(channel, "_ed")]]
    one_sided <- is.na(m$.in_raw) != is.na(m$.in_ed)
    is_changed <- one_sided | !.same_value(vr, ve)
    changed <- m$depth[is_changed]
    # Changed depths with no reading left to plot: set to NA, or gone from
    # `edited`. geom_point() drops them, so they get a cross at the floor.
    gone <- unique(m$depth[is_changed & is.na(ve)])
    if (!length(changed)) { n_skip <- n_skip + 1L; next }
    rb$.source <- "Input"; eb$.source <- "Edited"
    rb$.changed <- FALSE;  eb$.changed <- eb$depth %in% changed
    keep <- c("depth", channel, ".source", ".changed")
    comb <- rbind(rb[, keep], eb[, keep])
    comb$.source <- factor(comb$.source, levels = c("Input", "Edited"))
    dmax <- max(comb$depth, na.rm = TRUE)
    ymax <- .axis_cap(comb[[channel]], 1)
    fl <- .y_floor(comb[[channel]], ymin, ymax, sprintf("qc_compare('%s')", b))
    gone_pts <- data.frame(depth = gone)
    gone_pts[[channel]] <- rep(fl$ymin + 0.02 * (ymax - fl$ymin), nrow(gone_pts))
    gone_pts$.source <- factor(rep("Edited", nrow(gone_pts)),
                               levels = c("Input", "Edited"))
    p <- ggplot2::ggplot(comb, ggplot2::aes(x = .data$depth, y = .data[[channel]])) +
      .geom_area_gaps(fill = .LIFR_AREA, alpha = 0.55, na.rm = TRUE) +
      ggplot2::geom_line(colour = "black", linewidth = 0.5, na.rm = TRUE) +
      ggplot2::geom_point(data = comb[comb$.changed, , drop = FALSE],
                          colour = "red", size = 1.6, na.rm = TRUE) +
      ggplot2::geom_point(data = gone_pts, colour = "red", size = 1.8,
                          shape = 4, stroke = 0.6) +
      .zero_ref(fl$ymin) +
      ggplot2::facet_wrap(~ .source, ncol = 2) +
      ggplot2::coord_flip(xlim = c(0, dmax), ylim = c(fl$ymin, ymax)) +
      ggplot2::scale_x_reverse(expand = c(0, 0)) +
      ggplot2::scale_y_continuous(expand = c(0, 0)) +
      ggplot2::labs(title = sprintf("%s -- %s (edited depths in red)", b, channel),
                    subtitle = if (nrow(gone_pts))
                      "x = reading removed or set to NA",
                    x = "Depth (ft)", y = channel) +
      theme_lifr()
    if (!is.null(fl$caption)) p <- p + ggplot2::labs(caption = fl$caption)
    plots[[b]] <- p
    if (!is.null(output_dir)) {
      f <- file.path(output_dir, paste0(b, ".png"))
      ggplot2::ggsave(f, p, width = 9, height = 5, dpi = 150)
      message("Written: ", f)
    }
  }
  message(sprintf("qc_compare: %d boring(s) with changes plotted, %d unchanged.",
                  length(plots), n_skip))
  invisible(plots)
}

# ---------------------------------------------------------------------------
# Plan-view maps
# ---------------------------------------------------------------------------

# Plan-view ranges padded to a minimum extent (#16).
.plan_extent <- function(x, y, min_extent) {
  xr <- range(x, na.rm = TRUE); yr <- range(y, na.rm = TRUE)
  if (diff(xr) < min_extent) xr <- mean(xr) + c(-0.5, 0.5) * min_extent
  if (diff(yr) < min_extent) yr <- mean(yr) + c(-0.5, 0.5) * min_extent
  list(xr = xr, yr = yr)
}

# Reference sizes for boring_map()'s size key (daktools #662): the site
# maximum and a
# quarter and a sixteenth of it, which under an area law are markers of half
# and a quarter of the maximum diameter -- so the key spans the small markers
# a reader actually has to judge, where ggplot's extended breaks (25 % of the
# maximum at best) give nothing. The maximum is kept exact (its label is
# rounded, not its size); the fractions are rounded to two significant
# figures; non-positive, duplicate and out-of-range values drop. The scale
# then censors any break below the data minimum, so a one-value site keys a
# single entry.
.size_key_breaks <- function(limits) {
  mx <- max(limits, na.rm = TRUE)
  if (!is.finite(mx) || mx <= 0) return(mx)
  b <- unique(c(mx, signif(c(mx / 4, mx / 16), 2)))
  b <- b[is.finite(b) & b > 0 & b <= mx]
  if (!length(b)) mx else sort(b)
}

# Per-boring peak summary used by boring_map() and the charts.
.boring_peaks <- function(data, depth_min = NULL, depth_max = NULL, warn = TRUE) {
  has_color <- "color" %in% names(data) && any(!is.na(data$color))
  rows <- lapply(split(data, as.character(data$boring)), function(d) {
    if (isTRUE(warn)) for (cc in c("easting", "northing"))
      if (cc %in% names(d) && length(unique(stats::na.omit(d[[cc]]))) > 1L)
        warning(sprintf("boring '%s' has inconsistent %s values; using the first.",
                        d$boring[1], cc), call. = FALSE)
    s <- d
    if (!is.null(depth_min)) s <- s[!is.na(s$depth) & s$depth >= depth_min, , drop = FALSE]
    if (!is.null(depth_max)) s <- s[!is.na(s$depth) & s$depth <= depth_max, , drop = FALSE]
    empty <- nrow(s) == 0L || all(is.na(s$signal))
    i <- if (empty) NA_integer_ else which.max(s$signal)
    data.frame(
      boring = d$boring[1],
      easting  = if ("easting" %in% names(d)) d$easting[1] else NA_real_,
      northing = if ("northing" %in% names(d)) d$northing[1] else NA_real_,
      peak_signal = if (empty) 0 else s$signal[i],
      peak_depth  = if (empty) NA_real_ else s$depth[i],
      peak_color  = if (!empty && has_color) .norm_hex(s$color[i]) else NA_character_,
      sampled = !empty,
      stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Plan-view map of boring locations sized by peak LIF signal
#'
#' Each boring is a marker at its easting/northing, labelled with its name
#' and peak %RE. Marker **area** is proportional to peak signal, with a size
#' key, so the site's response pattern reads even in greyscale; non-detects
#' are hollow circles. Marker fill is a neutral blue unless
#' `use_instrument_color = TRUE`, which fills each marker with the
#' emission colour recorded at the depth of peak signal.
#'
#' @param data A [lif_data] frame with `easting` and `northing`.
#' @param depth_min,depth_max Optional depth window (ft); only readings
#'   inside it contribute to each boring's peak.
#' @param nd_threshold Peak signal at or below this value is a non-detect.
#'   Default 0; must be `>= 0` when `size_by_signal = TRUE` (the signal is
#'   non-negative).
#' @param size_by_signal Logical. When `TRUE` (default), marker **area** is
#'   proportional to the boring's peak signal (`ggplot2::scale_size_area()`),
#'   with a size key, so magnitude reads on greyscale prints; no minimum size
#'   is applied. Below about 1 % of the site peak the drawn dot is dominated
#'   by its 0.7 outline stroke and the on-map label carries the value.
#'   Suppress the key with `ggplot2::guides(size = "none")`. Set `FALSE` for
#'   constant-size markers.
#' @param point_size Reference marker diameter. With
#'   `size_by_signal = TRUE` the maximum-signal marker is drawn at **twice**
#'   this and marker area is proportional to peak signal below it; with
#'   `FALSE` every marker is drawn at exactly this. The hollow non-detect
#'   ring is not on the size scale and is drawn no larger than the smallest
#'   detect marker (at most half `point_size`). Default 4.
#' @param use_instrument_color Fill markers with the emission colour at peak
#'   depth. Default `FALSE`.
#' @param label_size Label font size. Default 2.4.
#' @param repel Use `ggrepel` for non-overlapping labels when installed.
#' @param seed Seed for reproducible label placement.
#' @param signal_digits Significant digits in the peak label.
#' @param coord_units Unit string for the axis titles and scale bar.
#' @param title,site_name,figure_date,preparer,crs_label Text for the title,
#'   subtitle, and caption lines. `NULL` omits each.
#' @param north_arrow,scale_bar Logical. Draw the north arrow (upper corner)
#'   and scale bar (lower corner); each is placed in the corner that
#'   overlaps the fewest borings.
#' @param basemap A `lifr_basemap` from [fetch_basemap()] drawn under the
#'   markers; labels switch to white with a dark halo.
#' @param min_extent Minimum width and height of the plan window, in
#'   coordinate units. A single boring or a collinear transect is padded to
#'   this extent so the panel, north arrow, and scale bar keep sensible
#'   proportions. Default 100.
#' @param output_file Optional PNG path.
#' @param width,height,dpi Passed to `ggplot2::ggsave()`.
#' @param fill_floor Screening floor (%RE), or `NULL` (default) for none.
#'   A detect whose peak is **strictly below** this value keeps its size and
#'   its detect status -- the reading is real -- but is filled the non-detect
#'   grey instead of the emission colour or neutral blue, and a caption line
#'   names the floor. This matches [chart_max_response()], which greys a bar
#'   below its lowest screening threshold, so the two figures in one report
#'   agree about every boring (daktools #801); `<` rather than `<=` in both,
#'   so a peak exactly at the floor is coloured in both. [process_site()]
#'   passes the report's lowest `response_thresholds` value.
#' @return A ggplot object.
#' @section Reading the map:
#' * Marker **area** is proportional to peak signal, so the response pattern
#'   reads in greyscale. The size key gives the site maximum and a quarter
#'   and a sixteenth of it; a marker at 1 % of the peak really is 1 % of the
#'   peak's area, so a ring of weak detects cannot read as a broad plume.
#' * A **hollow circle** is a non-detect: no reading above `nd_threshold`
#'   in the depth window.
#' * With `fill_floor` set, a **grey filled** marker is a real detect whose
#'   peak is below the screening floor: sized like any other detect, but
#'   carrying no colour claim, as the bar chart's grey bars do.
#' * Marker **fill** is a neutral blue unless `use_instrument_color = TRUE`,
#'   which uses the emission colour recorded at the depth of peak signal.
#'   That colour is the product signature analysts read in the field; the
#'   caption says so whenever it is in use.
#' * The label under each marker is the boring name and its peak %RE.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' boring_map(lif)
#'
#' # Product-signature colours, a depth window, and figure metadata
#' boring_map(lif, depth_min = 10, depth_max = 25, use_instrument_color = TRUE,
#'            site_name = "Demo site", figure_date = "2026-09-04",
#'            preparer = "Field team", crs_label = "NAD83 / Louisiana South (ftUS)")
#'
#' # Uniform markers, no cartographic furniture
#' boring_map(lif, size_by_signal = FALSE, north_arrow = FALSE, scale_bar = FALSE)
#'
#' \dontrun{
#' # Over aerial imagery (needs sf, png, and network access)
#' bm <- fetch_basemap(lif, crs = 3452)
#' boring_map(lif, basemap = bm, output_file = "boring_map.png")
#' }
#' @seealso [depth_slice_map()], [fetch_basemap()], `vignette("plotting")`
#' @export
boring_map <- function(data, depth_min = NULL, depth_max = NULL,
                       nd_threshold = 0, size_by_signal = TRUE, point_size = 4,
                       use_instrument_color = FALSE, label_size = 2.4,
                       repel = TRUE, seed = 42, signal_digits = 3,
                       coord_units = "ft", title = NULL, site_name = NULL,
                       figure_date = NULL, preparer = NULL, crs_label = NULL,
                       north_arrow = TRUE, scale_bar = TRUE, basemap = NULL,
                       min_extent = 100, output_file = NULL, width = 8,
                       height = 7, dpi = 200, fill_floor = NULL) {
  .check_data_arg(data, "boring_map")
  .check_scalar_number(min_extent, "min_extent", "boring_map")
  .check_required_cols(data, c("boring", "easting", "northing", "depth", "signal"),
                       source = "data")
  if (!is.null(basemap) && !inherits(basemap, "lifr_basemap"))
    stop("basemap must be a lifr_basemap object from fetch_basemap(), or NULL.",
         call. = FALSE)
  # A negative threshold would admit zero or negative peaks as "detects",
  # which an area scale draws at zero size or (negative) at a positive area
  # -- and the signal is non-negative anyway (daktools #662).
  if (isTRUE(size_by_signal) && !(is.numeric(nd_threshold) && nd_threshold >= 0))
    stop("boring_map: `nd_threshold` must be a number >= 0 (the signal is ",
         "non-negative); got ", format(nd_threshold), call. = FALSE)
  # The fill floor only recolours sub-floor detects; NULL is the old look
  # (daktools #801).
  if (!is.null(fill_floor) &&
      !(is.numeric(fill_floor) && length(fill_floor) == 1L &&
        is.finite(fill_floor) && fill_floor >= 0))
    stop("boring_map: `fill_floor` must be NULL or a single finite number ",
         ">= 0; got ", format(fill_floor), call. = FALSE)
  bs <- .boring_peaks(data, depth_min, depth_max)
  bs <- bs[is.finite(bs$easting) & is.finite(bs$northing), , drop = FALSE]
  if (nrow(bs) == 0L) stop("boring_map: no boring has finite coordinates.", call. = FALSE)
  bs$is_nd <- bs$peak_signal <= nd_threshold
  showing_color <- isTRUE(use_instrument_color) && any(!is.na(bs$peak_color))
  bs$fill <- if (showing_color) ifelse(is.na(bs$peak_color), "#444444", bs$peak_color)
             else .LIFR_BLUE
  # A detect below the screening floor stays a sized detect -- the reading is
  # real -- but loses its colour, so the map agrees with the grey bars of
  # chart_max_response() beside it in the report (daktools #801). `<`, not
  # `<=`, matching the bar chart, so a peak exactly at the floor is coloured
  # in both figures.
  below_floor <- !bs$is_nd & bs$peak_signal < (fill_floor %||% -Inf)
  bs$fill[below_floor] <- .LIFR_GREY
  bs$fill[bs$is_nd] <- "#bbbbbb"
  bs$label <- ifelse(bs$is_nd, bs$boring,
                     paste0(bs$boring, "\n", .fmt_num(bs$peak_signal, signal_digits),
                            " %RE"))
  # A minimum plan extent keeps one boring or a collinear transect from
  # collapsing coord_equal() into a hairline panel (#16); the north arrow
  # and scale bar are sized from the same padded extent.
  ext <- .plan_extent(bs$easting, bs$northing, min_extent)
  # Marker size. size_by_signal = TRUE (daktools #662): marker AREA is
  # proportional to
  # peak signal -- the detect layer maps peak_signal through
  # scale_size_area(max_size = 2 * point_size), so the maximum-signal marker
  # keeps the diameter the old law drew it at and every other marker shrinks
  # to its honest area. The old formula, point_size * (0.4 + 1.6 * sqrt(r)),
  # had a 40 % diameter floor that drew a boring at 1 % of the peak at 7.8 %
  # of the peak's area (10 % at 20 %, 25 % at 36 %), with no key to read it
  # against: a ring of weak detects around a hot spot read as a broad
  # moderate plume. No minimum now -- below ~1 % of the peak the 0.7 outline
  # stroke dominates the drawn dot and the on-map label carries the value.
  # The hollow non-detect ring is off the size scale and is never larger than
  # the smallest detect, so a non-detect cannot outweigh a real detect (it
  # stays point_size * 0.5 wherever no detect is that small).
  # size_by_signal = FALSE: a constant diameter through the identity scale,
  # exactly as before.
  if (isTRUE(size_by_signal)) {
    det_peak <- bs$peak_signal[!bs$is_nd]
    det_size <- if (length(det_peak) && max(det_peak) > 0)
      2 * point_size * sqrt(det_peak / max(det_peak)) else numeric(0)
    nd_size  <- min(point_size * 0.5, det_size)
  } else bs$marker_size <- point_size

  det <- bs[!bs$is_nd, , drop = FALSE]; nds <- bs[bs$is_nd, , drop = FALSE]
  p <- ggplot2::ggplot(bs, ggplot2::aes(x = .data$easting, y = .data$northing))
  if (!is.null(basemap)) {
    xlim <- ext$xr + c(-1, 1) * diff(ext$xr) * 0.07
    ylim <- ext$yr + c(-1, 1) * diff(ext$yr) * 0.12
    bmc <- .crop_basemap(basemap, xlim, ylim)
    p <- p + ggplot2::annotation_raster(bmc$image, xmin = bmc$xmin, xmax = bmc$xmax,
                                        ymin = bmc$ymin, ymax = bmc$ymax)
  }
  if (isTRUE(size_by_signal)) {
    if (nrow(det))
      p <- p + ggplot2::geom_point(data = det,
                                   ggplot2::aes(fill = .data$fill,
                                                size = .data$peak_signal),
                                   shape = 21, colour = "#2a2a2a", stroke = 0.7) +
        ggplot2::scale_size_area(
          max_size = 2 * point_size, name = "Peak signal (%RE)",
          breaks = .size_key_breaks, labels = .fmt_num,
          # the key's fill is not on the colour scale; colour, stroke and
          # shape are inherited from the geom
          guide = ggplot2::guide_legend(override.aes = list(fill = "grey70")))
    if (nrow(nds))
      p <- p + ggplot2::geom_point(data = nds,
                                   size = nd_size,   # a constant, off the size scale
                                   shape = 1, colour = "#2a2a2a", stroke = 1)
  } else {
    if (nrow(det))
      p <- p + ggplot2::geom_point(data = det,
                                   ggplot2::aes(fill = .data$fill, size = .data$marker_size),
                                   shape = 21, colour = "#2a2a2a", stroke = 0.7)
    if (nrow(nds))
      p <- p + ggplot2::geom_point(data = nds, ggplot2::aes(size = .data$marker_size),
                                   shape = 1, colour = "#2a2a2a", stroke = 1)
    p <- p + ggplot2::scale_size_identity(guide = "none")
  }
  p <- p + ggplot2::scale_fill_identity()

  label_col <- if (is.null(basemap)) "#1a1a1a" else "#ffffff"
  seg_col   <- if (is.null(basemap)) "#999999" else "#e8e8e8"
  if (isTRUE(repel) && requireNamespace("ggrepel", quietly = TRUE)) {
    args <- list(mapping = ggplot2::aes(label = .data$label), colour = label_col,
                 size = label_size, lineheight = 0.95, box.padding = 0.5,
                 point.padding = 0.4, min.segment.length = 0.8,
                 segment.colour = seg_col, segment.size = 0.25,
                 max.overlaps = 30, seed = seed, show.legend = FALSE)
    if (!is.null(basemap)) { args$bg.color <- "#1a1a1a"; args$bg.r <- 0.12 }
    p <- p + do.call(ggrepel::geom_text_repel, args)
  } else {
    if (isTRUE(repel))
      message("boring_map: install 'ggrepel' for non-overlapping labels.")
    p <- p + ggplot2::geom_text(ggplot2::aes(label = .data$label), colour = label_col,
                                size = label_size, lineheight = 0.95, vjust = -0.75,
                                show.legend = FALSE)
  }

  auto_title <- if (!is.null(depth_min) || !is.null(depth_max))
    sprintf("Boring locations - peak LIF signal (%s-%s ft bgs)",
            depth_min %||% "0", depth_max %||% "TD")
  else "Boring locations - peak LIF signal"
  cap <- c(if (showing_color) "Marker fill = emission colour at depth of peak signal.",
           # A screening rule, so it is stated whenever a floor is in force,
           # whether or not a marker happens to be grey -- the bar chart's
           # rule, in the bar chart's wording (daktools #801).
           if (!is.null(fill_floor))
             sprintf("Grey fill = peak below the %s %%RE screening floor.",
                     format(fill_floor)),
           if (!is.null(figure_date)) paste("Date:", figure_date),
           if (!is.null(preparer)) paste("Prepared by:", preparer),
           crs_label,
           if (!is.null(basemap)) basemap$attribution,
           .wrap_note(.RE_PROXY_NOTE, 90))
  fmt_coord <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
  p <- p +
    ggplot2::coord_equal(xlim = ext$xr, ylim = ext$yr, clip = "off") +
    ggplot2::scale_x_continuous(labels = fmt_coord, expand = ggplot2::expansion(mult = 0.07)) +
    ggplot2::scale_y_continuous(labels = fmt_coord, expand = ggplot2::expansion(mult = 0.12)) +
    ggplot2::labs(x = paste0("Easting (", coord_units, ")"),
                  y = paste0("Northing (", coord_units, ")"),
                  title = title %||% auto_title, subtitle = site_name,
                  caption = paste(cap, collapse = "\n")) +
    theme_lifr() +
    ggplot2::theme(panel.border = ggplot2::element_rect(colour = "#aaaaaa", fill = NA,
                                                        linewidth = 0.7),
                   plot.title = ggplot2::element_text(face = "plain", size = 11))

  if (isTRUE(north_arrow) || isTRUE(scale_bar)) {
    xr <- ext$xr; yr <- ext$yr
    xs <- diff(xr); ys <- diff(yr)
    buf <- min(xs, ys) * 0.10
    hits <- function(b) sum(bs$easting >= b$xmin - buf & bs$easting <= b$xmax + buf &
                            bs$northing >= b$ymin - buf & bs$northing <= b$ymax + buf)
    pick <- function(boxes) boxes[[which.min(vapply(boxes, hits, integer(1)))]]
    if (isTRUE(north_arrow)) {
      arr_h <- max(ys * 0.08, 2); arr_hw <- arr_h * 0.32
      y_bot <- yr[2] + ys * 0.015; y_tip <- y_bot + arr_h
      c1 <- list(x = xr[2] - arr_hw, xmin = xr[2] - 2 * arr_hw, xmax = xr[2], ymin = y_bot, ymax = y_tip)
      c2 <- list(x = xr[1] + arr_hw, xmin = xr[1], xmax = xr[1] + 2 * arr_hw, ymin = y_bot, ymax = y_tip)
      nx <- pick(list(c1, c2))$x
      # A drawn arrow rather than a Unicode glyph: the arrow character is
      # missing from the default PDF device font.
      p <- p +
        ggplot2::annotate("segment", x = nx, xend = nx, y = y_bot, yend = y_tip,
                          colour = "#1a1a1a", linewidth = 0.6,
                          arrow = grid::arrow(length = grid::unit(0.14, "cm"),
                                              type = "closed")) +
        ggplot2::annotate("text", x = nx, y = y_tip + arr_h * 0.35, label = "N",
                          fontface = "bold", size = 3.6, colour = "#1a1a1a")
    }
    if (isTRUE(scale_bar)) {
      target <- xs * 0.2; mag <- 10^floor(log10(max(target, 1)))
      len <- round(target / mag) * mag; if (len <= 0) len <- mag
      h <- ys * 0.012; y1 <- yr[1] - ys * 0.015; y0 <- y1 - h
      c1 <- list(x0 = xr[1], xmin = xr[1], xmax = xr[1] + len, ymin = y0 - ys * 0.03, ymax = y1)
      c2 <- list(x0 = xr[2] - len, xmin = xr[2] - len, xmax = xr[2], ymin = y0 - ys * 0.03, ymax = y1)
      x0 <- pick(list(c1, c2))$x0; x1 <- x0 + len
      p <- p +
        ggplot2::annotate("segment", x = x0, xend = x1, y = y1, yend = y1,
                          colour = "#1a1a1a", linewidth = 0.5) +
        ggplot2::annotate("segment", x = c(x0, x1), xend = c(x0, x1), y = y0, yend = y1,
                          colour = "#1a1a1a", linewidth = 0.5) +
        ggplot2::annotate("text", x = c(x0, x1), y = y0 - h * 0.6,
                          label = c("0", sprintf("%s %s", format(len, big.mark = ","), coord_units)),
                          size = 2.8, colour = "#1a1a1a", vjust = 1)
    }
  }
  if (!is.null(output_file)) {
    dir.create(dirname(output_file), showWarnings = FALSE, recursive = TRUE)
    ggplot2::ggsave(output_file, p, width = width, height = height, dpi = dpi)
    message("boring_map: written to ", normalizePath(output_file, mustWork = FALSE))
  }
  p
}

#' Plan-view map of aggregated signal in a depth band
#'
#' Each boring is coloured by the aggregate (default maximum) of `signal`
#' inside `depth_range`. Borings with no usable readings in the band are
#' drawn as grey crosses and named in a message, so "not sampled here" is
#' never mistaken for "no boring here".
#'
#' @inheritParams boring_map
#' @param depth_range `c(top, bottom)` in ft.
#' @param channel Column to aggregate. Default `"signal"`.
#' @param agg_fn Aggregation function applied per boring to the non-`NA`
#'   in-band readings (it receives a plain numeric vector). Default `max`.
#' @param point_size Marker size. Default 3.
#' @param label_borings Logical. Label each boring.
#' @param show_unsampled Logical. Mark borings with no in-band readings.
#' @param title Plot title. `NULL` builds one from the channel and depth
#'   band.
#' @return A ggplot object.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' depth_slice_map(lif, depth_range = c(10, 20))
#' @export
depth_slice_map <- function(data, depth_range, channel = "signal", agg_fn = max,
                            point_size = 3, label_borings = TRUE,
                            show_unsampled = TRUE, title = NULL,
                            coord_units = "ft", seed = 42) {
  .check_data_arg(data, "depth_slice_map")
  if (!is.numeric(depth_range) || length(depth_range) != 2L || depth_range[1] >= depth_range[2])
    stop("depth_range must be c(top, bottom) with top < bottom.", call. = FALSE)
  channel <- tolower(channel)
  .check_required_cols(data, c("boring", "easting", "northing", "depth", channel),
                       source = "data")
  in_band <- !is.na(data$depth) & data$depth >= depth_range[1] & data$depth <= depth_range[2]
  slice <- data[in_band, , drop = FALSE]
  if (nrow(slice) == 0L)
    warning(sprintf("depth_slice_map: no readings between %.1f and %.1f ft.",
                    depth_range[1], depth_range[2]), call. = FALSE)
  agg <- if (nrow(slice)) do.call(rbind, lapply(split(slice, slice$boring), function(d)
    data.frame(boring = d$boring[1], easting = mean(d$easting, na.rm = TRUE),
               northing = mean(d$northing, na.rm = TRUE),
               value = suppressWarnings(agg_fn(d[[channel]][!is.na(d[[channel]])])),
               stringsAsFactors = FALSE)))
  else data.frame(boring = character(), easting = numeric(), northing = numeric(),
                  value = numeric())
  agg <- agg[is.finite(agg$value), , drop = FALSE]
  uns <- setdiff(unique(data$boring), agg$boring)
  uns_df <- if (length(uns)) do.call(rbind, lapply(split(data[data$boring %in% uns, ],
                                                         data$boring[data$boring %in% uns]),
    function(d) data.frame(boring = d$boring[1], easting = mean(d$easting, na.rm = TRUE),
                           northing = mean(d$northing, na.rm = TRUE), stringsAsFactors = FALSE)))
  else data.frame(boring = character(), easting = numeric(), northing = numeric())
  uns_df <- uns_df[is.finite(uns_df$easting) & is.finite(uns_df$northing), , drop = FALSE]
  if (nrow(slice) && length(uns))
    message(sprintf("depth_slice_map: %d boring(s) have no usable readings in %.1f-%.1f ft: %s",
                    length(uns), depth_range[1], depth_range[2],
                    paste(sort(uns), collapse = ", ")))
  unit <- .channel_units(channel)
  legend_name <- if (is.na(unit)) channel else sprintf("%s (%s)", channel, unit)
  p <- ggplot2::ggplot() +
    ggplot2::geom_point(data = agg,
                        ggplot2::aes(x = .data$easting, y = .data$northing,
                                     colour = .data$value), size = point_size) +
    ggplot2::scale_colour_viridis_c(name = legend_name)
  if (isTRUE(show_unsampled) && nrow(uns_df))
    p <- p + ggplot2::geom_point(data = uns_df,
                                 ggplot2::aes(x = .data$easting, y = .data$northing),
                                 shape = 4, colour = "grey55", size = point_size,
                                 stroke = 1.1) +
      ggplot2::labs(caption = "x = no usable readings in the depth band")
  lab <- agg[, c("boring", "easting", "northing")]
  if (isTRUE(show_unsampled)) lab <- rbind(lab, uns_df)
  if (isTRUE(label_borings) && nrow(lab)) {
    if (requireNamespace("ggrepel", quietly = TRUE))
      p <- p + ggrepel::geom_text_repel(data = lab,
        ggplot2::aes(x = .data$easting, y = .data$northing, label = .data$boring),
        size = 3, colour = "#1a1a1a", box.padding = 0.5, point.padding = 0.4,
        min.segment.length = 0.8, segment.colour = "#999999", segment.size = 0.25,
        max.overlaps = 30, seed = seed, show.legend = FALSE)
    else
      p <- p + ggplot2::geom_text(data = lab,
        ggplot2::aes(x = .data$easting, y = .data$northing, label = .data$boring),
        size = 3, vjust = -0.8, show.legend = FALSE)
  }
  p + theme_lifr() +
    ggplot2::labs(title = title %||% sprintf("%s at %.1f-%.1f ft", channel,
                                              depth_range[1], depth_range[2]),
                  x = paste0("Easting (", coord_units, ")"),
                  y = paste0("Northing (", coord_units, ")")) +
    ggplot2::coord_equal()
}
