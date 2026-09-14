# Regression tests for the defects found in the September 2026 review
# (lifr issues #1-#20). Each test names the issue it guards.

write_log <- function(dir, name, lines) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  writeLines(lines, file.path(dir, paste0(name, ".lif.dat.txt")))
}

# -- import ------------------------------------------------------------------

test_that("#1 trailing delimiters on data lines do not shift columns", {
  d <- withr::local_tempdir()
  write_log(d, "T1", c("Depth\tSignal\tEC.Value", "1\t2\t8\t", "2\t3\t9\t"))
  x <- lif_read(file.path(d, "T1.lif.dat.txt"))
  expect_equal(x$depth, c(1, 2)); expect_equal(x$signal, c(2, 3)); expect_equal(x$ec, c(8, 9))
  write_log(d, "T2", c("Depth\tSignal", "1\t2\t8", "2\t3"))
  expect_error(lif_read(file.path(d, "T2.lif.dat.txt")), "different field counts")
})

test_that("#2 all-digit colour codes keep their leading zeros", {
  d <- withr::local_tempdir()
  write_log(d, "C1", c("Depth\tSignal\tcolor", "1\t2\t000000", "2\t3\t112233"))
  expect_equal(lif_read(file.path(d, "C1.lif.dat.txt"))$color, c("#000000", "#112233"))
})

test_that("#3 a header-only log is omitted with a warning, not a crash", {
  d <- withr::local_tempdir()
  write_log(d, "A", c("Depth\tSignal\tEC.Value", "1\t2\t3", "2\t4\t5"))
  write_log(d, "B", "Depth\tSignal")
  expect_warning(x <- lif_import(d, locations_file = FALSE, verbose = FALSE),
                 "header but no readings.*B")
  expect_equal(unique(x$boring), "A")
})

test_that("#4 locations aliases never overwrite a canonical column", {
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("boring,x,easting,northing,msl", "A,9,100,200,50"), f)
  loc <- read_locations(f)
  expect_equal(loc$easting, 100); expect_equal(loc$x, 9)
  writeLines(c("id,boring,easting,northing,msl", "1,A,100,200,50"), f)
  expect_equal(read_locations(f)$boring, "A")
  writeLines(c("x,y,z,name", "1,2,3,A"), f)
  expect_equal(names(read_locations(f)), c("easting", "northing", "msl", "boring"))
})

# -- audit trail --------------------------------------------------------------

test_that("#5 a factor boring does not scramble per-boring water tables", {
  d <- data.frame(boring = factor(c("A", "B"), levels = c("B", "A")), depth = 10,
                  signal = 0, hp = 5)
  out <- suppressMessages(hp_correction(d, water_table = c(A = 10, B = 0)))
  expect_equal(out$hp, c(5, 5 - 4.33))
  expect_type(new_lif_data(d)$boring, "character")
})

test_that("#6 the edit history survives [, j], rbind, and dplyr verbs", {
  lif <- demo_lif()
  a <- suppressMessages(lif_editor(lif[lif$boring == "LIF-01", ], "LIF-01", top = 0, bottom = 1))
  b <- suppressMessages(lif_editor(lif[lif$boring == "LIF-02", ], "LIF-02", top = 0, bottom = 2))
  expect_equal(nrow(edit_history(a[, c("boring", "depth", "signal")])), 1)
  expect_equal(nrow(edit_history(a[1:5, ])), 1)
  ab <- rbind(a, b)
  expect_s3_class(ab, "lif_data")
  expect_equal(edit_history(ab)$boring, c("LIF-01", "LIF-02"))
  expect_equal(nrow(edit_history(rbind(lif[1:3, ], a))), 1)
  skip_if_not_installed("dplyr")
  expect_equal(nrow(edit_history(dplyr::mutate(a, z = 1))), 1)
  expect_equal(nrow(edit_history(dplyr::filter(a, depth > 1))), 1)
  expect_equal(nrow(edit_history(dplyr::select(a, boring, depth, signal))), 1)
})

test_that("#7 n_rows_changed counts readings that changed", {
  d <- data.frame(boring = "A", depth = 1:5, signal = c(0, 0, 0, 4, 5))
  z <- suppressMessages(lif_editor(d, "A", top = 1, bottom = 5))
  z <- suppressMessages(lif_editor(z, "A", top = 1, bottom = 5))
  expect_equal(edit_history(z)$n_rows_changed, c(2L, 0L))
  z2 <- suppressMessages(lif_zero_below_threshold(d, threshold = 1))
  expect_equal(edit_history(z2)$n_rows_changed, 0L)
  h <- data.frame(boring = "A", depth = c(1, 5, 20), signal = 0, hp = 5)
  expect_equal(edit_history(suppressMessages(hp_correction(h, water_table = 10)))$n_rows_changed, 1L)
  expect_error(lif_editor(d, "A", top = 1, bottom = 2, value = "x"), "single number")
})

