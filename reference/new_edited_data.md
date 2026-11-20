# Tag a data frame as carrying edit-history provenance

Prepends the `edited_data` class to a frame that has an `edits`
attribute, so printing it shows a provenance banner. Every editor tags
its output automatically.

## Usage

``` r
new_edited_data(df)

# S3 method for class 'edited_data'
print(x, ...)
```

## Arguments

- df:

  A data frame, typically fresh from an editor.

- x:

  An `edited_data` object.

- ...:

  Passed to the next print method.

## Value

`df` with the `edited_data` class prepended when an `edits` attribute is
present; `df` unchanged otherwise.

## What keeps the history

These rules are verified by test (`test-port-tier2.R`) rather than
asserted, because most of them depend on S3 dispatch finding a `lifr`
method, and that depends on *which* argument carries the class.

Kept:

- `[` – rows, columns, or both.

- The dplyr verbs – [`filter()`](https://rdrr.io/r/stats/filter.html),
  `mutate()`, `select()`, `arrange()`, and the joins – through
  `dplyr_reconstruct()`.

- [`rbind()`](https://rdrr.io/r/base/cbind.html), **when its first
  argument** is an `edited_data` or `lif_data` frame: then every
  argument's history is concatenated in argument order. This is the one
  operation that merges two histories.

Lost:

- [`rbind()`](https://rdrr.io/r/base/cbind.html) when the first argument
  is a plain data frame or tibble. `rbind.data.frame` is dispatched
  instead, and the result silently carries no class and no history at
  all – not even the classed argument's. Put the edited frame first.

- [`dplyr::bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html)
  keeps at most the **first** argument's history and never concatenates
  two. Use [`rbind()`](https://rdrr.io/r/base/cbind.html) to combine
  edited frames.

- [`merge()`](https://rdrr.io/r/base/merge.html), and rebuilding a frame
  from its columns.

- [`tibble::as_tibble()`](https://tibble.tidyverse.org/reference/as_tibble.html)
  and [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html)
  drop the **class**, so the provenance banner stops printing. The
  attribute itself usually survives, and
  [`edit_history()`](https://mjorden.github.io/lifr/reference/edit_history.md)
  will still read it, but nothing maintains it from then on: a declassed
  frame placed first in [`rbind()`](https://rdrr.io/r/base/cbind.html)
  keeps only its own history and silently drops the rest.

Use
[`lif_get_edits()`](https://mjorden.github.io/lifr/reference/lif_edits_rescue.md)
/
[`lif_set_edits()`](https://mjorden.github.io/lifr/reference/lif_edits_rescue.md)
around the operations that lose it.

## See also

[`edit_history()`](https://mjorden.github.io/lifr/reference/edit_history.md)

## Examples

``` r
d  <- data.frame(boring = "B1", depth = 1:3, signal = c(5, 0, 2))
ed <- lif_zero_shallow(d, depth = 1)
#> [lif_zero_shallow] changed 1 reading(s) at or above 1 ft across 1 boring(s)
inherits(ed, "edited_data")
#> [1] TRUE
nrow(edit_history(ed[, c("boring", "depth", "signal")]))
#> [1] 1
```
