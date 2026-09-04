# Zero signal at or above a given depth

Convenience wrapper over
[`lif_editor()`](https://mjorden.github.io/lifr/reference/lif_editor.md)
that masks the top `depth` feet of every boring (or the named
`borings`), the usual way to remove surface smear before summarising or
mapping.

## Usage

``` r
lif_zero_shallow(data, depth, borings = NULL, value = 0)
```

## Arguments

- data:

  A [lif_data](https://mjorden.github.io/lifr/reference/lif_data.md)
  frame (any data frame with `boring`, `depth`, `signal`).

- depth:

  Readings at or shallower than this depth (ft) are zeroed.

- borings:

  Character vector restricting the edit; `NULL` for all.

- value:

  Replacement value. Default 0; `NA` is allowed.

## Value

The edited frame; one audit row per boring.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
lif <- lif_zero_shallow(lif, depth = 2)
#> [lif_zero_shallow] zeroed 96 row(s) above 2 ft across 12 boring(s)
```
