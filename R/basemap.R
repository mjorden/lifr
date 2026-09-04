# Aerial-imagery underlay for boring_map() from the USGS National Map
# (public domain, no API key, US coverage). The tile is requested in WGS84
# and stretched onto the projected bounding box; over a site-scale extent the
# projection is effectively affine so the registration error is sub-pixel.

.basemap_attribution <- "Imagery courtesy of the U.S. Geological Survey"

.basemap_bbox <- function(easting, northing, pad_frac = 0.30, min_extent = 400) {
  xr <- range(easting, na.rm = TRUE); yr <- range(northing, na.rm = TRUE)
  pad <- max(diff(xr), diff(yr), min_extent / (1 + 2 * pad_frac)) * pad_frac
  xmin <- xr[1] - pad; xmax <- xr[2] + pad; ymin <- yr[1] - pad; ymax <- yr[2] + pad
  if ((xmax - xmin) < min_extent) {
    cx <- (xmin + xmax) / 2; xmin <- cx - min_extent / 2; xmax <- cx + min_extent / 2
  }
  if ((ymax - ymin) < min_extent) {
    cy <- (ymin + ymax) / 2; ymin <- cy - min_extent / 2; ymax <- cy + min_extent / 2
  }
  list(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax)
}

.basemap_wms_url <- function(west, south, east, north, width, height) {
  sprintf(paste0(
    "https://basemap.nationalmap.gov/arcgis/services/USGSImageryOnly/MapServer/WMSServer",
    "?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap&BBOX=%.8f,%.8f,%.8f,%.8f",
    "&SRS=EPSG:4326&WIDTH=%d&HEIGHT=%d&LAYERS=0&STYLES=&FORMAT=image/png&TRANSPARENT=FALSE"),
    west, south, east, north, as.integer(width), as.integer(height))
}

#' Fetch public-domain aerial imagery for a site
#'
#' Downloads a USGS National Map imagery tile covering the boring cluster
#' (padded) for use as a [boring_map()] underlay. Needs the `sf` and `png`
#' packages, network access, and a site inside US coverage; any failure
#' returns `NULL` with a warning so callers degrade gracefully.
#'
#' @param data A data frame with `easting` and `northing` in projected
#'   coordinates.
#' @param crs The projected coordinate reference system of the coordinates:
#'   an EPSG code or anything `sf::st_crs()` accepts (for example `3452`,
#'   NAD83 Louisiana South ftUS). A geographic (lon/lat) CRS is rejected.
#' @param pad_frac Padding added around the site extent on each side, as a
#'   fraction of the extent. Default 0.30.
#' @param px Pixel width of the tile; height follows the aspect ratio.
#' @param timeout Seconds allowed for the download.
#' @return A `lifr_basemap` list (`image`, `xmin`, `xmax`, `ymin`, `ymax`,
#'   `attribution`) or `NULL`.
#' @examples
#' \dontrun{
#' bm <- fetch_basemap(lif, crs = 3452)
#' boring_map(lif, basemap = bm)
#' }
#' @export
fetch_basemap <- function(data, crs, pad_frac = 0.30, px = 1024L, timeout = 30) {
  .check_required_cols(data, c("easting", "northing"), source = "data")
  if (all(is.na(data$easting)) || all(is.na(data$northing)))
    stop("fetch_basemap: easting/northing are all NA -- was a locations file joined?",
         call. = FALSE)
  for (pkg in c("sf", "png")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      warning("fetch_basemap: package '", pkg, "' is required; returning NULL.",
              call. = FALSE)
      return(NULL)
    }
  }
  crs_obj <- sf::st_crs(crs)
  if (isTRUE(sf::st_is_longlat(crs_obj)))
    stop("fetch_basemap: `crs` is geographic (lon/lat); easting/northing must be ",
         "projected coordinates (e.g. a State Plane EPSG code).", call. = FALSE)
  bb <- .basemap_bbox(data$easting, data$northing, pad_frac = pad_frac)
  tryCatch({
    corners <- sf::st_as_sf(data.frame(x = c(bb$xmin, bb$xmax, bb$xmin, bb$xmax),
                                       y = c(bb$ymin, bb$ymin, bb$ymax, bb$ymax)),
                            coords = c("x", "y"), crs = crs_obj)
    ll <- sf::st_coordinates(sf::st_transform(corners, 4326))
    aspect <- (bb$ymax - bb$ymin) / (bb$xmax - bb$xmin)
    width <- as.integer(px); height <- max(1L, as.integer(round(px * aspect)))
    url <- .basemap_wms_url(min(ll[, 1]), min(ll[, 2]), max(ll[, 1]), max(ll[, 2]),
                            width, height)
    tmp <- tempfile(fileext = ".png")
    on.exit(unlink(tmp), add = TRUE)
    old <- options(timeout = timeout); on.exit(options(old), add = TRUE)
    utils::download.file(url, tmp, mode = "wb", quiet = TRUE, method = "libcurl")
    if (file.info(tmp)$size < 1000L)
      stop("tile response too small (", file.info(tmp)$size, " bytes)")
    img <- png::readPNG(tmp)
    if (stats::sd(img) < 0.02)
      stop("tile is featureless -- the site is likely outside USGS imagery coverage")
    structure(list(image = img, xmin = bb$xmin, xmax = bb$xmax, ymin = bb$ymin,
                   ymax = bb$ymax, attribution = .basemap_attribution),
              class = "lifr_basemap")
  }, error = function(e) {
    warning("fetch_basemap: imagery fetch failed; continuing without a basemap.\n  ",
            conditionMessage(e), call. = FALSE)
    NULL
  })
}

# Crop a basemap tile to a projected window so it stays inside the panel
# when boring_map() draws with clip = "off".
.crop_basemap <- function(bm, xlim, ylim) {
  xlim <- c(max(min(xlim), bm$xmin), min(max(xlim), bm$xmax))
  ylim <- c(max(min(ylim), bm$ymin), min(max(ylim), bm$ymax))
  img <- bm$image; dims <- dim(img); nr <- dims[1]; nc <- dims[2]
  if (diff(xlim) <= 0 || diff(ylim) <= 0 || nr < 2L || nc < 2L) return(bm)
  col1 <- max(1L, floor((xlim[1] - bm$xmin) / (bm$xmax - bm$xmin) * nc) + 1L)
  col2 <- min(nc, ceiling((xlim[2] - bm$xmin) / (bm$xmax - bm$xmin) * nc))
  row1 <- max(1L, floor((bm$ymax - ylim[2]) / (bm$ymax - bm$ymin) * nr) + 1L)
  row2 <- min(nr, ceiling((bm$ymax - ylim[1]) / (bm$ymax - bm$ymin) * nr))
  if (col2 <= col1 || row2 <= row1) return(bm)
  out <- bm
  out$image <- if (length(dims) == 3L) img[row1:row2, col1:col2, , drop = FALSE]
               else img[row1:row2, col1:col2, drop = FALSE]
  out$xmin <- bm$xmin + (col1 - 1L) / nc * (bm$xmax - bm$xmin)
  out$xmax <- bm$xmin + col2 / nc * (bm$xmax - bm$xmin)
  out$ymax <- bm$ymax - (row1 - 1L) / nr * (bm$ymax - bm$ymin)
  out$ymin <- bm$ymax - row2 / nr * (bm$ymax - bm$ymin)
  out
}
