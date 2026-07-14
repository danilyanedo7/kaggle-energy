# Spain's Power Grid

A minimalist Quarto dashboard + long-form data-viz narrative on Spain's
electricity generation mix and renewables transition (2015–2018), built on the
Kaggle [*Hourly energy demand generation and weather*](https://www.kaggle.com/datasets/nicholasjhana/energy-consumption-generation-prices-and-weather)
dataset.

- `index.qmd`: the dashboard, KPI tiles, the generation-mix chart, and a
  geospatial exploration section (an interpolated temperature surface, a
  wind-capacity-by-region overlay, and a city picker linked to both the map
  and a per-city chart), plus two supporting charts.
- `deep-dive.qmd`: the deep-dive report, the full renewables-transition
  narrative (drought/hydro/fossil substitution, solar policy stagnation,
  solar/wind seasonal complementarity, the merit-order price effect,
  weather-vs-demand), an STL decomposition and changepoint-detected regime
  break for the drought, a rough counterfactual price estimate, three named
  extreme-price events, methodology, and known limitations.

## Project layout

```
R/
  01_clean_data.R     # raw CSVs -> data/processed/*.rds,csv (run this first)
  02_geo_reference.R  # builds data/processed/wind_regions.geojson (run once; not needed at render time)
  theme_energy.R      # shared ggplot theme + validated color palette
data/
  raw/                # the two Kaggle CSVs (gitignored -- you provide these)
  processed/          # small derived files the .qmd files actually read (committed)
index.qmd             # dashboard (format: dashboard)
deep-dive.qmd         # long-form report (format: html)
theme.scss            # site-wide minimalist theme (flat cards, no chart junk)
_quarto.yml           # project + navbar + format config
.github/workflows/publish.yml  # auto-deploy to GitHub Pages on push to main
```

## Reproducing this locally

**1. Get the data.** Download `energy_dataset.csv` and `weather_features.csv`
from the [Kaggle dataset page](https://www.kaggle.com/datasets/nicholasjhana/energy-consumption-generation-prices-and-weather)
and place both in `data/raw/`. (Or use the Kaggle API/CLI if you have
credentials configured.)

**2. Install R dependencies:**

```r
install.packages(c(
  "tidyverse", "plotly", "leaflet", "htmltools", "scales", "gt",
  "sf", "gstat", "terra", "crosstalk", "changepoint"
))
```

`sf`/`gstat`/`terra` need GDAL, GEOS and PROJ installed at the system level
(on macOS, `brew install gdal geos proj` if `install.packages()` complains).
`rnaturalearth` + `rnaturalearthhires` are only needed if you want to
regenerate `data/processed/wind_regions.geojson` yourself (see step 3);
nothing at render time depends on them.

**3. Clean the data** (writes the small files in `data/processed/` that both
`.qmd` files read from):

```r
Rscript R/01_clean_data.R
Rscript R/02_geo_reference.R   # optional -- only if wind_regions.geojson needs regenerating
```

**4. Render the site** (requires [Quarto](https://quarto.org/docs/get-started/) ≥ 1.4):

```
quarto render        # builds both pages into _site/
quarto preview        # or: live-reloading local preview
```

## Deploying to GitHub Pages

Two ways, either works:

**A. Automatic (recommended).** Push this repo to GitHub with the data
already cleaned (`data/processed/` committed, it's small and derived, no
license concerns). The included `.github/workflows/publish.yml` will render
the site and push it to a `gh-pages` branch on every push to `main`. After
the first run, go to **Settings → Pages** in your GitHub repo and set the
Pages source to the `gh-pages` branch (only needed once).

Before pushing, update the two placeholders in `_quarto.yml`
(`site-url` and the `github` navbar link) to point at your actual repo.

**B. Manual, one-off:**

```
quarto publish gh-pages
```

This renders locally and pushes straight to `gh-pages`, no GitHub Actions
needed, but you have to re-run it yourself after every change.

## Notes on scope

- **Renewable = hydro + wind + solar + biomass + other renewable +
  geothermal.** Waste-to-energy is counted as "Other." See the Methodology
  section of the deep-dive for the reasoning and other judgment calls
  (weather-as-proxy limitations, DST de-duplication, sensor-glitch handling).
- The national weather proxy is **population-weighted** across the 5 cities
  (approximate metro-area populations, hardcoded in `01_clean_data.R`), not a
  flat average.
- The wind-capacity-by-region map layer is **2022 external reference data**
  (AEE via Wikipedia), not part of the Kaggle dataset. It's there to show
  where Spain's wind farms actually sit relative to the 5 weather-observation
  cities, not to make a claim about any specific year.
- The interpolated temperature surface on the map is inverse-distance
  weighting from just 5 points. Treat it as illustrative, not a real
  meteorological analysis, same caveat as the map's wind-speed limitation.
- The color palette (fixed hue order, colorblind-safe adjacency, contrast
  checks) and chart conventions follow a validated data-viz methodology,
  see `R/theme_energy.R` for the palette definitions.
- Chart figures are forced onto the `ragg_png` graphics device
  (`_quarto.yml` -> `knitr.opts_chunk.dev`). Some R graphics devices silently
  drop all text when handed a theme with a non-resolvable font family, and
  `ragg` is the reliable one across platforms.
- The map's city-picker filter and its linked chart use crosstalk's
  **filter** mechanism (`filter_select`), not click-to-select. Clicking a
  leaflet marker directly does not filter the chart; static crosstalk's
  click-based cross-widget selection between leaflet and plotly is not
  reliably supported outside Shiny, so this deliberately uses the more
  robust of the two mechanisms.
