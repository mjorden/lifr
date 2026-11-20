# Defects ported from the daktools October/November 2026 fixes, tier 2:
# daktools #791, #792, #801, #795, #661, #647.
# Layers are located by geom class, never by index.

geom_classes2 <- function(p) vapply(p$layers, function(l) class(l$geom)[1], character(1))
layers_by_geom2 <- function(p, cls) {
  i <- which(geom_classes2(p) == cls)
  lapply(i, function(j) ggplot2::layer_data(p, j))
}
# Conditions of one class, collected without letting them reach the console.
# Never wrap the call in suppressMessages() *inside* this: the inner muffle
# restart unwinds before the outer handler runs, and nothing is collected.
# Put suppressMessages() outside catch_floor() instead.
catch_floor <- function(expr) {
  seen <- character(0)
  val <- withCallingHandlers(expr, lifr_below_floor = function(c) {
    seen <<- c(seen, conditionMessage(c))
    rlang::cnd_muffle(c)
  })
  list(value = val, messages = seen)
}
# A layer with no rows satisfies all(ld$shape == 4) vacuously, so a shape
# test must require rows first.
pts_of_shape <- function(p, shape)
  Filter(function(ld) nrow(ld) > 0 && all(ld$shape == shape),
         layers_by_geom2(p, "GeomPoint"))
site <- function(n_borings = 2, signal = c(0.5, 4, 40), ec = NULL, hp = NULL) {
  do.call(rbind, lapply(seq_len(n_borings), function(i) {
    d <- data.frame(boring = sprintf("B%02d", i),
                    easting = 1000 + i * 60, northing = 2000,
                    depth = seq_along(signal), signal = signal,
                    stringsAsFactors = FALSE)
    if (!is.null(ec)) d$ec <- ec
    if (!is.null(hp)) d$hp <- hp
    d
  }))
}

# -- daktools #791 lif_zero_below_threshold(borings=) audit rows -------------

test_that("#791 a scoped call records one row per named boring", {
  d <- site(3, signal = c(0.5, 0.5, 40))
  z <- suppressMessages(lif_zero_below_threshold(d, threshold = 1,
                                                 borings = c("B01", "B03")))
  h <- edit_history(z)
  expect_equal(nrow(h), 2L)
  expect_equal(h$boring, c("B01", "B03"))
  # Each row carries its own count, not the site total: two sub-threshold
  # readings per boring.
  expect_equal(h$n_rows_changed, c(2L, 2L))
  expect_true(all(h$notes == "threshold=1"))
  # B02 was never touched, and no row claims it was.
  expect_false(any(is.na(h$boring)))
  expect_equal(z$signal[z$boring == "B02"], c(0.5, 0.5, 40))
})

test_that("#791 an unscoped call still records one boring = NA row", {
  d <- site(3, signal = c(0.5, 0.5, 40))
  z <- suppressMessages(lif_zero_below_threshold(d, threshold = 1))
  h <- edit_history(z)
  expect_equal(nrow(h), 1L)
  expect_true(is.na(h$boring))
  expect_equal(h$n_rows_changed, 6L)   # the site total, which is true here
})

test_that("#791 a duplicated name in borings is one target, not two", {
  d <- site(2, signal = c(0.5, 0.5, 40))
  z <- suppressMessages(lif_zero_below_threshold(d, threshold = 1,
                                                 borings = c("B01", "B01")))
  h <- edit_history(z)
  expect_equal(nrow(h), 1L)
  expect_equal(h$boring, "B01")
  expect_equal(h$n_rows_changed, 2L)
})

test_that("#791 the scoped and unscoped paths change the same readings", {
  d <- site(3, signal = c(0.5, 0.5, 40))
  all_b <- c("B01", "B02", "B03")
  scoped <- suppressMessages(lif_zero_below_threshold(d, threshold = 1,
                                                      borings = all_b))
  site_wide <- suppressMessages(lif_zero_below_threshold(d, threshold = 1))
  expect_equal(scoped$signal, site_wide$signal)
  expect_equal(sum(edit_history(scoped)$n_rows_changed),
               edit_history(site_wide)$n_rows_changed)
})

