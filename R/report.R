# Site pipeline (import -> edits -> corrections -> summary -> charts) and the
# report renderer (self-contained HTML, Markdown, PDF, per-boring logs PDF).

#' Run the import -> edit -> correct -> summarise -> report pipeline for a site
#'
#' One call that imports a directory of LIF logs, optionally applies a batch
#' edit plan and corrections, summarises the data, writes the site summary
#' charts, and renders the site report. Every step is logged and every edit
#' is recorded in the audit trail the report prints.
#'
#' @param data_dir Directory of `.lif.dat.txt` files (and, usually, the
#'   locations file).
#' @param locations_file Passed to [lif_import()].
#' @param edits Optional batch edit plan: a CSV path or data frame for
#'   [lif_apply_edits()].
#' @param corrections Named list of corrections applied after the edits, in
#'   this order:
#'   * `zero_shallow`: a depth (ft); readings at or above it are zeroed via
#'     [lif_zero_shallow()].
#'   * `zero_below`: a %RE threshold; readings below it are zeroed via
#'     [lif_zero_below_threshold()].
#'   * `hp`: `TRUE` for [hp_correction()] defaults, or a named list of its
#'     arguments such as `list(water_table = 8)`.
#' @param output_dir Directory for the charts and report (created if
#'   missing).
#' @param prefix Filename prefix for the charts and report. Default: a slug
#'   of `site_name`.
#' @param site_name Human-readable site name. Default: the `data_dir`
#'   basename.
#' @param crs Projected CRS (EPSG code) of the coordinates. When supplied
#'   the report adds a boring map over USGS aerial imagery via
#'   [fetch_basemap()]; needs network access and degrades to a note offline.
#' @param charts Logical. Write the site summary charts as PNGs.
#' @param report Logical. Render the report.
#' @param report_formats Any of `"html"`, `"md"`, `"pdf"`.
#' @param response_thresholds The Summary tab lists the borings whose peak
#'   exceeds each of these %RE values. `NULL` suppresses those tables.
#' @param date_suffix Logical. Append `_YYMMDD` to the prefix so successive
#'   runs sit side by side.
#' @param quiet Suppress progress messages.
#' @return Invisibly, a `lif_site` object: a list with `data` (processed
#'   frame), `raw_data` (as imported), `site_name`, `log` (one row per step),
#'   `summary` ([summarize_lif()] result), `edits` (the audit trail),
#'   `charts` (PNG paths), `reports` (named list of report paths), and
#'   `meta`.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' out <- tempfile("site")
#' site <- process_site(demo, output_dir = out,
#'                      corrections = list(zero_shallow = 1),
#'                      report = FALSE, quiet = TRUE)
#' site
#' site$log
#' \donttest{
#' site <- process_site(demo, output_dir = out, report_formats = "html",
#'                      quiet = TRUE)
#' site$reports$html
#' }
#' @seealso [site_report()] to re-render from the returned object.
#' @export
process_site <- function(data_dir, locations_file = NULL, edits = NULL,
                         corrections = list(), output_dir = ".", prefix = NULL,
                         site_name = NULL, crs = NULL, charts = TRUE,
                         report = TRUE, report_formats = c("html", "md", "pdf"),
                         response_thresholds = c(1, 10, 50),
                         date_suffix = FALSE, quiet = FALSE) {
  report_formats <- match.arg(report_formats, c("html", "md", "pdf"), several.ok = TRUE)
  if (!is.null(response_thresholds) &&
      (!is.numeric(response_thresholds) || any(!is.finite(response_thresholds))))
    stop("process_site: `response_thresholds` must be finite numbers or NULL.",
         call. = FALSE)
  if (length(corrections)) {
    known <- c("zero_shallow", "zero_below", "hp")
    bad <- setdiff(names(corrections) %||% "<unnamed>", known)
    if (length(bad) || any(!nzchar(names(corrections))))
      stop("process_site: unknown corrections key(s): ", paste(bad, collapse = ", "),
           ". Valid keys: ", paste(known, collapse = ", "), ".", call. = FALSE)
  }
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  say <- function(...) if (!quiet) message(...)
  hush <- if (quiet) suppressMessages else identity
  started <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %z")
  site_name <- site_name %||% basename(normalizePath(data_dir, mustWork = FALSE))
  prefix <- prefix %||% .site_slug(site_name)
  if (isTRUE(date_suffix)) prefix <- paste0(prefix, "_", format(Sys.Date(), "%y%m%d"))

  log <- data.frame(step = character(), action = character(), detail = character(),
                    n_rows = integer(), n_borings = integer(), stringsAsFactors = FALSE)
  add <- function(step, action, detail, d)
    log[nrow(log) + 1L, ] <<- list(step, action, detail, nrow(d),
                                   length(unique(d$boring)))

  say("[process_site] importing LIF logs from ", data_dir)
  data <- hush(lif_import(data_dir, locations_file = locations_file, verbose = !quiet))
  add("import", "lif_import()", data_dir, data)
  raw_data <- data

  if (!is.null(edits)) {
    say("[process_site] applying batch edits")
    data <- hush(lif_apply_edits(data, edits))
    add("edits", "lif_apply_edits()",
        sprintf("%d edit row(s)", nrow(attr(data, "edits") %||% data.frame())), data)
  }
  if (!is.null(corrections$zero_shallow)) {
    say("[process_site] zeroing shallow readings")
    data <- hush(lif_zero_shallow(data, depth = corrections$zero_shallow))
    add("correct", "lif_zero_shallow()", sprintf("depth=%g", corrections$zero_shallow), data)
  }
  if (!is.null(corrections$zero_below)) {
    say("[process_site] zeroing readings below threshold")
    data <- hush(lif_zero_below_threshold(data, threshold = corrections$zero_below))
    add("correct", "lif_zero_below_threshold()",
        sprintf("threshold=%g", corrections$zero_below), data)
  }
  if (!is.null(corrections$hp)) {
    if (!"hp" %in% names(data) || all(is.na(data$hp))) {
      say("[process_site] hp correction skipped: no hp channel")
    } else {
      say("[process_site] hydrostatic HP correction")
      p <- if (isTRUE(corrections$hp)) list() else corrections$hp
      data <- hush(do.call(hp_correction, c(list(data), p)))
      add("correct", "hp_correction()",
          paste(names(p), unlist(p), sep = "=", collapse = "; "), data)
    }
  }

  summ <- tryCatch(summarize_lif(data), error = function(e) {
    say("[process_site] summary skipped: ", conditionMessage(e)); NULL })

  chart_files <- character(0)
  if (isTRUE(charts)) {
    chart_files <- tryCatch(export_site_charts(data, output_dir, prefix,
                                               thresholds = response_thresholds %||% c(1, 5),
                                               quiet = TRUE),
                            error = function(e) { say("[process_site] charts skipped: ",
                                                      conditionMessage(e)); character(0) })
    if (length(chart_files))
      add("charts", "export_site_charts()", paste(basename(chart_files), collapse = ", "), data)
  }

  result <- structure(list(
    data = data, raw_data = raw_data, site_name = site_name, log = log,
    summary = summ, edits = suppressMessages(edit_history(data)),
    charts = chart_files, reports = list(),
    meta = list(started = started, data_dir = data_dir, output_dir = output_dir,
                prefix = prefix, crs = crs, response_thresholds = response_thresholds,
                lifr_version = as.character(utils::packageVersion("lifr")))),
    class = "lif_site")

  if (isTRUE(report) && length(report_formats))
    result$reports <- tryCatch(
      site_report(result, formats = report_formats, output_dir = output_dir,
                  file_prefix = prefix, quiet = quiet),
      error = function(e) { say("[process_site] report skipped: ",
                                conditionMessage(e)); list() })
  invisible(result)
}

