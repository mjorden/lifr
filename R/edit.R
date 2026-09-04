# Editors: mask depth intervals and record every change in an audit trail.
#
# Edits set `signal` to a replacement value (0 by default) inside or outside
# a depth window and append one row per call to attr(data, "edits"). The
# history travels with the frame through every lifr function and is printed
# in the site report; dplyr verbs strip it (see lif_get_edits()).

.BULK_BORING <- "*"

# Append one row to the edits attribute. boring = NA means "all borings".
.record_edit <- function(data, fn, boring, top, bottom, value, n_rows_changed,
                         notes = NA_character_) {
  new_row <- data.frame(
    timestamp      = format(Sys.time(), "%Y-%m-%d %H:%M:%S %z"),
    fn             = fn,
    boring         = if (is.na(boring)) NA_character_ else as.character(boring),
    top            = as.numeric(top),
    bottom         = as.numeric(bottom),
    value          = as.numeric(value),
    n_rows_changed = as.integer(n_rows_changed),
    notes          = if (is.na(notes)) NA_character_ else as.character(notes),
    stringsAsFactors = FALSE
  )
  history <- attr(data, "edits")
  attr(data, "edits") <- if (is.null(history)) new_row else rbind(history, new_row)
  new_edited_data(data)
}

.check_depth_range <- function(top, bottom) {
  if (is.na(top) || is.na(bottom))
    stop(sprintf("top (%s) and bottom (%s) must not be NA",
                 format(top), format(bottom)), call. = FALSE)
  if (top > bottom)
    stop(sprintf("top (%g) must be less than or equal to bottom (%g)",
                 top, bottom), call. = FALSE)
  if (is.finite(top) && top < 0)
    warning(sprintf("top (%g) is negative -- unusual for depth", top),
            call. = FALSE)
  invisible(TRUE)
}

.validate_intervals <- function(x, arg_name) {
  if (!is.list(x) || length(x) == 0L)
    stop(sprintf("`%s` must be a non-empty list of length-2 numeric vectors",
                 arg_name), call. = FALSE)
  for (i in seq_along(x)) {
    iv <- x[[i]]
    if (!is.numeric(iv) || length(iv) != 2L)
      stop(sprintf("`%s[[%d]]` is not a length-2 numeric vector", arg_name, i),
           call. = FALSE)
    .check_depth_range(iv[1L], iv[2L])
  }
  invisible(TRUE)
}

.check_edit_target <- function(data, fn_name) {
  .check_data_arg(data, fn_name)
  .check_required_cols(data, c("boring", "depth", "signal"), source = fn_name)
  invisible(TRUE)
}

.fmt_intervals <- function(intervals) {
  paste(vapply(intervals, function(iv) sprintf("%g-%g ft", iv[1L], iv[2L]),
               character(1)), collapse = ", ")
}

