# Import a directory of LIF logs and join boring locations

Reads every `*.lif.dat.txt` / `*.lif.dat.csv` file in `data_dir` with
[`lif_read()`](https://mjorden.github.io/lifr/reference/lif_read.md),
binds them into one data frame (one row per depth reading), and joins a
locations table so every row carries its boring's `easting`, `northing`,
and ground-surface elevation `msl`. All source columns are preserved.

## Usage

``` r
lif_import(
  data_dir = ".",
  locations_file = NULL,
  pattern = .LIF_FILE_PATTERN,
  legacy = FALSE,
  verbose = TRUE
)
```

## Arguments

- data_dir:

  Directory containing the log files.

- locations_file:

  Path to the locations file (see
  [`read_locations()`](https://mjorden.github.io/lifr/reference/read_locations.md)).
  `NULL` (default) looks for `locations*.csv` / `locations*.txt` inside
  `data_dir`, preferring `locations.csv`; when none is found the logs
  are imported without coordinates and a message says so. `FALSE` skips
  the join explicitly.

- pattern:

  Regular expression selecting the log files. Default matches
  `.lif.dat.txt` and `.lif.dat.csv`.

- legacy:

  Passed to
  [`lif_read()`](https://mjorden.github.io/lifr/reference/lif_read.md):
  `TRUE` for headerless legacy files.

- verbose:

  Logical. Print per-file progress and the import summary.

## Value

A [lif_data](https://mjorden.github.io/lifr/reference/lif_data.md)
object. Columns are ordered `easting`, `northing`, `depth`, `signal`,
`boring`, `msl`, `ec`, `hp`, `color` (those present), then every other
source column. Borings that have a log file but no row in the locations
file are dropped with a warning naming them; if no boring matches at all
the import stops, because that is almost always a naming-format
mismatch.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
lif
#> <lif_data> 12 boring(s), 1489 sample(s), depth 0.2-37.5 ft, 0 edit(s)
#>   channels: signal, ec, hp, color
#>    easting northing depth signal boring   msl    ec   hp   color
#> 1   1014.5   2017.9  0.25  2.506 LIF-01 149.6  8.87 2.79 #6B8E23
#> 2   1014.5   2017.9  0.50  0.206 LIF-01 149.6  9.31 2.41 #B0B0B0
#> 3   1014.5   2017.9  0.75  2.146 LIF-01 149.6  9.75 2.59 #6B8E23
#> 4   1014.5   2017.9  1.00  0.095 LIF-01 149.6  9.40 2.83 #B0B0B0
#> 5   1014.5   2017.9  1.25  0.208 LIF-01 149.6 10.38 2.97 #B0B0B0
#> 6   1014.5   2017.9  1.50  0.098 LIF-01 149.6  9.38 2.68 #B0B0B0
#> 7   1014.5   2017.9  1.75  0.213 LIF-01 149.6 10.07 2.72 #B0B0B0
#> 8   1014.5   2017.9  2.00  0.148 LIF-01 149.6  9.48 3.08 #B0B0B0
#> 9   1014.5   2017.9  2.25  0.050 LIF-01 149.6 10.04 2.86 #B0B0B0
#> 10  1014.5   2017.9  2.50  0.003 LIF-01 149.6  9.46 3.01 #B0B0B0
#> # ... 1479 more row(s)
unique(lif$boring)
#>  [1] "LIF-01" "LIF-02" "LIF-03" "LIF-04" "LIF-05" "LIF-06" "LIF-07" "LIF-08"
#>  [9] "LIF-09" "LIF-10" "LIF-11" "LIF-12"
```
