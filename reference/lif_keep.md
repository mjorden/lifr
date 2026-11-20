# Keep one clean window for a boring and zero everything outside it

The inverse of
[`lif_editor()`](https://mjorden.github.io/lifr/reference/lif_editor.md):
every reading of `borename` whose depth falls outside the kept window(s)
is set to `value`. One audit row is recorded for the whole call,
spanning the outermost kept depths, with the window list in `notes`
(`"kept 12-28 ft; zeroed rows outside these windows"`); the report's log
plots read that note to shade the zeroed depths.

## Usage

``` r
lif_keep(
  data,
  borename,
  top = -Inf,
  bottom = Inf,
  value = 0,
  keep = NULL,
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

  Depth window (ft) to keep. Defaults `-Inf` / `Inf`; at least one bound
  or `keep` is required.

- value:

  Replacement value. Default 0; `NA` is allowed.

- keep:

  Optional list of `c(top, bottom)` windows to keep together.

- preview:

  Logical. `TRUE` reports how many rows would change without modifying
  the data.

## Value

The edited frame with one audit row appended.

## Details

A keep window (or set of `keep` windows) that contains none of
`borename`'s readings would zero the whole boring, so it is an error of
class `"lifr_keep_window_miss"` naming the boring, the window, and the
boring's depth range, under `preview = TRUE` too. This is the ft/metres
and decimal-slip guard: `lif_keep(lif, "B2", top = 300, bottom = 350)`
on a 20 ft boring used to blank it silently. To blank a boring on
purpose, call
[`lif_editor()`](https://mjorden.github.io/lifr/reference/lif_editor.md)
with no `top`/`bottom`.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
lif <- lif_keep(lif, "LIF-04", top = 10, bottom = 25)
#> [lif_keep] LIF-04: changed 42 reading(s) outside 10-25 ft
lif <- lif_keep(lif, "LIF-06", keep = list(c(8, 12), c(20, 28)))
#> [lif_keep] LIF-06: changed 100 reading(s) outside 8-12 ft, 20-28 ft
```
