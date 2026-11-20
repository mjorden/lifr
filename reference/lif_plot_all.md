# Plot LIF depth profiles for every boring

Both layouts draw the per-reading emission-colour fill and the colour
strip left of zero when the frame carries a `color` channel, so a
small-multiples sheet shows which borings share a fluorescence
signature. Colour is decided per boring: a boring with a colour at any
depth gets the colour layers, the rest get the flat fill. All panels
share one signal axis, so a colour-less panel on a mixed sheet shows an
empty strip band.

## Usage

``` r
lif_plot_all(
  data,
  xmax = NULL,
  ymax = NULL,
  layout = c("facet", "list"),
  ncol = NULL,
  output_file = NULL,
  width = 12,
  height = 8,
  dpi = 200
)
```

## Arguments

- data:

  A [lif_data](https://mjorden.github.io/lifr/reference/lif_data.md)
  frame.

- xmax:

  Maximum depth shown (ft). Default: the deepest reading in `data`, so
  every boring shares one depth axis.

- ymax:

  Signal axis cap shared by all borings. `NULL` uses 5% above the site
  maximum so panels are comparable.

- layout:

  `"facet"` (default) returns one ggplot with a small multiple per
  boring; `"list"` returns a named list of single-boring plots from
  [`lif_plot()`](https://mjorden.github.io/lifr/reference/lif_plot.md).

- ncol:

  Facet columns for `layout = "facet"`; `NULL` lets ggplot2 choose.

- output_file:

  Optional PNG path for the facet plot.

- width, height, dpi:

  Passed to
  [`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html)
  when saving.

## Value

A ggplot (facet) or a named list of ggplots (list), invisibly when
saved.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
lif_plot_all(lif, ncol = 4)
```
