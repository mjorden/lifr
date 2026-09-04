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

The edited frame with one audit row recording the threshold.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
lif <- lif_zero_below_threshold(lif, threshold = 1)
#> [lif_zero_below_threshold] zeroed 1014 row(s) below 1 across 12 boring(s)
```
