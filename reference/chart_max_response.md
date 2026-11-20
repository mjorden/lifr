# Chart: maximum LIF response by boring

One bar per boring at its peak %RE. Each bar has one of three kinds, and
the caption names only the ones actually drawn:

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

## Details

- **filled with the emission colour** recorded at the peak depth – the
  product signature – when the frame carries a valid colour for that
  boring;

- **hollow** (no fill, ink outline) when the peak is above the screening
  floor but the delivery carried no usable colour. A coloured fallback
  would read as a real signature, so the bar carries none, following the
  non-detect marker convention;

- **grey** when the peak is below the lowest threshold: at that level
  the peak is background, so a product colour would imply a signature
  that is not there.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
chart_max_response(lif)
```
