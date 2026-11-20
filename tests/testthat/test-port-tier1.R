# Defects ported from the daktools October/November 2026 fixes (#30-#35).
# Layers are located by geom class, never by index.

geom_classes <- function(p) vapply(p$layers, function(l) class(l$geom)[1], character(1))
layer_by_geom <- function(p, cls) {
  i <- which(geom_classes(p) == cls)
  expect_length(i, 1L)
  ggplot2::layer_data(p, i)
}
pk_site <- function(peaks) {
  do.call(rbind, lapply(seq_along(peaks), function(i) data.frame(
    boring = sprintf("B%02d", i), easting = 1000 + i * 60, northing = 2000,
    depth = c(5, 10), signal = c(0, peaks[i]), stringsAsFactors = FALSE)))
}

# -- #31 boring_map() marker area is proportional to peak signal -------------

test_that("#31 marker area is proportional to peak signal, with no floor", {
  peaks <- c(400, 100, 25, 4, 0.4)
  p <- boring_map(new_lif_data(pk_site(peaks)), repel = FALSE,
                  north_arrow = FALSE, scale_bar = FALSE)
  sz <- layer_by_geom(p, "GeomPoint")$size
  # Area goes as the square of the drawn diameter, so squared size ratios
  # must equal the signal ratios -- the old 40 % diameter floor drew the
  # 0.1 %-of-peak boring at ~5 % of the peak's area.
  expect_equal((sz / max(sz))^2, peaks / max(peaks), tolerance = 1e-8)
  expect_equal(max(sz), 2 * 4)            # max_size = 2 * point_size
  expect_equal(sz[peaks == 4], 0.2 * 4)   # 1 % of peak -> 10 % of diameter
})

test_that("#31 the size key gives the maximum and its quarter and sixteenth", {
  expect_equal(.size_key_breaks(c(0, 400)), c(25, 100, 400))
  expect_equal(.size_key_breaks(c(0, 1.6)), c(0.1, 0.4, 1.6))
  expect_equal(.size_key_breaks(c(0, 0)), 0)      # degenerate: no key
  expect_equal(.size_key_breaks(c(-5, -1)), -1)   # non-positive: no key
  p <- boring_map(new_lif_data(pk_site(c(400, 100))), repel = FALSE,
                  north_arrow = FALSE, scale_bar = FALSE)
  sc <- p$scales$get_scales("size")
  expect_s3_class(sc, "ScaleContinuous")
  expect_equal(sc$name, "Peak signal (%RE)")
  # Big-marked and rounded to .fmt_num()'s 3 significant figures, never
  # scientific notation however wide the range.
  expect_equal(sc$labels(c(1234, 0.5)), c("1,230", "0.5"))
  expect_equal(sc$labels(1e6), "1,000,000")
})

test_that("#31 the non-detect ring never outweighs a real detect", {
  mk <- function(peaks) new_lif_data(pk_site(peaks))
  # A detect smaller than the usual ring caps the ring at that detect.
  p <- boring_map(mk(c(400, 0.4, 0)), repel = FALSE, north_arrow = FALSE,
                  scale_bar = FALSE)
  det <- ggplot2::layer_data(p, 1)$size; nd <- ggplot2::layer_data(p, 2)$size
  expect_equal(nd, min(det))
  expect_true(all(nd <= det))
  # With no detect that small the ring keeps point_size * 0.5.
  p2 <- boring_map(mk(c(400, 100, 0)), repel = FALSE, north_arrow = FALSE,
                   scale_bar = FALSE)
  expect_equal(ggplot2::layer_data(p2, 2)$size, 2)
  # An all-non-detect frame has no detects to scale against (#456-class bug).
  p3 <- boring_map(mk(c(0, 0)), repel = FALSE, north_arrow = FALSE,
                   scale_bar = FALSE)
  expect_equal(unique(ggplot2::layer_data(p3, 1)$size), 2)
})

