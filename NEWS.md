# lifr (development version)

Defects ported from the daktools October/November 2026 fixes (daktools
issues #662, #666, #667, #649, #789, #796). Three of them changed what a
figure claimed about the data, so figures regenerate:

- `boring_map()`: marker **area** is now proportional to peak signal, and
  the map carries a size key (daktools #662). The old law kept a 40 %
  diameter floor, which drew a boring at 1 % of the site peak at 7.8 % of
  the peak's area
  (10 % at 20 %, 25 % at 36 %), with no key to read sizes against -- a ring
  of weak detects around a hot spot read as a broad moderate plume. The
  maximum-signal marker keeps the diameter it had (`2 * point_size`); every
  other marker shrinks to its honest area. The hollow non-detect ring is off
  the size scale and is never larger than the smallest detect.
  `nd_threshold` must be `>= 0` when `size_by_signal = TRUE`;
  `size_by_signal = FALSE` is unchanged. Suppress the key with
  `ggplot2::guides(size = "none")`.
- `chart_max_response()`: the caption now names only the encodings the bars
  carry (daktools #667). It used to claim "bar colour = emission colour at
  peak-signal depth" over every chart and fill the colour-less bars a muted
  olive -- a plausible fluorescence hue -- so a delivery with no colour
  channel shipped a false caption over bars that read as real signatures.
  A bar above the screening floor with no usable colour is now hollow.
- Area fills break at `NA` instead of running straight across the gap
  (daktools #796). Since ggplot2 3.4 `geom_area()` defaults to
  `stat_align`, which
  drops `NA` rows and interpolates, so an interval deleted with
  `value = NA` was painted as signal while the line over it broke
  correctly. Affects `lif_plot()`, `lif_plot_all()`, `qc_compare()` and the
  report's channel panels.
- `lif_plot_all(layout = "facet")` draws the per-reading emission colour
  and the colour strip, as `layout = "list"` already did (daktools #666).
  The sheet
  ignored `color` entirely, so the comparison a small-multiples sheet
  exists for -- which borings share a fluorescence signature -- was the one
  thing it could not show. Colour is decided per boring; a frame with no
  colour renders exactly as before.
- **`lif_keep()` now errors** when the keep window contains none of the
  boring's readings (daktools #789), instead of silently zeroing the whole
  boring --
  the feet/metres and decimal-slip guard. `lif_apply_edits()` checks every
  `keep` row before applying any of them. A delete window that changes 0
  readings raises a classed warning (`"lifr_edit_noop"`) naming the boring,
  the window and the boring's depth range; `lif_zero_shallow()` muffles it,
  since a boring with nothing left to zero is expected there.
- `export_site_charts()` reports a chart it could not build or save instead
  of skipping it like an absent channel (daktools #649). Both used to
  return `NULL`,
  so the report embedded the previous run's PNG and `process_site()` logged
  the survivors as the complete set. Each failure now warns, lands in the
  returned value's `"failed"` attribute and gets its own `process_site()`
  log row, the other charts still render, and a stale PNG at a failed
  chart's path is deleted. A builder returning `NULL` because the site has
  no data for that chart is still a silent skip.

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
