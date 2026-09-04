# Raw LIF log ingestion.
#
# A LIF survey delivers one log file per boring. The modern export is a
# tab-delimited text file named <boring>.lif.dat.txt with a header row such as
#
#   Depth  Signal  EC.Value  HP.PresDown  color
#
# though the exact channel set varies by probe and firmware. Older firmware
# wrote the same layout with no header row (11 columns for LIF, 16 for the
# combined HP-LIF probe). Everything the file records is kept: the known
# channels are canonicalised to snake_case names and any other column is
# carried through under a cleaned name.

# File-name suffixes stripped to derive the boring name.
.LIF_FILE_PATTERN <- "\\.lif\\.dat\\.(txt|csv)$"

.LEGACY_11 <- c("depth", "signal", "ch1", "ch2", "ch3", "ch4",
                "ec_depth", "ec_value", "hmr_depth", "hmr_val", "color")
.LEGACY_16 <- c(.LEGACY_11, "hp_depth", "hp_time", "hp_presup",
                "hp_presdown", "hp_flowup")

# Canonical names for the channels lifr understands. Instrument headers vary
# ("EC.Value", "ec value", "EC_Value"); normalising them in one place means
# every importer treats the same file identically.
.canonical_lif_names <- function(nm) {
  low <- tolower(gsub("[^A-Za-z0-9]+", "_", nm))
  low <- gsub("^_+|_+$", "", low)
  out <- low
  out[low %in% c("depth", "depth_ft")]                        <- "depth"
  out[low %in% c("signal", "signal_re", "lif", "lif_signal")] <- "signal"
  out[low %in% c("ec_value", "ec", "ec_ms_m")]                <- "ec"
  out[low %in% c("hp_presdown", "hp", "hp_pres_down")]        <- "hp"
  out[low %in% c("color", "colour", "hex")]                   <- "color"
  # Only the FIRST match of each canonical name is taken; a second column
  # that would map to the same name keeps its snake_case source name.
  for (cn in c("depth", "signal", "ec", "hp", "color")) {
    i <- which(out == cn)
    if (length(i) > 1L) out[i[-1L]] <- low[i[-1L]]
  }
  out[!nzchar(out)] <- "col"
  make.unique(out, sep = "_")
}

# Sniff the delimiter from the first line: tab wins, then comma, then
# whitespace.
.sniff_sep <- function(file) {
  first <- readLines(file, n = 1L, warn = FALSE)
  if (length(first) == 0L) return("\t")
  if (grepl("\t", first)) "\t" else if (grepl(",", first)) "," else ""
}

#' Read one raw LIF log file
#'
#' Reads a single `.lif.dat.txt` (or `.csv`) log into a data frame, keeping
#' every column the instrument recorded. The known channels are renamed to
#' `depth`, `signal`, `ec`, `hp`, and `color`; any other column is kept under
#' a cleaned snake_case version of its header (for example `EC.Depth`
#' becomes `ec_depth`, `Detector 1 Max (uV)` becomes `detector_1_max_uv`).
#' The boring name is the file name with its `.lif.dat.*` suffix removed.
#'
#' @param file Path to one log file.
#' @param legacy Logical. `TRUE` for older firmware exports that have no
#'   header row: an 11-column file is read as a LIF log and a 16-column file
#'   as a combined HP-LIF log. Default `FALSE` (header row present).
#' @return A data frame with `boring`, `depth`, `signal`, then the optional
#'   canonical channels present in the file, then every remaining source
#'   column.
#' @examples
#' f <- system.file("extdata", "demo", "LIF-01.lif.dat.txt", package = "lifr")
#' head(lif_read(f))
#' @seealso [lif_import()] for a whole directory with a locations join.
#' @export
lif_read <- function(file, legacy = FALSE) {
  if (!file.exists(file))
    stop("lif_read: file not found: ", file, call. = FALSE)
  sep <- .sniff_sep(file)
  raw <- utils::read.table(file, header = !isTRUE(legacy), sep = sep,
                           check.names = FALSE, stringsAsFactors = FALSE,
                           comment.char = "", quote = "\"",
                           strip.white = TRUE)
  if (isTRUE(legacy)) {
    names(raw) <- switch(as.character(ncol(raw)),
      "11" = .LEGACY_11,
      "16" = .LEGACY_16,
      stop("lif_read: legacy file '", basename(file), "' has ", ncol(raw),
           " columns; expected 11 (LIF) or 16 (HP-LIF).", call. = FALSE))
    # The legacy layouts record EC and HP under their own names.
    names(raw)[names(raw) == "ec_value"]    <- "ec"
    names(raw)[names(raw) == "hp_presdown"] <- "hp"
  } else {
    names(raw) <- .canonical_lif_names(names(raw))
  }
  .check_required_cols(raw, c("depth", "signal"),
                       source = sprintf("Log file '%s'", basename(file)))
  for (cc in c("depth", "signal", "ec", "hp")) {
    if (!cc %in% names(raw)) next
    v <- suppressWarnings(as.numeric(raw[[cc]]))
    bad <- is.na(v) & !is.na(raw[[cc]]) & nzchar(trimws(as.character(raw[[cc]])))
    if (any(bad))
      stop(sprintf("lif_read: column '%s' in '%s' has %d non-numeric value(s), e.g. \"%s\".",
                   cc, basename(file), sum(bad),
                   as.character(raw[[cc]][bad][1])), call. = FALSE)
    raw[[cc]] <- v
  }
  if ("color" %in% names(raw)) raw$color <- .norm_hex(raw$color)
  raw$boring <- sub(.LIF_FILE_PATTERN, "", basename(file), ignore.case = TRUE)
  raw$boring <- sub("\\.(txt|csv)$", "", raw$boring, ignore.case = TRUE)
  .order_lif_cols(raw)
}

