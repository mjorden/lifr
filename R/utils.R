# Shared internal helpers.

# NULL-coalescing operator (NULL only, matching base R >= 4.4's %||%).
`%||%` <- function(a, b) if (is.null(a)) b else a

# Session-scoped once-only warning registry: a key present means the
# warning already fired this session.
.lifr_warned <- new.env(parent = emptyenv())

# Stop unless every column in `required` is present in `df`. The message
# names the missing column(s) and lists what was found so a renamed header
# is distinguishable from a truly absent one.
.check_required_cols <- function(df, required, source = "data") {
  missing <- setdiff(required, names(df))
  if (length(missing) > 0)
    stop(sprintf(
      "%s is missing required column(s): %s\nColumns found: %s",
      source,
      paste(missing, collapse = ", "),
      paste(names(df), collapse = ", ")
    ), call. = FALSE)
  invisible(df)
}

# Stop with the list of valid borings when `borename` is not in the data.
.check_borename <- function(data, borename) {
  valid <- sort(unique(as.character(data$boring)))
  if (length(borename) != 1L || !borename %in% valid)
    stop(sprintf("Boring '%s' not found. Valid borings: %s",
                 paste(borename, collapse = ", "),
                 paste(valid, collapse = ", ")), call. = FALSE)
  invisible(TRUE)
}

# Guard the first argument of editor / plot functions against the common
# "forgot to pipe the data in" mistake.
.check_data_arg <- function(data, fn_name) {
  if (is.character(data))
    stop(sprintf(paste0(
      "%s() expected a data frame as the first argument but got a character ",
      "vector (\"%s\"). Did you forget to pass the data frame in?"),
      fn_name, data[1]), call. = FALSE)
  if (!is.data.frame(data))
    stop(sprintf("%s() expected a data frame as the first argument but got %s",
                 fn_name, class(data)[1L]), call. = FALSE)
  invisible(TRUE)
}

# Auto-scaled axis cap: 5% headroom over the maximum, or `fallback` when
# there is no positive finite value to scale against.
.axis_cap <- function(x, fallback) {
  m <- suppressWarnings(max(x, na.rm = TRUE))
  if (is.finite(m) && m > 0) m * 1.05 else fallback
}

# Normalise an instrument colour cell ("FF8851", "#ff8851", " #FF8851 ") to a
# ggplot-safe "#RRGGBB" string, or NA when it is not a 6-digit hex.
.norm_hex <- function(x) {
  x <- toupper(trimws(as.character(x)))
  x <- sub("^#", "", x)
  ifelse(!is.na(x) & grepl("^[0-9A-F]{6}$", x), paste0("#", x), NA_character_)
}

# Filename-safe slug of a site name.
.site_slug <- function(site_name) {
  slug <- gsub("[^A-Za-z0-9]+", "_", tolower(site_name))
  slug <- gsub("^_+|_+$", "", slug)
  if (!nzchar(slug)) "site" else slug
}

# Snake-case a raw instrument header: "EC.Value" -> "ec_value",
# "HP PresDown" -> "hp_presdown", "Detector 1 Max (uV)" -> "detector_1_max_uv".
.snake_name <- function(x) {
  x <- gsub("[^A-Za-z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  x <- tolower(x)
  x[!nzchar(x)] <- "col"
  make.unique(x, sep = "_")
}
