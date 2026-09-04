# Render the site report from a `lif_site` object

Renders the object returned by
[`process_site()`](https://mjorden.github.io/lifr/reference/process_site.md)
into any of:

- `"html"`: one self-contained file (inline CSS/JS, base64 figures,
  sortable tables) with four tabs: **Summary** (tiles, boring maps, the
  %RE proxy disclosure, peak-response tables), **Data & QA** (per-boring
  inventory, summary statistics, site charts), **Processing history**
  (the complete edit log, corrections, pipeline steps), and **Boring
  logs** (input-vs-edited log pairs with a changed-only filter).
  Printing shows every tab as its own section.

- `"md"`: a Markdown document that references its figures as PNG
  sidecars written next to it.

- `"pdf"`: the Markdown rendered through `rmarkdown` (pandoc plus a
  LaTeX distribution such as TinyTeX). Skipped with a warning when that
  toolchain is missing. Also writes `<prefix>_logs.pdf`, one page per
  boring, through R's own
  [`pdf()`](https://rdrr.io/r/grDevices/pdf.html) device, which needs no
  LaTeX.

## Usage

``` r
site_report(
  x,
  formats = c("html", "md"),
  output_dir = ".",
  file_prefix = NULL,
  quiet = FALSE
)
```

## Arguments

- x:

  A `lif_site` object.

- formats:

  Any of `"html"`, `"md"`, `"pdf"`.

- output_dir:

  Directory to write into (created if missing).

- file_prefix:

  Base filename. Default: the prefix recorded by
  [`process_site()`](https://mjorden.github.io/lifr/reference/process_site.md),
  else a slug of the site name. Existing files are overwritten.

- quiet:

  Suppress the "written" messages.

## Value

Invisibly, a named list of the paths written (`html`, `md`, `pdf`,
`logs_pdf` as applicable).

## Examples

``` r
# \donttest{
demo <- system.file("extdata", "demo", package = "lifr")
out <- tempfile("site")
site <- process_site(demo, output_dir = out, report = FALSE, quiet = TRUE)
site_report(site, formats = "md", output_dir = out, quiet = TRUE)
# }
```
