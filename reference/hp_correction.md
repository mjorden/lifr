# Remove the hydrostatic component from hydraulic push pressure

Raw `hp` rises with depth from the weight of the water column alone.
Subtracting `gradient * max(0, depth - water_table)` leaves the pressure
the formation itself exerts, which is the quantity that reflects
permeability.

## Usage

``` r
hp_correction(data, gradient = 0.433, water_table = 0)
```

## Arguments

- data:

  A data frame with `depth` and `hp` columns.

- gradient:

  Hydrostatic gradient in psi/ft. Default 0.433 (fresh water).

- water_table:

  Depth to water (ft below ground surface): one value applied site-wide,
  or a named vector of per-boring depths such as
  `c("LIF-01" = 12, "LIF-02" = 14.5)`. Default 0 applies the correction
  from the ground surface and prints a reminder to supply a real value.

## Value

`data` with `hp` corrected in place and one audit row recording the
parameters.

## Examples

``` r
demo <- system.file("extdata", "demo", package = "lifr")
lif <- lif_import(demo, verbose = FALSE)
lif <- hp_correction(lif, water_table = 6)
edit_history(lif)
#>                   timestamp            fn boring top bottom value
#> 1 2026-09-04 20:42:27 +0000 hp_correction   <NA>  NA     NA    NA
#>   n_rows_changed                         notes
#> 1           1489 gradient=0.433; water_table=6
```
