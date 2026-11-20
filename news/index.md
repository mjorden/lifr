# Changelog

## lifr (development version)

### Second round of daktools ports

Six more defects carried over from the daktools October/November 2026
fixes (daktools issues
[\#791](https://github.com/mjorden/lifr/issues/791),
[\#792](https://github.com/mjorden/lifr/issues/792),
[\#801](https://github.com/mjorden/lifr/issues/801),
[\#795](https://github.com/mjorden/lifr/issues/795),
[\#661](https://github.com/mjorden/lifr/issues/661),
[\#647](https://github.com/mjorden/lifr/issues/647)). Two changed what a
figure claimed about the data:

- [`lif_overview()`](https://mjorden.github.io/lifr/reference/lif_overview.md)
  and
  [`qc_compare()`](https://mjorden.github.io/lifr/reference/qc_compare.md)
  gain `ymin`, and say what falls below the value-axis floor (daktools
  [\#661](https://github.com/mjorden/lifr/issues/661)).
  `coord_flip(ylim = )` zooms rather than drops, so every row stayed in
  the layer data, ggplot emitted no “Removed n rows” warning, and a
  reading below the floor was drawn on the panel edge, reading as zero.
  That mattered most for `hp`: with the default `water_table = 0`,
  [`hp_correction()`](https://mjorden.github.io/lifr/reference/hp_correction.md)
  subtracts the full hydrostatic column from the ground surface, which
  the function itself warns over-corrects the unsaturated zone – on the
  bundled demo site that puts 101 of LIF-06’s 150 readings as low as
  -2.64 psi, and the 0 floor turned them into a flat trace against the
  axis that reads as “very permeable” rather than “correction artifact”.
  `ymin` defaults to `0`, so no existing figure changes shape; what is
  new under the defaults is the disclosure, a message of class
  `"lifr_below_floor"` and a one-line panel caption (“101 readings below
  0”). `ymin = NULL` floors at `min(0, 1.05 * min(value))` and marks 0
  with a thin line. The LIF panels keep their 0 floor: negative %RE is
  not a quantity.
  [`qc_compare()`](https://mjorden.github.io/lifr/reference/qc_compare.md)
  discloses on every channel, `signal` included – it is a QC view of
  what an edit changed, not a log display.
- `boring_map(fill_floor =)` greys a detect below the screening floor,
  and
  [`process_site()`](https://mjorden.github.io/lifr/reference/process_site.md)
  passes the report’s floor (daktools
  [\#801](https://github.com/mjorden/lifr/issues/801)). The response map
  gave a boring at 0.3 %RE a full-strength emission colour while
  [`chart_max_response()`](https://mjorden.github.io/lifr/reference/chart_max_response.md),
  a page away in the same report, greyed that same boring’s bar – so two
  figures in one deliverable disagreed about whether a boring carried a
  product signature. A grey marker keeps its size and its detect status:
  the reading is real, it just carries no colour claim. Default `NULL`
  is the old look.
- **`lif_zero_below_threshold(borings =)` records which borings it
  edited** (daktools
  [\#791](https://github.com/mjorden/lifr/issues/791)). Scoped to a
  subset, it wrote a single audit row with `boring = NA`, which the
  report reads as “every boring at the site” – putting the whole-log
  caption under logs the edit never touched. It now writes one row per
  named boring, each with its own `n_rows_changed`, as
  [`lif_zero_shallow()`](https://mjorden.github.io/lifr/reference/lif_zero_shallow.md)
  already did. Called without `borings` it still writes the one
  `boring = NA` row, because there that is true. A name repeated in
  `borings` is one target, not two.
- [`qc_compare()`](https://mjorden.github.io/lifr/reference/qc_compare.md)
  marks a reading it can no longer plot, and no longer drops a one-sided
  depth (daktools [\#795](https://github.com/mjorden/lifr/issues/795)).
  A depth whose value is `NA` in `edited` – what
  `lif_editor(value = NA)` writes – was detected as a change, but
  [`geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)
  had no `y` to draw and silently dropped the mark, so the panel pair
  looked identical. Those depths now get a red cross just above the
  panel floor and a subtitle saying so. The depth match is also an outer
  join now: a depth present in only one frame, which is what
  [`lif_downsample()`](https://mjorden.github.io/lifr/reference/lif_downsample.md)
  leaves behind, was excluded from the comparison entirely and could
  report a changed boring as unchanged.
- [`process_site()`](https://mjorden.github.io/lifr/reference/process_site.md)’s
  step log formats each correction argument on its own (daktools
  [\#792](https://github.com/mjorden/lifr/issues/792)). The detail
  string was built with `paste(names(p), unlist(p), sep = "=")`, which
  recycled the argument names over the flattened values, so any argument
  longer than one value shifted every later one:
  `hp = list(water_table = c("LIF-01" = 12, "LIF-02" = 14.5), gradient = 0.433)`
  was logged as `water_table=12; gradient=14.5; water_table=0.433`,
  putting a 14.5 ft/ft gradient on the record and contradicting the edit
  history in the same report. Vectors now render as
  `c(LIF-01=12|LIF-02=14.5)` and lists as `list(a=1|b=c(2|3))`.
  Scalar-only details are unchanged.
- [`?new_edited_data`](https://mjorden.github.io/lifr/reference/new_edited_data.md)
  now states the real edit-history survival rules (daktools
  [\#647](https://github.com/mjorden/lifr/issues/647)). Three places
  claimed [`rbind()`](https://rdrr.io/r/base/cbind.html) concatenates
  histories unconditionally. It does so only when its **first** argument
  carries a `lifr` class:
  [`rbind()`](https://rdrr.io/r/base/cbind.html)’s dispatch takes the
  first argument whose class has a method and `data.frame` has one, so
  `rbind(plain_df, edited)` falls to `rbind.data.frame` and returns an
  unclassed frame with no history at all – not even the edited
  argument’s – and nothing warns. Also newly stated:
  [`dplyr::bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html)
  keeps at most the first argument’s history and never merges two, and
  `as_tibble()`/[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html)
  drop the *class* rather than the attribute, so the banner stops
  printing while
  [`edit_history()`](https://mjorden.github.io/lifr/reference/edit_history.md)
  still reads it. Verified by execution and pinned by test, so an
  upstream change reads as “re-verify the docs” rather than as a `lifr`
  regression. No behaviour changes.

### First round of daktools ports

Defects ported from the daktools October/November 2026 fixes (daktools
issues [\#662](https://github.com/mjorden/lifr/issues/662),
[\#666](https://github.com/mjorden/lifr/issues/666),
[\#667](https://github.com/mjorden/lifr/issues/667),
[\#649](https://github.com/mjorden/lifr/issues/649),
[\#789](https://github.com/mjorden/lifr/issues/789),
[\#796](https://github.com/mjorden/lifr/issues/796)). Three of them
changed what a figure claimed about the data, so figures regenerate:

- [`boring_map()`](https://mjorden.github.io/lifr/reference/boring_map.md):
  marker **area** is now proportional to peak signal, and the map
  carries a size key (daktools
  [\#662](https://github.com/mjorden/lifr/issues/662)). The old law kept
  a 40 % diameter floor, which drew a boring at 1 % of the site peak at
  7.8 % of the peak’s area (10 % at 20 %, 25 % at 36 %), with no key to
  read sizes against – a ring of weak detects around a hot spot read as
  a broad moderate plume. The maximum-signal marker keeps the diameter
  it had (`2 * point_size`); every other marker shrinks to its honest
  area. The hollow non-detect ring is off the size scale and is never
  larger than the smallest detect. `nd_threshold` must be `>= 0` when
  `size_by_signal = TRUE`; `size_by_signal = FALSE` is unchanged.
  Suppress the key with `ggplot2::guides(size = "none")`.
- [`chart_max_response()`](https://mjorden.github.io/lifr/reference/chart_max_response.md):
  the caption now names only the encodings the bars carry (daktools
  [\#667](https://github.com/mjorden/lifr/issues/667)). It used to claim
  “bar colour = emission colour at peak-signal depth” over every chart
  and fill the colour-less bars a muted olive – a plausible fluorescence
  hue – so a delivery with no colour channel shipped a false caption
  over bars that read as real signatures. A bar above the screening
  floor with no usable colour is now hollow.
- Area fills break at `NA` instead of running straight across the gap
  (daktools [\#796](https://github.com/mjorden/lifr/issues/796)). Since
  ggplot2 3.4
  [`geom_area()`](https://ggplot2.tidyverse.org/reference/geom_ribbon.html)
  defaults to `stat_align`, which drops `NA` rows and interpolates, so
  an interval deleted with `value = NA` was painted as signal while the
  line over it broke correctly. Affects
  [`lif_plot()`](https://mjorden.github.io/lifr/reference/lif_plot.md),
  [`lif_plot_all()`](https://mjorden.github.io/lifr/reference/lif_plot_all.md),
  [`qc_compare()`](https://mjorden.github.io/lifr/reference/qc_compare.md)
  and the report’s channel panels.
- `lif_plot_all(layout = "facet")` draws the per-reading emission colour
  and the colour strip, as `layout = "list"` already did (daktools
  [\#666](https://github.com/mjorden/lifr/issues/666)). The sheet
  ignored `color` entirely, so the comparison a small-multiples sheet
  exists for – which borings share a fluorescence signature – was the
  one thing it could not show. Colour is decided per boring; a frame
  with no colour renders exactly as before.
- **[`lif_keep()`](https://mjorden.github.io/lifr/reference/lif_keep.md)
  now errors** when the keep window contains none of the boring’s
  readings (daktools
  [\#789](https://github.com/mjorden/lifr/issues/789)), instead of
  silently zeroing the whole boring – the feet/metres and decimal-slip
  guard.
  [`lif_apply_edits()`](https://mjorden.github.io/lifr/reference/lif_apply_edits.md)
  checks every `keep` row before applying any of them. A delete window
  that changes 0 readings raises a classed warning (`"lifr_edit_noop"`)
  naming the boring, the window and the boring’s depth range;
  [`lif_zero_shallow()`](https://mjorden.github.io/lifr/reference/lif_zero_shallow.md)
  muffles it, since a boring with nothing left to zero is expected
  there.
- [`export_site_charts()`](https://mjorden.github.io/lifr/reference/export_site_charts.md)
  reports a chart it could not build or save instead of skipping it like
  an absent channel (daktools
  [\#649](https://github.com/mjorden/lifr/issues/649)). Both used to
  return `NULL`, so the report embedded the previous run’s PNG and
  [`process_site()`](https://mjorden.github.io/lifr/reference/process_site.md)
  logged the survivors as the complete set. Each failure now warns,
  lands in the returned value’s `"failed"` attribute and gets its own
  [`process_site()`](https://mjorden.github.io/lifr/reference/process_site.md)
  log row, the other charts still render, and a stale PNG at a failed
  chart’s path is deleted. A builder returning `NULL` because the site
  has no data for that chart is still a silent skip.

## lifr 0.1.1

Fixes from the September 2026 code review (issues
[\#1](https://github.com/mjorden/lifr/issues/1)-#20). Behaviour changes
worth knowing:

- [`lif_read()`](https://mjorden.github.io/lifr/reference/lif_read.md) /
  [`lif_import()`](https://mjorden.github.io/lifr/reference/lif_import.md):
  trailing delimiters on data lines no longer shift every column
  ([\#1](https://github.com/mjorden/lifr/issues/1)); digits-only colour
  codes keep their leading zeros
  ([\#2](https://github.com/mjorden/lifr/issues/2)); a header-only log
  is omitted with a warning instead of aborting the import
  ([\#3](https://github.com/mjorden/lifr/issues/3));
  [`read_locations()`](https://mjorden.github.io/lifr/reference/read_locations.md)
  aliases (`x`, `y`, `id`, …) never overwrite a canonical column
  ([\#4](https://github.com/mjorden/lifr/issues/4)).
- [`hp_correction()`](https://mjorden.github.io/lifr/reference/hp_correction.md)
  indexes a per-boring `water_table` by name even when `boring` is a
  factor ([\#5](https://github.com/mjorden/lifr/issues/5));
  [`new_lif_data()`](https://mjorden.github.io/lifr/reference/lif_data.md)
  converts factor borings to character.
- The edit history now survives `[`,
  [`rbind()`](https://rdrr.io/r/base/cbind.html) (histories
  concatenate), and the dplyr verbs
  ([\#6](https://github.com/mjorden/lifr/issues/6)).
  [`merge()`](https://rdrr.io/r/base/merge.html) and `as_tibble()` still
  drop it.
- `n_rows_changed` counts readings whose value changed, not readings
  inside the window, so re-applying an edit records 0
  ([\#7](https://github.com/mjorden/lifr/issues/7)). The editors’
  default `bottom` is now `Inf` rather than `1000`.
- `process_site(corrections = list(hp = FALSE))` skips the correction
  ([\#8](https://github.com/mjorden/lifr/issues/8)). A failing summary,
  chart, or report step raises a warning and is logged as `failed` even
  with `quiet = TRUE`
  ([\#11](https://github.com/mjorden/lifr/issues/11)).
- NA-depth readings are left alone by every editor;
  [`lif_zero_shallow()`](https://mjorden.github.io/lifr/reference/lif_zero_shallow.md)
  also masks readings above ground surface; a `keep` plan row needs at
  least one bound ([\#9](https://github.com/mjorden/lifr/issues/9)).
- The Markdown report escapes paths and names, so Windows paths no
  longer break the PDF
  ([\#10](https://github.com/mjorden/lifr/issues/10)). The logs PDF is
  written before the Markdown that links to it and is removed if it
  fails; unrenderable figures leave a visible placeholder
  ([\#18](https://github.com/mjorden/lifr/issues/18)). TinyTeX installs
  off `PATH` are detected.
- [`compat_rename_legacy()`](https://mjorden.github.io/lifr/reference/compat_rename_legacy.md)
  warns on every collision, not once per session
  ([\#12](https://github.com/mjorden/lifr/issues/12)).
  [`lif_simulate()`](https://mjorden.github.io/lifr/reference/lif_simulate.md)
  restores the caller’s RNG state
  ([\#13](https://github.com/mjorden/lifr/issues/13)).
- [`qc_compare()`](https://mjorden.github.io/lifr/reference/qc_compare.md)
  pairs repeated depths correctly;
  [`re_feet()`](https://mjorden.github.io/lifr/reference/re_feet.md)
  averages repeated depths;
  [`lif_downsample()`](https://mjorden.github.io/lifr/reference/lif_downsample.md)
  keeps NA-depth rows;
  [`summarize_lif()`](https://mjorden.github.io/lifr/reference/summarize_lif.md)
  handles a 0-row frame and reports unbinned readings
  ([\#14](https://github.com/mjorden/lifr/issues/14)).
- The report’s change detection matches readings on depth
  ([\#15](https://github.com/mjorden/lifr/issues/15)).
  [`boring_map()`](https://mjorden.github.io/lifr/reference/boring_map.md)
  gains `min_extent` so one boring or a collinear transect keeps a
  sensible window, and labels are formatted per element
  ([\#16](https://github.com/mjorden/lifr/issues/16)).
  [`chart_ec_histogram()`](https://mjorden.github.io/lifr/reference/chart_ec_histogram.md)
  leaves outliers out of the histogram and states them in the caption
  ([\#17](https://github.com/mjorden/lifr/issues/17)). The HTML report
  has proper tab and header roles, keyboard-sortable tables, and a hash
  handler that cannot throw
  ([\#19](https://github.com/mjorden/lifr/issues/19)).
  [`theme_lifr()`](https://mjorden.github.io/lifr/reference/theme_lifr.md)
  honours `base_size`; `depth_slice_map(agg_fn=)` receives a plain
  vector; the basemap featureless check ignores the alpha plane
  ([\#20](https://github.com/mjorden/lifr/issues/20)).

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
- Documentation: a getting-started guide plus articles on the raw file
  format, editing with an audit trail, a plot gallery, and the site
  report; README with rendered example figures.
