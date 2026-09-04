# Synthetic LIF site generator. Used to build the bundled demo dataset and
# handy for examples, tests, and trying the package without field data.

# Emission-colour palette keyed to signal strength: grey below detection,
# then olive -> yellow -> orange -> red -> dark red with rising response.
.sim_color <- function(s) {
  breaks <- c(0, 0.5, 3, 12, 35, 60, Inf)
  cols <- c("#B0B0B0", "#6B8E23", "#D4C84A", "#E07B30", "#C03020", "#7B0010")
  cols[findInterval(s, breaks, rightmost.closed = TRUE)]
}

#' Simulate a synthetic LIF site
#'
#' Generates plausible LIF logs for a made-up site: irregular boring
#' positions over a rectangular area, a plume built from one or more
#' three-dimensional Gaussian lobes with log-normal noise, a hydrostatic HP
#' pressure profile with thin low-pressure sand layers, an EC profile that
#' rises inside the plume and drops in the sands, and an emission colour
#' keyed to signal strength. Written as one `.lif.dat.txt` per boring plus a
#' `locations.csv`, exactly the layout [lif_import()] reads, or returned as a
#' [lif_data] frame when `dir` is `NULL`. The data has no relation to any real
#' site.
#'
#' @param n_borings Number of borings. Default 12.
#' @param dir Directory to write into (created if missing). `NULL` returns
#'   the data frame without writing.
#' @param seed Random seed. Default 1.
#' @param extent Site width and height (ft). Default 200.
#' @param origin `c(easting, northing)` of the site's lower-left corner.
#' @param interval Depth sampling interval (ft). Default 0.25.
#' @param depth_range Range of boring total depths (ft), sampled uniformly.
#' @param lobes A list of plume lobes, each a list with `e`, `n` (plan
#'   position, ft), `elev` (core elevation, ft MSL), `sig_h`, `sig_v`
#'   (horizontal and vertical spread, ft), and `peak` (%RE). `NULL` uses two
#'   overlapping lobes near the centre of the site.
#' @param msl Mean ground-surface elevation (ft MSL). Default 150.
#' @param noise Log-normal noise standard deviation on the signal.
#' @param verbose Print the written file names.
#' @return With `dir = NULL`, a [lif_data] frame (with the locations joined).
#'   Otherwise the directory path, invisibly.
#' @examples
#' lif <- lif_simulate(n_borings = 6)
#' lif
#' boring_map(lif)
#'
#' d <- tempfile("site")
#' lif_simulate(n_borings = 4, dir = d, verbose = FALSE)
#' list.files(d)
#' @export
lif_simulate <- function(n_borings = 12, dir = NULL, seed = 1, extent = 200,
                         origin = c(1000, 2000), interval = 0.25,
                         depth_range = c(22, 40), lobes = NULL, msl = 150,
                         noise = 0.25, verbose = TRUE) {
  if (!is.numeric(n_borings) || n_borings < 1) stop("n_borings must be >= 1", call. = FALSE)
  set.seed(seed)
  n <- as.integer(n_borings)
  # Jittered grid so borings are irregular but never stacked.
  side <- ceiling(sqrt(n))
  cell <- extent / side
  grid <- expand.grid(i = seq_len(side) - 1, j = seq_len(side) - 1)[seq_len(n), ]
  locs <- data.frame(
    boring = sprintf("LIF-%02d", seq_len(n)),
    easting  = origin[1] + (grid$i + stats::runif(n, 0.2, 0.8)) * cell,
    northing = origin[2] + (grid$j + stats::runif(n, 0.2, 0.8)) * cell,
    msl = round(msl + stats::rnorm(n, 0, 0.6), 1),
    td  = round(stats::runif(n, depth_range[1], depth_range[2]) / interval) * interval,
    stringsAsFactors = FALSE)
  locs$easting <- round(locs$easting, 1); locs$northing <- round(locs$northing, 1)

  if (is.null(lobes)) {
    cx <- origin[1] + extent * 0.5; cy <- origin[2] + extent * 0.55
    lobes <- list(
      list(e = cx + 5,  n = cy + 8,  elev = msl - 15, sig_h = extent * 0.18, sig_v = 2.6, peak = 85),
      list(e = cx - 18, n = cy - 12, elev = msl - 19, sig_h = extent * 0.12, sig_v = 2.0, peak = 40))
  }
  sand_elevs <- msl - c(8, 14.5, 21); sand_w <- 0.8
  signal_at <- function(e, nn, z) {
    s <- 0
    for (lb in lobes) {
      dh <- sqrt(((e - lb$e)^2 + (nn - lb$n)^2)) / lb$sig_h
      dv <- (z - lb$elev) / lb$sig_v
      s <- s + lb$peak * exp(-0.5 * (dh^2 + dv^2))
    }
    s
  }
  sand_at <- function(z) max(vapply(sand_elevs, function(ze) exp(-0.5 * ((z - ze) / sand_w)^2),
                                    numeric(1)))

  rows <- lapply(seq_len(n), function(i) {
    L <- locs[i, ]
    depth <- seq(interval, L$td, by = interval)
    z <- L$msl - depth
    sig <- vapply(z, function(zz) signal_at(L$easting, L$northing, zz), numeric(1))
    sig <- sig * exp(stats::rnorm(length(sig), 0, noise)) + abs(stats::rnorm(length(sig), 0, 0.15))
    sig[depth < 1] <- sig[depth < 1] + stats::runif(sum(depth < 1), 0, 3)   # surface smear
    sig <- round(sig, 3)
    sand <- vapply(z, sand_at, numeric(1))
    hp <- 0.433 * pmax(0, depth - 6) + 2.5 * (1 - 0.7 * sand) +
          0.6 * sin(depth / 3) + stats::rnorm(length(depth), 0, 0.15)
    ec <- 9 + 4 * pmin(sig / 20, 1) - 3.5 * sand + 1.2 * sin(depth / 2.2) +
          stats::rnorm(length(depth), 0, 0.5)
    data.frame(depth = depth, signal = sig, ec = round(pmax(ec, 0.5), 2),
               hp = round(pmax(hp, 0), 2), color = .sim_color(sig),
               boring = L$boring, stringsAsFactors = FALSE)
  })
  data <- do.call(rbind, rows)

  if (is.null(dir)) {
    idx <- match(data$boring, locs$boring)
    data$easting <- locs$easting[idx]; data$northing <- locs$northing[idx]
    data$msl <- locs$msl[idx]
    return(new_lif_data(.order_lif_cols(data)))
  }
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  for (b in unique(data$boring)) {
    d <- data[data$boring == b, c("depth", "signal", "ec", "hp", "color")]
    names(d) <- c("Depth", "Signal", "EC.Value", "HP.PresDown", "color")
    f <- file.path(dir, paste0(b, ".lif.dat.txt"))
    utils::write.table(d, f, sep = "\t", quote = FALSE, row.names = FALSE)
    if (isTRUE(verbose)) message("wrote ", f)
  }
  utils::write.csv(locs[, c("boring", "easting", "northing", "msl")],
                   file.path(dir, "locations.csv"), row.names = FALSE)
  if (isTRUE(verbose)) message("wrote ", file.path(dir, "locations.csv"))
  invisible(dir)
}
