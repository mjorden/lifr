#' The lifr ggplot2 theme
#'
#' A quiet, data-first theme shared by every lifr plot: white panel, no tick
#' marks, light warm-grey gridlines, and a four-tier type hierarchy (title,
#' subtitle, axis, caption). Add it to your own ggplots to match the
#' package's figures.
#'
#' @param base_size Base font size. Default 10.
#' @return A ggplot2 theme object.
#' @examples
#' library(ggplot2)
#' ggplot(mtcars, aes(wt, mpg)) + geom_point() + theme_lifr()
#' @export
theme_lifr <- function(base_size = 10) {
  ggplot2::theme_bw(base_family = "sans", base_size = base_size) +
    ggplot2::theme(
      panel.grid.major = ggplot2::element_line(colour = "#e0dbd2", linewidth = 0.35),
      panel.grid.minor = ggplot2::element_blank(),
      panel.border     = ggplot2::element_blank(),
      axis.line        = ggplot2::element_line(colour = "#a89070", linewidth = 0.5),
      plot.background  = ggplot2::element_rect(fill = "white", colour = NA),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      plot.title = ggplot2::element_text(face = "bold", size = 13, hjust = 0,
                                         colour = "#1a1a1a",
                                         margin = ggplot2::margin(b = 4)),
      plot.subtitle = ggplot2::element_text(size = 10, hjust = 0, colour = "#555555",
                                            margin = ggplot2::margin(b = 8)),
      plot.caption = ggplot2::element_text(size = 8, hjust = 1, colour = "#555555",
                                           margin = ggplot2::margin(t = 6)),
      plot.title.position   = "plot",
      plot.caption.position = "plot",
      axis.title  = ggplot2::element_text(size = 9, colour = "#333333"),
      axis.text   = ggplot2::element_text(size = 9, colour = "#333333"),
      axis.ticks  = ggplot2::element_blank(),
      legend.title = ggplot2::element_text(size = 9, colour = "#333333", face = "bold"),
      legend.text  = ggplot2::element_text(size = 9, colour = "#666666"),
      legend.background = ggplot2::element_rect(fill = "white", colour = NA),
      legend.key   = ggplot2::element_rect(fill = "white", colour = NA),
      plot.margin  = ggplot2::margin(12, 16, 10, 12)
    )
}
