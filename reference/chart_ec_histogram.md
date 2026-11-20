# Chart: distribution of electrical conductivity

Pooled `ec` across all borings. Exact-zero readings are treated as not
recorded rather than as 0 mS/m and are excluded with their count in the
caption; the axis is bounded at a round value just above the 99th
percentile (capped at five times the median) so a few conductive spikes
cannot bury the bulk of the distribution. Readings beyond the bound are
left out of the histogram and their count and maximum are stated in the
caption.

## Usage

``` r
chart_ec_histogram(data)
```

## Arguments

- data:

  A [lif_data](https://mjorden.github.io/lifr/reference/lif_data.md)
  frame with an `ec` column.

## Value

A ggplot, or `NULL` with fewer than 10 positive readings.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
chart_ec_histogram(lif)
```
