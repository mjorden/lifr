# S3 classes: lif_data (an imported LIF frame) and edited_data (a frame that
# carries an edit-history attribute), plus the methods that keep the edit
# history alive through subsetting, binding, and dplyr verbs.

# Legacy TitleCase / UPPERCASE column names and their snake_case targets.
.LIFR_RENAME_MAP <- c(
  Depth  = "depth",
  Signal = "signal",
  EC     = "ec",
  HP     = "hp",
  Color  = "color",
  Boring = "boring",
  Easting  = "easting",
  Northing = "northing",
  MSL      = "msl"
)

.LIF_SCHEMA <- c("boring", "depth", "signal")

# Canonical column order for the leading part of every LIF frame; any other
# source column follows in its original order.
.LIF_LEAD_COLS <- c("easting", "northing", "depth", "signal", "boring", "msl",
                    "ec", "hp", "color")

#' Rename legacy TitleCase columns to the snake_case convention
#'
#' Maps `Depth`, `Signal`, `EC`, `HP`, `Color`, `Boring`, `Easting`,
#' `Northing`, and `MSL` to their lowercase equivalents. Only exact matches
#' are renamed; a rename that would collide with an existing lowercase column
#' is skipped with a warning.
#'
#' @param df A data frame.
#' @return `df` with any legacy columns renamed.
#' @examples
#' df <- data.frame(boring = "B1", Depth = 1:3, Signal = c(0, 5, 2))
#' names(compat_rename_legacy(df))
#' @export
compat_rename_legacy <- function(df) {
  if (!is.data.frame(df))
    stop("compat_rename_legacy: input must be a data frame.", call. = FALSE)
  nm  <- names(df)
  hit <- nm %in% names(.LIFR_RENAME_MAP)
  new_target <- unname(.LIFR_RENAME_MAP[nm[hit]])
  collides   <- new_target %in% nm
  if (any(collides))
    warning("compat_rename_legacy: skipping rename(s) that would collide ",
            "with existing columns: ",
            paste0(nm[hit][collides], " -> ", new_target[collides],
                   collapse = ", "), call. = FALSE)
  do_hit <- hit
  do_hit[hit][collides] <- FALSE
  names(df)[do_hit] <- unname(.LIFR_RENAME_MAP[nm[do_hit]])
  df
}

#' Construct a validated LIF data frame
#'
#' Tags a data frame with the `lif_data` class after checking that it carries
#' `boring`, `depth`, and `signal`. A factor `boring` is converted to
#' character, so boring names never reach an indexing path as integer codes.
#' The object still inherits from `data.frame`, so every base-R and tidyverse
#' operation keeps working; the class only adds `print()` and `summary()`
#' methods. Importers return classed objects automatically.
#'
#' @param df A data frame with at least `boring`, `depth`, `signal`.
#' @return `df` with class `lif_data` prepended. Construction is idempotent.
#' @examples
#' df <- data.frame(boring = "B1", depth = 1:3, signal = c(0, 5, 2))
#' lif <- new_lif_data(df)
#' class(lif)
#' @name lif_data
#' @export
new_lif_data <- function(df) {
  if (!is.data.frame(df))
    stop("new_lif_data: input must be a data frame.", call. = FALSE)
  df <- compat_rename_legacy(df)
  .check_required_cols(df, .LIF_SCHEMA, source = "lif_data")
  if (is.factor(df$boring)) df$boring <- as.character(df$boring)
  if (!inherits(df, "lif_data")) class(df) <- c("lif_data", class(df))
  df
}

#' @param x A `lif_data` object.
#' @param ... Ignored.
#' @param n Number of rows to preview. Default 10.
#' @return `print()` returns `x` invisibly.
#' @rdname lif_data
#' @export
print.lif_data <- function(x, ..., n = 10) {
  n_borings <- length(unique(x$boring))
  drange <- if (nrow(x) > 0 && "depth" %in% names(x))
    suppressWarnings(range(x$depth, na.rm = TRUE)) else c(NA_real_, NA_real_)
  edits   <- attr(x, "edits")
  n_edits <- if (is.null(edits)) 0L else nrow(edits)
  present <- intersect(c("signal", "ec", "hp", "color"), names(x))
  present <- present[vapply(present, function(cc) any(!is.na(x[[cc]])),
                            logical(1))]
  extra <- setdiff(names(x), .LIF_LEAD_COLS)
  cat(sprintf("<lif_data> %d boring(s), %d sample(s), depth %.1f-%.1f ft, %d edit(s)\n",
              n_borings, nrow(x), drange[1], drange[2], n_edits))
  if (length(present))
    cat(sprintf("  channels: %s\n", paste(present, collapse = ", ")))
  if (length(extra))
    cat(sprintf("  extra columns: %s\n", paste(extra, collapse = ", ")))
  print(utils::head(as.data.frame(x), n))
  if (nrow(x) > n) cat(sprintf("# ... %d more row(s)\n", nrow(x) - n))
  invisible(x)
}