#' Zero LIF signal inside a depth window for one boring
#'
#' Sets `signal` to `value` (default 0) for every reading of `borename`
#' whose depth falls inside the interval(s). Use this to mask known
#' artifacts: surface smear, a rod change, a fluorescent mineral seam. The
#' inverse, keeping one clean window and zeroing everything else, is
#' [lif_keep()].
#'
#' @param data A [lif_data] frame (any data frame with `boring`, `depth`,
#'   `signal`).
#' @param borename Boring name to edit.
#' @param top,bottom Depth interval (ft) to zero. Defaults `0` and `1000`
#'   cover the whole boring, which triggers a warning.
#' @param value Replacement value. Default 0; `NA` is allowed.
#' @param delete Optional list of `c(top, bottom)` pairs to zero several
#'   intervals in one call. Cannot be combined with `top`/`bottom`.
#' @param preview Logical. `TRUE` reports how many rows would change without
#'   modifying the data.
#' @return The edited frame with one audit row per interval appended to its
#'   edit history (see [edit_history()]). With `preview = TRUE` the input is
#'   returned unchanged.
#' @section The audit trail:
#' Every editor appends a row to `attr(data, "edits")` recording the
#' timestamp, function, boring, depth window, replacement value, and number
#' of readings changed. The history prints with the frame, is returned by
#' [edit_history()], can be saved with [edit_history_save()], and is
#' rendered in full on the site report's Processing history tab. dplyr
#' verbs drop it; see [lif_get_edits()] to carry it across a pipe.
#' @section Choosing an editor:
#' * A known artifact inside an otherwise good log: `lif_editor()` with
#'   `top`/`bottom`, or several windows through `delete`.
#' * The same window on every boring (surface smear): [lif_editor_bulk()]
#'   or [lif_zero_shallow()].
#' * One clean interval and everything else suspect: [lif_keep()].
#' * Many edits across a site: put them in a CSV and use
#'   [lif_apply_edits()].
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#'
#' # Mask one interval
#' lif <- lif_editor(lif, "LIF-03", top = 20, bottom = 22)
#'
#' # Several intervals in one call, with NA instead of 0
#' lif <- lif_editor(lif, "LIF-05", delete = list(c(0, 1.5), c(30, Inf)),
#'                   value = NA)
#'
#' # See what a call would do without doing it
#' lif_editor(lif, "LIF-07", top = 0, bottom = 3, preview = TRUE)
#'
#' edit_history(lif)
#' @seealso `vignette("editing")`
#' @export
lif_editor <- function(data, borename, top = 0, bottom = 1000, value = 0,
                       delete = NULL, preview = FALSE) {
  .check_edit_target(data, "lif_editor")
  if (!is.null(delete) && (!missing(top) || !missing(bottom)))
    stop("Use either `delete=` or `top=`/`bottom=`, not both.", call. = FALSE)
  .check_borename(data, borename)
  if (missing(top) && missing(bottom) && is.null(delete))
    warning(sprintf(paste0(
      "lif_editor('%s') called with no top/bottom; zeroing the ENTIRE boring. ",
      "Pass top= and/or bottom= to silence this warning."), borename),
      call. = FALSE)

  intervals <- if (!is.null(delete)) {
    .validate_intervals(delete, "delete"); delete
  } else {
    .check_depth_range(top, bottom); list(c(top, bottom))
  }

  total <- 0L
  out <- data
  for (iv in intervals) {
    mask <- out$boring == borename & !is.na(out$depth) &
            out$depth >= iv[1L] & out$depth <= iv[2L]
    n <- sum(mask)
    total <- total + n
    if (!preview) {
      out$signal[mask] <- value
      out <- .record_edit(out, "lif_editor", borename, iv[1L], iv[2L], value, n)
    }
  }
  message(sprintf("[lif_editor] %s%s: zeroed %d row(s) (%s)",
                  if (preview) "PREVIEW " else "", borename, total,
                  .fmt_intervals(intervals)))
  if (preview) data else out
}

#' Zero LIF signal inside a depth window across all borings
#'
#' @inheritParams lif_editor
#' @param verbose Logical. Print a per-boring breakdown of rows changed.
#' @return The edited frame with one audit row (boring `NA`, meaning all
#'   borings) appended.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' lif <- lif_editor_bulk(lif, top = 0, bottom = 2)
#' lif_editor_bulk(lif, top = 0, bottom = 1, preview = TRUE)
#' @export
lif_editor_bulk <- function(data, top = 0, bottom = 1000, value = 0,
                            preview = FALSE, verbose = TRUE) {
  .check_edit_target(data, "lif_editor_bulk")
  if (missing(top) && missing(bottom))
    warning("lif_editor_bulk() called with no top/bottom; zeroing the ENTIRE ",
            "dataset. Pass top= and/or bottom= to silence this warning.",
            call. = FALSE)
  .check_depth_range(top, bottom)
  mask <- !is.na(data$depth) & data$depth >= top & data$depth <= bottom
  n <- sum(mask)
  borings <- sort(unique(data$boring))
  counts <- vapply(borings, function(b) sum(data$boring == b & mask), integer(1))
  counts <- counts[counts > 0L]
  message(sprintf("[lif_editor_bulk] %szeroed %d row(s) (%g-%g ft) across %d boring(s)",
                  if (preview) "PREVIEW: would have " else "", n, top, bottom,
                  length(borings)))
  if (isTRUE(verbose) && length(counts))
    for (b in names(counts)) message(sprintf("  %-20s %d rows", b, counts[[b]]))
  if (preview) return(data)
  data$signal[mask] <- value
  .record_edit(data, "lif_editor_bulk", NA, top, bottom, value, n)
}

