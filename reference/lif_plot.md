# Plot the LIF depth profile of one boring

Signal against depth, filled with the instrument's emission colour at
each depth when a `color` channel is present (with a colour strip left
of zero), or a single fill otherwise.

## Usage

``` r
lif_plot(data, borename, xmax = NULL, ymax = NULL)
```

## Arguments

- data:

  A [lif_data](https://mjorden.github.io/lifr/reference/lif_data.md)
  frame.

- borename:

  Boring to plot.

- xmax:

  Maximum depth shown (ft). Default: the deepest reading in `data`, so
  every boring shares one depth axis.

- ymax:

  Signal axis cap. `NULL` (default) auto-scales to 5% above the boring's
  maximum.

## Value

A ggplot object.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
lif_plot(lif, "LIF-05")

lif_plot(lif, "LIF-05", ymax = 100)
```