test_that("#791 NA readings are left alone and counted as unchanged", {
  d <- site(1, signal = c(0.5, NA, 40))
  z <- suppressMessages(lif_zero_below_threshold(d, threshold = 1,
                                                 borings = "B01"))
  expect_true(is.na(z$signal[2]))
  expect_equal(edit_history(z)$n_rows_changed, 1L)
})

test_that("#791 the report's whole-log caption no longer names every boring", {
  d <- site(3, signal = c(0.5, 0.5, 40))
  z <- suppressMessages(lif_zero_below_threshold(d, threshold = 1,
                                                 borings = c("B01", "B03")))
  h <- edit_history(z)
  # .boring_edit_windows() and the report's "whole-log edit(s)" caption both
  # select on (is.na(boring) | boring == b). With a boring = NA row that
  # matched B02 as well.
  bulk <- function(b) h[(is.na(h$boring) | h$boring == b) &
                        is.na(h$top) & is.na(h$bottom), , drop = FALSE]
  expect_equal(nrow(bulk("B01")), 1L)
  expect_equal(nrow(bulk("B03")), 1L)
  expect_equal(nrow(bulk("B02")), 0L)
})

# -- daktools #792 step-log argument formatting ------------------------------

test_that("#792 a named vector argument keeps its own name and values", {
  # The old paste(names(p), unlist(p), sep = "=") recycled the names over the
  # flattened values and logged "water_table=12; gradient=14.5;
  # water_table=0.433" -- a 14.5 ft/ft gradient on the record.
  expect_equal(
    .fmt_step_args(list(water_table = c("B01" = 12, "B02" = 14.5),
                        gradient = 0.433)),
    "water_table=c(B01=12|B02=14.5); gradient=0.433")
})

test_that("#792 scalars are unchanged and order is preserved", {
  expect_equal(.fmt_step_args(list(gradient = 0.433, water_table = 0)),
               "gradient=0.433; water_table=0")
  expect_equal(.fmt_step_args(list(water_table = 0, gradient = 0.433)),
               "water_table=0; gradient=0.433")
  expect_equal(.fmt_step_args(list()), "")
})

test_that("#792 lists, NULL, NA and unnamed vectors each format on their own", {
  expect_equal(.fmt_step_args(list(x = NULL)), "x=NULL")
  expect_equal(.fmt_step_args(list(x = c(1, NA, 3))), "x=c(1|NA|3)")
  expect_equal(.fmt_step_args(list(x = list(a = 1, b = c(2, 3)))),
               "x=list(a=1|b=c(2|3))")
  expect_equal(.fmt_step_args(list(TRUE, n = 2)), "TRUE; n=2")
  expect_equal(.fmt_step_arg(c(a = 1)), "c(a=1)")      # named length-1 keeps its name
  expect_equal(.fmt_step_arg(1), "1")                   # bare scalar does not
})

test_that("#792 every argument's value appears exactly once", {
  p <- list(water_table = c("B01" = 12, "B02" = 14.5), gradient = 0.433)
  s <- .fmt_step_args(p)
  for (v in c("12", "14.5", "0.433")) expect_equal(lengths(gregexpr(v, s, fixed = TRUE)), 1L)
  expect_equal(lengths(gregexpr("water_table", s, fixed = TRUE)), 1L)
  expect_equal(lengths(gregexpr("gradient", s, fixed = TRUE)), 1L)
})

# -- daktools #801 grey sub-floor detects on boring_map() -------------------

