# The lifr ggplot2 theme

A quiet, data-first theme shared by every lifr plot: white panel, no
tick marks, light warm-grey gridlines, and a four-tier type hierarchy
(title, subtitle, axis, caption). Add it to your own ggplots to match
the package's figures.

## Usage

``` r
theme_lifr(base_size = 10)
```

## Arguments

- base_size:

  Base font size. Default 10.

## Value

A ggplot2 theme object.

## Examples

``` r
library(ggplot2)
ggplot(mtcars, aes(wt, mpg)) + geom_point() + theme_lifr()
```