#' Zero signal at or above a given depth
#'
#' Convenience wrapper over [lif_editor()] that masks the top `depth` feet
#' of every boring (or the named `borings`), the usual way to remove
#' surface smear before summarising or mapping.
#'
#' @inheritParams lif_editor
#' @param depth Readings at or shallower than this depth (ft) are zeroed.
#' @param borings Character vector restricting the edit; `NULL` for all.
#' @return The edited frame; one audit row per boring.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' lif <- lif_zero_shallow(lif, depth = 2)
#' @export
lif_zero_shallow <- function(data, depth, borings = NULL, value = 0) {
  .check_edit_target(data, "lif_zero_shallow")
  targets <- if (is.null(borings)) sort(unique(data$boring)) else borings
  for (b in targets) {
    .check_borename(data, b)
    data <- suppressMessages(lif_editor(data, b, top = 0, bottom = depth,
                                        value = value))
  }
  n <- sum(data$boring %in% targets & !is.na(data$depth) & data$depth <= depth)
  message(sprintf("[lif_zero_shallow] zeroed %d row(s) above %g ft across %d boring(s)",
                  n, depth, length(targets)))
  data
}

#' Zero signal below a threshold value
#'
#' Sets `signal` to `value` wherever it is strictly less than `threshold`,
#' across all borings or the named subset. `NA` readings are left alone.
#'
#' @inheritParams lif_zero_shallow
#' @param threshold Readings below this %RE value are zeroed.
#' @return The edited frame with one audit row recording the threshold.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' lif <- lif_zero_below_threshold(lif, threshold = 1)
#' @export
lif_zero_below_threshold <- function(data, threshold, borings = NULL, value = 0) {
  .check_edit_target(data, "lif_zero_below_threshold")
  targets <- if (is.null(borings)) sort(unique(data$boring)) else borings
  for (b in targets) .check_borename(data, b)
  mask <- data$boring %in% targets & !is.na(data$signal) & data$signal < threshold
  n <- sum(mask)
  data$signal[mask] <- value
  data <- .record_edit(data, "lif_zero_below_threshold", NA, NA, NA, value, n,
                       notes = sprintf("threshold=%g; borings=%s", threshold,
                                       if (is.null(borings)) "all"
                                       else paste(borings, collapse = "|")))
  message(sprintf("[lif_zero_below_threshold] zeroed %d row(s) below %g across %d boring(s)",
                  n, threshold, length(targets)))
  data
}

