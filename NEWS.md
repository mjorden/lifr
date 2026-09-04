# lifr 0.1.0

Initial public release.

- `lif_read()` / `lif_import()` read `.lif.dat.txt` / `.csv` logs (modern
  header layout and headerless legacy 11- and 16-column layouts), keep every
  source column, and join a locations table via `read_locations()`.
- Editors with an audit trail: `lif_editor()`, `lif_editor_bulk()`,
  `lif_keep()`, `lif_zero_shallow()`, `lif_zero_below_threshold()`,
  `lif_apply_edits()`, and the `edit_history()` accessors.
- Processing: `hp_correction()`, `re_feet()`, `lif_downsample()`.
- `summarize_lif()` QA statistics.
- Plots: `lif_plot()`, `lif_plot_all()`, `lif_overview()`, `qc_compare()`,
  `boring_map()` (with `fetch_basemap()` imagery), `depth_slice_map()`, and
  the `chart_*()` site charts with `export_site_charts()`.
- `process_site()` pipeline and `site_report()` renderer: self-contained
  HTML, Markdown, PDF, and a per-boring logs PDF.
- `lif_simulate()` synthetic site generator; the bundled `demo` dataset is
  built with it.
- Documentation: a getting-started guide plus articles on the raw file
  format, editing with an audit trail, a plot gallery, and the site report;
  README with rendered example figures.
