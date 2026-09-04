# Shared fixtures.

demo_dir <- function() system.file("extdata", "demo", package = "lifr")

demo_lif <- function() suppressMessages(lif_import(demo_dir(), verbose = FALSE))

# A tiny hand-built site: two borings with known values, written to a temp
# directory in the modern header layout.
write_tiny_site <- function(dir, with_locations = TRUE) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  b1 <- data.frame(Depth = c(0.5, 1, 1.5, 2), Signal = c(0, 5, 20, 2),
                   EC.Value = c(8, 9, 10, 11), HP.PresDown = c(1, 1.5, 2, 2.5),
                   color = c("B0B0B0", "6B8E23", "#E07B30", "6B8E23"),
                   Extra.Thing = c("a", "b", "c", "d"))
  b2 <- data.frame(Depth = c(0.5, 1, 1.5), Signal = c(1, 2, 3),
                   EC.Value = c(7, 7, 7), HP.PresDown = c(0.5, 0.6, 0.7),
                   color = c("B0B0B0", "B0B0B0", "B0B0B0"),
                   Extra.Thing = c("x", "y", "z"))
  utils::write.table(b1, file.path(dir, "B-1.lif.dat.txt"), sep = "\t",
                     quote = FALSE, row.names = FALSE)
  utils::write.table(b2, file.path(dir, "B-2.lif.dat.txt"), sep = "\t",
                     quote = FALSE, row.names = FALSE)
  if (with_locations)
    utils::write.csv(data.frame(boring = c("B-1", "B-2", "B-9"),
                                easting = c(100, 150, 999),
                                northing = c(200, 250, 999),
                                msl = c(50, 45, 40)),
                     file.path(dir, "locations.csv"), row.names = FALSE)
  invisible(dir)
}
