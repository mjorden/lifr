# Read a boring locations table

Reads a CSV or tab-delimited file with one row per boring and the
columns `boring`, `easting`, `northing`, and `msl` (ground-surface
elevation). Column names are matched case-insensitively and the
delimiter is sniffed from the first line. A boring listed twice is an
error, because a repeated row would multiply every reading of that
boring through the join.

## Usage

``` r
read_locations(file)
```

## Arguments

- file:

  Path to the locations file.

## Value

A data frame with `boring`, `easting`, `northing`, `msl`, plus any other
columns the file carries.

## Examples

``` r
f <- system.file("extdata", "demo", "locations.csv", package = "lifr")
read_locations(f)
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
