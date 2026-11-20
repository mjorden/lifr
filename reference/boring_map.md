# Plan-view map of boring locations sized by peak LIF signal

Each boring is a marker at its easting/northing, labelled with its name
and peak %RE. Marker **area** is proportional to peak signal, with a
size key, so the site's response pattern reads even in greyscale;
non-detects are hollow circles. Marker fill is a neutral blue unless
`use_instrument_color = TRUE`, which fills each marker with the emission
colour recorded at the depth of peak signal.

## Usage

``` r
boring_map(
  data,
  depth_min = NULL,
  depth_max = NULL,
  nd_threshold = 0,
  size_by_signal = TRUE,
  point_size = 4,
  use_instrument_color = FALSE,
  label_size = 2.4,
  repel = TRUE,
  seed = 42,
  signal_digits = 3,
  coord_units = "ft",
  title = NULL,
  site_name = NULL,
  figure_date = NULL,
  preparer = NULL,
  crs_label = NULL,
  north_arrow = TRUE,
  scale_bar = TRUE,
  basemap = NULL,
  min_extent = 100,
  output_file = NULL,
  width = 8,
  height = 7,
  dpi = 200,
  fill_floor = NULL
)
```

## Arguments

- data:

  A [lif_data](https://mjorden.github.io/lifr/reference/lif_data.md)
  frame with `easting` and `northing`.

- depth_min, depth_max:

  Optional depth window (ft); only readings inside it contribute to each
  boring's peak.

- nd_threshold:

  Peak signal at or below this value is a non-detect. Default 0; must be
  `>= 0` when `size_by_signal = TRUE` (the signal is non-negative).

- size_by_signal:

  Logical. When `TRUE` (default), marker **area** is proportional to the
  boring's peak signal
  ([`ggplot2::scale_size_area()`](https://ggplot2.tidyverse.org/reference/scale_size.html)),
  with a size key, so magnitude reads on greyscale prints; no minimum
  size is applied. Below about 1 % of the site peak the drawn dot is
  dominated by its 0.7 outline stroke and the on-map label carries the
  value. Suppress the key with `ggplot2::guides(size = "none")`. Set
  `FALSE` for constant-size markers.

- point_size:

  Reference marker diameter. With `size_by_signal = TRUE` the
  maximum-signal marker is drawn at **twice** this and marker area is
  proportional to peak signal below it; with `FALSE` every marker is
  drawn at exactly this. The hollow non-detect ring is not on the size
  scale and is drawn no larger than the smallest detect marker (at most
  half `point_size`). Default 4.

- use_instrument_color:

  Fill markers with the emission colour at peak depth. Default `FALSE`.

- label_size:

  Label font size. Default 2.4.

- repel:

  Use `ggrepel` for non-overlapping labels when installed.

- seed:

  Seed for reproducible label placement.

- signal_digits:

  Significant digits in the peak label.

- coord_units:

  Unit string for the axis titles and scale bar.

- title, site_name, figure_date, preparer, crs_label:

  Text for the title, subtitle, and caption lines. `NULL` omits each.

- north_arrow, scale_bar:

  Logical. Draw the north arrow (upper corner) and scale bar (lower
  corner); each is placed in the corner that overlaps the fewest
  borings.

- basemap:

  A `lifr_basemap` from
  [`fetch_basemap()`](https://mjorden.github.io/lifr/reference/fetch_basemap.md)
  drawn under the markers; labels switch to white with a dark halo.

- min_extent:

  Minimum width and height of the plan window, in coordinate units. A
  single boring or a collinear transect is padded to this extent so the
  panel, north arrow, and scale bar keep sensible proportions. Default
  100.

- output_file:

  Optional PNG path.

- width, height, dpi:

  Passed to
  [`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html).

- fill_floor:

  Screening floor (%RE), or `NULL` (default) for none. A detect whose
  peak is **strictly below** this value keeps its size and its detect
  status – the reading is real – but is filled the non-detect grey
  instead of the emission colour or neutral blue, and a caption line
  names the floor. This matches
  [`chart_max_response()`](https://mjorden.github.io/lifr/reference/chart_max_response.md),
  which greys a bar below its lowest screening threshold, so the two
  figures in one report agree about every boring (daktools \#801); `<`
  rather than `<=` in both, so a peak exactly at the floor is coloured
  in both.
  [`process_site()`](https://mjorden.github.io/lifr/reference/process_site.md)
  passes the report's lowest `response_thresholds` value.

## Value

A ggplot object.

## Reading the map

- Marker **area** is proportional to peak signal, so the response
  pattern reads in greyscale. The size key gives the site maximum and a
  quarter and a sixteenth of it; a marker at 1 % of the peak really is 1
  % of the peak's area, so a ring of weak detects cannot read as a broad
  plume.

- A **hollow circle** is a non-detect: no reading above `nd_threshold`
  in the depth window.

- With `fill_floor` set, a **grey filled** marker is a real detect whose
  peak is below the screening floor: sized like any other detect, but
  carrying no colour claim, as the bar chart's grey bars do.

- Marker **fill** is a neutral blue unless
  `use_instrument_color = TRUE`, which uses the emission colour recorded
  at the depth of peak signal. That colour is the product signature
  analysts read in the field; the caption says so whenever it is in use.

- The label under each marker is the boring name and its peak %RE.

## See also

[`depth_slice_map()`](https://mjorden.github.io/lifr/reference/depth_slice_map.md),
[`fetch_basemap()`](https://mjorden.github.io/lifr/reference/fetch_basemap.md),
[`vignette("plotting")`](https://mjorden.github.io/lifr/articles/plotting.md)

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
boring_map(lif)


# Product-signature colours, a depth window, and figure metadata
boring_map(lif, depth_min = 10, depth_max = 25, use_instrument_color = TRUE,
           site_name = "Demo site", figure_date = "2026-09-04",
           preparer = "Field team", crs_label = "NAD83 / Louisiana South (ftUS)")


# Uniform markers, no cartographic furniture
boring_map(lif, size_by_signal = FALSE, north_arrow = FALSE, scale_bar = FALSE)


if (FALSE) { # \dontrun{
# Over aerial imagery (needs sf, png, and network access)
bm <- fetch_basemap(lif, crs = 3452)
boring_map(lif, basemap = bm, output_file = "boring_map.png")
} # }
```
