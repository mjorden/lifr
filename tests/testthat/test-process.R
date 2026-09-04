test_that("hp_correction subtracts the hydrostatic column below the water table", {
  d <- data.frame(boring = "A", depth = c(0, 10, 20), signal = 0, hp = c(5, 5, 5))
  expect_message(x <- hp_correction(d, water_table = 10), NA)
  expect_equal(x$hp, c(5, 5, 5 - 0.433 * 10))
  expect_match(edit_history(x)$notes, "water_table=10")
  expect_message(y <- hp_correction(d), "not supplied")
  expect_equal(y$hp, 5 - 0.433 * c(0, 10, 20))

  d2 <- rbind(d, transform(d, boring = "B"))
  z <- hp_correction(d2, water_table = c(A = 10, B = 0))
  expect_equal(z$hp[z$boring == "B"], 5 - 0.433 * c(0, 10, 20))
  expect_error(hp_correction(d2, water_table = c(A = 10)), "no entry for boring")
  expect_error(hp_correction(d, water_table = -1), "non-negative")
  expect_error(hp_correction(d, water_table = c(1, 2)), "single site-wide")
  expect_error(hp_correction(d[, c("boring", "depth")]), "missing required")
  expect_message(hp_correction(transform(d, hp = NA_real_)), "nothing to correct|no hp")
})

test_that("re_feet integrates signal over depth per boring", {
  d <- data.frame(boring = rep(c("A", "B"), each = 3), depth = rep(c(0, 1, 2), 2),
                  signal = c(0, 10, 0, 2, 2, 2), easting = rep(c(1, 2), each = 3),
                  northing = 0, msl = 100)
  rf <- re_feet(d)
  expect_equal(rf$re_feet[rf$boring == "A"], 10)
  expect_equal(rf$re_feet[rf$boring == "B"], 4)
  expect_equal(rf$peak_depth[rf$boring == "A"], 1)
  expect_equal(rf$easting, c(1, 2))
  d$signal[1] <- -1
  expect_warning(re_feet(d), "negative signal")
  # unsorted depth gives the same integral
  expect_equal(suppressWarnings(re_feet(d[c(3, 1, 2, 6, 5, 4), ]))$re_feet[2], 4)
})

test_that("lif_downsample thins uniformly, preserves peaks, and records an edit", {
  lif <- demo_lif()
  thin <- suppressMessages(lif_downsample(lif, target_interval = 1))
  expect_lt(nrow(thin), nrow(lif) / 3)
  h <- edit_history(thin)
  expect_equal(h$fn, "lif_downsample")
  expect_equal(h$n_rows_changed, nrow(lif) - nrow(thin))
  keep <- suppressMessages(lif_downsample(lif, target_interval = 2, preserve_above = 20))
  expect_true(all(lif$depth[lif$signal > 20] %in% keep$depth))
  expect_error(lif_downsample(lif, target_interval = 0), "positive number")
})