test_that("#31 size_by_signal = FALSE is unchanged and a negative floor is refused", {
  p <- boring_map(new_lif_data(pk_site(c(400, 100, 0))), size_by_signal = FALSE,
                  point_size = 5, repel = FALSE, north_arrow = FALSE,
                  scale_bar = FALSE)
  pts <- which(geom_classes(p) == "GeomPoint")   # not the label layer
  expect_equal(unique(unlist(lapply(pts, function(i)
    ggplot2::layer_data(p, i)$size))), 5)
  # A negative threshold would admit zero or negative peaks as detects.
  expect_error(boring_map(new_lif_data(pk_site(400)), nd_threshold = -1),
               "must be a number >= 0")
  expect_silent(boring_map(new_lif_data(pk_site(400)), nd_threshold = -1,
                           size_by_signal = FALSE, repel = FALSE,
                           north_arrow = FALSE, scale_bar = FALSE))
})

# -- #32 per-boring window guards --------------------------------------------

test_that("#32 a keep window that misses its boring is an error, preview too", {
  d <- data.frame(boring = "A", depth = 1:20, signal = 5)
  expect_error(lif_keep(d, "A", top = 300, bottom = 350),
               class = "lifr_keep_window_miss")
  expect_error(lif_keep(d, "A", top = 300, bottom = 350, preview = TRUE),
               class = "lifr_keep_window_miss")
  expect_error(lif_keep(d, "A", keep = list(c(300, 350), c(400, 410))),
               class = "lifr_keep_window_miss")
  err <- tryCatch(lif_keep(d, "A", top = 300, bottom = 350), error = identity)
  expect_match(conditionMessage(err), "300-350 ft")
  expect_match(conditionMessage(err), "its readings span 1-20 ft")
  expect_equal(err$boring, "A")
  # A window that holds at least one reading is still fine.
  expect_silent(suppressMessages(lif_keep(d, "A", top = 19.5, bottom = 400)))
})

test_that("#32 the guard is per boring, not per site", {
  # B's window is inside the SITE's depth range but misses B entirely.
  d <- data.frame(boring = rep(c("A", "B"), c(20, 5)),
                  depth = c(1:20, 1:5), signal = 5)
  expect_error(lif_keep(d, "B", top = 15, bottom = 18),
               class = "lifr_keep_window_miss")
  expect_silent(suppressMessages(lif_keep(d, "A", top = 15, bottom = 18)))
})

test_that("#32 a delete that changes nothing warns and says why", {
  d <- data.frame(boring = "A", depth = 1:5, signal = c(0, 0, 3, 4, 5))
  w <- tryCatch(suppressMessages(lif_editor(d, "A", top = 50, bottom = 60)),
                warning = identity)
  expect_s3_class(w, "lifr_edit_noop")
  expect_match(conditionMessage(w), "contains none of the boring's readings")
  expect_equal(c(w$top, w$bottom), c(50, 60))
  # A window whose readings already hold the replacement value says so
  # instead -- a re-applied edit, not a typo.
  w2 <- tryCatch(suppressMessages(lif_editor(d, "A", top = 1, bottom = 2)),
                 warning = identity)
  expect_match(conditionMessage(w2), "already hold the replacement value")
  # preview reports it too, and a real edit stays silent.
  expect_warning(suppressMessages(lif_editor(d, "A", top = 50, bottom = 60,
                                             preview = TRUE)),
                 class = "lifr_edit_noop")
  expect_silent(suppressMessages(lif_editor(d, "A", top = 3, bottom = 4)))
})

test_that("#32 lif_zero_shallow muffles the no-op warning it expects", {
  d <- data.frame(boring = rep(c("A", "B"), each = 5), depth = rep(1:5, 2),
                  signal = c(0, 0, 3, 4, 5, 9, 9, 9, 9, 9))
  z <- suppressMessages(lif_zero_shallow(d, depth = 2))
  expect_silent(suppressMessages(lif_zero_shallow(z, depth = 2)))
})

