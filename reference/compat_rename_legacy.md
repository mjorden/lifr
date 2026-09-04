# Rename legacy TitleCase columns to the snake_case convention

Maps `Depth`, `Signal`, `EC`, `HP`, `Color`, `Boring`, `Easting`,
`Northing`, and `MSL` to their lowercase equivalents. Only exact matches
are renamed; a rename that would collide with an existing lowercase
column is skipped with a one-per-session warning.

## Usage

``` r
compat_rename_legacy(df)
```

## Arguments

- df:

  A data frame.

## Value

`df` with any legacy columns renamed.

## Examples

``` r
df <- data.frame(boring = "B1", Depth = 1:3, Signal = c(0, 5, 2))
names(compat_rename_legacy(df))
#> [1] "boring" "depth"  "signal"
```
