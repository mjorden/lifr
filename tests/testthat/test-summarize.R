test_that("summarize_lif returns the five tables with the documented columns", {
  s <- summarize_lif(demo_lif())
  expect_named(s, c("overview", "by_boring", "by_threshold", "by_depth_zone", "quantiles"))
  expect_equal(s$overview$n_borings, 12)
  expect_named(s$by_boring, c("boring", "n", "peak", "peak_depth", "mean", "geom_mean",
                              "geom_mean_n_excluded", "p50", "p95"))
  expect_true(!is.unsorted(rev(s$by_boring$peak)))
  expect_equal(s$by_threshold$threshold, c(1, 2, 5, 10, 50))
  expect_equal(unique(s$by_threshold$units), "%RE")
  expect_equal(s$by_depth_zone$depth_zone, c("0-5", "5-10", "10-15", "15-20", "20+"))
  expect_named(s$quantiles, c("channel", "p5", "p25", "p50", "p75", "p95"))
})

test_that("summarize_lif options: channel, thresholds, sort order, detection limit", {
  lif <- demo_lif()
  s <- summarize_lif(lif, channel = "hp", thresholds = c(1, 3))
  expect_equal(s$by_threshold$units, c("psi", "psi"))
  s2 <- summarize_lif(lif, sort_by = "input")
  expect_equal(s2$by_boring$boring, unique(lif$boring))
  expect_lt(summarize_lif(lif, detection_limit = 5)$overview$pct_detect,
            summarize_lif(lif)$overview$pct_detect)
  expect_error(summarize_lif(lif, channel = "nope"), "missing required")
})

test_that("geometric mean excludes non-positive values and reports the count", {
  d <- data.frame(boring = "A", depth = 1:4, signal = c(0, 1, 10, 100))
  s <- summarize_lif(d)
  expect_equal(s$overview$geom_mean, 10)
  expect_equal(s$overview$geom_mean_n_excluded, 1)
})
