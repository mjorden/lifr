test_that("new_lif_data validates the schema and is idempotent", {
  df <- data.frame(boring = "B1", Depth = 1:3, Signal = c(0, 5, 2))
  x <- new_lif_data(df)
  expect_s3_class(x, "lif_data")
  expect_equal(names(x), c("boring", "depth", "signal"))
  expect_identical(class(new_lif_data(x)), class(x))
  expect_error(new_lif_data(data.frame(boring = "B1", depth = 1)), "missing required")
  expect_error(new_lif_data("nope"), "must be a data frame")
})

test_that("compat_rename_legacy skips colliding renames with one warning", {
  df <- data.frame(Depth = 1, depth = 2, Signal = 3)
  expect_warning(out <- compat_rename_legacy(df), "collide")
  expect_true(all(c("Depth", "depth", "signal") %in% names(out)))
})

test_that("print methods summarise without error", {
  lif <- demo_lif()
  out <- capture.output(print(lif, n = 3))
  expect_match(out[1], "^<lif_data> 12 boring")
  expect_match(out[2], "channels: signal, ec, hp, color")
  ed <- suppressMessages(lif_editor_bulk(lif, top = 0, bottom = 1, verbose = FALSE))
  out2 <- capture.output(print(ed, n = 2))
  expect_match(out2[1], "^<edited_data> 1 edit")
  stripped <- ed; attr(stripped, "edits") <- NULL
  out3 <- capture.output(print(stripped, n = 2))
  expect_match(out3[1], "provenance was dropped")
})

test_that("summary.lif_data dispatches to summarize_lif", {
  s <- summary(demo_lif())
  expect_named(s, c("overview", "by_boring", "by_threshold", "by_depth_zone", "quantiles"))
})
