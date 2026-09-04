# Integrate LIF signal over depth per boring (RE-feet)

The trapezoidal integral of `signal` against `depth` for each boring, a
single number summarising how much fluorescence a boring encountered.
Like %RE itself it is a screening quantity, not a mass or concentration.

## Usage

``` r
re_feet(data)
```

## Arguments

- data:

  A [lif_data](https://mjorden.github.io/lifr/reference/lif_data.md)
  frame.

## Value

One row per boring with `boring`, `re_feet`, `peak_signal`,
`peak_depth`, and the boring's `easting`, `northing`, `msl` when
present.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
re_feet(lif)
#>    boring    re_feet peak_signal peak_depth easting northing   msl
#> 1  LIF-01   5.620875       2.506       0.25  1014.5   2017.9 149.6
#> 2  LIF-02   9.786125       2.157       0.75  1074.5   2012.3 149.1
#> 3  LIF-03  10.863625       3.006       0.75  1148.3   2015.6 150.3
#> 4  LIF-04   5.577500       2.956       0.50  1199.9   2024.8 151.2
#> 5  LIF-05  36.348375       5.334      14.75  1031.5   2074.0 150.8
#> 6  LIF-06 299.232500      49.434      18.25  1074.5   2084.6 149.6
#> 7  LIF-07 292.909000      49.217      16.00  1125.0   2078.3 150.2
#> 8  LIF-08 113.103375      21.045      17.00  1178.9   2096.4 150.8
#> 9  LIF-09 113.826375      19.417      15.25  1039.3   2135.9 150.5
#> 10 LIF-10 328.390125      82.625      16.75  1071.4   2148.9 150.1
#> 11 LIF-11 505.072750      88.607      16.75  1141.2   2128.7 150.3
#> 12 LIF-12  62.282250      12.387      15.75  1198.1   2145.3 149.8
```