# Canonical column order: lead columns that exist, then everything else in
# its source order.
.order_lif_cols <- function(df) {
  lead <- intersect(.LIF_LEAD_COLS, names(df))
  df[, c(lead, setdiff(names(df), lead)), drop = FALSE]
}

# rbind with NA-fill over the union of columns, warning when the files do
# not agree on their column set (firmware drift, hand-edited exports).
.bind_fill <- function(rows, files) {
  all_cols <- unique(unlist(lapply(rows, names)))
  differing <- vapply(rows, function(r) !setequal(names(r), all_cols), logical(1))
  if (any(differing)) {
    ref <- names(rows[[which(!differing)[1] %||% 1L]])
    detail <- vapply(which(differing), function(i) {
      extra <- setdiff(names(rows[[i]]), ref)
      miss  <- setdiff(ref, names(rows[[i]]))
      sprintf("  %s: %s%s", basename(files[i]),
              if (length(extra)) paste0("extra ", paste(extra, collapse = ", ")) else "",
              if (length(miss)) paste0(if (length(extra)) "; " else "",
                                       "missing ", paste(miss, collapse = ", ")) else "")
    }, character(1))
    warning("lif_import: log files do not share one column set; missing ",
            "columns are NA-filled.\n", paste(detail, collapse = "\n"),
            call. = FALSE)
  }
  rows <- lapply(rows, function(r) {
    for (cc in setdiff(all_cols, names(r))) r[[cc]] <- NA
    r[, all_cols, drop = FALSE]
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Read a boring locations table
#'
#' Reads a CSV or tab-delimited file with one row per boring and the columns
#' `boring`, `easting`, `northing`, and `msl` (ground-surface elevation).
#' Column names are matched case-insensitively and the delimiter is sniffed
#' from the first line. A boring listed twice is an error, because a repeated
#' row would multiply every reading of that boring through the join.
#'
#' @param file Path to the locations file.
#' @return A data frame with `boring`, `easting`, `northing`, `msl`, plus any
#'   other columns the file carries.
#' @examples
#' f <- system.file("extdata", "demo", "locations.csv", package = "lifr")
#' read_locations(f)
#' @export
read_locations <- function(file) {
  if (!file.exists(file))
    stop("read_locations: file not found: ", file, call. = FALSE)
  sep <- .sniff_sep(file)
  loc <- utils::read.table(file, header = TRUE, sep = sep, check.names = FALSE,
                           stringsAsFactors = FALSE, strip.white = TRUE,
                           comment.char = "", quote = "\"")
  names(loc) <- tolower(trimws(names(loc)))
  names(loc)[names(loc) %in% c("x", "east")]      <- "easting"
  names(loc)[names(loc) %in% c("y", "north")]     <- "northing"
  names(loc)[names(loc) %in% c("elevation", "elev", "z", "ground")] <- "msl"
  names(loc)[names(loc) %in% c("name", "hole", "id")] <- "boring"
  .check_required_cols(loc, c("boring", "easting", "northing", "msl"),
                       source = sprintf("Locations file '%s'", basename(file)))
  loc$boring <- trimws(as.character(loc$boring))
  for (cc in c("easting", "northing", "msl")) {
    v <- suppressWarnings(as.numeric(loc[[cc]]))
    if (any(is.na(v) & !is.na(loc[[cc]]) & nzchar(loc[[cc]])))
      stop(sprintf("read_locations: column '%s' in '%s' is not numeric.",
                   cc, basename(file)), call. = FALSE)
    loc[[cc]] <- v
  }
  loc <- loc[!is.na(loc$boring) & nzchar(loc$boring), , drop = FALSE]
  dup <- unique(loc$boring[duplicated(loc$boring)])
  if (length(dup))
    stop(sprintf(paste0(
      "read_locations: '%s' lists %d boring(s) more than once: %s. ",
      "Each boring must appear exactly once."),
      basename(file), length(dup), paste(dup, collapse = ", ")), call. = FALSE)
  rownames(loc) <- NULL
  loc
}

# Choose a locations file in `data_dir`: locations.csv > locations.txt >
# first alphabetical match, warning on the fallback.
.find_locations_file <- function(data_dir) {
  cand <- list.files(data_dir, pattern = "^locations.*\\.(csv|txt)$",
                     ignore.case = TRUE, full.names = TRUE)
  if (length(cand) == 0L) return(NULL)
  if (length(cand) == 1L) return(cand)
  pref <- match(c("locations.csv", "locations.txt"), tolower(basename(cand)))
  pref <- pref[!is.na(pref)]
  if (length(pref)) return(cand[pref[1]])
  warning("Multiple locations files found; using '", basename(cand[1]),
          "'. Supply locations_file= to override.", call. = FALSE)
  cand[1]
}

#' Import a directory of LIF logs and join boring locations
#'
#' Reads every `*.lif.dat.txt` / `*.lif.dat.csv` file in `data_dir` with
#' [lif_read()], binds them into one data frame (one row per depth reading),
#' and joins a locations table so every row carries its boring's `easting`,
#' `northing`, and ground-surface elevation `msl`. All source columns are
#' preserved.
#'
#' @param data_dir Directory containing the log files.
#' @param locations_file Path to the locations file (see [read_locations()]).
#'   `NULL` (default) looks for `locations*.csv` / `locations*.txt` inside
#'   `data_dir`, preferring `locations.csv`; when none is found the logs are
#'   imported without coordinates and a message says so. `FALSE` skips the
#'   join explicitly.
#' @param pattern Regular expression selecting the log files. Default matches
#'   `.lif.dat.txt` and `.lif.dat.csv`.
#' @param legacy Passed to [lif_read()]: `TRUE` for headerless legacy files.
#' @param verbose Logical. Print per-file progress and the import summary.
#' @return A [lif_data] object. Columns are ordered `easting`, `northing`,
#'   `depth`, `signal`, `boring`, `msl`, `ec`, `hp`, `color` (those present),
#'   then every other source column. Borings that have a log file but no row
#'   in the locations file are dropped with a warning naming them; if no
#'   boring matches at all the import stops, because that is almost always a
#'   naming-format mismatch.
#' @examples
#' demo <- system.file("extdata", "demo", package = "lifr")
#' lif <- lif_import(demo, verbose = FALSE)
#' lif
#' unique(lif$boring)
#' @export
lif_import <- function(data_dir = ".", locations_file = NULL,
                       pattern = .LIF_FILE_PATTERN, legacy = FALSE,
                       verbose = TRUE) {
  say <- function(...) if (isTRUE(verbose)) message(...)
  if (!dir.exists(data_dir))
    stop("lif_import: data_dir does not exist: '", data_dir, "'", call. = FALSE)
  files <- list.files(data_dir, pattern = pattern, full.names = TRUE,
                      ignore.case = TRUE)
  if (length(files) == 0L)
    stop("lif_import: no files matching '", pattern, "' in '", data_dir, "'.",
         call. = FALSE)

  say("Importing ", length(files), " log file(s) from ", data_dir)
  rows <- lapply(files, function(f) {
    say("  reading ", basename(f))
    lif_read(f, legacy = legacy)
  })
  data <- .bind_fill(rows, files)
  n_in <- nrow(data)

  # Locations join ------------------------------------------------------------
  join <- !isFALSE(locations_file)
  if (join && is.null(locations_file)) {
    locations_file <- .find_locations_file(data_dir)
    if (is.null(locations_file)) {
      say("No locations file found in ", data_dir,
          "; importing without coordinates.")
      join <- FALSE
    } else say("Locations file: ", basename(locations_file))
  }
  if (join) {
    loc <- read_locations(locations_file)
    data_b <- unique(data$boring)
    missing_locs <- setdiff(data_b, loc$boring)
    unused_locs  <- setdiff(loc$boring, data_b)
    if (length(missing_locs) == length(data_b)) {
      ex <- function(x) paste(utils::head(sort(x), 5), collapse = ", ")
      stop(sprintf(paste0(
        "lif_import: no boring in the logs matched the locations file, so ",
        "every row would be dropped.\n  log files (%d): %s\n  locations (%d): %s\n",
        "  Check that the boring-name format matches on both sides."),
        length(data_b), ex(data_b), nrow(loc), ex(loc$boring)), call. = FALSE)
    }
    if (length(missing_locs))
      warning("lif_import: borings with a log but no locations row (dropped): ",
              paste(sort(missing_locs), collapse = ", "), call. = FALSE)
    if (length(unused_locs))
      say("Locations with no log file (ignored): ",
          paste(sort(unused_locs), collapse = ", "))
    idx <- match(data$boring, loc$boring)
    for (cc in setdiff(names(loc), "boring")) {
      if (cc %in% names(data)) next   # never clobber an instrument column
      data[[cc]] <- loc[[cc]][idx]
    }
    data <- data[!is.na(idx), , drop = FALSE]
    rownames(data) <- NULL
  }

  data <- .order_lif_cols(data)
  n_out <- nrow(data)
  say(sprintf("Imported %d row(s) across %d boring(s)%s.",
              n_out, length(unique(data$boring)),
              if (n_in != n_out) sprintf(" (%d dropped)", n_in - n_out) else ""))
  new_lif_data(data)
}
