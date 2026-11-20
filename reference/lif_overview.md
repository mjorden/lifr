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
  ymax = NULL,
  ymin = 0
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

- ymin:

  Value-axis floor for the `channels` panels (the LIF panel keeps its
  own 0 floor: negative %RE is not a quantity). Default `0`, so no
  existing figure changes shape. Readings below the floor are left out
  of view by the coordinate limits, not dropped, so nothing warns on its
  own; when any are, a message of class `"lifr_below_floor"` and a panel
  caption say how many. `NULL` floors at `min(0, 1.05 * min(value))` and
  marks 0 with a thin line, which is how to see the negative `hp` that
  [`hp_correction()`](https://mjorden.github.io/lifr/reference/hp_correction.md)
  produces by default through the unsaturated zone.

## Value

A patchwork object (prints like a ggplot).

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
lif_overview(lif, "LIF-05")
```