test_that("#32 a plan with a bad keep row fails before anything is applied", {
  d <- data.frame(boring = rep(c("A", "B"), c(20, 5)),
                  depth = c(1:20, 1:5), signal = 5)
  plan <- data.frame(boring = c("A", "B"), action = c("delete", "keep"),
                     top = c(1, 300), bottom = c(2, 350))
  expect_error(lif_apply_edits(d, plan), "contains none of boring 'B'")
  expect_error(lif_apply_edits(d, plan), "row 2")
  # Nothing was applied: A's delete did not land either.
  out <- tryCatch(lif_apply_edits(d, plan), error = function(e) NULL)
  expect_null(out)
  # A no-op delete row reaches the caller instead of being swallowed by the
  # batch path's suppressWarnings().
  plan2 <- data.frame(boring = "A", action = "delete", top = 500, bottom = 600)
  expect_warning(suppressMessages(lif_apply_edits(d, plan2)),
                 class = "lifr_edit_noop")
})

# -- #33 chart_max_response bar kinds and caption ----------------------------

test_that("#33 the caption names only the encodings the bars carry", {
  lif <- demo_lif()
  cap <- function(p) p$labels$caption
  # Every bar filled: the emission clause, no hollow clause.
  expect_match(cap(chart_max_response(lif)), "emission colour at peak-signal depth")
  expect_false(grepl("Hollow", cap(chart_max_response(lif))))
  # No colour channel at all: no emission clause, and the hollow clause
  # counts the borings.
  no_col <- lif; no_col$color <- NULL
  expect_false(grepl("emission colour at peak-signal depth", cap(chart_max_response(no_col))))
  expect_match(cap(chart_max_response(no_col)), "Hollow = no emission colour recorded \\(12 of 12 borings\\)")
  # Mixed frames carry both clauses.
  mix <- lif; mix$color[mix$boring %in% c("LIF-01", "LIF-02")] <- NA
  expect_match(cap(chart_max_response(mix)), "emission colour at peak-signal depth")
  expect_match(cap(chart_max_response(mix)), "\\(2 of 12 borings\\)")
  # The screening-floor clause is the rule, so it is always stated.
  for (p in list(chart_max_response(lif), chart_max_response(no_col)))
    expect_match(cap(p), "Grey = peak below the 1 %RE screening floor")
})

test_that("#33 a colour-less bar is hollow, not a plausible product colour", {
  lif <- demo_lif()
  no_col <- lif; no_col$color <- NULL
  ld <- layer_by_geom(chart_max_response(no_col), "GeomCol")
  expect_true(all(is.na(ld$fill)))            # unfilled, not .LIFR_FILL olive
  expect_true(all(ld$fill != .LIFR_FILL | is.na(ld$fill)))
  expect_equal(unique(ld$colour), .LIFR_INK)  # ink outline
  expect_equal(unique(ld$linewidth), 0.4)
  # Below-floor bars stay grey whatever the colour cell holds.
  d <- data.frame(boring = c("A", "B"), depth = 1, signal = c(0.5, 50),
                  color = c("#6B8E23", "#6B8E23"))
  ld2 <- layer_by_geom(chart_max_response(d, thresholds = c(1, 5)), "GeomCol")
  expect_equal(ld2$fill[1], .LIFR_GREY)
  expect_equal(ld2$fill[2], "#6B8E23")
})

# -- #34 a failed chart is reported, not logged as an absent channel ---------

# Run `expr`, returning its value and every warning it raised.
with_warnings <- function(expr) {
  w <- character(0)
  val <- withCallingHandlers(expr, warning = function(cond) {
    w <<- c(w, conditionMessage(cond)); invokeRestart("muffleWarning")
  })
  list(value = val, warnings = w)
}