test_that("#801 a detect below the fill floor is grey but keeps its size", {
  d <- new_lif_data(site(1, signal = c(0.5, 4, 40)))
  d <- rbind(d, new_lif_data(within(site(1, signal = c(0.1, 0.2, 0.3)),
                                    boring <- "B02")))
  d$boring[d$easting == 1060 & d$signal <= 0.3] <- "B02"
  d$easting[d$boring == "B02"] <- 1120
  p <- boring_map(new_lif_data(d), fill_floor = 1, repel = FALSE,
                  north_arrow = FALSE, scale_bar = FALSE)
  ld <- layers_by_geom2(p, "GeomPoint")[[1]]
  expect_equal(nrow(ld), 2L)                    # both are detects, not NDs
  expect_equal(sum(ld$fill == .LIFR_GREY), 1L)  # the 0.3 %RE peak
  # Size still comes off the area scale, so the grey marker is sized by its
  # real peak: it is a real reading, just below the screening floor.
  expect_equal((min(ld$size) / max(ld$size))^2, 0.3 / 40, tolerance = 1e-6)
})

test_that("#801 the floor is strict, matching chart_max_response()'s bars", {
  d <- new_lif_data(site(1, signal = c(0, 0, 5)))
  p <- boring_map(d, fill_floor = 5, repel = FALSE, north_arrow = FALSE,
                  scale_bar = FALSE)
  ld <- layers_by_geom2(p, "GeomPoint")[[1]]
  expect_false(any(ld$fill == .LIFR_GREY))      # peak == floor is coloured
  # chart_max_response() greys at `<` too, on the same data: a peak exactly
  # at the floor is above it in both figures.
  bars <- layers_by_geom2(chart_max_response(d, thresholds = 5), "GeomCol")[[1]]
  expect_false(any(bars$fill == .LIFR_GREY, na.rm = TRUE))
})

test_that("#801 the floor does not turn a sub-floor detect into a non-detect", {
  d <- new_lif_data(site(1, signal = c(0, 0, 0.3)))
  p <- boring_map(d, fill_floor = 1, repel = FALSE, north_arrow = FALSE,
                  scale_bar = FALSE)
  ld <- layers_by_geom2(p, "GeomPoint")[[1]]
  expect_equal(ld$shape, 21)                    # filled, not the hollow 1
  expect_equal(ld$fill, .LIFR_GREY)
})

test_that("#801 the floor clause is in the caption whenever a floor is set", {
  d <- new_lif_data(site(1, signal = c(0, 0, 40)))
  with_floor <- boring_map(d, fill_floor = 1, repel = FALSE,
                           north_arrow = FALSE, scale_bar = FALSE)
  # Stated even though no marker is grey: it is a screening rule, not a key.
  expect_match(with_floor$labels$caption, "Grey fill = peak below the 1 %RE")
  no_floor <- boring_map(d, repel = FALSE, north_arrow = FALSE, scale_bar = FALSE)
  expect_false(grepl("screening floor", no_floor$labels$caption))
})

test_that("#801 fill_floor is validated and NULL keeps the old fills", {
  d <- new_lif_data(site(1, signal = c(0, 0, 40)))
  expect_error(boring_map(d, fill_floor = -1), "fill_floor")
  expect_error(boring_map(d, fill_floor = c(1, 2)), "fill_floor")
  expect_error(boring_map(d, fill_floor = Inf), "fill_floor")
  plain <- boring_map(d, repel = FALSE, north_arrow = FALSE, scale_bar = FALSE)
  expect_equal(layers_by_geom2(plain, "GeomPoint")[[1]]$fill, .LIFR_BLUE)
})

# -- daktools #661 value-axis floor disclosure ------------------------------

test_that("#661 .y_floor reports what falls below the floor in force", {
  fl <- suppressMessages(.y_floor(c(-3, -1, 2, 5), 0, 10, "test"))
  expect_equal(fl$ymin, 0)
  expect_equal(fl$n_below, 2L)
  expect_equal(fl$caption, "2 readings below 0")
  one <- catch_floor(.y_floor(c(-1, 2), 0, 10, "test"))
  expect_equal(one$value$caption, "1 reading below 0")   # singular
  expect_length(one$messages, 1L)
})

