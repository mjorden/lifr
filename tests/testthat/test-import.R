test_that("lif_read canonicalises known channels and keeps every other column", {
  d <- withr::local_tempdir(); write_tiny_site(d)
  x <- lif_read(file.path(d, "B-1.lif.dat.txt"))
  expect_equal(names(x)[1:3], c("depth", "signal", "boring"))
  expect_true(all(c("ec", "hp", "color", "extra_thing") %in% names(x)))
  expect_equal(x$boring, rep("B-1", 4))
  expect_equal(x$signal, c(0, 5, 20, 2))
  expect_equal(x$ec, c(8, 9, 10, 11))
  expect_equal(x$color, c("#B0B0B0", "#6B8E23", "#E07B30", "#6B8E23"))
  expect_equal(x$extra_thing, c("a", "b", "c", "d"))
})

test_that("lif_read reads comma-delimited logs and errors on non-numeric signal", {
  d <- withr::local_tempdir()
  utils::write.csv(data.frame(Depth = 1:3, Signal = c(1, 2, 3)),
                   file.path(d, "C-1.lif.dat.csv"), row.names = FALSE)
  x <- lif_read(file.path(d, "C-1.lif.dat.csv"))
  expect_equal(x$boring, rep("C-1", 3))
  expect_equal(x$signal, c(1, 2, 3))

  writeLines(c("Depth\tSignal", "1\tabc", "2\t3"), file.path(d, "bad.lif.dat.txt"))
  expect_error(lif_read(file.path(d, "bad.lif.dat.txt")), "non-numeric")
  expect_error(lif_read(file.path(d, "nope.lif.dat.txt")), "not found")
})

test_that("lif_read handles headerless legacy layouts", {
  d <- withr::local_tempdir()
  m11 <- cbind(seq(0.5, 2, 0.5), c(0, 1, 5, 2), 1, 2, 3, 4, 0.5, 8, 0.5, 0, "B0B0B0")
  utils::write.table(m11, file.path(d, "L-1.lif.dat.txt"), sep = "\t",
                     quote = FALSE, row.names = FALSE, col.names = FALSE)
  x <- lif_read(file.path(d, "L-1.lif.dat.txt"), legacy = TRUE)
  expect_true(all(c("depth", "signal", "ch1", "ch4", "ec", "color") %in% names(x)))
  expect_equal(x$ec, rep(8, 4))
  expect_equal(x$signal, c(0, 1, 5, 2))

  m16 <- cbind(m11, 0.5, 1, 2, c(3, 4, 5, 6), 7)
  utils::write.table(m16, file.path(d, "L-2.lif.dat.txt"), sep = "\t",
                     quote = FALSE, row.names = FALSE, col.names = FALSE)
  y <- lif_read(file.path(d, "L-2.lif.dat.txt"), legacy = TRUE)
  expect_equal(y$hp, c(3, 4, 5, 6))

  utils::write.table(m11[, 1:5], file.path(d, "L-3.lif.dat.txt"), sep = "\t",
                     quote = FALSE, row.names = FALSE, col.names = FALSE)
  expect_error(lif_read(file.path(d, "L-3.lif.dat.txt"), legacy = TRUE), "expected 11")
})

test_that("lif_import joins locations, drops unmatched borings loudly, keeps extras", {
  d <- withr::local_tempdir(); write_tiny_site(d)
  suppressMessages(expect_message(x <- lif_import(d), "Locations with no log file"))
  expect_s3_class(x, "lif_data")
  expect_equal(names(x)[1:9], c("easting", "northing", "depth", "signal", "boring",
                                "msl", "ec", "hp", "color"))
  expect_true("extra_thing" %in% names(x))
  expect_equal(nrow(x), 7)
  expect_equal(unique(x$easting[x$boring == "B-1"]), 100)
  expect_equal(unique(x$msl[x$boring == "B-2"]), 45)
})

test_that("lif_import warns when a log has no locations row and stops when none match", {
  d <- withr::local_tempdir(); write_tiny_site(d)
  utils::write.csv(data.frame(boring = "B-1", easting = 1, northing = 2, msl = 3),
                   file.path(d, "locations.csv"), row.names = FALSE)
  expect_warning(x <- lif_import(d, verbose = FALSE), "no locations row.*B-2")
  expect_equal(unique(x$boring), "B-1")

  utils::write.csv(data.frame(boring = c("Z1", "Z2"), easting = 1, northing = 2, msl = 3),
                   file.path(d, "locations.csv"), row.names = FALSE)
  expect_error(lif_import(d, verbose = FALSE), "no boring in the logs matched")
})

test_that("lif_import works without a locations file and with locations_file = FALSE", {
  d <- withr::local_tempdir(); write_tiny_site(d, with_locations = FALSE)
  suppressMessages(expect_message(x <- lif_import(d), "without coordinates"))
  expect_false("easting" %in% names(x))
  expect_equal(nrow(x), 7)
  d2 <- withr::local_tempdir(); write_tiny_site(d2)
  y <- lif_import(d2, locations_file = FALSE, verbose = FALSE)
  expect_false("msl" %in% names(y))
})

test_that("lif_import NA-fills when files disagree on columns and warns", {
  d <- withr::local_tempdir(); write_tiny_site(d)
  writeLines(c("Depth\tSignal", "1\t4", "2\t6"), file.path(d, "B-2.lif.dat.txt"))
  expect_warning(x <- lif_import(d, verbose = FALSE), "do not share one column set")
  expect_true(all(is.na(x$ec[x$boring == "B-2"])))
  expect_false(any(is.na(x$ec[x$boring == "B-1"])))
})

test_that("lif_import errors on a missing directory or no matching files", {
  expect_error(lif_import(file.path(tempdir(), "definitely-missing")), "does not exist")
  d <- withr::local_tempdir()
  expect_error(lif_import(d), "no files matching")
})

test_that("read_locations validates columns, uniqueness, and numeric coordinates", {
  d <- withr::local_tempdir()
  f <- file.path(d, "locations.csv")
  utils::write.csv(data.frame(Boring = c("A", "B"), Easting = 1:2, Northing = 3:4, MSL = 5:6), f,
                   row.names = FALSE)
  loc <- read_locations(f)
  expect_equal(names(loc), c("boring", "easting", "northing", "msl"))
  utils::write.csv(data.frame(boring = c("A", "A"), easting = 1:2, northing = 3:4, msl = 5:6), f,
                   row.names = FALSE)
  expect_error(read_locations(f), "more than once")
  utils::write.csv(data.frame(boring = "A", easting = "x", northing = 3, msl = 5), f,
                   row.names = FALSE)
  expect_error(read_locations(f), "not numeric")
  utils::write.csv(data.frame(boring = "A", easting = 1), f, row.names = FALSE)
  expect_error(read_locations(f), "missing required column")
})

test_that("the bundled demo imports with all four channels", {
  lif <- demo_lif()
  expect_s3_class(lif, "lif_data")
  expect_equal(length(unique(lif$boring)), 12)
  expect_true(all(c("signal", "ec", "hp", "color") %in% names(lif)))
  expect_false(anyNA(lif$easting))
})
