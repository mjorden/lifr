test_that("process_site runs end to end and writes HTML and Markdown reports", {
  out <- withr::local_tempdir()
  site <- process_site(demo_dir(), output_dir = out, site_name = "Test Site",
                       corrections = list(zero_shallow = 1, hp = list(water_table = 5)),
                       report_formats = c("html", "md"), quiet = TRUE)
  expect_s3_class(site, "lif_site")
  expect_s3_class(site$data, "lif_data")
  expect_equal(site$log$step, c("import", "correct", "correct", "charts"))
  expect_gte(nrow(site$edits), 13)
  expect_length(site$charts, 4)
  expect_true(file.exists(site$reports$html))
  expect_true(file.exists(site$reports$md))
  expect_match(basename(site$reports$html), "^test_site_report\\.html$")
  txt <- capture.output(print(site))
  expect_match(txt[1], "^<lif_site> Test Site")

  html <- paste(readLines(site$reports$html, warn = FALSE), collapse = "\n")
  expect_match(html, "<!doctype html>")
  expect_match(html, "data-tab='logs'")
  expect_match(html, "Edit &amp; change log")
  expect_match(html, "Data inventory")
  expect_match(html, "class='badge'")
  expect_no_match(html, "<script src=")
  expect_gt(length(gregexpr("<img class='fig'", html)[[1]]), 10)

  md <- paste(readLines(site$reports$md, warn = FALSE), collapse = "\n")
  expect_match(md, "## Summary")
  expect_match(md, "### Peak response by boring")
  expect_match(md, "### Edit & change log")
  expect_true(file.exists(file.path(out, "test_site_map_response.png")))
})

test_that("process_site applies an edits CSV and validates its arguments", {
  out <- withr::local_tempdir()
  f <- file.path(out, "edits.csv")
  utils::write.csv(data.frame(boring = c("*", "LIF-02"), action = c("delete", "keep"),
                              top = c(0, 6), bottom = c(1, 28)), f, row.names = FALSE)
  site <- process_site(demo_dir(), edits = f, output_dir = out, report = FALSE,
                       charts = FALSE, quiet = TRUE)
  expect_equal(nrow(site$edits), 2)
  expect_true("edits" %in% site$log$step)
  expect_length(site$reports, 0); expect_length(site$charts, 0)
  chg <- lifr:::.log_change_summary(site)
  expect_true(all(chg$changed))
  expect_match(chg$label[chg$boring == "LIF-02"], "28")

  expect_error(process_site(demo_dir(), corrections = list(bogus = 1)), "unknown corrections")
  expect_error(process_site(demo_dir(), response_thresholds = c(1, NA)), "finite numbers")
  expect_error(process_site(demo_dir(), report_formats = "docx"), "should be one of")
})

test_that("site_report re-renders from the object and rejects other inputs", {
  out <- withr::local_tempdir()
  site <- process_site(demo_dir(), output_dir = out, report = FALSE, quiet = TRUE,
                       date_suffix = TRUE)
  expect_match(site$meta$prefix, "_[0-9]{6}$")
  r <- site_report(site, formats = "md", output_dir = out, file_prefix = "again", quiet = TRUE)
  expect_named(r, "md")
  expect_true(file.exists(file.path(out, "again_report.md")))
  expect_error(site_report(list()), "must be a lif_site")
})

test_that("an unedited site renders single input logs and no filter", {
  out <- withr::local_tempdir()
  site <- process_site(demo_dir(), output_dir = out, report_formats = "html",
                       charts = FALSE, quiet = TRUE)
  html <- paste(readLines(site$reports$html, warn = FALSE), collapse = "\n")
  expect_match(html, "none changed by the pipeline")
  expect_no_match(html, "id='chgonly'")
  expect_match(html, "0 edits recorded")
})

test_that("the PDF path either renders or degrades with a warning", {
  out <- withr::local_tempdir()
  site <- process_site(demo_dir(), output_dir = out, report = FALSE, charts = FALSE,
                       quiet = TRUE)
  msgs <- character(0)
  r <- withCallingHandlers(
    site_report(site, formats = "pdf", output_dir = out, quiet = TRUE),
    warning = function(w) {
      msgs <<- c(msgs, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
  expect_true("md" %in% names(r))
  expect_true("logs_pdf" %in% names(r))
  expect_true(file.exists(r$logs_pdf))
  # No warning other than a missing PDF toolchain is acceptable.
  expect_true(all(grepl("PDF|LaTeX", msgs)),
              info = paste("unexpected warning(s):", paste(msgs, collapse = " | ")))
  if (is.null(r$pdf)) expect_true(any(grepl("PDF", msgs)))
  else expect_true(file.exists(r$pdf))
})

test_that("a site without coordinates still reports", {
  d <- withr::local_tempdir(); write_tiny_site(d, with_locations = FALSE)
  out <- withr::local_tempdir()
  site <- process_site(d, output_dir = out, report_formats = "html", charts = FALSE,
                       quiet = TRUE)
  html <- paste(readLines(site$reports$html, warn = FALSE), collapse = "\n")
  expect_match(html, "no coordinates joined")
  expect_match(html, "extra thing|extra_thing")
})
