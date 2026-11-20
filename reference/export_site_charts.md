# Write the site summary charts as PNG files

Writes whichever of
[`chart_max_response()`](https://mjorden.github.io/lifr/reference/chart_max_response.md),
[`chart_peak_by_boring()`](https://mjorden.github.io/lifr/reference/chart_peak_by_boring.md),
[`chart_hp_histogram()`](https://mjorden.github.io/lifr/reference/chart_hp_histogram.md),
and
[`chart_ec_histogram()`](https://mjorden.github.io/lifr/reference/chart_ec_histogram.md)
the data supports as `<prefix>_chart_<name>.png`.

## Usage

``` r
export_site_charts(
  data,
  output_dir = ".",
  prefix = "site",
  thresholds = c(1, 5),
  width = 7,
  height = 3.4,
  dpi = 150,
  quiet = FALSE
)
```

## Arguments

- data:

  A [lif_data](https://mjorden.github.io/lifr/reference/lif_data.md)
  frame.

- output_dir:

  Directory to write into (created if missing).

- prefix:

  Filename prefix. Default `"site"`.

- thresholds:

  Passed to
  [`chart_max_response()`](https://mjorden.github.io/lifr/reference/chart_max_response.md).

- width, height, dpi:

  `ggsave()` geometry.

- quiet:

  Suppress the per-file message.

## Value

Character vector of written paths, invisibly, carrying a `"failed"`
attribute: a data frame of `chart`, `stage` (`"build"` or `"save"`) and
`error` for every chart that could not be produced, or `NULL` when all
of them were.
[`process_site()`](https://mjorden.github.io/lifr/reference/process_site.md)
logs it.

## Failures are reported, not skipped

A builder returns `NULL` when the site has no data for that chart (no
`hp` channel, say), and that is a silent, expected skip. An **error**
inside a builder, or a `ggsave()` that cannot write the file, is
different: each raises a warning naming the chart and is recorded in the
`"failed"` attribute, and the remaining charts still render. Previously
both paths returned `NULL` and a thrown builder was indistinguishable
from an absent channel, so the report embedded the previous run's PNG
and the step log called the survivors the complete set. A stale file
left at the path of a chart that failed is deleted, so nothing
downstream reads it as current.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
out <- tempfile("charts")
export_site_charts(lif, out, quiet = TRUE)
list.files(out)
#> [1] "site_chart_ec_histogram.png"   "site_chart_hp_histogram.png"  
#> [3] "site_chart_max_response.png"   "site_chart_peak_by_boring.png"
```
