# Multi-channel overview of one boring

LIF signal beside whichever of `ec` and `hp` the boring recorded, on a
shared depth axis.

## Usage

``` r
lif_overview(
  data,
  borename,
  channels = c("ec", "hp"),
  depth_max = NULL,
  ymax = NULL
)
```

## Arguments

- data:

  A [lif_data](https://mjorden.github.io/lifr/reference/lif_data.md)
  frame.

- borename:

  Boring to plot.

- channels:

  Channels to draw after the LIF panel, in order. Default
  `c("ec", "hp")`; channels absent or all-`NA` for the boring are
  skipped.

- depth_max:

  Shared depth limit (ft). Default: the boring's deepest reading.

- ymax:

  Signal axis cap. `NULL` (default) auto-scales to 5% above the boring's
  maximum.

## Value

A patchwork object (prints like a ggplot).

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
lif_overview(lif, "LIF-05")
```
