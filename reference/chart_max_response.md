# Chart: maximum LIF response by boring

One bar per boring at its peak %RE, filled with the emission colour
recorded at that depth (the product signature) when a `color` channel is
present. Borings whose peak is below the lowest threshold are drawn
grey: at that level the peak is background, so a product colour would
imply a signature that is not there.

## Usage

``` r
chart_max_response(data, thresholds = c(1, 5))
```

## Arguments

- data:

  A [lif_data](https://mjorden.github.io/lifr/reference/lif_data.md)
  frame.

- thresholds:

  Screening thresholds (%RE); the lowest greys out bars.

## Value

A ggplot, or `NULL` when there is no signal data.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
chart_max_response(lif)
```
