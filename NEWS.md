# lifr (development version)

## Documentation and examples

The prose and the worked examples now match the behaviour the two rounds of
ports left behind. No code changed.

- The README's figures and printed output were knitted in September, before
  marker area, the size key, the hollow bars on `chart_max_response()`, the
  emission colour on the facet sheet, and the `NA` break in area fills. The
  map in the README showed the old diameter law with no key; it has been
  re-knitted, along with the five-minute tour's edit-history output, whose
  recorded windows and changed-row counts had moved with the ports.
- Help pages no longer cite `daktools` issue numbers. A lifr reader cannot
  resolve them; the provenance stays here in `NEWS.md`, where it belongs.
  Affects `?boring_map`, `?qc_compare`, and `?lif_zero_below_threshold`.
- Examples now exercise what the ports added: `ymin = NULL` on
  `lif_overview()` and `qc_compare()`, the red cross `qc_compare()` draws
  where `value = NA` left nothing to plot, `boring_map(fill_floor =)`, the
  per-boring audit rows from `lif_zero_below_threshold(borings =)`, the
  `"failed"` attribute on `export_site_charts()`, the keep-window guard in
  `lif_keep()`, and the per-boring `water_table` vector that
  `hp_correction()` has always accepted but never showed.
- `vignette("editing")` covers the scoped audit rows, the outer-join depth
  match, the `NA` crosses, and `ymin` on a QC panel.
  `vignette("reporting")` covers how a correction's arguments are rendered
  in the step log, that the lowest `response_thresholds` value is the
  screening floor shared by the response map and the peak-response chart,
  and what a failed optional step leaves in the log.

## Second round of daktools ports

Six more defects carried over from the daktools October/November 2026 fixes
(daktools issues #791, #792, #801, #795, #661, #647). Two changed what a
figure claimed about the data:

- `lif_overview()` and `qc_compare()` gain `ymin`, and say what falls below
  the value-axis floor (daktools #661). `coord_flip(ylim = )` zooms rather
  than drops, so every row stayed in the layer data, ggplot emitted no
  "Removed n rows" warning, and a reading below the floor was drawn on the
  panel edge, reading as zero. That mattered most for `hp`: with the
  default `water_table = 0`, `hp_correction()` subtracts the full
  hydrostatic column from the ground surface, which the function itself
  warns over-corrects the unsaturated zone -- on the bundled demo site that
  puts 101 of LIF-06's 150 readings as low as -2.64 psi, and the 0 floor
  turned them into a flat trace against the axis that reads as "very
  permeable"
  rather than "correction artifact". `ymin` defaults to `0`, so no existing
  figure changes shape; what is new under the defaults is the disclosure, a
  message of class `"lifr_below_floor"` and a one-line panel caption
  ("101 readings below 0"). `ymin = NULL` floors at `min(0, 1.05 * min(value))`
  and marks 0 with a thin line. The LIF panels keep their 0 floor: negative
  %RE is not a quantity. `qc_compare()` discloses on every channel,
  `signal` included -- it is a QC view of what an edit changed, not a log
  display.
- `boring_map(fill_floor =)` greys a detect below the screening floor, and
  `process_site()` passes the report's floor (daktools #801). The response
  map gave a boring at 0.3 %RE a full-strength emission colour while
  `chart_max_response()`, a page away in the same report, greyed that same
  boring's bar -- so two figures in one deliverable disagreed about whether
  a boring carried a product signature. A grey marker keeps its size and
  its detect status: the reading is real, it just carries no colour claim.
  Default `NULL` is the old look.
- **`lif_zero_below_threshold(borings =)` records which borings it edited**
  (daktools #791). Scoped to a subset, it wrote a single audit row with
  `boring = NA`, which the report reads as "every boring at the site" --
  putting the whole-log caption under logs the edit never touched. It now
  writes one row per named boring, each with its own `n_rows_changed`, as
  `lif_zero_shallow()` already did. Called without `borings` it still writes
  the one `boring = NA` row, because there that is true. A name repeated in
  `borings` is one target, not two.
- `qc_compare()` marks a reading it can no longer plot, and no longer drops
  a one-sided depth (daktools #795). A depth whose value is `NA` in
  `edited` -- what `lif_editor(value = NA)` writes -- was detected as a
  change, but `geom_point()` had no `y` to draw and silently dropped the
  mark, so the panel pair looked identical. Those depths now get a red
  cross just above the panel floor and a subtitle saying so. The depth
  match is also an outer join now: a depth present in only one frame, which
  is what `lif_downsample()` leaves behind, was excluded from the
  comparison entirely and could report a changed boring as unchanged.
- `process_site()`'s step log formats each correction argument on its own
  (daktools #792). The detail string was built with
  `paste(names(p), unlist(p), sep = "=")`, which recycled the argument names
  over the flattened values, so any argument longer than one value shifted
  every later one: `hp = list(water_table = c("LIF-01" = 12, "LIF-02" =
  14.5), gradient = 0.433)` was logged as `water_table=12; gradient=14.5;
  water_table=0.433`, putting a 14.5 ft/ft gradient on the record and
  contradicting the edit history in the same report. Vectors now render as
  `c(LIF-01=12|LIF-02=14.5)` and lists as `list(a=1|b=c(2|3))`.
  Scalar-only details are unchanged.
- `?new_edited_data` now states the real edit-history survival rules
  (daktools #647). Three places claimed `rbind()` concatenates histories
  unconditionally. It does so only when its **first** argument carries a
  `lifr` class: `rbind()`'s dispatch takes the first argument whose class
  has a method and `data.frame` has one, so `rbind(plain_df, edited)` falls
  to `rbind.data.frame` and returns an unclassed frame with no history at
  all -- not even the edited argument's -- and nothing warns. Also newly
  stated: `dplyr::bind_rows()` keeps at most the first argument's history
  and never merges two, and `as_tibble()`/`as.data.frame()` drop the
  *class* rather than the attribute, so the banner stops printing while
  `edit_history()` still reads it. Verified by execution and pinned by test,
  so an upstream change reads as "re-verify the docs" rather than as a
  `lifr` regression. No behaviour changes.

## First round of daktools ports

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