#' @export
print.lif_site <- function(x, ...) {
  cat(sprintf("<lif_site> %s\n", x$site_name))
  cat(sprintf("  %d boring(s), %d sample(s), %d edit(s), %d chart(s)\n",
              length(unique(x$data$boring)), nrow(x$data), nrow(x$edits),
              length(x$charts)))
  if (length(x$reports))
    cat("  report(s): ", paste(unlist(x$reports), collapse = ", "), "\n", sep = "")
  invisible(x)
}

# ---------------------------------------------------------------------------
# Shared building blocks
# ---------------------------------------------------------------------------

.h_esc <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  gsub("'", "&#39;", x, fixed = TRUE)
}

.fmt_cell <- function(v, esc = TRUE) {
  out <- if (is.numeric(v)) formatC(v, digits = 4, format = "fg")
         else if (esc) .h_esc(v) else as.character(v)
  out[is.na(v)] <- "\u2014"
  out
}

.df_html_table <- function(df, max_rows = Inf) {
  if (is.null(df) || nrow(df) == 0) return("<p class='muted'>None.</p>")
  n_total <- nrow(df); df <- utils::head(df, max_rows)
  th <- paste0("<th>", .h_esc(names(df)), "</th>", collapse = "")
  cells <- vapply(df, .fmt_cell, character(nrow(df)))
  if (!is.matrix(cells)) cells <- matrix(cells, nrow = nrow(df))
  rows <- vapply(seq_len(nrow(cells)), function(i)
    paste0("<tr>", paste0("<td>", cells[i, ], "</td>", collapse = ""), "</tr>"), character(1))
  note <- if (n_total > nrow(df))
    sprintf("<p class='muted'>Showing %d of %d rows.</p>", nrow(df), n_total) else ""
  paste0("<div class='tablewrap'><table class='sortable'><thead><tr>", th,
         "</tr></thead><tbody>", paste(rows, collapse = ""), "</tbody></table></div>", note)
}

.md_table <- function(df, max_rows = Inf) {
  if (is.null(df) || nrow(df) == 0) return("_None._\n")
  n_total <- nrow(df); df <- utils::head(df, max_rows)
  esc <- function(s) gsub("|", "\\|", gsub("[\r\n]+", " ", s), fixed = TRUE)
  cells <- vapply(df, function(v) esc(.fmt_cell(v, esc = FALSE)), character(nrow(df)))
  if (!is.matrix(cells)) cells <- matrix(cells, nrow = nrow(df))
  # Underscored headers cannot wrap in a pandoc pipe table, so a wide table
  # overflows the PDF page; spaces let LaTeX break them.
  hdr <- paste0("| ", paste(esc(gsub("_", " ", names(df), fixed = TRUE)),
                            collapse = " | "), " |")
  sep <- paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |")
  rows <- vapply(seq_len(nrow(cells)), function(i)
    paste0("| ", paste(cells[i, ], collapse = " | "), " |"), character(1))
  note <- if (n_total > nrow(df)) sprintf("\n\n_Showing %d of %d rows._", nrow(df), n_total) else ""
  paste0(paste(c(hdr, sep, rows), collapse = "\n"), note, "\n")
}

.stat_tile <- function(value, label) sprintf(
  "<div class='tile'><div class='tile-val'>%s</div><div class='tile-lab'>%s</div></div>",
  .h_esc(value), .h_esc(label))

# Render a ggplot to a base64 <img>, or "" on failure.
.embed_img <- function(p, alt, width = 7, height = 5, dpi = 110) {
  tryCatch({
    f <- tempfile(fileext = ".png")
    on.exit(unlink(f), add = TRUE)
    suppressMessages(ggplot2::ggsave(f, p, width = width, height = height, dpi = dpi))
    sprintf("<img class='fig' alt='%s' src='%s' />", .h_esc(alt),
            base64enc::dataURI(file = f, mime = "image/png"))
  }, error = function(e) "")
}