test_that("#661 nothing is claimed when nothing is below the floor", {
  fl <- .y_floor(c(0, 2, 5), 0, 10, "test")
  expect_equal(fl$n_below, 0L)
  expect_null(fl$caption)
  # No condition, so a clean panel stays silent.
  expect_length(catch_floor(.y_floor(c(0, 2, 5), 0, 10, "test"))$messages, 0L)
})

test_that("#661 ymin = NULL floors below the lowest reading and never above 0", {
  expect_equal(.y_floor(c(-3, 2), NULL, 10, "test")$ymin, -3 * 1.05)
  expect_equal(.y_floor(c(1, 2), NULL, 10, "test")$ymin, 0)   # all positive
  expect_equal(.y_floor(numeric(0), NULL, 10, "test")$ymin, 0)
  expect_equal(.y_floor(c(NA, NaN, Inf), NULL, 10, "test")$ymin, 0)
  # The auto floor shows every reading, so it discloses nothing.
  expect_equal(.y_floor(c(-3, 2), NULL, 10, "test")$n_below, 0L)
})

test_that("#661 an impossible or malformed floor is an error, not a silent plot", {
  expect_error(.y_floor(c(1, 2), c(0, 1), 10, "test"), "single finite number")
  expect_error(.y_floor(c(1, 2), NA_real_, 10, "test"), "single finite number")
  expect_error(.y_floor(c(1, 2), "0", 10, "test"), "single finite number")
  expect_error(.y_floor(c(1, 2), 20, 10, "test"), "must be below its ceiling")
})

test_that("#661 lif_overview discloses hp readings a 0 floor would hide", {
  d <- site(1, signal = c(1, 2, 3), hp = c(-2, 1, 4))
  r <- catch_floor(lif_overview(d, "B01"))
  expect_length(r$messages, 1L)
  expect_match(r$messages, "lif_overview\\('B01', hp\\)")
  expect_match(r$messages, "1 reading below the axis floor \\(0\\)")
  expect_match(r$messages, "pass ymin = NULL")
})

test_that("#661 the default still floors at 0, so no existing figure moves", {
  d <- site(1, signal = c(1, 2, 3), hp = c(-2, 1, 4))
  hp_panel <- suppressMessages(
    .channel_panel(d[d$boring == "B01", ], "hp", "HP (psi)", 3))
  expect_equal(hp_panel$coordinates$limits$y, c(0, .axis_cap(c(-2, 1, 4), 1)))
  # ... and the panel says so, rather than drawing the -2 on the edge.
  expect_equal(hp_panel$labels$caption, "1 reading below 0")
})

test_that("#661 ymin = NULL opens the axis and adds a zero reference", {
  d <- site(1, signal = c(1, 2, 3), hp = c(-2, 1, 4))
  p <- suppressMessages(lif_overview(d, "B01", ymin = NULL))
  hp_panel <- p[[2]]
  expect_equal(hp_panel$coordinates$limits$y[1], -2 * 1.05)
  expect_true("GeomHline" %in% geom_classes2(hp_panel))
  expect_null(hp_panel$labels$caption)        # nothing hidden, nothing to say
  # A 0 floor needs no zero line: the axis edge already is zero.
  dflt <- suppressMessages(
    .channel_panel(d[d$boring == "B01", ], "hp", "HP (psi)", 3))
  expect_false("GeomHline" %in% geom_classes2(dflt))
})

test_that("#661 the LIF panel keeps its 0 floor and raises nothing", {
  d <- site(1, signal = c(-5, 2, 3), hp = c(1, 2, 3))
  r <- catch_floor(lif_plot(d, "B01"))
  expect_length(r$messages, 0L)
  expect_equal(r$value$coordinates$limits$y[1], 0)
})

