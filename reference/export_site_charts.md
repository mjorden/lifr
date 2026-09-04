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

Character vector of written paths, invisibly.

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
