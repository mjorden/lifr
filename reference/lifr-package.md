# lifr: import, plot, and report LIF borehole logs

Laser-Induced Fluorescence (LIF) probes such as UVOST and TarGOST are
pushed into the ground and record a fluorescence response at a fixed
depth interval. Each boring produces one log file. `lifr` reads those
logs into a tidy data frame, joins boring coordinates from a locations
file, lets you mask known-bad depth intervals with a recorded audit
trail, summarises and plots the data, and renders a site report.

## Data model

Every importer returns a
[lif_data](https://mjorden.github.io/lifr/reference/lif_data.md) object:
a data frame with one row per depth reading and at least the columns
`boring`, `depth` (ft below ground surface, downward-positive), and
`signal` (LIF response, %RE). When a locations file is joined the frame
also carries `easting`, `northing`, and `msl` (ground-surface elevation,
ft). Optional instrument channels are canonicalised to `ec` (electrical
conductivity, mS/m), `hp` (hydraulic push pressure, psi), and `color`
(emission-wavelength hex colour). Every other column in the source file
is kept under a cleaned snake_case name, so nothing recorded by the
instrument is lost at import.

## %RE is a screening proxy

LIF response is relative fluorescence, expressed as a percentage of a
reference emitter (%RE). It indicates where fluorescent product is
likely present. It is not a concentration and is not comparable to
regulatory criteria; `lifr` never maps %RE onto such criteria.

## Workflow

    lif <- lif_import("data/LIF")                 # read logs + locations
    lif <- lif_zero_shallow(lif, depth = 2)       # mask surface noise
    lif <- lif_editor(lif, "B-07", top = 18.5, bottom = 19.2)
    edit_history(lif)                             # audit trail
    summarize_lif(lif)
    lif_plot_all(lif, layout = "facet")
    boring_map(lif)
    site <- process_site("data/LIF", output_dir = "out")
    site$reports$html

## See also

Useful links:

- <https://github.com/mjorden/lifr>

- <https://mjorden.github.io/lifr/>

- Report bugs at <https://github.com/mjorden/lifr/issues>

## Author

**Maintainer**: Matthew Jorden <matthew.jorden@gmail.com> \[copyright
holder\]
