# Tag a data frame as carrying edit-history provenance

Prepends the `edited_data` class to a frame that has an `edits`
attribute, so printing it shows a provenance banner. Every editor tags
its output automatically. Like the attribute itself, the class is
stripped by dplyr verbs and
[`tibble::as_tibble()`](https://tibble.tidyverse.org/reference/as_tibble.html);
use
[`lif_get_edits()`](https://mjorden.github.io/lifr/reference/lif_edits_rescue.md)
/
[`lif_set_edits()`](https://mjorden.github.io/lifr/reference/lif_edits_rescue.md)
to carry the history across such a step.

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

## See also

[`edit_history()`](https://mjorden.github.io/lifr/reference/edit_history.md)

## Examples

``` r
d  <- data.frame(boring = "B1", depth = 1:3, signal = c(5, 0, 2))
ed <- lif_zero_shallow(d, depth = 1)
#> [lif_zero_shallow] zeroed 1 row(s) above 1 ft across 1 boring(s)
inherits(ed, "edited_data")
#> [1] TRUE
```
