# Package-wide constants. This file sorts first so every other file can use
# them at load time.

# Palette shared by the plots and charts.
.LIFR_FILL <- "#6E7F4E"   # muted olive: single data fill
.LIFR_GREY <- "#C9C9C9"   # sub-threshold / no-signature
.LIFR_INK  <- "#222222"
.LIFR_BLUE <- "#2166ac"   # neutral detect marker
.LIFR_AREA <- "chocolate4"

# The %RE disclosure printed on charts and in the report. Deliberately does
# not map %RE onto any regulatory criterion.
.RE_PROXY_NOTE <- paste0(
  "LIF response (%RE) is relative fluorescence, a screening proxy for the ",
  "presence of fluorescent product. It is not a concentration and is not ",
  "comparable to regulatory criteria.")

# Wrap a note for use as a figure caption.
.wrap_note <- function(x, width = 95) paste(strwrap(x, width = width), collapse = "\n")
