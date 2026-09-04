# Plan-view map of aggregated signal in a depth band

Each boring is coloured by the aggregate (default maximum) of `signal`
inside `depth_range`. Borings with no usable readings in the band are
drawn as grey crosses and named in a message, so "not sampled here" is
never mistaken for "no boring here".

## Usage

``` r
depth_slice_map(
  data,
  depth_range,
  channel = "signal",
  agg_fn = max,
  point_size = 3,
  label_borings = TRUE,
  show_unsampled = TRUE,
  title = NULL,
  coord_units = "ft",
  seed = 42
)
```

## Arguments

- data:

  A [lif_data](https://mjorden.github.io/lifr/reference/lif_data.md)
  frame with `easting` and `northing`.

- depth_range:

  `c(top, bottom)` in ft.

- channel:

  Column to aggregate. Default `"signal"`.

- agg_fn:

  Aggregation function applied per boring. Default `max`.

- point_size:

  Marker size. Default 3.

- label_borings:

  Logical. Label each boring.

- show_unsampled:

  Logical. Mark borings with no in-band readings.

- title:

  Plot title. `NULL` builds one from the channel and depth band.

- coord_units:

  Unit string for the axis titles and scale bar.

- seed:

  Seed for reproducible label placement.

## Value

A ggplot object.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
depth_slice_map(lif, depth_range = c(10, 20))
```