test_that("#34 a builder that throws is warned and recorded, not skipped", {
  lif <- demo_lif()
  bad <- lif; bad$signal <- as.list(bad$signal)   # makes two builders throw
  out <- withr::local_tempdir()
  res <- with_warnings(export_site_charts(bad, out, quiet = TRUE))
  expect_length(res$warnings, 2L)
  expect_true(all(grepl("failed to build and was skipped", res$warnings)))
  f <- attr(res$value, "failed")
  expect_s3_class(f, "data.frame")
  expect_setequal(f$chart, c("max_response", "peak_by_boring"))
  expect_equal(unique(f$stage), "build")
  expect_true(all(nzchar(f$error)))               # a one-line reason each
  expect_false(any(grepl("\n", f$error)))         # cli errors are flattened
  # The charts that still work are written anyway.
  expect_length(res$value, 2L)
})

test_that("#34 a save that fails is warned and recorded", {
  lif <- demo_lif()
  notadir <- withr::local_tempfile()
  writeLines("x", notadir)
  res <- with_warnings(export_site_charts(lif, notadir, quiet = TRUE))
  expect_length(res$value, 0L)
  expect_length(res$warnings, 4L)                 # one per chart
  expect_true(all(grepl("failed to save and was skipped", res$warnings)))
  expect_equal(unique(attr(res$value, "failed")$stage), "save")
})

test_that("#34 an absent channel is still a silent, unrecorded skip", {
  lif <- demo_lif()
  lif$ec <- NULL; lif$hp <- NULL
  out <- withr::local_tempdir()
  r <- export_site_charts(lif, out, quiet = TRUE)
  expect_null(attr(r, "failed"))
  expect_setequal(basename(r), c("site_chart_max_response.png",
                                 "site_chart_peak_by_boring.png"))
})

test_that("#34 a stale PNG at a failed chart's path is removed", {
  lif <- demo_lif()
  bad <- lif; bad$signal <- as.list(bad$signal)
  out <- withr::local_tempdir()
  stale <- file.path(out, "site_chart_max_response.png")
  writeLines("last run", stale)
  suppressWarnings(export_site_charts(bad, out, quiet = TRUE))
  expect_false(file.exists(stale))
})

test_that("#34 process_site logs every chart it could not produce", {
  site <- withr::local_tempdir()
  write_tiny_site(site)
  out <- withr::local_tempdir()
  # An output_dir that is a regular file makes every save fail.
  notadir <- file.path(out, "blocked")
  writeLines("x", notadir)
  r <- suppressWarnings(suppressMessages(
    process_site(site, output_dir = notadir, charts = TRUE, report = FALSE)))
  rows <- r$log[r$log$step == "charts", ]
  expect_true(nrow(rows) >= 1L)
  expect_true(all(grepl("^failed to ", rows$detail)))
  expect_false(any(rows$action == "export_site_charts()"))  # no "complete set"
})

# -- #35 the facet sheet draws the emission colour ---------------------------

test_that("#35 lif_plot_all(layout = 'facet') draws the emission colour", {
  lif <- demo_lif()
  p <- lif_plot_all(lif)
  expect_setequal(geom_classes(p), c("GeomRect", "GeomSegment", "GeomLine"))
  fills <- unique(layer_by_geom(p, "GeomRect")$fill)
  expect_true(length(fills) > 1L)               # real per-reading colours
  expect_true(all(grepl("^#[0-9A-F]{6}$", fills)))
  # The signal axis drops below zero to make room for the colour strip.
  expect_lt(p$coordinates$limits$y[1], 0)
})

test_that("#35 a frame with no colour renders exactly as before", {
  lif <- demo_lif(); lif$color <- NULL
  p <- lif_plot_all(lif)
  expect_setequal(geom_classes(p), c("GeomArea", "GeomLine"))
  expect_equal(p$coordinates$limits$y[1], 0)
})

test_that("#35 colour is decided per boring on a mixed sheet", {
  lif <- demo_lif()
  lif$color[lif$boring %in% c("LIF-01", "LIF-02")] <- NA
  p <- lif_plot_all(lif)
  expect_setequal(geom_classes(p), c("GeomRect", "GeomSegment", "GeomArea",
                                     "GeomLine"))
  # The two colour-less borings get the flat area; the other ten get rects.
  expect_setequal(unique(layer_by_geom(p, "GeomArea")$PANEL), factor(1:2, levels = 1:12))
  expect_length(unique(layer_by_geom(p, "GeomRect")$PANEL), 10L)
})