#' Keep one clean window for a boring and zero everything outside it
#'
#' The inverse of [lif_editor()]: every reading of `borename` whose depth
#' falls outside the kept window(s) is set to `value`. One audit row is
#' recorded for the whole call, spanning the outermost kept depths, with the
#' window list in `notes` (`"kept 12-28 ft; zeroed rows outside these
#' windows"`); the report's log plots read that note to shade the zeroed
#' depths.
#'
#' @inheritParams lif_editor
#' @param top,bottom Depth window (ft) to keep. Defaults `-Inf` / `Inf`; at
#'   least one bound or `keep` is required.
#' @param keep Optional list of `c(top, bottom)` windows to keep together.
#' @return The edited frame with one audit row appended.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' lif <- lif_keep(lif, "LIF-04", top = 10, bottom = 25)
#' lif <- lif_keep(lif, "LIF-06", keep = list(c(8, 12), c(20, 28)))
#' @export
lif_keep <- function(data, borename, top = -Inf, bottom = Inf, value = 0,
                     keep = NULL, preview = FALSE) {
  .check_edit_target(data, "lif_keep")
  if (missing(top) && missing(bottom) && is.null(keep))
    stop(sprintf("lif_keep('%s') requires at least one of top=, bottom=, or keep=.",
                 borename), call. = FALSE)
  if (!is.null(keep) && (!missing(top) || !missing(bottom)))
    stop("Use either `keep=` or `top=`/`bottom=`, not both.", call. = FALSE)
  .check_borename(data, borename)
  intervals <- if (!is.null(keep)) {
    .validate_intervals(keep, "keep"); keep
  } else {
    .check_depth_range(top, bottom); list(c(top, bottom))
  }
  in_boring <- data$boring == borename
  keep_mask <- rep(FALSE, nrow(data))
  for (iv in intervals)
    keep_mask <- keep_mask | (!is.na(data$depth) & data$depth >= iv[1L] &
                              data$depth <= iv[2L])
  to_zero <- in_boring & !keep_mask
  n <- sum(to_zero)
  ivstr <- .fmt_intervals(intervals)
  if (preview) {
    message(sprintf("[lif_keep] PREVIEW %s: would zero %d row(s) outside %s",
                    borename, n, ivstr))
    return(data)
  }
  data$signal[to_zero] <- value
  span <- range(unlist(intervals))
  notes <- paste0("kept ", paste(vapply(intervals, function(iv)
    sprintf("%g-%g ft", iv[1L], iv[2L]), character(1)), collapse = "; "),
    "; zeroed rows outside these windows")
  data <- .record_edit(data, "lif_keep", borename, span[1L], span[2L], value,
                       n, notes = notes)
  message(sprintf("[lif_keep] %s: zeroed %d row(s) outside %s", borename, n, ivstr))
  data
}

# Parse the kept windows out of a lif_keep audit note.
.parse_kept_windows <- function(note) {
  if (!is.character(note) || length(note) != 1L || is.na(note) ||
      !startsWith(note, "kept ")) return(NULL)
  body <- sub("^kept ", "", note)
  m <- regmatches(body, gregexpr("(-?[0-9.]+|-?Inf)-(-?[0-9.]+|-?Inf) ft", body))[[1]]
  if (!length(m)) return(NULL)
  out <- lapply(m, function(x) {
    p <- regmatches(x, regexec("^(-?[0-9.]+|-?Inf)-(-?[0-9.]+|-?Inf) ft$", x))[[1]]
    as.numeric(p[2:3])
  })
  out <- Filter(function(w) length(w) == 2L && !anyNA(w) && w[2] >= w[1], out)
  if (length(out)) out else NULL
}

