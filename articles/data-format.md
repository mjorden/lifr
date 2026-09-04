# Raw files and what import does with them

``` r

library(lifr)
```

## The survey folder

A LIF survey folder looks like this:

    MySite/LIF/
    ├── LIF-01.lif.dat.txt
    ├── LIF-02.lif.dat.txt
    ├── ...
    └── locations.csv

One log per boring, named for the boring, plus one locations table.

### Log files

A modern log is tab-delimited text with a header row. The first lines of
a demo file:

``` r

demo <- system.file("extdata", "demo", package = "lifr")
cat(readLines(file.path(demo, "LIF-05.lif.dat.txt"), n = 4), sep = "\n")
#> Depth    Signal  EC.Value    HP.PresDown color
#> 0.25 1.445   8.73    2.6 #6B8E23
#> 0.5  1.453   9.88    2.53    #6B8E23
#> 0.75 3.361   10.08   2.54    #D4C84A
```

The exact set of columns depends on the probe and its firmware. `lifr`
recognises these headers (case and punctuation are ignored):

| Header seen in the field | Becomes | Notes |
|----|----|----|
| `Depth`, `Depth (ft)` | `depth` | Required |
| `Signal`, `LIF` | `signal` | Required |
| `EC.Value`, `EC Value`, `EC` | `ec` | Conductivity value (not `EC.Depth`, the channel’s own offset depth) |
| `HP.PresDown`, `HP PresDown`, `HP` | `hp` | Downward hydraulic push pressure |
| `color`, `Color`, `colour` | `color` | Normalised to `#RRGGBB`; anything else becomes `NA` |

Every other header is kept under a cleaned snake_case name:

``` r

x <- lif_read(file.path(demo, "LIF-05.lif.dat.txt"))
names(x)
#> [1] "depth"  "signal" "boring" "ec"     "hp"     "color"
```

If a file carried, say, `EC.Depth` and `Detector 1 Max (uV)`, they would
come through as `ec_depth` and `detector_1_max_uv`. Nothing recorded by
the instrument is dropped at import.

Comma-separated `.lif.dat.csv` files are read the same way; the
delimiter is sniffed from the first line.

### Legacy files without a header

Older firmware wrote the same layout with no header row. Pass
`legacy = TRUE` and the columns are assigned by count: 11 columns is a
LIF log (`depth`, `signal`, `ch1`-`ch4`, `ec_depth`, `ec`, `hmr_depth`,
`hmr_val`, `color`) and 16 columns is a combined HP-LIF log (the same
plus `hp_depth`, `hp_time`, `hp_presup`, `hp`, `hp_flowup`).

``` r

lif <- lif_import("C:/Projects/OldSite/LIF", legacy = TRUE)
```

### The locations file

A CSV or tab-delimited table with one row per boring:

``` r

read_locations(file.path(demo, "locations.csv"))
#>    boring easting northing   msl
#> 1  LIF-01  1014.5   2017.9 149.6
#> 2  LIF-02  1074.5   2012.3 149.1
#> 3  LIF-03  1148.3   2015.6 150.3
#> 4  LIF-04  1199.9   2024.8 151.2
#> 5  LIF-05  1031.5   2074.0 150.8
#> 6  LIF-06  1074.5   2084.6 149.6
#> 7  LIF-07  1125.0   2078.3 150.2
#> 8  LIF-08  1178.9   2096.4 150.8
#> 9  LIF-09  1039.3   2135.9 150.5
#> 10 LIF-10  1071.4   2148.9 150.1
#> 11 LIF-11  1141.2   2128.7 150.3
#> 12 LIF-12  1198.1   2145.3 149.8
```

Column names are matched case-insensitively, and a few aliases are
accepted (`x`/`y` for easting/northing, `elevation` or `z` for `msl`,
`name` or `id` for `boring`). Coordinates should be in a projected
system in feet, typically the site’s State Plane zone; `msl` is the
ground-surface elevation, used to convert depth to elevation.

A boring listed twice is an error. A duplicate row would double every
reading of that boring through the join, which is the kind of mistake
that is invisible in a plot and wrong in every statistic.

## What `lif_import()` does

