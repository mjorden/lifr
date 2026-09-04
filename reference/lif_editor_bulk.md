# Zero LIF signal inside a depth window across all borings

Zero LIF signal inside a depth window across all borings

## Usage

``` r
lif_editor_bulk(
  data,
  top = 0,
  bottom = 1000,
  value = 0,
  preview = FALSE,
  verbose = TRUE
)
```

## Arguments

- data:

  A [lif_data](https://mjorden.github.io/lifr/reference/lif_data.md)
  frame (any data frame with `boring`, `depth`, `signal`).

- top, bottom:

  Depth interval (ft) to zero. Defaults `0` and `1000` cover the whole
  boring, which triggers a warning.

- value:

  Replacement value. Default 0; `NA` is allowed.

- preview:

  Logical. `TRUE` reports how many rows would change without modifying
  the data.

- verbose:

  Logical. Print a per-boring breakdown of rows changed.

## Value

The edited frame with one audit row (boring `NA`, meaning all borings)
appended.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
lif <- lif_editor_bulk(lif, top = 0, bottom = 2)
#> [lif_editor_bulk] zeroed 96 row(s) (0-2 ft) across 12 boring(s)
#>   LIF-01               8 rows
#>   LIF-02               8 rows
#>   LIF-03               8 rows
#>   LIF-04               8 rows
#>   LIF-05               8 rows
#>   LIF-06               8 rows
#>   LIF-07               8 rows
#>   LIF-08               8 rows
#>   LIF-09               8 rows
#>   LIF-10               8 rows
#>   LIF-11               8 rows
#>   LIF-12               8 rows
lif_editor_bulk(lif, top = 0, bottom = 1, preview = TRUE)
#> [lif_editor_bulk] PREVIEW: would have zeroed 48 row(s) (0-1 ft) across 12 boring(s)
#>   LIF-01               4 rows
#>   LIF-02               4 rows
#>   LIF-03               4 rows
#>   LIF-04               4 rows
#>   LIF-05               4 rows
#>   LIF-06               4 rows
#>   LIF-07               4 rows
#>   LIF-08               4 rows
#>   LIF-09               4 rows
#>   LIF-10               4 rows
#>   LIF-11               4 rows
#>   LIF-12               4 rows
#> <edited_data> 1 edit(s) recorded -- provenance attached (edit_history() to inspect).
#> <lif_data> 12 boring(s), 1489 sample(s), depth 0.2-37.5 ft, 1 edit(s)
#>   channels: signal, ec, hp, color
#>    easting northing depth signal boring   msl    ec   hp   color
#> 1   1014.5   2017.9  0.25  0.000 LIF-01 149.6  8.87 2.79 #6B8E23
#> 2   1014.5   2017.9  0.50  0.000 LIF-01 149.6  9.31 2.41 #B0B0B0
#> 3   1014.5   2017.9  0.75  0.000 LIF-01 149.6  9.75 2.59 #6B8E23
#> 4   1014.5   2017.9  1.00  0.000 LIF-01 149.6  9.40 2.83 #B0B0B0
#> 5   1014.5   2017.9  1.25  0.000 LIF-01 149.6 10.38 2.97 #B0B0B0
#> 6   1014.5   2017.9  1.50  0.000 LIF-01 149.6  9.38 2.68 #B0B0B0
#> 7   1014.5   2017.9  1.75  0.000 LIF-01 149.6 10.07 2.72 #B0B0B0
#> 8   1014.5   2017.9  2.00  0.000 LIF-01 149.6  9.48 3.08 #B0B0B0
#> 9   1014.5   2017.9  2.25  0.050 LIF-01 149.6 10.04 2.86 #B0B0B0
#> 10  1014.5   2017.9  2.50  0.003 LIF-01 149.6  9.46 3.01 #B0B0B0
#> # ... 1479 more row(s)
```
