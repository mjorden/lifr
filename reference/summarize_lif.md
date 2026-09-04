# Summarise a LIF channel for QA reporting

Standard site-level, per-boring, per-threshold, and per-depth-zone
statistics for `signal` (or another numeric channel), returned as a list
of data frames so reports and dashboards render the same numbers.

## Usage

``` r
summarize_lif(
  data,
  channel = "signal",
  thresholds = NULL,
  depth_bins = c(0, 5, 10, 15, 20, Inf),
  quantiles = c(0.05, 0.25, 0.5, 0.75, 0.95),
  detection_limit = 0,
  sort_by = c("peak", "input"),
  plot = FALSE
)
```

## Arguments

- data:

  A [lif_data](https://mjorden.github.io/lifr/reference/lif_data.md)
  frame.

- channel:

  Column to summarise. Default `"signal"`; `"ec"` and `"hp"` also work.

- thresholds:

  Threshold values for `$by_threshold`. `NULL` uses a unit-appropriate
  default (`c(1, 2, 5, 10, 50)` %RE for signal).

- depth_bins:

  Break points (ft) for `$by_depth_zone`; the last may be `Inf`.

- quantiles:

  Probabilities for `$quantiles`.

- detection_limit:

  Minimum value counted as a detection in `pct_detect`. Default 0.

- sort_by:

  Order of `$by_boring`: `"peak"` (descending, default) or `"input"`
  (first-appearance order).

- plot:

  Logical. Also print a lollipop chart of peak signal per boring (see
  [`chart_peak_by_boring()`](https://mjorden.github.io/lifr/reference/chart_peak_by_boring.md)).

## Value

A list: `overview` (one row: `n_borings`, `n_samples`, `min`, `mean`,
`geom_mean`, `geom_mean_n_excluded`, `median`, `max`, `pct_detect`),
`by_boring` (`boring`, `n`, `peak`, `peak_depth`, `mean`, `geom_mean`,
`geom_mean_n_excluded`, `p50`, `p95`), `by_threshold` (`threshold`,
`units`, `n_samples_above`, `pct_samples_above`, `n_borings_above`,
`pct_borings_above`), `by_depth_zone` (`depth_zone`, `n`, `pct_detect`,
`p50`, `p95`), and `quantiles` (one row, `channel` plus one column per
probability).

## Geometric mean

LIF response is right-skewed, so the geometric mean is reported beside
the arithmetic mean. It is defined over positive values only;
`geom_mean_n_excluded` counts the zeros and negatives left out.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
qa <- summarize_lif(lif)
qa$overview
#>   n_borings n_samples   min     mean geom_mean geom_mean_n_excluded median
#> 1        12      1489 0.001 4.796974 0.5000454                    0  0.265
#>      max pct_detect
#> 1 88.607        100
qa$by_boring
#>    boring   n   peak peak_depth       mean  geom_mean geom_mean_n_excluded
#> 1  LIF-11 116 88.607      16.75 17.4281552 2.12999620                    0
#> 2  LIF-10 110 82.625      16.75 11.9499182 2.06925613                    0
#> 3  LIF-06 150 49.434      18.25  7.9871267 0.93680456                    0
#> 4  LIF-07 116 49.217      16.00 10.1069655 1.61645954                    0
#> 5  LIF-08 109 21.045      17.00  4.1576147 0.86528941                    0
#> 6  LIF-09 125 19.417      15.25  3.6465520 0.77629080                    0
#> 7  LIF-12 119 12.387      15.75  2.1056387 0.51082103                    0
#> 8  LIF-05 150  5.334      14.75  0.9744667 0.32150494                    0
#> 9  LIF-03 101  3.006       0.75  0.4334950 0.24115949                    0
#> 10 LIF-04 103  2.956       0.50  0.2241262 0.14409070                    0
#> 11 LIF-01 146  2.506       0.25  0.1629589 0.09988629                    0
#> 12 LIF-02 144  2.157       0.75  0.2754167 0.15499746                    0
#>       p50      p95
#> 1  2.5760 74.57925
#> 2  2.2865 45.34470
#> 3  0.3905 34.20915
#> 4  1.8255 39.87375
#> 5  0.8120 17.72540
#> 6  0.5120 14.93840
#> 7  0.3280  8.44400
#> 8  0.2640  3.97035
#> 9  0.2480  1.40400
#> 10 0.1590  0.52830
#> 11 0.1250  0.30050
#> 12 0.1790  0.82420
qa$by_threshold
#>   threshold units n_samples_above pct_samples_above n_borings_above
#> 1         1   %RE             475         31.900604              12
#> 2         2   %RE             396         26.595030              12
#> 3         5   %RE             288         19.341840               8
#> 4        10   %RE             204         13.700470               7
#> 5        50   %RE              20          1.343183               2
#>   pct_borings_above
#> 1         100.00000
#> 2         100.00000
#> 3          66.66667
#> 4          58.33333
#> 5          16.66667
```