test_that("#661 qc_compare discloses on the signal channel too", {
  raw <- site(1, signal = c(5, 5, 5))
  ed  <- raw
  ed$signal <- c(-3, 5, 5)
  r <- suppressMessages(catch_floor(qc_compare(raw, ed)))
  expect_length(r$messages, 1L)
  expect_match(r$messages, "qc_compare\\('B01'\\)")
  expect_equal(r$value[["B01"]]$labels$caption, "1 reading below 0")
  open <- suppressMessages(qc_compare(raw, ed, ymin = NULL))
  expect_equal(open[["B01"]]$coordinates$limits$y[1], -3 * 1.05)
})

# -- daktools #795 qc_compare shows readings it can no longer plot ----------

test_that("#795 a value = NA edit is marked, not silently dropped", {
  raw <- site(1, signal = c(5, 6, 7))
  ed  <- suppressMessages(lif_editor(raw, "B01", top = 2, bottom = 2, value = NA))
  pl  <- suppressMessages(qc_compare(raw, ed))
  expect_named(pl, "B01")
  p <- pl[["B01"]]
  # The red dot layer cannot draw an NA, so the cross layer carries it.
  crosses <- pts_of_shape(p, 4)
  expect_length(crosses, 1L)
  expect_equal(nrow(crosses[[1]]), 1L)
  expect_equal(crosses[[1]]$colour, "red")
  expect_match(p$labels$subtitle, "removed or set to NA")
})

test_that("#795 the cross sits just inside the panel floor of Edited only", {
  raw <- site(1, signal = c(5, 6, 7))
  ed  <- suppressMessages(lif_editor(raw, "B01", top = 2, bottom = 2, value = NA))
  p   <- suppressMessages(qc_compare(raw, ed))[["B01"]]
  crosses <- pts_of_shape(p, 4)[[1]]
  ymax <- .axis_cap(c(5, NA, 7, 5, 6, 7), 1)
  expect_equal(crosses$y, 0.02 * ymax)
  expect_equal(as.character(crosses$PANEL), "2")   # the Edited facet
})

test_that("#795 a depth dropped from `edited` is reported, not ignored", {
  raw <- site(1, signal = c(5, 6, 7))
  ed  <- raw[raw$depth != 2, , drop = FALSE]
  pl  <- suppressMessages(qc_compare(raw, ed))
  # The old inner merge saw only the two matched depths and called the
  # boring unchanged.
  expect_named(pl, "B01")
  crosses <- pts_of_shape(pl[["B01"]], 4)
  expect_length(crosses, 1L)
  expect_equal(nrow(crosses[[1]]), 1L)
})

test_that("#795 an NA filled in is an edit; NA on both sides is not", {
  raw <- site(1, signal = c(NA, 6, 7))
  filled <- raw; filled$signal[1] <- 5
  expect_named(suppressMessages(qc_compare(raw, filled)), "B01")
  expect_length(suppressMessages(qc_compare(raw, raw)), 0L)
})

test_that("#795 an ordinary edit still gets a dot and no cross or subtitle", {
  raw <- site(1, signal = c(5, 6, 7))
  ed  <- suppressMessages(lif_editor(raw, "B01", top = 2, bottom = 2))
  p   <- suppressMessages(qc_compare(raw, ed))[["B01"]]
  dots <- pts_of_shape(p, 19)
  expect_length(dots, 1L)
  expect_equal(nrow(dots[[1]]), 1L)
  expect_length(pts_of_shape(p, 4), 0L)
  expect_null(p$labels$subtitle)
})

# -- daktools #647 what actually keeps the edit history ---------------------

edited_frame <- function(tag) {
  d <- data.frame(boring = tag, depth = 1:3, signal = c(5, 0, 2),
                  stringsAsFactors = FALSE)
  suppressMessages(lif_zero_shallow(d, depth = 1))
}
declass <- function(x) {
  class(x) <- "data.frame"
  attr(x, "edits") <- NULL
  x
}
n_hist <- function(x) {
  h <- attr(x, "edits")
  if (is.null(h)) 0L else nrow(h)
}

