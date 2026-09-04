# Inspect, save, or clear the edit history

Every editor appends one row to the `edits` attribute of the frame it
returns: `timestamp`, `fn`, `boring` (`NA` = all borings), `top`,
`bottom`, `value`, `n_rows_changed`, `notes`. These accessors read,
write out, or remove that audit trail.

## Usage

``` r
edit_history(data)

edit_history_save(data, file)

edit_history_clear(data)
```

## Arguments

- data:

  A data frame, typically one returned by an editor.

- file:

  Output CSV path for `edit_history_save()`.

## Value

`edit_history()` returns the history data frame (empty, with a message,
when there is none). `edit_history_save()` returns `file` invisibly.
`edit_history_clear()` returns `data` without the attribute.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
lif <- lif_editor_bulk(lif, top = 0, bottom = 2, verbose = FALSE)
#> [lif_editor_bulk] zeroed 96 row(s) (0-2 ft) across 12 boring(s)
edit_history(lif)
#>                   timestamp              fn boring top bottom value
#> 1 2026-09-04 20:42:25 +0000 lif_editor_bulk   <NA>   0      2     0
#>   n_rows_changed notes
#> 1             96  <NA>
lif <- edit_history_clear(lif)
is.null(attr(lif, "edits"))
#> [1] TRUE
```
