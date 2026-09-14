# Shared internal helpers.

# NULL-coalescing operator (NULL only, matching base R >= 4.4's %||%).
`%||%` <- function(a, b) if (is.null(a)) b else a

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

# Require a single finite (or NA when allowed) numeric scalar.
.check_scalar_number <- function(x, arg, fn_name, allow_na = FALSE) {
  ok <- length(x) == 1L && !is.character(x) && !is.list(x) &&
        ((allow_na && is.na(x)) || (is.numeric(x) && !is.na(x)))
  if (!ok)
    stop(sprintf("%s: `%s` must be a single %snumber.", fn_name, arg,
                 if (allow_na) "number or NA; got a non-" else ""), call. = FALSE)
  invisible(TRUE)
}

# TRUE where old and new would be identical after assignment, so an editor
# can count the readings it actually changed rather than the ones it masked.
.same_value <- function(old, new) {
  (is.na(old) & is.na(new)) | (!is.na(old) & !is.na(new) & old == new)
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

# Format numbers one at a time so a tiny value cannot pad every label with
# its decimals (format() on a vector uses a common number of digits).
.fmt_num <- function(x, digits = 3) {
  vapply(signif(x, digits), function(v)
    format(v, big.mark = ",", scientific = FALSE, trim = TRUE), character(1))
}

# Filename-safe slug of a site name.
.site_slug <- function(site_name) {
  slug <- gsub("[^A-Za-z0-9]+", "_", tolower(site_name))
  slug <- gsub("^_+|_+$", "", slug)
  if (!nzchar(slug)) "site" else slug
}