test_that("#35 each boring's rects span its own sample interval", {
  lif <- demo_lif()
  a <- lif[lif$boring == "LIF-01", ]
  b <- transform(lif[lif$boring == "LIF-02", ], depth = depth * 2)
  w <- layer_by_geom(lif_plot_all(rbind(a, b)), "GeomRect")
  w$span <- abs(w$xmax - w$xmin)
  spans <- tapply(w$span, w$PANEL, stats::median)
  # The doubled-depth boring is logged on twice the step, so its rects are
  # twice as tall -- not drawn at its neighbour's step.
  expect_equal(unname(spans[2] / spans[1]), 2, tolerance = 1e-6)
})

# -- #30 area fills break at NA ----------------------------------------------

test_that("#30 an NA interval breaks the area fill instead of being filled", {
  d <- data.frame(boring = "A", depth = 1:7, signal = c(1, 5, NA, NA, 4, 2, 1))
  ld <- layer_by_geom(lif_plot(d, "A"), "GeomArea")
  # The NA rows survive into the layer data, so GeomRibbon splits the
  # polygon there. stat_align (the geom_area default since ggplot2 3.4)
  # dropped them and ran the fill straight across the gap.
  # scale_x_reverse negates x, so match depths rather than row positions,
  # and the NA must land in y -- PositionStack used to put it in x.
  expect_equal(nrow(ld), 7L)
  expect_false(anyNA(ld$x))
  expect_equal(sort(-ld$x[is.na(ld$y)]), c(3, 4))
  # Two polygons, not one spanning the gap.
  g <- ggplot2::ggplotGrob(lif_plot(d, "A"))
  polys <- 0L
  walk <- function(k) {
    if (inherits(k, c("polygon", "pathgrob"))) polys <<- polys + 1L
    if (!is.null(k$children)) invisible(lapply(k$children, walk))
  }
  walk(g$grobs[[which(g$layout$name == "panel")]])
  expect_equal(polys, 2L)
})

test_that("#30 a frame with no NA is unchanged, and no warning is emitted", {
  d <- data.frame(boring = "A", depth = 1:5, signal = c(1, 5, 3, 4, 1))
  ld <- layer_by_geom(lif_plot(d, "A"), "GeomArea")
  expect_equal(nrow(ld), 5L)
  expect_equal(ld$y[order(-ld$x)], c(1, 5, 3, 4, 1))   # x is reversed
  # na.rm = TRUE is kept at the call sites, so a deleted interval does not
  # cost a "Removed n rows" warning in every report panel.
  dna <- data.frame(boring = "A", depth = 1:5, signal = c(1, NA, 3, 4, 1))
  expect_silent(ggplot2::ggplot_build(lif_plot(dna, "A")))
})

test_that("#30 a value = NA edit shows as a gap on the QC comparison", {
  d <- data.frame(boring = "A", depth = 1:6, signal = c(1, 5, 6, 4, 2, 1))
  e <- suppressMessages(lif_editor(d, "A", top = 3, bottom = 4, value = NA))
  plots <- suppressMessages(qc_compare(d, e))
  expect_named(plots, "A")
  ld <- layer_by_geom(plots$A, "GeomArea")
  # The edited facet carries the NA rows; the input facet does not. The NA
  # must be in y: geom_area()'s default stacking turned it into x = NA,
  # y = 0 and drew a polygon pinned to the axis instead of a gap.
  expect_equal(sum(is.na(ld$y)), 2L)
  expect_false(anyNA(ld$x))
  expect_equal(sum(is.na(ld$y[ld$PANEL == 1])), 0L)
  expect_equal(sum(is.na(ld$y[ld$PANEL == 2])), 2L)
})