#' @param object A `lif_data` object.
#' @return `summary()` returns the list from [summarize_lif()].
#' @rdname lif_data
#' @export
summary.lif_data <- function(object, ...) summarize_lif(object)

# ---------------------------------------------------------------------------
# edited_data: provenance that survives ordinary data-frame operations
# ---------------------------------------------------------------------------

#' Tag a data frame as carrying edit-history provenance
#'
#' Prepends the `edited_data` class to a frame that has an `edits`
#' attribute, so printing it shows a provenance banner. Every editor tags its
#' output automatically.
#'
#' @section What keeps the history:
#' The `edits` attribute is carried through `[` (row and column subsetting),
#' `rbind()` (histories are concatenated in argument order), and the dplyr
#' verbs (`filter()`, `mutate()`, `select()`, `arrange()`, joins) via
#' `dplyr_reconstruct()`. It is still lost by `merge()`,
#' `tibble::as_tibble()`, and by rebuilding the frame from its columns; use
#' [lif_get_edits()] / [lif_set_edits()] around those.
#'
#' @param df A data frame, typically fresh from an editor.
#' @return `df` with the `edited_data` class prepended when an `edits`
#'   attribute is present; `df` unchanged otherwise.
#' @examples
#' d  <- data.frame(boring = "B1", depth = 1:3, signal = c(5, 0, 2))
#' ed <- lif_zero_shallow(d, depth = 1)
#' inherits(ed, "edited_data")
#' nrow(edit_history(ed[, c("boring", "depth", "signal")]))
#' @seealso [edit_history()]
#' @export
new_edited_data <- function(df) {
  if (is.null(attr(df, "edits"))) return(df)
  if (!inherits(df, "edited_data")) class(df) <- c("edited_data", class(df))
  df
}

.drop_edited_class <- function(df) {
  if (inherits(df, "edited_data"))
    class(df) <- setdiff(class(df), "edited_data")
  df
}

#' @param x An `edited_data` object.
#' @param ... Passed to the next print method.
#' @rdname new_edited_data
#' @export
print.edited_data <- function(x, ...) {
  e <- attr(x, "edits")
  if (is.null(e)) {
    cat("<edited_data> WARNING: the edit history is no longer attached to this frame.\n")
    cat("  Restore it with lif_set_edits(); see ?new_edited_data for which operations keep it.\n")
  } else {
    cat(sprintf("<edited_data> %d edit(s) recorded -- provenance attached (edit_history() to inspect).\n",
                nrow(e)))
  }
  NextMethod()
}

# `[` re-attaches the history whenever the result is still a data frame
# (column subsetting otherwise drops it while keeping the class, #6).
#' @export
`[.edited_data` <- function(x, ...) {
  ed  <- attr(x, "edits")
  out <- NextMethod()
  if (is.data.frame(out) && !is.null(ed)) attr(out, "edits") <- ed
  out
}

# rbind concatenates every argument's history; the default method kept only
# the first frame's, silently dropping the rest (#6). Dispatch reaches this
# method whenever the first argument carrying a method is lif_data or
# edited_data.
.rbind_with_edits <- function(..., deparse.level = 1) {
  parts <- list(...)
  hist  <- lapply(parts, attr, "edits")
  hist  <- hist[!vapply(hist, is.null, logical(1))]
  is_lif <- any(vapply(parts, inherits, logical(1), "lif_data"))
  strip <- lapply(parts, function(p) {
    attr(p, "edits") <- NULL
    class(p) <- setdiff(class(p), c("edited_data", "lif_data"))
    p
  })
  out <- do.call(rbind, c(strip, list(deparse.level = deparse.level)))
  if (is_lif && is.data.frame(out) && all(.LIF_SCHEMA %in% names(out)))
    out <- new_lif_data(out)
  if (length(hist)) out <- lif_set_edits(out, do.call(rbind, hist))
  out
}

#' @export
rbind.edited_data <- .rbind_with_edits

#' @export
rbind.lif_data <- .rbind_with_edits

# dplyr rebuilds a data frame through dplyr_reconstruct() after every verb;
# re-attaching the history here is what keeps mutate()/select()/joins from
# dropping it (#6). Registered lazily so dplyr stays in Suggests.
#' @exportS3Method dplyr::dplyr_reconstruct
dplyr_reconstruct.edited_data <- function(data, template) {
  out <- NextMethod()
  ed  <- attr(template, "edits")
  if (is.data.frame(out) && !is.null(ed)) attr(out, "edits") <- ed
  out
}
