# Changelog

## lifr 0.1.0

Initial public release.

- [`lif_read()`](https://mjorden.github.io/lifr/reference/lif_read.md) /
  [`lif_import()`](https://mjorden.github.io/lifr/reference/lif_import.md)
  read `.lif.dat.txt` / `.csv` logs (modern header layout and headerless
  legacy 11- and 16-column layouts), keep every source column, and join
  a locations table via
  [`read_locations()`](https://mjorden.github.io/lifr/reference/read_locations.md).
- Editors with an audit trail:
  [`lif_editor()`](https://mjorden.github.io/lifr/reference/lif_editor.md),
  [`lif_editor_bulk()`](https://mjorden.github.io/lifr/reference/lif_editor_bulk.md),
  [`lif_keep()`](https://mjorden.github.io/lifr/reference/lif_keep.md),
  [`lif_zero_shallow()`](https://mjorden.github.io/lifr/reference/lif_zero_shallow.md),
  [`lif_zero_below_threshold()`](https://mjorden.github.io/lifr/reference/lif_zero_below_threshold.md),
  [`lif_apply_edits()`](https://mjorden.github.io/lifr/reference/lif_apply_edits.md),
  and the
  [`edit_history()`](https://mjorden.github.io/lifr/reference/edit_history.md)
  accessors.
- Processing:
  [`hp_correction()`](https://mjorden.github.io/lifr/reference/hp_correction.md),
  [`re_feet()`](https://mjorden.github.io/lifr/reference/re_feet.md),
  [`lif_downsample()`](https://mjorden.github.io/lifr/reference/lif_downsample.md).
- [`summarize_lif()`](https://mjorden.github.io/lifr/reference/summarize_lif.md)
  QA statistics.
- Plots:
  [`lif_plot()`](https://mjorden.github.io/lifr/reference/lif_plot.md),
  [`lif_plot_all()`](https://mjorden.github.io/lifr/reference/lif_plot_all.md),
  [`lif_overview()`](https://mjorden.github.io/lifr/reference/lif_overview.md),
  [`qc_compare()`](https://mjorden.github.io/lifr/reference/qc_compare.md),
  [`boring_map()`](https://mjorden.github.io/lifr/reference/boring_map.md)
  (with
  [`fetch_basemap()`](https://mjorden.github.io/lifr/reference/fetch_basemap.md)
  imagery),
  [`depth_slice_map()`](https://mjorden.github.io/lifr/reference/depth_slice_map.md),
  and the `chart_*()` site charts with
  [`export_site_charts()`](https://mjorden.github.io/lifr/reference/export_site_charts.md).
- [`process_site()`](https://mjorden.github.io/lifr/reference/process_site.md)
  pipeline and
  [`site_report()`](https://mjorden.github.io/lifr/reference/site_report.md)
  renderer: self-contained HTML, Markdown, PDF, and a per-boring logs
  PDF.
- [`lif_simulate()`](https://mjorden.github.io/lifr/reference/lif_simulate.md)
  synthetic site generator; the bundled `demo` dataset is built with it.
