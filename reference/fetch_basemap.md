# Fetch public-domain aerial imagery for a site

Downloads a USGS National Map imagery tile covering the boring cluster
(padded) for use as a
[`boring_map()`](https://mjorden.github.io/lifr/reference/boring_map.md)
underlay. Needs the `sf` and `png` packages, network access, and a site
inside US coverage; any failure returns `NULL` with a warning so callers
degrade gracefully.

## Usage

``` r
fetch_basemap(data, crs, pad_frac = 0.3, px = 1024L, timeout = 30)
```

## Arguments

- data:

  A data frame with `easting` and `northing` in projected coordinates.

- crs:

  The projected coordinate reference system of the coordinates: an EPSG
  code or anything
  [`sf::st_crs()`](https://r-spatial.github.io/sf/reference/st_crs.html)
  accepts (for example `3452`, NAD83 Louisiana South ftUS). A geographic
  (lon/lat) CRS is rejected.

- pad_frac:

  Padding added around the site extent on each side, as a fraction of
  the extent. Default 0.30.

- px:

  Pixel width of the tile; height follows the aspect ratio.

- timeout:

  Seconds allowed for the download.

## Value

A `lifr_basemap` list (`image`, `xmin`, `xmax`, `ymin`, `ymax`,
`attribution`) or `NULL`.

## Examples

``` r
if (FALSE) { # \dontrun{
bm <- fetch_basemap(lif, crs = 3452)
boring_map(lif, basemap = bm)
} # }
```
