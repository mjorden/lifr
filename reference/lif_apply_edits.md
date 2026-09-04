# Apply a batch of edits from a data frame or CSV

Applies each row of an edit plan in order through
[`lif_editor()`](https://mjorden.github.io/lifr/reference/lif_editor.md),
[`lif_editor_bulk()`](https://mjorden.github.io/lifr/reference/lif_editor_bulk.md),
or [`lif_keep()`](https://mjorden.github.io/lifr/reference/lif_keep.md),
so a site's edits live in one reviewable file instead of a script of
editor calls.

## Usage

``` r
lif_apply_edits(data, edits, validate = FALSE)
```

## Arguments

- data:

  A [lif_data](https://mjorden.github.io/lifr/reference/lif_data.md)
  frame.

- edits:

  A data frame or the path to a CSV with the columns above.

- validate:

  Logical. `TRUE` checks every row and prints how many readings each
  would affect without modifying the data; invalid rows stop with a
  message naming them.

## Value

The edited frame (or, with `validate = TRUE`, the input unchanged,
invisibly).

## Plan columns

- `boring` (required): boring name, or `"*"` for every boring (delete
  rows only; recorded as one bulk edit).

- `action` (optional): `"delete"` (default), `"clean"` (alias), or
  `"keep"`.

- `top`, `bottom` (optional): depth bounds. `NA` means the function's
  own default (whole boring for delete; open-ended for keep).

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
plan <- data.frame(boring = c("*", "LIF-02", "LIF-05"),
                   action = c("delete", "delete", "keep"),
                   top = c(0, 25, 8), bottom = c(1.5, NA, 30))
lif_apply_edits(lif, plan, validate = TRUE)
#> [lif_apply_edits] Validation summary (no changes applied):
#>  boring action top bottom n_rows_affected
#>       * delete   0    1.5              72
#>  LIF-02 delete  25     NA              45
#>  LIF-05   keep   8   30.0              61
lif <- lif_apply_edits(lif, plan)
#> [lif_apply_edits] Applied 3 edit(s).
edit_history(lif)
#>                   timestamp              fn boring top bottom value
#> 1 2026-09-04 20:26:23 +0000 lif_editor_bulk   <NA>   0    1.5     0
#> 2 2026-09-04 20:26:23 +0000      lif_editor LIF-02  25 1000.0     0
#> 3 2026-09-04 20:26:23 +0000        lif_keep LIF-05   8   30.0     0
#>   n_rows_changed                                           notes
#> 1             72                                            <NA>
#> 2             45                                            <NA>
#> 3             61 kept 8-30 ft; zeroed rows outside these windows
```
