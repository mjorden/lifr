# Thin a LIF frame to a coarser depth spacing

Keeps one reading every `target_interval` feet per boring, always
retaining readings whose `signal` exceeds `preserve_above` so peaks are
never thinned away. Row deletion is an edit: one audit row records the
parameters and the number of rows removed.

## Usage

``` r
lif_downsample(data, target_interval = 1, preserve_above = NULL)
```

## Arguments

- data:

  A [lif_data](https://mjorden.github.io/lifr/reference/lif_data.md)
  frame.

- target_interval:

  Target spacing (ft). Default 1.

- preserve_above:

  Signal threshold above which every reading is kept. `NULL` (default)
  thins uniformly.

## Value

The thinned frame, sorted by depth within each boring.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
thin <- lif_downsample(lif, target_interval = 1, preserve_above = 5)
#> lif_downsample: 1489 -> 596 rows (40% retained, target_interval=1 ft)
nrow(lif); nrow(thin)
#> [1] 1489
#> [1] 596
```