test_that("#647 rbind() concatenates only when its first argument is classed", {
  a <- edited_frame("A"); b <- edited_frame("B"); c3 <- edited_frame("C")
  expect_equal(n_hist(rbind(a, b)), 2L)
  expect_equal(n_hist(rbind(a, b, c3)), 3L)
  expect_true(inherits(rbind(a, b), "edited_data"))
  # A plain frame first sends the whole call to rbind.data.frame: no class,
  # no history, and nothing warns.
  out <- rbind(declass(a), b)
  expect_equal(n_hist(out), 0L)
  expect_false(inherits(out, "edited_data"))
  expect_silent(rbind(declass(a), b))
  # Classed first, plain later: the plain frame contributes nothing, which
  # is correct -- it has nothing to contribute.
  expect_equal(n_hist(rbind(a, declass(b))), 1L)
  expect_equal(n_hist(rbind(a, declass(b), c3)), 2L)
})

test_that("#647 the rbind rule holds for lif_data as well as edited_data", {
  demo <- system.file("extdata", "demo", package = "lifr")
  l <- suppressMessages(lif_import(demo, verbose = FALSE))
  l1 <- suppressMessages(lif_zero_shallow(l[l$boring == "LIF-01", ], depth = 1))
  l2 <- suppressMessages(lif_zero_shallow(l[l$boring == "LIF-02", ], depth = 1))
  out <- rbind(l1, l2)
  expect_equal(n_hist(out), 2L)
  expect_true(inherits(out, "lif_data"))
})

test_that("#647 bind_rows() keeps at most the first history and never merges", {
  skip_if_not_installed("dplyr")
  a <- edited_frame("A"); b <- edited_frame("B")
  # Current behaviour, pinned so a dplyr change reads as "re-verify the
  # docs" rather than as a lifr regression.
  expect_equal(n_hist(dplyr::bind_rows(a, b)), 1L)
  expect_equal(n_hist(dplyr::bind_rows(declass(a), b)), 0L)
})

test_that("#647 `[` and the dplyr verbs keep the history", {
  skip_if_not_installed("dplyr")
  a <- edited_frame("A")
  expect_equal(n_hist(a[1:2, ]), 1L)
  expect_equal(n_hist(a[, c("boring", "depth")]), 1L)
  expect_equal(n_hist(dplyr::filter(a, depth > 1)), 1L)
  expect_equal(n_hist(dplyr::mutate(a, q = 1)), 1L)
  expect_equal(n_hist(dplyr::select(a, boring, depth)), 1L)
  expect_equal(n_hist(dplyr::arrange(a, -depth)), 1L)
  expect_equal(
    n_hist(dplyr::left_join(a, data.frame(boring = "A", z = 1), by = "boring")),
    1L)
})

test_that("#647 merge() and a rebuild lose the history outright", {
  a <- edited_frame("A")
  expect_equal(n_hist(merge(a, data.frame(boring = "A", z = 1), by = "boring")), 0L)
  expect_equal(n_hist(data.frame(boring = a$boring, depth = a$depth)), 0L)
})

test_that("#647 as_tibble()/as.data.frame() drop the class, not the attribute", {
  skip_if_not_installed("tibble")
  a <- edited_frame("A")
  tb <- tibble::as_tibble(a)
  expect_false(inherits(tb, "edited_data"))
  # The attribute usually rides along, and edit_history() reads it -- but
  # nothing maintains it, which is why ?new_edited_data says to restore it.
  expect_equal(n_hist(tb), 1L)
  expect_false(inherits(as.data.frame(a), "edited_data"))
  # A declassed frame first in rbind() keeps only its own history.
  expect_equal(n_hist(rbind(tb, edited_frame("B"))), 1L)
})

test_that("#647 lif_get_edits()/lif_set_edits() restore what is lost", {
  a <- edited_frame("A")
  saved <- lif_get_edits(a)
  joined <- merge(a, data.frame(boring = "A", z = 1), by = "boring")
  expect_equal(n_hist(joined), 0L)
  expect_equal(n_hist(lif_set_edits(joined, saved)), 1L)
})
