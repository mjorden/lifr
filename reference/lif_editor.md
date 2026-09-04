# Zero LIF signal inside a depth window for one boring

Sets `signal` to `value` (default 0) for every reading of `borename`
whose depth falls inside the interval(s). Use this to mask known
artifacts: surface smear, a rod change, a fluorescent mineral seam. The
inverse, keeping one clean window and zeroing everything else, is
[`lif_keep()`](https://mjorden.github.io/lifr/reference/lif_keep.md).

## Usage

``` r
lif_editor(
  data,
  borename,
  top = 0,
  bottom = 1000,
  value = 0,
  delete = NULL,
  preview = FALSE
)
```

## Arguments

- data:

  A [lif_data](https://mjorden.github.io/lifr/reference/lif_data.md)
  frame (any data frame with `boring`, `depth`, `signal`).

- borename:

  Boring name to edit.

- top, bottom:

  Depth interval (ft) to zero. Defaults `0` and `1000` cover the whole
  boring, which triggers a warning.

- value:

  Replacement value. Default 0; `NA` is allowed.

- delete:

  Optional list of `c(top, bottom)` pairs to zero several intervals in
  one call. Cannot be combined with `top`/`bottom`.

- preview:

  Logical. `TRUE` reports how many rows would change without modifying
  the data.

## Value

The edited frame with one audit row per interval appended to its edit
history (see
[`edit_history()`](https://mjorden.github.io/lifr/reference/edit_history.md)).
With `preview = TRUE` the input is returned unchanged.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
lif <- lif_editor(lif, "LIF-03", top = 0, bottom = 2)
#> [lif_editor] LIF-03: zeroed 8 row(s) (0-2 ft)
lif <- lif_editor(lif, "LIF-05", delete = list(c(0, 1.5), c(30, Inf)))
#> [lif_editor] LIF-05: zeroed 37 row(s) (0-1.5 ft, 30-Inf ft)
edit_history(lif)
#>                   timestamp         fn boring top bottom value n_rows_changed
#> 1 2026-09-04 20:34:28 +0000 lif_editor LIF-03   0    2.0     0              8
#> 2 2026-09-04 20:34:28 +0000 lif_editor LIF-05   0    1.5     0              6
#> 3 2026-09-04 20:34:28 +0000 lif_editor LIF-05  30    Inf     0             31
#>   notes
#> 1  <NA>
#> 2  <NA>
#> 3  <NA>
```