1.  Lists every file matching `.lif.dat.txt` or `.lif.dat.csv` in the
    folder and reads each with
    [`lif_read()`](https://mjorden.github.io/lifr/reference/lif_read.md).
2.  Binds them. If the files do not agree on their column set (firmware
    drift, a hand-edited export), the union is used and the missing
    cells are `NA`, with a warning naming the files.
3.  Finds the locations file (`locations.csv` is preferred over
    `locations.txt`, then any `locations*.csv`), or uses the path you
    give in `locations_file`.
4.  Joins the coordinates on `boring`.
5.  Orders the columns: `easting`, `northing`, `depth`, `signal`,
    `boring`, `msl`, `ec`, `hp`, `color`, then everything else.

``` r

lif <- lif_import(demo)
```

### When borings and locations disagree

Boring names come from the file names, so `LIF-01.lif.dat.txt` must
match a `LIF-01` row in the locations file exactly.

- A log with no locations row is **dropped with a warning that names
  it**. Fix the locations file and re-import.
- A locations row with no log is ignored, with a message.
- If **nothing** matches, import stops and prints both name lists side
  by side. That is almost always a format mismatch (`LIF-01` versus
  `LIF01`).

### Importing without coordinates

You can look at logs before the survey crew has sent coordinates:

``` r

lif <- lif_import("C:/Projects/MySite/LIF", locations_file = FALSE)
```

Depth profiles and summaries work without coordinates. Maps and the
report’s map section need them and will say so.

## The `lif_data` object

The import returns a plain data frame tagged with the `lif_data` class.
The class adds a compact [`print()`](https://rdrr.io/r/base/print.html)
and a [`summary()`](https://rdrr.io/r/base/summary.html) that calls
[`summarize_lif()`](https://mjorden.github.io/lifr/reference/summarize_lif.md);
everything else you know about data frames, base R or tidyverse, keeps
working.

``` r

class(lif)
#> [1] "lif_data"   "data.frame"
lif[lif$boring == "LIF-05" & lif$depth > 15 & lif$depth < 16, ]
#> <lif_data> 1 boring(s), 3 sample(s), depth 15.2-15.8 ft, 0 edit(s)
#>   channels: signal, ec, hp, color
#>     easting northing depth signal boring   msl   ec   hp   color
#> 555  1031.5     2074 15.25  4.455 LIF-05 150.8 7.29 4.32 #D4C84A
#> 556  1031.5     2074 15.50  3.560 LIF-05 150.8 7.59 4.24 #D4C84A
#> 557  1031.5     2074 15.75  2.583 LIF-05 150.8 7.11 4.98 #6B8E23
```

To tag a frame you built some other way, use
[`new_lif_data()`](https://mjorden.github.io/lifr/reference/lif_data.md);
it checks for `boring`, `depth`, and `signal`.
[`compat_rename_legacy()`](https://mjorden.github.io/lifr/reference/compat_rename_legacy.md)
maps older TitleCase column names (`Depth`, `Signal`) onto the lowercase
convention.

## Trying the package without field data

[`lif_simulate()`](https://mjorden.github.io/lifr/reference/lif_simulate.md)
writes a synthetic site in exactly this layout:

``` r

d <- tempfile("practice")
lif_simulate(n_borings = 6, dir = d, verbose = FALSE)
list.files(d)
#> [1] "LIF-01.lif.dat.txt" "LIF-02.lif.dat.txt" "LIF-03.lif.dat.txt"
#> [4] "LIF-04.lif.dat.txt" "LIF-05.lif.dat.txt" "LIF-06.lif.dat.txt"
#> [7] "locations.csv"
sim <- lif_import(d, verbose = FALSE)
sim
#> <lif_data> 6 boring(s), 692 sample(s), depth 0.2-37.8 ft, 0 edit(s)
#>   channels: signal, ec, hp, color
#>    easting northing depth signal boring   msl    ec   hp   color
#> 1     1024   2051.1  0.25  1.844 LIF-01 150.3  9.40 2.54 #6B8E23
#> 2     1024   2051.1  0.50  0.222 LIF-01 150.3  8.74 2.58 #B0B0B0
#> 3     1024   2051.1  0.75  0.501 LIF-01 150.3  9.21 2.88 #6B8E23
#> 4     1024   2051.1  1.00  0.107 LIF-01 150.3  9.93 2.55 #B0B0B0
#> 5     1024   2051.1  1.25  0.011 LIF-01 150.3  9.67 2.82 #B0B0B0
#> 6     1024   2051.1  1.50  0.006 LIF-01 150.3  9.76 3.04 #B0B0B0
#> 7     1024   2051.1  1.75  0.102 LIF-01 150.3  9.78 2.79 #B0B0B0
#> 8     1024   2051.1  2.00  0.049 LIF-01 150.3 10.66 2.77 #B0B0B0
#> 9     1024   2051.1  2.25  0.009 LIF-01 150.3 10.04 2.88 #B0B0B0
#> 10    1024   2051.1  2.50  0.088 LIF-01 150.3 10.23 3.02 #B0B0B0
#> # ... 682 more row(s)
```

The plume is a pair of Gaussian lobes, the pressure profile is
hydrostatic with thin low-pressure sand layers, and the emission colour
is keyed to signal strength. It is deliberately plausible and entirely
made up.