# Write a named list of ggplots as PNG sidecars; returns basenames named by
# their caption.
.write_pngs <- function(plots, alts, output_dir, slug, tag, width = 7, height = 5) {
  files <- character(0)
  for (nm in names(plots)) {
    f <- paste0(slug, "_", tag, "_", nm, ".png")
    ok <- tryCatch({
      suppressMessages(ggplot2::ggsave(file.path(output_dir, f), plots[[nm]],
                                       width = width, height = height, dpi = 110))
      TRUE
    }, error = function(e) FALSE)
    if (ok) files[[alts[[nm]]]] <- f
  }
  files
}

# Renderer bundles: the same section builders emit HTML or Markdown.
.html_r <- list(
  table = .df_html_table,
  h2 = function(s) paste0("<h2>", .h_esc(s), "</h2>"),
  h3 = function(s) paste0("<h3>", .h_esc(s), "</h3>"),
  note = function(s) paste0("<p class='muted'>", .h_esc(s), "</p>"),
  para = function(s) paste0("<p>", .h_esc(s), "</p>"),
  none = function(s) paste0("<p class='muted'>", .h_esc(s), "</p>"))
.md_r <- list(
  table = .md_table,
  h2 = function(s) paste0("\n### ", s, "\n"),
  h3 = function(s) paste0("\n#### ", s, "\n"),
  note = function(s) paste0("\n_", s, "_\n"),
  para = function(s) paste0("\n", s, "\n"),
  none = function(s) paste0("_", s, "_\n"))

# ---------------------------------------------------------------------------
# Figures built once and shared by every format
# ---------------------------------------------------------------------------

.REPORT_MAP_ALTS <- c(imagery = "Boring locations over aerial imagery",
                      response = "Boring locations sized by peak signal")
.REPORT_CHART_ALTS <- c(max_response = "Maximum LIF response by boring",
                        ec = "Pooled electrical conductivity (EC) distribution, mS/m",
                        hp = "Pooled hydraulic pressure (HP) distribution, psi")

.report_maps <- function(x) {
  d <- x$data
  if (!all(c("easting", "northing", "signal") %in% names(d))) return(NULL)
  if (all(is.na(d$easting)) || all(is.na(d$northing))) return(NULL)
  bm <- NULL; fetch_failed <- FALSE
  if (!is.null(x$meta$crs)) {
    bm <- suppressWarnings(fetch_basemap(d, crs = x$meta$crs))
    fetch_failed <- is.null(bm)
  }
  plots <- list()
  if (!is.null(bm))
    plots$imagery <- boring_map(d, basemap = bm, size_by_signal = FALSE,
                                title = "Boring locations - site imagery",
                                site_name = x$site_name)
  plots$response <- boring_map(d, basemap = bm, use_instrument_color = TRUE,
                               site_name = x$site_name)
  list(plots = plots, fetch_failed = fetch_failed)
}

.report_charts <- function(x) {
  d <- x$data
  thr <- x$meta$response_thresholds %||% c(1, 5)
  out <- list()
  p <- tryCatch(chart_max_response(d, thresholds = thr), error = function(e) NULL)
  if (!is.null(p)) out$max_response <- p
  for (nm in c("ec", "hp")) {
    p <- tryCatch(switch(nm, ec = chart_ec_histogram(d), hp = chart_hp_histogram(d)),
                  error = function(e) NULL)
    if (!is.null(p)) out[[nm]] <- p
  }
  out
}

# The depth windows a boring's audit rows zeroed, clamped to [0, xmax]. Keep
# rows are inverted: they record the KEPT span, so the zeroed depths are
# its complement.
.boring_edit_windows <- function(edits, b, xmax) {
  if (!is.data.frame(edits) || nrow(edits) == 0L) return(list())
  ed <- edits[(is.na(edits$boring) | edits$boring == b) &
              (!is.na(edits$top) | !is.na(edits$bottom)), , drop = FALSE]
  if (nrow(ed) == 0L) return(list())
  out <- list()
  for (j in seq_len(nrow(ed))) {
    e_top <- if (is.na(ed$top[j])) 0 else max(0, ed$top[j])
    e_bot <- if (is.na(ed$bottom[j])) xmax else min(xmax, ed$bottom[j])
    note <- ed$notes[j]
    if (is.character(note) && !is.na(note) && startsWith(note, "kept ")) {
      kept <- .parse_kept_windows(note) %||% list(c(e_top, e_bot))
      kept <- lapply(kept, function(w) c(max(0, w[1]), min(xmax, w[2])))
      kept <- kept[order(vapply(kept, `[`, numeric(1), 1L))]
      lo <- 0
      for (w in kept) {
        if (w[1] > lo) out[[length(out) + 1L]] <- c(lo, w[1])
        lo <- max(lo, w[2])
      }
      if (lo < xmax) out[[length(out) + 1L]] <- c(lo, xmax)
    } else out[[length(out) + 1L]] <- c(e_top, e_bot)
  }
  out
}

