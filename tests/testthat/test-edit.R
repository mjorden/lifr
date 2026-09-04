tiny <- function() new_lif_data(data.frame(
  boring = rep(c("A", "B"), each = 5), depth = rep(1:5, 2),
  signal = c(1, 2, 3, 4, 5, 10, 20, 30, 40, 50)))

test_that("lif_editor zeroes the window and records one audit row per interval", {
  x <- suppressMessages(lif_editor(tiny(), "A", top = 2, bottom = 3))
  expect_equal(x$signal[x$boring == "A"], c(1, 0, 0, 4, 5))
  expect_equal(x$signal[x$boring == "B"], c(10, 20, 30, 40, 50))
  h <- edit_history(x)
  expect_equal(nrow(h), 1)
  expect_equal(h$fn, "lif_editor"); expect_equal(h$boring, "A")
  expect_equal(h$n_rows_changed, 2L)
  expect_s3_class(x, "edited_data")

  y <- suppressMessages(lif_editor(tiny(), "B", delete = list(c(1, 1), c(4, 5)), value = NA))
  expect_equal(y$signal[y$boring == "B"], c(NA, 20, 30, NA, NA))
  expect_equal(nrow(edit_history(y)), 2)
})

test_that("lif_editor guards its arguments", {
  expect_error(lif_editor("A", "A"), "expected a data frame")
  expect_error(suppressMessages(lif_editor(tiny(), "Z", top = 1)), "Valid borings: A, B")
  expect_error(lif_editor(tiny(), "A", top = 1, delete = list(c(1, 2))), "not both")
  expect_error(lif_editor(tiny(), "A", top = 5, bottom = 1), "less than or equal")
  expect_warning(suppressMessages(lif_editor(tiny(), "A")), "ENTIRE boring")
  expect_message(p <- lif_editor(tiny(), "A", top = 1, bottom = 2, preview = TRUE), "PREVIEW")
  expect_null(attr(p, "edits"))
  expect_equal(p$signal, tiny()$signal)
})

test_that("lif_editor_bulk applies to every boring with one audit row", {
  x <- suppressMessages(lif_editor_bulk(tiny(), top = 1, bottom = 2, verbose = FALSE))
  expect_equal(x$signal, c(0, 0, 3, 4, 5, 0, 0, 30, 40, 50))
  h <- edit_history(x)
  expect_true(is.na(h$boring)); expect_equal(h$n_rows_changed, 4L)
  expect_warning(suppressMessages(lif_editor_bulk(tiny(), verbose = FALSE)), "ENTIRE dataset")
})

test_that("lif_zero_shallow and lif_zero_below_threshold", {
  x <- suppressMessages(lif_zero_shallow(tiny(), depth = 2))
  expect_equal(x$signal, c(0, 0, 3, 4, 5, 0, 0, 30, 40, 50))
  expect_equal(nrow(edit_history(x)), 2)
  y <- suppressMessages(lif_zero_shallow(tiny(), depth = 2, borings = "B"))
  expect_equal(y$signal[y$boring == "A"], 1:5)

  z <- suppressMessages(lif_zero_below_threshold(tiny(), threshold = 25))
  expect_equal(z$signal, c(0, 0, 0, 0, 0, 0, 0, 30, 40, 50))
  expect_match(edit_history(z)$notes, "threshold=25")
  w <- tiny(); w$signal[1] <- NA
  w <- suppressMessages(lif_zero_below_threshold(w, threshold = 25))
  expect_true(is.na(w$signal[1]))
  expect_equal(edit_history(w)$n_rows_changed, 6L)
})

