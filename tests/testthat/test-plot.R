lif <- demo_lif()

test_that("depth-profile plots return ggplot objects", {
  expect_s3_class(lif_plot(lif, "LIF-05"), "ggplot")
  expect_s3_class(lif_plot(lif, "LIF-05", ymax = 100, xmax = 20), "ggplot")
  nocol <- lif; nocol$color <- NULL
  expect_s3_class(lif_plot(nocol, "LIF-05"), "ggplot")
  expect_error(lif_plot(lif, "nope"), "Valid borings")
  expect_s3_class(lif_plot_all(lif, ncol = 3), "ggplot")
  l <- lif_plot_all(lif, layout = "list")
  expect_length(l, 12); expect_s3_class(l[["LIF-01"]], "ggplot")
  expect_s3_class(lif_overview(lif, "LIF-05"), "patchwork")
  expect_s3_class(lif_overview(lif, "LIF-05", channels = character()), "patchwork")
})

test_that("lif_plot_all can write a PNG", {
  d <- withr::local_tempdir()
  f <- file.path(d, "sub", "all.png")
  expect_message(lif_plot_all(lif, output_file = f, width = 6, height = 4, dpi = 60), "Written")
  expect_true(file.exists(f))
})

test_that("qc_compare plots only changed borings and warns on mismatched sets", {
  ed <- suppressMessages(lif_editor(lif, "LIF-03", top = 0, bottom = 2))
  expect_message(p <- qc_compare(lif, ed), "1 boring\\(s\\) with changes plotted, 11 unchanged")
  suppressMessages(suppressWarnings(qc_compare(lif, ed)))
  expect_named(p, "LIF-03")
  expect_s3_class(p[[1]], "ggplot")
  suppressMessages(expect_warning(qc_compare(lif, ed[ed$boring != "LIF-01", ]), "not 'edited'"))
})

test_that("boring_map builds with and without options", {
  expect_s3_class(boring_map(lif), "ggplot")
  expect_s3_class(boring_map(lif, depth_min = 10, depth_max = 20, use_instrument_color = TRUE,
                             site_name = "x", figure_date = "2026-01-01", preparer = "me",
                             crs_label = "EPSG:0000", repel = FALSE), "ggplot")
  nd <- lif; nd$signal <- 0
  expect_s3_class(boring_map(nd), "ggplot")
  expect_error(boring_map(lif, basemap = list()), "lifr_basemap")
  expect_error(boring_map(lif[, c("boring", "depth", "signal")]), "missing required")
})

test_that("depth_slice_map names unsampled borings and validates the range", {
  expect_s3_class(depth_slice_map(lif, c(10, 20)), "ggplot")
  expect_message(depth_slice_map(lif, c(36, 40)), "no usable readings")
  expect_warning(depth_slice_map(lif, c(100, 200)), "no readings")
  expect_error(depth_slice_map(lif, c(20, 10)), "top < bottom")
})

test_that("charts return ggplots or NULL when a channel is absent", {
  expect_s3_class(chart_max_response(lif), "ggplot")
  expect_s3_class(chart_peak_by_boring(lif), "ggplot")
  expect_s3_class(chart_hp_histogram(lif), "ggplot")
  expect_s3_class(chart_ec_histogram(lif), "ggplot")
  bare <- lif[, c("boring", "depth", "signal")]
  expect_null(chart_hp_histogram(bare)); expect_null(chart_ec_histogram(bare))
  expect_null(chart_max_response(data.frame(x = 1)))
  d <- withr::local_tempdir()
  files <- export_site_charts(lif, d, prefix = "t", quiet = TRUE)
  expect_length(files, 4)
  expect_true(all(file.exists(files)))
})

test_that("theme_lifr is a theme and the basemap bbox pads to a minimum extent", {
  expect_s3_class(theme_lifr(), "theme")
  bb <- lifr:::.basemap_bbox(c(0, 10), c(0, 10))
  expect_gte(bb$xmax - bb$xmin, 400)
  bm <- structure(list(image = array(runif(3 * 40 * 40), c(40, 40, 3)),
                       xmin = 0, xmax = 100, ymin = 0, ymax = 100, attribution = "t"),
                  class = "lifr_basemap")
  cr <- lifr:::.crop_basemap(bm, c(25, 75), c(25, 75))
  expect_lt(dim(cr$image)[1], 40)
  expect_s3_class(boring_map(transform(lif, easting = easting - 1000 + 40,
                                       northing = northing - 2000 + 40), basemap = bm),
                  "ggplot")
})