# Per-boring log plots: an input | edited pair with the zeroed windows
# shaded when anything was edited, else the single input log.
.report_log_plots <- function(x) {
  raw <- x$raw_data %||% x$data; proc <- x$data
  if (!all(c("boring", "depth", "signal") %in% names(proc))) return(NULL)
  paired <- is.data.frame(x$edits) && nrow(x$edits) > 0
  borings <- sort(unique(as.character(proc$boring)))
  plots <- list()
  for (b in borings) {
    rd <- raw[raw$boring == b, , drop = FALSE]; pd <- proc[proc$boring == b, , drop = FALSE]
    xmax <- suppressWarnings(max(c(rd$depth, pd$depth), na.rm = TRUE))
    if (!is.finite(xmax) || xmax <= 0) xmax <- 1
    ymax <- .axis_cap(c(rd$signal, pd$signal), 200)
    left <- .lif_panel(rd, b, xmax, ymax, title = paste0(b, " - input"))
    if (!paired) { plots[[b]] <- left; next }
    right <- .lif_panel(pd, b, xmax, ymax, show_y_axis = FALSE,
                        title = paste0(b, " - edited"))
    shade <- .boring_edit_windows(x$edits, b, xmax)
    if (length(shade)) {
      top <- vapply(shade, `[`, numeric(1), 1L); bot <- vapply(shade, `[`, numeric(1), 2L)
      ok <- is.finite(top) & is.finite(bot) & bot > top
      if (any(ok))
        right <- right + ggplot2::annotate("rect", xmin = top[ok], xmax = bot[ok],
                                           ymin = -Inf, ymax = Inf,
                                           fill = "#e34948", alpha = 0.15)
    }
    bulk <- x$edits[(is.na(x$edits$boring) | x$edits$boring == b) &
                    is.na(x$edits$top) & is.na(x$edits$bottom), , drop = FALSE]
    if (nrow(bulk)) {
      lab <- vapply(seq_len(nrow(bulk)), function(j) {
        n <- bulk$n_rows_changed[j]
        cnt <- if (is.na(n) || n <= 0) "" else sprintf(" (%d row%s)", as.integer(n),
                                                       if (n == 1) "" else "s")
        note <- if (identical(bulk$fn[j], "hp_correction"))
          " - does not alter the plotted signal" else ""
        paste0(bulk$fn[j], cnt, note)
      }, character(1))
      right <- right + ggplot2::labs(caption = paste0(strwrap(
        paste0("Whole-log edit(s), no depth window to shade: ",
               paste(lab, collapse = "; ")), width = 90), collapse = "\n"))
    }
    plots[[b]] <- patchwork::wrap_plots(left, right, nrow = 1L)
  }
  if (!length(plots)) return(NULL)
  list(plots = plots, paired = paired)
}

