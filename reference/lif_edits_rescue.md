# Carry the edit history across dplyr operations

dplyr verbs strip non-standard attributes, which silently drops the edit
history. Save it with `lif_get_edits()` before such a step and put it
back with `lif_set_edits()` afterwards.

## Usage

``` r
lif_get_edits(data)

lif_set_edits(data, edits)
```

## Arguments

- data:

  A data frame.

- edits:

  The history returned by `lif_get_edits()`, or `NULL` to clear it.

## Value

`lif_get_edits()`: the history data frame or `NULL`. `lif_set_edits()`:
`data` with the history attached.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
lif <- lif_editor_bulk(lif, top = 0, bottom = 2, verbose = FALSE)
#> [lif_editor_bulk] zeroed 96 row(s) (0-2 ft) across 12 boring(s)
saved <- lif_get_edits(lif)
sub <- lif[lif$boring %in% c("LIF-01", "LIF-02"), ]
sub <- lif_set_edits(sub, saved)
nrow(edit_history(sub))
#> [1] 1
```
