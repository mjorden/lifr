# Side-by-side comparison of input and edited profiles

For every boring whose `signal` differs between `raw` and `edited`,
builds a two-panel plot (input \| edited) with changed depths marked in
red. Unchanged borings are skipped and counted in a message.

## Usage

``` r
qc_compare(raw, edited, channel = "signal", output_dir = NULL, ymin = 0)
```

## Arguments

- raw:

  The frame before editing.

- edited:

  The frame after editing. Rows are matched on `boring` and `depth`.

- channel:

  Column to compare. Default `"signal"`.

- output_dir:

  Optional directory; when supplied one PNG per changed boring is
  written there.

- ymin:

  Value-axis floor, default `0`, or `NULL` to floor at
  `min(0, 1.05 * min(value))` and mark 0 with a thin line. Readings
  below the floor are left out of view, not dropped; when any are, a
  message of class `"lifr_below_floor"` and a caption say how many. This
  is a QC view of what an edit changed, so the floor applies to every
  channel, `signal` included – unlike the LIF log panels, which keep a 0
  floor (daktools \#661).

## Value

A named list of ggplots (one per changed boring), invisibly.

## Details

A reading set to `NA` (what `lif_editor(value = NA)` writes), an `NA`
filled in, and a depth present in only one of the two frames all count
as edits; `NA` on both sides counts as unchanged. A depth with no
reading left in `edited` has no value to put a dot on, so it is marked
with a red cross just above the panel floor, where the fill and line
break (daktools \#795).

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
raw <- lif_import(demo, verbose = FALSE)
ed  <- lif_editor_bulk(raw, top = 0, bottom = 3, verbose = FALSE)
#> [lif_editor_bulk] changed 144 reading(s) (0-3 ft) across 12 boring(s)
plots <- qc_compare(raw, ed)
#> qc_compare: 12 boring(s) with changes plotted, 0 unchanged.
plots[[1]]
```
