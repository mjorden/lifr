# Construct a validated LIF data frame

Tags a data frame with the `lif_data` class after checking that it
carries `boring`, `depth`, and `signal`. The object still inherits from
`data.frame`, so every base-R and tidyverse operation keeps working; the
class only adds [`print()`](https://rdrr.io/r/base/print.html) and
[`summary()`](https://rdrr.io/r/base/summary.html) methods. Importers
return classed objects automatically.

## Usage

``` r
new_lif_data(df)

# S3 method for class 'lif_data'
print(x, ..., n = 10)

# S3 method for class 'lif_data'
summary(object, ...)
```

## Arguments

- df:

  A data frame with at least `boring`, `depth`, `signal`.

- x:

  A `lif_data` object.

- ...:

  Ignored.

- n:

  Number of rows to preview. Default 10.

- object:

  A `lif_data` object.

## Value

`df` with class `lif_data` prepended. Construction is idempotent.

[`print()`](https://rdrr.io/r/base/print.html) returns `x` invisibly.

[`summary()`](https://rdrr.io/r/base/summary.html) returns the list from
[`summarize_lif()`](https://mjorden.github.io/lifr/reference/summarize_lif.md).

## Examples

``` r
df <- data.frame(boring = "B1", depth = 1:3, signal = c(0, 5, 2))
lif <- new_lif_data(df)
class(lif)
#> [1] "lif_data"   "data.frame"
```