test_that("#8 corrections = list(hp = FALSE) skips the correction", {
  out <- withr::local_tempdir()
  site <- process_site(demo_dir(), output_dir = out, report = FALSE, charts = FALSE,
                       quiet = TRUE, corrections = list(hp = FALSE))
  expect_equal(nrow(site$edits), 0)
  expect_error(process_site(demo_dir(), output_dir = out, corrections = list(hp = 3)),
               "must be TRUE or a named list")
})

test_that("#9 NA and negative depths are handled consistently", {
  d <- data.frame(boring = "A", depth = c(1, NA, 3), signal = 5)
  expect_equal(suppressMessages(lif_keep(d, "A", top = 0, bottom = 2))$signal, c(5, 5, 0))
  expect_equal(suppressMessages(lif_editor(d, "A", top = 0, bottom = 2))$signal, c(0, 5, 5))
  n <- data.frame(boring = "A", depth = c(-0.5, -0.25, 0, 0.25, 0.5, 1), signal = 5)
  expect_message(z <- lif_zero_shallow(n, 0.5), "changed 5 reading")
  expect_equal(z$signal, c(0, 0, 0, 0, 0, 5))
  plan <- data.frame(boring = "A", action = "keep", top = NA, bottom = NA)
  expect_error(lif_apply_edits(d, plan), "needs top and/or bottom")
})

# -- report and pipeline ------------------------------------------------------

test_that("#10 backslash paths and underscores survive the Markdown report", {
  out <- withr::local_tempdir()
  dd <- file.path(out, "_arch", "site\\data")
  site <- process_site(demo_dir(), output_dir = out, report = FALSE, charts = FALSE,
                       quiet = TRUE, site_name = "Site_A *test*")
  site$meta$data_dir <- "C:\\Users\\_arch\\demo"
  r <- site_report(site, formats = "md", output_dir = out, quiet = TRUE)
  md <- readLines(r$md, warn = FALSE)
  expect_true(any(grepl("`C:\\\\Users\\\\_arch\\\\demo`", md, fixed = FALSE)))
  expect_true(any(grepl("^# Site\\\\_A \\\\\\*test\\\\\\*", md)))
  expect_equal(lifr:::.md_esc("a_b|c\\d"), "a\\_b\\|c\\\\d")
})

test_that("#11 a failing optional step warns and is logged even when quiet", {
  out <- withr::local_tempdir()
  testthat::local_mocked_bindings(site_report = function(...) stop("renderer exploded"))
  expect_warning(site <- process_site(demo_dir(), output_dir = out, report_formats = "html",
                                      charts = FALSE, quiet = TRUE),
                 "report failed and was skipped: renderer exploded")
  expect_true(any(site$log$step == "report" & grepl("^failed", site$log$detail)))
  expect_length(site$reports, 0)
})

test_that("#12 the collision warning fires on every call", {
  expect_warning(compat_rename_legacy(data.frame(Depth = 1, depth = 2)), "collide")
  expect_warning(compat_rename_legacy(data.frame(Depth = 5, depth = 6)), "collide")
})

test_that("#13 lif_simulate leaves the caller's RNG state alone", {
  set.seed(123); a <- stats::runif(1)
  set.seed(123); invisible(lif_simulate(n_borings = 2)); b <- stats::runif(1)
  expect_identical(a, b)
})

test_that("#14 duplicate depths, NA depths, and empty frames", {
  d <- data.frame(boring = "A", depth = c(1, 1, 2), signal = c(5, 7, 9))
  expect_message(qc_compare(d, d), "0 boring\\(s\\) with changes")
  r <- data.frame(boring = "A", depth = c(0, 2, 2, 3), signal = c(0, 10, 0, 20))
  expect_equal(suppressWarnings(re_feet(r))$re_feet,
               suppressWarnings(re_feet(r[c(1, 3, 2, 4), ]))$re_feet)
  expect_warning(re_feet(r), "repeated depths")
  n <- data.frame(boring = "A", depth = c(1, NA, 3, 4), signal = 1)
  thin <- suppressMessages(lif_downsample(n, 2))
  expect_true(any(is.na(thin$depth)))
  expect_match(edit_history(thin)$notes, "na_depth_kept=1")
  s <- summarize_lif(data.frame(boring = character(), depth = numeric(), signal = numeric()))
  expect_equal(s$overview$n_borings, 0); expect_equal(nrow(s$by_boring), 0)
  neg <- data.frame(boring = "A", depth = c(-1, 1, 6), signal = 1)
  expect_equal(attr(summarize_lif(neg)$by_depth_zone, "unbinned"), 1L)
})