test_that("lif_keep zeroes outside the window and writes a parseable note", {
  x <- suppressMessages(lif_keep(tiny(), "B", top = 2, bottom = 4))
  expect_equal(x$signal[x$boring == "B"], c(0, 20, 30, 40, 0))
  h <- edit_history(x)
  expect_equal(h$n_rows_changed, 2L)
  expect_match(h$notes, "^kept 2-4 ft; zeroed")
  expect_equal(lifr:::.parse_kept_windows(h$notes), list(c(2, 4)))

  y <- suppressMessages(lif_keep(tiny(), "B", keep = list(c(1, 1), c(4, 5))))
  expect_equal(y$signal[y$boring == "B"], c(10, 0, 0, 40, 50))
  expect_equal(lifr:::.parse_kept_windows(edit_history(y)$notes), list(c(1, 1), c(4, 5)))
  expect_error(lif_keep(tiny(), "B"), "requires at least one")
  expect_error(lif_keep(tiny(), "B", top = 1, keep = list(c(1, 2))), "not both")
})

test_that("lif_apply_edits applies rows in order, handles '*' and validate", {
  plan <- data.frame(boring = c("*", "A", "B"), action = c("delete", "keep", "clean"),
                     top = c(0, 3, 5), bottom = c(1, NA, NA))
  x <- suppressMessages(lif_apply_edits(tiny(), plan))
  expect_equal(x$signal[x$boring == "A"], c(0, 0, 3, 4, 5))
  expect_equal(x$signal[x$boring == "B"], c(0, 20, 30, 40, 0))
  h <- edit_history(x)
  expect_equal(h$fn, c("lif_editor_bulk", "lif_keep", "lif_editor"))
  expect_true(is.na(h$boring[1]))

  d <- withr::local_tempdir()
  f <- file.path(d, "edits.csv")
  utils::write.csv(plan, f, row.names = FALSE)
  y <- suppressMessages(lif_apply_edits(tiny(), f))
  expect_equal(y$signal, x$signal)

  out <- capture.output(
    expect_message(v <- lif_apply_edits(tiny(), plan, validate = TRUE), "Validation summary"))
  expect_true(any(grepl("n_rows_affected", out)))
  expect_null(attr(v, "edits"))
})

test_that("lif_apply_edits rejects bad plans before touching the data", {
  expect_error(lif_apply_edits(tiny(), data.frame(x = 1)), "'boring' column")
  expect_error(lif_apply_edits(tiny(), data.frame(boring = "Z", top = 1)), "boring 'Z' not found")
  expect_error(lif_apply_edits(tiny(), data.frame(boring = "A", action = "explode")),
               "unknown action")
  expect_error(lif_apply_edits(tiny(), data.frame(boring = "*", action = "keep", top = 1)),
               "not supported with")
  expect_error(lif_apply_edits(tiny(), data.frame(boring = "*")), "wipe the dataset")
  expect_error(lif_apply_edits(tiny(), data.frame(boring = "A", top = 4, bottom = 2)),
               "top \\(4\\) > bottom")
  expect_error(lif_apply_edits(tiny(), file.path(tempdir(), "nope.csv")), "not found")
  expect_message(z <- lif_apply_edits(tiny(), data.frame(boring = character())), "No edits")
})

test_that("edit history accessors save, clear, and rescue", {
  x <- suppressMessages(lif_editor(tiny(), "A", top = 1, bottom = 1))
  d <- withr::local_tempdir()
  f <- file.path(d, "h.csv")
  expect_message(edit_history_save(x, f), "written")
  expect_equal(nrow(utils::read.csv(f)), 1)
  expect_error(edit_history_save(tiny(), f), "No edit history")
  expect_message(e <- edit_history(tiny()), "No edit history")
  expect_equal(nrow(e), 0)

  cleared <- edit_history_clear(x)
  expect_null(attr(cleared, "edits")); expect_false(inherits(cleared, "edited_data"))

  saved <- lif_get_edits(x)
  sub <- x[x$boring == "A", ]
  sub <- lif_set_edits(sub, saved)
  expect_equal(nrow(edit_history(sub)), 1); expect_s3_class(sub, "edited_data")
  expect_false(inherits(lif_set_edits(sub, NULL), "edited_data"))
})
