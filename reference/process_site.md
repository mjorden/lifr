# Run the import -\> edit -\> correct -\> summarise -\> report pipeline for a site

One call that imports a directory of LIF logs, optionally applies a
batch edit plan and corrections, summarises the data, writes the site
summary charts, and renders the site report. Every step is logged and
every edit is recorded in the audit trail the report prints.

## Usage

``` r
process_site(
  data_dir,
  locations_file = NULL,
  edits = NULL,
  corrections = list(),
  output_dir = ".",
  prefix = NULL,
  site_name = NULL,
  crs = NULL,
  charts = TRUE,
  report = TRUE,
  report_formats = c("html", "md", "pdf"),
  response_thresholds = c(1, 10, 50),
  date_suffix = FALSE,
  quiet = FALSE
)
```

## Arguments

- data_dir:

  Directory of `.lif.dat.txt` files (and, usually, the locations file).

- locations_file:

  Passed to
  [`lif_import()`](https://mjorden.github.io/lifr/reference/lif_import.md).

- edits:

  Optional batch edit plan: a CSV path or data frame for
  [`lif_apply_edits()`](https://mjorden.github.io/lifr/reference/lif_apply_edits.md).

- corrections:

  Named list of corrections applied after the edits, in this order:

  - `zero_shallow`: a depth (ft); readings at or above it are zeroed via
    [`lif_zero_shallow()`](https://mjorden.github.io/lifr/reference/lif_zero_shallow.md).

  - `zero_below`: a %RE threshold; readings below it are zeroed via
    [`lif_zero_below_threshold()`](https://mjorden.github.io/lifr/reference/lif_zero_below_threshold.md).

  - `hp`: `TRUE` for
    [`hp_correction()`](https://mjorden.github.io/lifr/reference/hp_correction.md)
    defaults, or a named list of its arguments such as
    `list(water_table = 8)`.

- output_dir:

  Directory for the charts and report (created if missing).

- prefix:

  Filename prefix for the charts and report. Default: a slug of
  `site_name`.

- site_name:

  Human-readable site name. Default: the `data_dir` basename.

- crs:

  Projected CRS (EPSG code) of the coordinates. When supplied the report
  adds a boring map over USGS aerial imagery via
  [`fetch_basemap()`](https://mjorden.github.io/lifr/reference/fetch_basemap.md);
  needs network access and degrades to a note offline.

- charts:

  Logical. Write the site summary charts as PNGs.

- report:

  Logical. Render the report.

- report_formats:

  Any of `"html"`, `"md"`, `"pdf"`.

- response_thresholds:

  The Summary tab lists the borings whose peak exceeds each of these %RE
  values. `NULL` suppresses those tables.

- date_suffix:

  Logical. Append `_YYMMDD` to the prefix so successive runs sit side by
  side.

- quiet:

  Suppress progress messages.

## Value

Invisibly, a `lif_site` object: a list with `data` (processed frame),
`raw_data` (as imported), `site_name`, `log` (one row per step),
`summary`
([`summarize_lif()`](https://mjorden.github.io/lifr/reference/summarize_lif.md)
result), `edits` (the audit trail), `charts` (PNG paths), `reports`
(named list of report paths), and `meta`.

## See also

[`site_report()`](https://mjorden.github.io/lifr/reference/site_report.md)
to re-render from the returned object.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
out <- tempfile("site")
site <- process_site(demo, output_dir = out,
                     corrections = list(zero_shallow = 1),
                     report = FALSE, quiet = TRUE)
site
#> <lif_site> demo
#>   12 boring(s), 1489 sample(s), 12 edit(s), 4 chart(s)
site$log
#>      step               action
#> 1  import         lif_import()
#> 2 correct   lif_zero_shallow()
#> 3  charts export_site_charts()
#>                                                                                                                 detail
#> 1                                                                    /home/runner/work/_temp/Library/lifr/extdata/demo
#> 2                                                                                                              depth=1
#> 3 demo_chart_max_response.png, demo_chart_peak_by_boring.png, demo_chart_hp_histogram.png, demo_chart_ec_histogram.png
#>   n_rows n_borings
#> 1   1489        12
#> 2   1489        12
#> 3   1489        12
# \donttest{
site <- process_site(demo, output_dir = out, report_formats = "html",
                     quiet = TRUE)
site$reports$html
#> [1] "/tmp/RtmpUuSK5L/site1d7e1df52fd9/demo_report.html"
# }
```
