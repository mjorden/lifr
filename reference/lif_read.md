# Read one raw LIF log file

Reads a single `.lif.dat.txt` (or `.csv`) log into a data frame, keeping
every column the instrument recorded. The known channels are renamed to
`depth`, `signal`, `ec`, `hp`, and `color`; any other column is kept
under a cleaned snake_case version of its header (for example `EC.Depth`
becomes `ec_depth`, `Detector 1 Max (uV)` becomes `detector_1_max_uv`).
The boring name is the file name with its `.lif.dat.*` suffix removed.

## Usage

``` r
lif_read(file, legacy = FALSE)
```

## Arguments

- file:

  Path to one log file.

- legacy:

  Logical. `TRUE` for older firmware exports that have no header row: an
  11-column file is read as a LIF log and a 16-column file as a combined
  HP-LIF log. Default `FALSE` (header row present).

## Value

A data frame with `boring`, `depth`, `signal`, then the optional
canonical channels present in the file, then every remaining source
column.

## See also

[`lif_import()`](https://mjorden.github.io/lifr/reference/lif_import.md)
for a whole directory with a locations join.

## Examples

``` r
f <- system.file("extdata", "demo", "LIF-01.lif.dat.txt", package = "lifr")
head(lif_read(f))
#>   depth signal boring    ec   hp   color
#> 1  0.25  2.506 LIF-01  8.87 2.79 #6B8E23
#> 2  0.50  0.206 LIF-01  9.31 2.41 #B0B0B0
#> 3  0.75  2.146 LIF-01  9.75 2.59 #6B8E23
#> 4  1.00  0.095 LIF-01  9.40 2.83 #B0B0B0
#> 5  1.25  0.208 LIF-01 10.38 2.97 #B0B0B0
#> 6  1.50  0.098 LIF-01  9.38 2.68 #B0B0B0
```