#' Apply a batch of edits from a data frame or CSV
#'
#' Applies each row of an edit plan in order through [lif_editor()],
#' [lif_editor_bulk()], or [lif_keep()], so a site's edits live in one
#' reviewable file instead of a script of editor calls.
#'
#' @section Plan columns:
#' * `boring` (required): boring name, or `"*"` for every boring (delete
#'   rows only; recorded as one bulk edit).
#' * `action` (optional): `"delete"` (default), `"clean"` (alias), or
#'   `"keep"`.
#' * `top`, `bottom` (optional): depth bounds. `NA` means the function's own
#'   default (whole boring for delete; open-ended for keep).
#'
#' @param data A [lif_data] frame.
#' @param edits A data frame or the path to a CSV with the columns above.
#' @param validate Logical. `TRUE` checks every row and prints how many
#'   readings each would affect without modifying the data; invalid rows
#'   stop with a message naming them.
#' @return The edited frame (or, with `validate = TRUE`, the input
#'   unchanged, invisibly).
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' plan <- data.frame(boring = c("*", "LIF-02", "LIF-05"),
#'                    action = c("delete", "delete", "keep"),
#'                    top = c(0, 25, 8), bottom = c(1.5, NA, 30))
#' lif_apply_edits(lif, plan, validate = TRUE)
#' lif <- lif_apply_edits(lif, plan)
#' edit_history(lif)
#' @export
lif_apply_edits <- function(data, edits, validate = FALSE) {
  .check_edit_target(data, "lif_apply_edits")
  if (is.character(edits) && length(edits) == 1L) {
    if (!file.exists(edits)) stop("edits file not found: ", edits, call. = FALSE)
    edits <- utils::read.csv(edits, stringsAsFactors = FALSE)
  }
  if (!is.data.frame(edits))
    stop("`edits` must be a data frame or a path to a CSV file", call. = FALSE)
  if (!"boring" %in% names(edits))
    stop("`edits` must have a 'boring' column", call. = FALSE)
  if (nrow(edits) == 0L) {
    message("[lif_apply_edits] No edits to apply.")
    return(data)
  }
  edits$boring <- trimws(as.character(edits$boring))
  action <- if ("action" %in% names(edits)) tolower(trimws(as.character(edits$action)))
            else rep("delete", nrow(edits))
  action[is.na(action) | !nzchar(action)] <- "delete"
  action[action == "clean"] <- "delete"
  top_v    <- if ("top" %in% names(edits)) suppressWarnings(as.numeric(edits$top))
              else rep(NA_real_, nrow(edits))
  bottom_v <- if ("bottom" %in% names(edits)) suppressWarnings(as.numeric(edits$bottom))
              else rep(NA_real_, nrow(edits))
  valid_b <- unique(data$boring)
  if (any(trimws(as.character(valid_b)) == .BULK_BORING))
    stop("lif_apply_edits: a boring is named '*', which is the all-borings ",
         "sentinel. Rename it before applying a plan.", call. = FALSE)
  dmax <- suppressWarnings(max(data$depth, na.rm = TRUE))

  # Validate every row before touching anything.
  problems <- character(0)
  for (i in seq_len(nrow(edits))) {
    b <- edits$boring[i]; row <- character(0)
    is_bulk <- identical(b, .BULK_BORING)
    if (!is_bulk && !b %in% valid_b) row <- c(row, sprintf("boring '%s' not found", b))
    if (!action[i] %in% c("delete", "keep"))
      row <- c(row, sprintf("unknown action '%s'", action[i]))
    if (is_bulk && action[i] == "keep")
      row <- c(row, "action 'keep' is not supported with '*'; list the borings")
    if (!is.na(top_v[i]) && !is.na(bottom_v[i]) && top_v[i] > bottom_v[i])
      row <- c(row, sprintf("top (%g) > bottom (%g)", top_v[i], bottom_v[i]))
    if (is_bulk && action[i] == "delete") {
      et <- if (is.na(top_v[i])) 0 else top_v[i]
      eb <- if (is.na(bottom_v[i])) 1000 else bottom_v[i]
      if (et <= 0 && eb >= dmax)
        row <- c(row, "a '*' delete row spanning every reading would wipe the dataset; narrow it")
    }
    if (length(row)) problems <- c(problems, sprintf("  row %d: %s", i,
                                                     paste(row, collapse = "; ")))
  }
  if (length(problems))
    stop(sprintf("[lif_apply_edits] %d invalid row(s):\n%s", length(problems),
                 paste(problems, collapse = "\n")), call. = FALSE)

  if (isTRUE(validate)) {
    n_aff <- vapply(seq_len(nrow(edits)), function(i) {
      b <- edits$boring[i]
      bmask <- if (identical(b, .BULK_BORING)) rep(TRUE, nrow(data)) else data$boring == b
      d <- data$depth
      if (action[i] == "delete") {
        t0 <- if (is.na(top_v[i])) 0 else top_v[i]
        b0 <- if (is.na(bottom_v[i])) 1000 else bottom_v[i]
        sum(bmask & !is.na(d) & d >= t0 & d <= b0)
      } else {
        t0 <- if (is.na(top_v[i])) -Inf else top_v[i]
        b0 <- if (is.na(bottom_v[i])) Inf else bottom_v[i]
        sum(bmask & !(!is.na(d) & d >= t0 & d <= b0))
      }
    }, integer(1))
    summ <- data.frame(boring = edits$boring, action = action, top = top_v,
                       bottom = bottom_v, n_rows_affected = n_aff,
                       stringsAsFactors = FALSE)
    message("[lif_apply_edits] Validation summary (no changes applied):")
    print(summ, row.names = FALSE)
    return(invisible(data))
  }

  for (i in seq_len(nrow(edits))) {
    b <- edits$boring[i]
    if (identical(b, .BULK_BORING)) {
      args <- list(data = data)
      if (!is.na(top_v[i]))    args$top    <- top_v[i]
      if (!is.na(bottom_v[i])) args$bottom <- bottom_v[i]
      data <- suppressMessages(suppressWarnings(do.call(lif_editor_bulk, args)))
      next
    }
    fn <- if (action[i] == "delete") lif_editor else lif_keep
    args <- list(data = data, borename = b)
    if (!is.na(top_v[i]))    args$top    <- top_v[i]
    if (!is.na(bottom_v[i])) args$bottom <- bottom_v[i]
    data <- suppressMessages(suppressWarnings(do.call(fn, args)))
  }
  message(sprintf("[lif_apply_edits] Applied %d edit(s).", nrow(edits)))
  data
}

