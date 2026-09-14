# lifr 0.1.1

Fixes from the September 2026 code review (issues #1-#20). Behaviour changes
worth knowing:

- `lif_read()` / `lif_import()`: trailing delimiters on data lines no
  longer shift every column (#1); digits-only colour codes keep their
  leading zeros (#2); a header-only log is omitted with a warning instead
  of aborting the import (#3); `read_locations()` aliases (`x`, `y`, `id`,
  ...) never overwrite a canonical column (#4).
- `hp_correction()` indexes a per-boring `water_table` by name even when
  `boring` is a factor (#5); `new_lif_data()` converts factor borings to
  character.
- The edit history now survives `[`, `rbind()` (histories concatenate), and
  the dplyr verbs (#6). `merge()` and `as_tibble()` still drop it.
- `n_rows_changed` counts readings whose value changed, not readings
  inside the window, so re-applying an edit records 0 (#7). The editors'
  default `bottom` is now `Inf` rather than `1000`.
- `process_site(corrections = list(hp = FALSE))` skips the correction (#8).
  A failing summary, chart, or report step raises a warning and is logged
  as `failed` even with `quiet = TRUE` (#11).
- NA-depth readings are left alone by every editor; `lif_zero_shallow()`
  also masks readings above ground surface; a `keep` plan row needs at
  least one bound (#9).
- The Markdown report escapes paths and names, so Windows paths no longer
  break the PDF (#10). The logs PDF is written before the Markdown that
  links to it and is removed if it fails; unrenderable figures leave a
  visible placeholder (#18). TinyTeX installs off `PATH` are detected.
- `compat_rename_legacy()` warns on every collision, not once per session
  (#12). `lif_simulate()` restores the caller's RNG state (#13).
- `qc_compare()` pairs repeated depths correctly; `re_feet()` averages
  repeated depths; `lif_downsample()` keeps NA-depth rows; `summarize_lif()`
  handles a 0-row frame and reports unbinned readings (#14).
- The report's change detection matches readings on depth (#15).
  `boring_map()` gains `min_extent` so one boring or a collinear transect
  keeps a sensible window, and labels are formatted per element (#16).
  `chart_ec_histogram()` leaves outliers out of the histogram and states
  them in the caption (#17). The HTML report has proper tab and header
  roles, keyboard-sortable tables, and a hash handler that cannot throw
  (#19). `theme_lifr()` honours `base_size`; `depth_slice_map(agg_fn=)`
  receives a plain vector; the basemap featureless check ignores the alpha
  plane (#20).

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