# Which borings actually changed between raw and processed, with a short
# label of the edited windows for the log-browser badges.
.log_change_summary <- function(x) {
  proc <- x$data; raw <- x$raw_data
  if (!is.data.frame(raw) || !all(c("boring", "depth", "signal") %in% names(raw)) ||
      !all(c("boring", "depth", "signal") %in% names(proc))) return(NULL)
  borings <- sort(union(unique(as.character(raw$boring)), unique(as.character(proc$boring))))
  same <- function(a, b) (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & abs(a - b) <= 1e-9)
  rows <- lapply(borings, function(b) {
    rd <- raw[raw$boring == b, , drop = FALSE]; pd <- proc[proc$boring == b, , drop = FALSE]
    if (nrow(pd) == 0L)
      return(data.frame(boring = b, changed = TRUE, label = "removed", stringsAsFactors = FALSE))
    changed <- if (nrow(rd) != nrow(pd)) TRUE
               else any(!same(rd$depth, pd$depth) | !same(rd$signal, pd$signal))
    xmax <- suppressWarnings(max(c(rd$depth, pd$depth), na.rm = TRUE))
    if (!is.finite(xmax) || xmax <= 0) xmax <- 1
    label <- if (!changed) "" else {
      w <- .boring_edit_windows(x$edits, b, xmax)
      if (length(w)) paste(unique(vapply(w, function(v) sprintf("%g\u2013%g ft", v[1], v[2]),
                                         character(1))), collapse = ", ")
      else {
        bulk <- x$edits[(is.na(x$edits$boring) | x$edits$boring == b) &
                        is.na(x$edits$top) & is.na(x$edits$bottom), , drop = FALSE]
        if (nrow(bulk)) paste(unique(bulk$fn), collapse = ", ") else "changed"
      }
    }
    data.frame(boring = b, changed = changed, label = label, stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

# ---------------------------------------------------------------------------
# Sections (format-agnostic via a renderer bundle)
# ---------------------------------------------------------------------------

.boring_peak_table <- function(data) {
  pk <- .boring_peaks(data)
  out <- data.frame(boring = pk$boring,
                    peak_signal = ifelse(pk$sampled, pk$peak_signal, NA_real_),
                    peak_depth = pk$peak_depth, stringsAsFactors = FALSE)
  out[order(-out$peak_signal, out$boring), , drop = FALSE]
}

.response_section <- function(x, r) {
  d <- x$data
  if (!all(c("boring", "signal") %in% names(d))) return("")
  pk <- .boring_peak_table(d)
  thr <- if ("response_thresholds" %in% names(x$meta)) x$meta$response_thresholds %||% numeric(0)
         else c(1, 10, 50)
  parts <- c(r$note(.RE_PROXY_NOTE), r$h2("Peak response by boring (%RE)"), r$table(pk))
  for (t in thr) {
    sub <- pk[!is.na(pk$peak_signal) & pk$peak_signal > t, , drop = FALSE]
    parts <- c(parts, r$h3(sprintf("Borings with peak response > %s %%RE (n = %d)",
                                   format(t), nrow(sub))),
               if (nrow(sub)) r$table(sub) else r$none("None."))
  }
  paste(parts, collapse = "\n")
}

.depth_interval <- function(depth) {
  d <- sort(unique(depth[is.finite(depth)]))
  if (length(d) < 2L) NA_real_ else stats::median(diff(d))
}

.data_inventory <- function(x) {
  d <- x$data
  if (!is.data.frame(d) || !all(c("boring", "depth") %in% names(d))) return(NULL)
  chans <- intersect(c("signal", "ec", "hp", "color"), names(d))
  rows <- lapply(sort(unique(as.character(d$boring))), function(b) {
    g <- d[d$boring == b, , drop = FALSE]
    present <- chans[vapply(chans, function(cc) any(!is.na(g[[cc]])), logical(1))]
    dep <- g$depth[is.finite(g$depth)]; n <- length(dep)
    data.frame(boring = b, samples = n,
               top_ft = if (n) min(dep) else NA_real_,
               bottom_ft = if (n) max(dep) else NA_real_,
               interval_ft = if (n) .depth_interval(dep) else NA_real_,
               channels = if (length(present)) paste(present, collapse = "+") else NA_character_,
               stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

.dataqa_section <- function(x, r) {
  d <- x$data
  chans <- intersect(c("signal", "ec", "hp", "color"), names(d))
  extra <- setdiff(names(d), .LIF_LEAD_COLS)
  ext <- if (all(c("easting", "northing") %in% names(d)) && any(is.finite(d$easting)))
    sprintf("E %.0f\u2013%.0f, N %.0f\u2013%.0f", min(d$easting, na.rm = TRUE),
            max(d$easting, na.rm = TRUE), min(d$northing, na.rm = TRUE),
            max(d$northing, na.rm = TRUE)) else "n/a"
  parts <- c(r$h2("Data inventory"), r$table(.data_inventory(x)),
             r$h2("Data overview"),
             r$para(sprintf("Channels present: %s. Spatial extent: %s.%s",
                            paste(chans, collapse = ", "), ext,
                            if (length(extra)) paste0(" Additional source columns carried through: ",
                                                      paste(extra, collapse = ", "), ".") else "")),
             r$h2("Summary statistics"))
  if (is.null(x$summary)) parts <- c(parts, r$none("Summary unavailable."))
  else {
    s <- x$summary
    ov <- s$overview; ov$units <- "%RE"
    parts <- c(parts, r$h3("Overview"), r$table(ov),
               r$h3("By boring"), r$table(s$by_boring),
               r$h3("Detections by threshold"), r$table(s$by_threshold),
               r$h3("By depth zone"), r$table(s$by_depth_zone))
  }
  paste(parts, collapse = "\n")
}

.DEFS_NOTE <- paste0(
  "Definitions: pct_detect counts values above detection_limit (default 0, so ",
  "any response counts as a detection). geom_mean is over positive values only. ",
  .RE_PROXY_NOTE)

.CORRECTION_FNS <- c("hp_correction", "lif_zero_shallow", "lif_zero_below_threshold",
                     "lif_downsample")

.history_section <- function(x, r) {
  imp <- x$log[x$log$step == "import", , drop = FALSE]
  parts <- c(r$h2("Import"), r$note(sprintf(
    "%s rows across %s borings imported from %s.",
    if (nrow(imp)) format(imp$n_rows[1], big.mark = ",") else "?",
    if (nrow(imp)) imp$n_borings[1] else "?", x$meta$data_dir %||% "the source directory")))
  parts <- c(parts, r$h2("Edit & change log"),
             if (nrow(x$edits) == 0L) r$none("No edits recorded.") else r$table(x$edits))
  corr <- if (nrow(x$edits) && "fn" %in% names(x$edits))
    x$edits[x$edits$fn %in% .CORRECTION_FNS, , drop = FALSE] else x$edits[0, ]
  parts <- c(parts, r$h2("Corrections"),
             if (nrow(corr) == 0L) r$none("No corrections applied.") else r$table(corr))
  parts <- c(parts, r$h2("Pipeline steps"), r$table(x$log))
  paste(parts, collapse = "\n")
}

# ---------------------------------------------------------------------------
# HTML
# ---------------------------------------------------------------------------

.report_css <- "
:root{--s1:#fcfcfb;--s2:#ffffff;--tp:#0b0b0b;--ts:#52514e;--tm:#8a8984;--ac:#2a78d6;--bd:#e6e5e1;--crit:#d03b3b}
@media(prefers-color-scheme:dark){:root{--s1:#1a1a19;--s2:#232322;--tp:#fff;--ts:#c3c2b7;--tm:#8f8e86;--ac:#3987e5;--bd:#333330}}
*{box-sizing:border-box}
body{margin:0;background:var(--s1);color:var(--tp);font:15px/1.55 -apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif}
.wrap{max-width:1040px;margin:0 auto;padding:32px 24px 64px}
h1{font-size:26px;margin:0 0 2px}
h2{font-size:18px;margin:36px 0 12px;padding-bottom:6px;border-bottom:1px solid var(--bd)}
h3{font-size:15px;margin:22px 0 8px}
.sub{color:var(--ts);margin:0 0 24px} .meta{color:var(--tm);font-size:13px}
.tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:12px;margin:18px 0}
.tile{background:var(--s2);border:1px solid var(--bd);border-radius:10px;padding:16px}
.tile-val{font-size:26px;font-weight:650;letter-spacing:-.01em}
.tile-lab{color:var(--ts);font-size:12px;text-transform:uppercase;letter-spacing:.04em;margin-top:4px}
table{border-collapse:collapse;width:100%;font-size:13px;margin:8px 0 4px}
th,td{text-align:left;padding:7px 10px;border-bottom:1px solid var(--bd)}
th{color:var(--ts);font-weight:600;cursor:pointer;user-select:none;white-space:nowrap;position:sticky;top:0;background:var(--s1)}
th:hover{color:var(--ac)} tbody tr:hover{background:var(--s2)} td{font-variant-numeric:tabular-nums}
.muted{color:var(--tm)} .fig{max-width:100%;border:1px solid var(--bd);border-radius:10px;margin:8px 0;background:#fff}
.tablewrap{max-height:420px;overflow:auto;border:1px solid var(--bd);border-radius:10px}
.tabbar{display:flex;gap:4px;margin:28px 0 0;border-bottom:1px solid var(--bd)}
.tabbar .tab{background:none;border:1px solid transparent;border-bottom:none;padding:8px 18px;font:inherit;font-size:14px;color:var(--ts);cursor:pointer;border-radius:10px 10px 0 0;margin-bottom:-1px}
.tabbar .tab:hover{color:var(--ac)}
.tabbar .tab.active{background:var(--s2);border-color:var(--bd);color:var(--tp);font-weight:600}
.tabpane{display:none;padding-top:4px} .tabpane.active{display:block}
code{background:var(--s2);padding:1px 5px;border-radius:4px;font-size:12px}
footer{color:var(--tm);font-size:12px;margin-top:40px;border-top:1px solid var(--bd);padding-top:12px}
.logctl{display:flex;flex-wrap:wrap;gap:14px;align-items:center;margin:14px 0}
.logctl label{font-size:13px;cursor:pointer} .count{color:var(--tm);font-size:13px} .count-print{display:none}
.boringnav{position:sticky;top:0;z-index:5;background:var(--s1);border-bottom:1px solid var(--bd);padding:8px 0;margin-bottom:8px;display:flex;flex-wrap:wrap;gap:6px}
.boringnav a{font-size:12px;color:var(--ts);text-decoration:none;border:1px solid var(--bd);border-radius:6px;padding:2px 7px}
.boringnav a.chg{color:var(--tp);border-color:var(--ac)}
.boringlog{scroll-margin-top:52px} .boringlog h3{font-size:15px;margin:18px 0 6px}
.badge{font-size:11px;font-weight:600;color:#fff;background:var(--crit);border-radius:5px;padding:1px 6px;margin-left:6px;vertical-align:middle}
@media print{
 .tabbar{display:none} .tabpane{display:block}
 .tabpane::before{content:attr(data-tab-title);display:block;font-size:1.3em;font-weight:700;margin:0.8em 0 0.3em;border-bottom:2px solid var(--bd)}
 .tablewrap{max-height:none;overflow:visible}
 .boringlog[hidden]{display:block!important}
 .boringnav,.logctl label{display:none} .count-screen{display:none} .count-print{display:inline}
}
"

.report_js <- "
document.querySelectorAll('table.sortable').forEach(function(t){
 t.querySelectorAll('th').forEach(function(th,i){
  th.addEventListener('click',function(){
   var tb=t.tBodies[0],rows=[].slice.call(tb.rows);
   var asc=th.dataset.asc!=='1';th.dataset.asc=asc?'1':'0';
   rows.sort(function(a,b){var x=a.cells[i].innerText,y=b.cells[i].innerText;
    var nx=parseFloat(x),ny=parseFloat(y);
    if(!isNaN(nx)&&!isNaN(ny)){return asc?nx-ny:ny-nx;}
    return asc?x.localeCompare(y):y.localeCompare(x);});
   rows.forEach(function(r){tb.appendChild(r);});});});});
function activateTab(name){
 var btn=document.querySelector(\".tabbar .tab[data-tab='\"+name+\"']\");
 var pane=document.getElementById('tab-'+name);
 if(!btn||!pane){return;}
 document.querySelectorAll('.tabbar .tab').forEach(function(x){x.classList.remove('active');});
 document.querySelectorAll('.tabpane').forEach(function(p){p.classList.remove('active');});
 btn.classList.add('active');pane.classList.add('active');}
document.querySelectorAll('.tabbar .tab').forEach(function(b){
 b.addEventListener('click',function(){activateTab(b.dataset.tab);
  history.replaceState(null,'','#'+b.dataset.tab);});});
if(location.hash){activateTab(location.hash.slice(1));}
(function(){
 var secs=[].slice.call(document.querySelectorAll('.boringlog'));
 if(!secs.length){return;}
 var nav=document.querySelector('.boringnav');
 var links=nav?[].slice.call(nav.querySelectorAll('a')):[];
 var box=document.getElementById('chgonly');
 var cnt=document.getElementById('logcount');
 function apply(){
  var only=box&&box.checked;
  secs.forEach(function(s){s.hidden=!!(only&&s.dataset.changed==='0');});
  links.forEach(function(a){var s=document.getElementById(a.getAttribute('href').slice(1));
   a.hidden=!!(s&&s.hidden);});
  if(cnt){var n=secs.filter(function(s){return !s.hidden;}).length,t=secs.length;
   cnt.textContent=only?('Showing '+n+' of '+t+' borings ('+(t-n)+' unchanged, hidden).'):('Showing all '+t+' borings.');}}
 if(box){box.addEventListener('change',apply);apply();}
})();
"

.embed_boring_logs_html <- function(x, lp) {
  if (is.null(lp))
    return("<h2>Boring logs</h2><p class='muted'>No per-boring logs available.</p>")
  intro <- if (lp$paired)
    "<p>Input data (left) beside the edited data (right); shaded bands mark the depth windows the recorded edits zeroed, and whole-log edits without a depth window are named beneath the edited panel.</p>"
  else "<p>Input data as imported; no edits or corrections were applied.</p>"
  w <- if (lp$paired) 9 else 5
  imgs <- vapply(names(lp$plots), function(b)
    .embed_img(lp$plots[[b]], alt = paste0(b, if (lp$paired) " input vs edited log" else " input log"),
               width = w, height = 4.5), character(1))
  chg <- .log_change_summary(x)
  borings <- names(lp$plots)
  ids <- paste0("log-", .h_esc(borings))
  state <- if (is.null(chg)) rep(NA, length(borings)) else chg$changed[match(borings, chg$boring)]
  label <- if (is.null(chg)) rep("", length(borings)) else chg$label[match(borings, chg$boring)]
  n_changed <- sum(state %in% TRUE)
  filterable <- !is.null(chg) && any(state %in% TRUE) && any(state %in% FALSE)
  sections <- vapply(seq_along(borings), function(i) {
    badge <- if (isTRUE(state[i]) && nzchar(label[i] %||% ""))
      paste0(" <span class='badge'>", .h_esc(label[i]), "</span>") else ""
    paste0("<section class='boringlog' id='", ids[i], "' data-changed='",
           if (isTRUE(state[i])) "1" else if (isFALSE(state[i])) "0" else "",
           "'><h3>", .h_esc(borings[i]), badge, "</h3>", imgs[i], "</section>")
  }, character(1))
  nav <- paste0("<nav class='boringnav' aria-label='Borings'>",
                paste0("<a href='#", ids, "'", ifelse(state %in% TRUE, " class='chg'", ""), ">",
                       .h_esc(borings), "</a>", collapse = ""), "</nav>")
  total <- length(borings)
  controls <- if (filterable) paste0(
    "<div class='logctl'><label><input type='checkbox' id='chgonly' checked> Changed borings only</label>",
    "<span class='count count-screen' id='logcount'>Showing ", n_changed, " of ", total,
    " borings (", total - n_changed, " unchanged, hidden).</span>",
    "<span class='count count-print'>", total, " borings (complete record).</span></div>")
  else paste0("<div class='logctl'><span class='count'>", total, " boring", if (total == 1L) "" else "s",
              if (is.null(chg)) "." else if (n_changed == 0L) ", none changed by the pipeline."
              else " (all changed).", "</span></div>")
  paste0("<h2>Boring logs</h2>", intro, controls, nav, paste(sections, collapse = "\n"))
}

.report_html <- function(x, mp, lp, cc) {
  d <- x$data; r <- .html_r
  chans <- intersect(c("signal", "ec", "hp", "color"), names(d))
  drng <- if ("depth" %in% names(d) && any(!is.na(d$depth)))
    suppressWarnings(range(d$depth, na.rm = TRUE)) else c(NA_real_, NA_real_)
  tiles <- paste0(.stat_tile(length(unique(d$boring)), "Borings"),
                  .stat_tile(format(nrow(d), big.mark = ","), "Samples"),
                  .stat_tile(sprintf("%.1f\u2013%.1f ft", drng[1], drng[2]), "Depth range"),
                  .stat_tile(length(chans), "Channels"),
                  .stat_tile(nrow(x$edits), "Edits"))
  maps_html <- if (is.null(mp)) "<p class='muted'>Boring map: no coordinates joined.</p>" else paste(
    c(if (mp$fetch_failed) "<p class='muted'>Imagery basemap unavailable (offline, service error, or site outside US coverage); continuing without it.</p>",
      vapply(names(mp$plots), function(nm) .embed_img(mp$plots[[nm]], .REPORT_MAP_ALTS[[nm]]),
             character(1))), collapse = "\n")
  charts_html <- if (!length(cc)) "" else paste0(
    "<h2>Site charts</h2>",
    paste(vapply(names(cc), function(nm) .embed_img(cc[[nm]], .REPORT_CHART_ALTS[[nm]],
                                                    height = 3.6), character(1)),
          collapse = "\n"))
  edits_pointer <- sprintf(
    "<p class='muted'>%d edit%s recorded \u2014 see the Processing history tab for the complete audit trail.</p>",
    nrow(x$edits), if (nrow(x$edits) == 1L) "" else "s")

  paste0(
    "<!doctype html><html lang='en'><head><meta charset='utf-8'>",
    "<meta name='viewport' content='width=device-width,initial-scale=1'>",
    "<title>", .h_esc(x$site_name), " \u2014 LIF site report</title><style>", .report_css,
    "</style></head><body><div class='wrap'>",
    "<h1>", .h_esc(x$site_name), "</h1><p class='sub'>LIF site report</p>",
    "<p class='meta'>Generated ", .h_esc(x$meta$started), " &middot; lifr ",
    .h_esc(x$meta$lifr_version), " &middot; source <code>", .h_esc(x$meta$data_dir), "</code></p>",
    "<div class='tiles'>", tiles, "</div>",
    "<div class='tabbar' role='tablist'>",
    "<button class='tab active' data-tab='summary'>Summary</button>",
    "<button class='tab' data-tab='data-qa'>Data &amp; QA</button>",
    "<button class='tab' data-tab='history'>Processing history</button>",
    "<button class='tab' data-tab='logs'>Boring logs</button></div>",
    "<div id='tab-summary' class='tabpane active' data-tab-title='Summary'>",
    maps_html, edits_pointer, .response_section(x, r), "</div>",
    "<div id='tab-data-qa' class='tabpane' data-tab-title='Data &amp; QA'>",
    .dataqa_section(x, r), charts_html, r$note(.DEFS_NOTE), "</div>",
    "<div id='tab-history' class='tabpane' data-tab-title='Processing history'>",
    "<p class='muted'>Chronological record of what was done to this data, in pipeline order.</p>",
    .history_section(x, r), "</div>",
    "<div id='tab-logs' class='tabpane' data-tab-title='Boring logs'>",
    .embed_boring_logs_html(x, lp), "</div>",
    "<footer>Report generated by lifr::process_site(). The Processing history tab is the ",
    "complete audit trail of edits applied to the data.</footer>",
    "</div><script>", .report_js, "</script></body></html>")
}

# ---------------------------------------------------------------------------
# Markdown
# ---------------------------------------------------------------------------

.report_md <- function(x, map_files = character(), chart_files = character(),
                       logs_pdf = NULL, has_logs = FALSE) {
  d <- x$data; r <- .md_r
  chans <- intersect(c("signal", "ec", "hp", "color"), names(d))
  drng <- if ("depth" %in% names(d) && any(!is.na(d$depth)))
    suppressWarnings(range(d$depth, na.rm = TRUE)) else c(NA_real_, NA_real_)
  figs <- function(files, title) if (!length(files)) "" else
    paste0("\n### ", title, "\n\n",
           paste0("![", names(files), "](", files, ")", collapse = "\n\n"), "\n\n")
  logs_md <- if (!has_logs) "" else paste0(
    "\n## Boring logs\n\n",
    if (!is.null(logs_pdf)) paste0("One page per boring in [`", logs_pdf, "`](", logs_pdf, ").\n")
    else "Rendered in the HTML report's Boring logs tab; request the \"pdf\" format for the standalone one-page-per-boring PDF.\n")
  paste0(
    "# ", x$site_name, " \u2014 LIF site report\n\n",
    "_Generated ", x$meta$started, " \u00b7 lifr ", x$meta$lifr_version, "_\n\n",
    "- Borings: **", length(unique(d$boring)), "**\n",
    "- Samples: **", nrow(d), "**\n",
    "- Depth range: **", sprintf("%.1f\u2013%.1f ft", drng[1], drng[2]), "**\n",
    "- Channels: `", paste(chans, collapse = "`, `"), "`\n",
    "- Edits recorded: **", nrow(x$edits), "**\n\n",
    "## Summary\n", figs(map_files, "Maps"), .response_section(x, r), "\n",
    "## Data & QA\n", .dataqa_section(x, r), figs(chart_files, "Site charts"),
    r$note(.DEFS_NOTE), "\n",
    "## Processing history\n", r$note("Chronological record of what was done to this data, in pipeline order."),
    .history_section(x, r), "\n", logs_md)
}

# ---------------------------------------------------------------------------
# Renderer entry point
# ---------------------------------------------------------------------------

#' Render the site report from a `lif_site` object
#'
#' Renders the object returned by [process_site()] into any of:
#' * `"html"`: one self-contained file (inline CSS/JS, base64 figures,
#'   sortable tables) with four tabs: **Summary** (tiles, boring maps, the
#'   %RE proxy disclosure, peak-response tables), **Data & QA** (per-boring
#'   inventory, summary statistics, site charts), **Processing history**
#'   (the complete edit log, corrections, pipeline steps), and **Boring
#'   logs** (input-vs-edited log pairs with a changed-only filter). Printing
#'   shows every tab as its own section.
#' * `"md"`: a Markdown document that references its figures as PNG
#'   sidecars written next to it.
#' * `"pdf"`: the Markdown rendered through `rmarkdown` (pandoc plus a LaTeX
#'   distribution such as TinyTeX). Skipped with a warning when that
#'   toolchain is missing. Also writes `<prefix>_logs.pdf`, one page per
#'   boring, through R's own `pdf()` device, which needs no LaTeX.
#'
#' @param x A `lif_site` object.
#' @param formats Any of `"html"`, `"md"`, `"pdf"`.
#' @param output_dir Directory to write into (created if missing).
#' @param file_prefix Base filename. Default: the prefix recorded by
#'   [process_site()], else a slug of the site name. Existing files are
#'   overwritten.
#' @param quiet Suppress the "written" messages.
#' @return Invisibly, a named list of the paths written (`html`, `md`,
#'   `pdf`, `logs_pdf` as applicable).
#' @examples
#' \donttest{
#' demo <- system.file("extdata", "demo", package = "lifr")
#' out <- tempfile("site")
#' site <- process_site(demo, output_dir = out, report = FALSE, quiet = TRUE)
#' site_report(site, formats = "md", output_dir = out, quiet = TRUE)
#' }
#' @export
site_report <- function(x, formats = c("html", "md"), output_dir = ".",
                        file_prefix = NULL, quiet = FALSE) {
  if (!inherits(x, "lif_site"))
    stop("site_report: x must be a lif_site object from process_site().", call. = FALSE)
  formats <- match.arg(formats, c("html", "md", "pdf"), several.ok = TRUE)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  slug <- file_prefix %||% x$meta$prefix %||% .site_slug(x$site_name)
  mp <- .report_maps(x)
  lp <- .report_log_plots(x)
  cc <- .report_charts(x)
  out <- list()
  if ("html" %in% formats) {
    f <- file.path(output_dir, paste0(slug, "_report.html"))
    writeLines(.report_html(x, mp, lp, cc), f, useBytes = TRUE)
    if (!quiet) message("Report written: ", f)
    out$html <- f
  }
  if (any(c("md", "pdf") %in% formats)) {
    map_files <- if (is.null(mp)) character(0)
                 else .write_pngs(mp$plots, .REPORT_MAP_ALTS, output_dir, slug, "map")
    chart_files <- .write_pngs(cc, .REPORT_CHART_ALTS, output_dir, slug, "chart",
                               height = 3.6)
    has_logs <- !is.null(lp) && length(lp$plots) > 0L
    logs_name <- if ("pdf" %in% formats && has_logs) paste0(slug, "_logs.pdf")
    f <- file.path(output_dir, paste0(slug, "_report.md"))
    writeLines(.report_md(x, map_files, chart_files, logs_pdf = logs_name,
                          has_logs = has_logs), f, useBytes = TRUE)
    if (!quiet) message("Report written: ", f)
    out$md <- f
    if ("pdf" %in% formats) {
      pdf <- .render_report_pdf(f, quiet = quiet)
      if (!is.null(pdf)) out$pdf <- pdf
      if (has_logs) {
        lpdf <- .render_logs_pdf(lp, output_dir, slug, quiet = quiet)
        if (!is.null(lpdf)) out$logs_pdf <- lpdf
      }
    }
  }
  invisible(out)
}

.render_report_pdf <- function(md_file, quiet = FALSE) {
  if (!requireNamespace("rmarkdown", quietly = TRUE) || !rmarkdown::pandoc_available()) {
    warning("site_report: PDF output needs the 'rmarkdown' package and pandoc; ",
            "skipping the PDF (other formats were written).", call. = FALSE)
    return(NULL)
  }
  tryCatch({
    out <- rmarkdown::render(md_file,
                             output_format = rmarkdown::pdf_document(latex_engine = "xelatex"),
                             output_file = sub("\\.md$", ".pdf", basename(md_file)),
                             output_dir = dirname(md_file), quiet = TRUE)
    if (!quiet) message("Report written: ", out)
    out
  }, error = function(e) {
    warning("site_report: PDF conversion failed -- is a LaTeX distribution installed ",
            "(tinytex::install_tinytex())? ", conditionMessage(e), call. = FALSE)
    NULL
  })
}

.render_logs_pdf <- function(lp, output_dir, slug, quiet = FALSE) {
  if (is.null(lp) || !length(lp$plots)) return(NULL)
  f <- file.path(output_dir, paste0(slug, "_logs.pdf"))
  opened <- FALSE
  ok <- tryCatch({
    grDevices::pdf(f, width = if (lp$paired) 11 else 8.5, height = 8, onefile = TRUE,
                   useDingbats = FALSE)
    opened <- TRUE
    for (b in names(lp$plots)) print(lp$plots[[b]])
    TRUE
  }, error = function(e) {
    warning("site_report: boring-logs PDF failed (", conditionMessage(e), ").", call. = FALSE)
    FALSE
  })
  if (opened) grDevices::dev.off()
  if (!ok) return(NULL)
  if (!quiet) message("Report written: ", f)
  f
}