# ---------------------------------------------------------------------------
# Edit-history accessors
# ---------------------------------------------------------------------------

.empty_edits <- function() data.frame(
  timestamp = character(), fn = character(), boring = character(),
  top = numeric(), bottom = numeric(), value = numeric(),
  n_rows_changed = integer(), notes = character(), stringsAsFactors = FALSE)

#' Inspect, save, or clear the edit history
#'
#' Every editor appends one row to the `edits` attribute of the frame it
#' returns: `timestamp`, `fn`, `boring` (`NA` = all borings), `top`,
#' `bottom`, `value`, `n_rows_changed`, `notes`. These accessors read, write
#' out, or remove that audit trail.
#'
#' @param data A data frame, typically one returned by an editor.
#' @param file Output CSV path for `edit_history_save()`.
#' @return `edit_history()` returns the history data frame (empty, with a
#'   message, when there is none). `edit_history_save()` returns `file`
#'   invisibly. `edit_history_clear()` returns `data` without the attribute.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' lif <- lif_editor_bulk(lif, top = 0, bottom = 2, verbose = FALSE)
#' edit_history(lif)
#' lif <- edit_history_clear(lif)
#' is.null(attr(lif, "edits"))
#' @name edit_history
#' @export
edit_history <- function(data) {
  h <- attr(data, "edits")
  if (is.null(h)) {
    message("No edit history found on this data frame.")
    return(invisible(.empty_edits()))
  }
  h
}

#' @rdname edit_history
#' @export
edit_history_save <- function(data, file) {
  h <- attr(data, "edits")
  if (is.null(h)) stop("No edit history found on this data frame. Nothing written.",
                       call. = FALSE)
  utils::write.csv(h, file = file, row.names = FALSE)
  message("Edit history written to: ", file)
  invisible(file)
}

#' @rdname edit_history
#' @export
edit_history_clear <- function(data) {
  attr(data, "edits") <- NULL
  .drop_edited_class(data)
}

#' Carry the edit history across dplyr operations
#'
#' dplyr verbs strip non-standard attributes, which silently drops the
#' edit history. Save it with `lif_get_edits()` before such a step and put
#' it back with `lif_set_edits()` afterwards.
#'
#' @param data A data frame.
#' @param edits The history returned by `lif_get_edits()`, or `NULL` to
#'   clear it.
#' @return `lif_get_edits()`: the history data frame or `NULL`.
#'   `lif_set_edits()`: `data` with the history attached.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' lif <- lif_editor_bulk(lif, top = 0, bottom = 2, verbose = FALSE)
#' saved <- lif_get_edits(lif)
#' sub <- lif[lif$boring %in% c("LIF-01", "LIF-02"), ]
#' sub <- lif_set_edits(sub, saved)
#' nrow(edit_history(sub))
#' @name lif_edits_rescue
#' @export
lif_get_edits <- function(data) attr(data, "edits")

#' @rdname lif_edits_rescue
#' @export
lif_set_edits <- function(data, edits) {
  attr(data, "edits") <- edits
  if (is.null(edits)) .drop_edited_class(data) else new_edited_data(data)
}
