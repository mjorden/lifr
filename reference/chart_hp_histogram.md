# Chart: distribution of hydraulic push pressure

Pooled `hp` across all borings with the median marked. Readings above
ground surface (negative depth) are dropped.

## Usage

``` r
chart_hp_histogram(data)
```

## Arguments

- data:

  A [lif_data](https://mjorden.github.io/lifr/reference/lif_data.md)
  frame with an `hp` column.

## Value

A ggplot, or `NULL` with fewer than 10 readings.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
chart_hp_histogram(lif)
```