test_that("#15 change detection matches readings on depth, not position", {
  out <- withr::local_tempdir()
  site <- process_site(demo_dir(), output_dir = out, report = FALSE, charts = FALSE, quiet = TRUE)
  site$data <- site$data[order(site$data$boring, -site$data$depth), ]
  chg <- lifr:::.log_change_summary(site)
  expect_false(any(chg$changed))
  site$data$signal[1] <- site$data$signal[1] + 1
  expect_equal(sum(lifr:::.log_change_summary(site)$changed), 1)
})

test_that("#16 boring_map pads degenerate extents and formats labels per element", {
  one <- data.frame(boring = "A", depth = 1:3, signal = c(0, 5, 1), easting = 10, northing = 20)
  p <- boring_map(one, repel = FALSE)
  expect_s3_class(p, "ggplot")
  expect_gte(diff(p$coordinates$limits$x), 100)
  line <- data.frame(boring = c("A", "B", "C"), depth = 1, signal = c(1, 2, 3),
                     easting = c(0, 50, 100), northing = 5)
  expect_gte(diff(boring_map(line, repel = FALSE)$coordinates$limits$y), 100)
  expect_equal(lifr:::.fmt_num(c(88.607, 0.578, 12.4), 3), c("88.6", "0.578", "12.4"))
})

test_that("#17 EC outliers are disclosed, not drawn as a spike at the bound", {
  d <- data.frame(boring = "A", depth = 1:60, signal = 0, ec = c(rep(10, 58), 5000, 5000))
  p <- chart_ec_histogram(d)
  expect_lte(max(p$data$ec), 20)
  expect_match(p$labels$caption, "2 reading\\(s\\) above .* not drawn")
})

test_that("#18 a logs PDF is never left half-written and the md does not link to it", {
  out <- withr::local_tempdir()
  site <- process_site(demo_dir(), output_dir = out, report = FALSE, charts = FALSE, quiet = TRUE)
  lp <- lifr:::.report_log_plots(site)
  lp$plots[[2]] <- ggplot2::ggplot(data.frame(a = 1)) +
    ggplot2::geom_point(ggplot2::aes(x = .data$no_such_column, y = .data$a))
  expect_warning(r <- lifr:::.render_logs_pdf(lp, out, "broken", quiet = TRUE), "no logs PDF")
  expect_null(r)
  expect_false(file.exists(file.path(out, "broken_logs.pdf")))
  expect_warning(html <- lifr:::.embed_img("not a plot", "the alt"), "could not be rendered")
  expect_match(html, "Figure unavailable")
})

test_that("#19 the report carries tab roles and sortable headers are focusable", {
  out <- withr::local_tempdir()
  site <- process_site(demo_dir(), output_dir = out, report_formats = "html", charts = FALSE,
                       quiet = TRUE)
  html <- paste(readLines(site$reports$html, warn = FALSE), collapse = "\n")
  expect_equal(lengths(regmatches(html, gregexpr("role='tab'", html))), 4)
  expect_match(html, "role='tabpanel'")
  expect_match(html, "<th tabindex='0' aria-sort='none'>")
  expect_no_match(html, "querySelector\\(\\\".tabbar .tab\\[data-tab=")
})

test_that("#20 theme scales with base_size and agg_fn needs no na.rm", {
  size_at <- function(b) ggplot2::calc_element("plot.title", theme_lifr(base_size = b))$size
  expect_gt(size_at(20), size_at(10))
  lif <- demo_lif()
  expect_s3_class(depth_slice_map(lif, c(10, 20), agg_fn = function(v) max(v)), "ggplot")
  bm <- structure(list(image = array(0.5, c(4, 4, 4)), xmin = 0, xmax = 1, ymin = 0, ymax = 1),
                  class = "lifr_basemap")
  expect_equal(stats::sd(bm$image[, , 1:3]), 0)
})
