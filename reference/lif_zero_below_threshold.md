# Zero signal below a threshold value

Sets `signal` to `value` wherever it is strictly less than `threshold`,
across all borings or the named subset. `NA` readings are left alone.

## Usage

``` r
lif_zero_below_threshold(data, threshold, borings = NULL, value = 0)
```

## Arguments

- data:

  A [lif_data](https://mjorden.github.io/lifr/reference/lif_data.md)
  frame (any data frame with `boring`, `depth`, `signal`).

- threshold:

  Readings below this %RE value are zeroed.

- borings:

  Character vector restricting the edit; `NULL` for all.

- value:

  Replacement value. Default 0; `NA` is allowed.

## Value

The edited frame: one audit row with `boring = NA` when `borings` is
`NULL`, otherwise one row per named boring.

## Details

Called without `borings`, the edit is recorded as a single audit row
with `boring = NA`, which the report reads as "every boring at the
site". Called with `borings`, it writes one row per named boring, each
with its own `n_rows_changed`, as
[`lif_zero_shallow()`](https://mjorden.github.io/lifr/reference/lif_zero_shallow.md)
does: a single `boring = NA` row claimed the edit had reached borings it
never touched, and put the report's whole-log caption under every log
(daktools \#791). A name repeated in `borings` is one target, not two.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
lif <- lif_zero_below_threshold(lif, threshold = 1)
#> [lif_zero_below_threshold] changed 1014 reading(s) below 1 across 12 boring(s)
```
