# Side-by-side comparison of input and edited profiles

For every boring whose `signal` differs between `raw` and `edited`,
builds a two-panel plot (input \| edited) with changed depths marked in
red. Unchanged borings are skipped and counted in a message.

## Usage

``` r
qc_compare(raw, edited, channel = "signal", output_dir = NULL)
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

## Value

A named list of ggplots (one per changed boring), invisibly.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
raw <- lif_import(demo, verbose = FALSE)
ed  <- lif_editor_bulk(raw, top = 0, bottom = 3, verbose = FALSE)
#> [lif_editor_bulk] zeroed 144 row(s) (0-3 ft) across 12 boring(s)
plots <- qc_compare(raw, ed)
#> qc_compare: 12 boring(s) with changes plotted, 0 unchanged.
plots[[1]]
```
