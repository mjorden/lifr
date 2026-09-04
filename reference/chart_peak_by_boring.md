# Chart: peak signal per boring as a lollipop

Borings sorted by peak value, one dot and stem each: the quickest read
of which borings dominate the site.

## Usage

``` r
chart_peak_by_boring(data, channel = "signal")
```

## Arguments

- data:

  A [lif_data](https://mjorden.github.io/lifr/reference/lif_data.md)
  frame.

- channel:

  Column to summarise. Default `"signal"`; `"ec"` and `"hp"` also work.

## Value

A ggplot object.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
chart_peak_by_boring(lif)
```
