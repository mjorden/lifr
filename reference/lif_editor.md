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
  bottom = Inf,
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

  Depth interval (ft) to zero. Defaults `0` and `Inf` cover the whole
  boring, which triggers a warning. Readings with an `NA` depth are
  never inside a window and are left unchanged.

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

## No-op edits

A window that changes 0 readings – one that misses the boring's depth
range, or that covers only readings already holding `value` – raises a
warning of class `"lifr_edit_noop"` naming the boring, the window, and
the boring's depth range, under `preview = TRUE` too. It is a warning
and not an error because a 0-row delete changes nothing; it is there to
catch the plan row whose depths are wrong. Warnings are not messages, so
`process_site(quiet = TRUE)` leaves it visible.
[`lif_zero_shallow()`](https://mjorden.github.io/lifr/reference/lif_zero_shallow.md)
muffles it, since a boring with nothing left to zero is expected there.

## The audit trail

Every editor appends a row to `attr(data, "edits")` recording the
timestamp, function, boring, depth window, replacement value, and
`n_rows_changed`: the number of readings whose value actually changed,
so re-applying an edit or zeroing readings already at zero records 0.
The history prints with the frame, is returned by
[`edit_history()`](https://mjorden.github.io/lifr/reference/edit_history.md),
can be saved with
[`edit_history_save()`](https://mjorden.github.io/lifr/reference/edit_history.md),
and is rendered in full on the site report's Processing history tab. It
survives `[`, the dplyr verbs, and
[`rbind()`](https://rdrr.io/r/base/cbind.html) when the edited frame is
its first argument; see
[`new_edited_data()`](https://mjorden.github.io/lifr/reference/new_edited_data.md)
for the full rules, the operations that drop it, and
[`lif_get_edits()`](https://mjorden.github.io/lifr/reference/lif_edits_rescue.md)
to carry it across those.

## Choosing an editor

- A known artifact inside an otherwise good log: `lif_editor()` with
  `top`/`bottom`, or several windows through `delete`.

- The same window on every boring (surface smear):
  [`lif_editor_bulk()`](https://mjorden.github.io/lifr/reference/lif_editor_bulk.md)
  or
  [`lif_zero_shallow()`](https://mjorden.github.io/lifr/reference/lif_zero_shallow.md).

- One clean interval and everything else suspect:
  [`lif_keep()`](https://mjorden.github.io/lifr/reference/lif_keep.md).

- Many edits across a site: put them in a CSV and use
  [`lif_apply_edits()`](https://mjorden.github.io/lifr/reference/lif_apply_edits.md).

## See also

[`vignette("editing")`](https://mjorden.github.io/lifr/articles/editing.md)

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)

# Mask one interval
lif <- lif_editor(lif, "LIF-03", top = 20, bottom = 22)
#> [lif_editor] LIF-03: changed 9 reading(s) (20-22 ft)

# Several intervals in one call, with NA instead of 0
lif <- lif_editor(lif, "LIF-05", delete = list(c(0, 1.5), c(30, Inf)),
                  value = NA)
#> [lif_editor] LIF-05: changed 37 reading(s) (0-1.5 ft, 30-Inf ft)

# See what a call would do without doing it
lif_editor(lif, "LIF-07", top = 0, bottom = 3, preview = TRUE)
#> [lif_editor] PREVIEW LIF-07: would change 12 reading(s) (0-3 ft)
#> <edited_data> 3 edit(s) recorded -- provenance attached (edit_history() to inspect).
#> <lif_data> 12 boring(s), 1489 sample(s), depth 0.2-37.5 ft, 3 edit(s)
#>   channels: signal, ec, hp, color
#>    easting northing depth signal boring   msl    ec   hp   color
#> 1   1014.5   2017.9  0.25  2.506 LIF-01 149.6  8.87 2.79 #6B8E23
#> 2   1014.5   2017.9  0.50  0.206 LIF-01 149.6  9.31 2.41 #B0B0B0
#> 3   1014.5   2017.9  0.75  2.146 LIF-01 149.6  9.75 2.59 #6B8E23
#> 4   1014.5   2017.9  1.00  0.095 LIF-01 149.6  9.40 2.83 #B0B0B0
#> 5   1014.5   2017.9  1.25  0.208 LIF-01 149.6 10.38 2.97 #B0B0B0
#> 6   1014.5   2017.9  1.50  0.098 LIF-01 149.6  9.38 2.68 #B0B0B0
#> 7   1014.5   2017.9  1.75  0.213 LIF-01 149.6 10.07 2.72 #B0B0B0
#> 8   1014.5   2017.9  2.00  0.148 LIF-01 149.6  9.48 3.08 #B0B0B0
#> 9   1014.5   2017.9  2.25  0.050 LIF-01 149.6 10.04 2.86 #B0B0B0
#> 10  1014.5   2017.9  2.50  0.003 LIF-01 149.6  9.46 3.01 #B0B0B0
#> # ... 1479 more row(s)

edit_history(lif)
#>                   timestamp         fn boring top bottom value n_rows_changed
#> 1 2026-11-20 22:10:20 +0000 lif_editor LIF-03  20   22.0     0              9
#> 2 2026-11-20 22:10:20 +0000 lif_editor LIF-05   0    1.5    NA              6
#> 3 2026-11-20 22:10:20 +0000 lif_editor LIF-05  30    Inf    NA             31
#>   notes
#> 1  <NA>
#> 2  <NA>
#> 3  <NA>
```
