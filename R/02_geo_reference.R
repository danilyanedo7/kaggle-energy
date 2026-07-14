library(tidyverse)
library(sf)
library(rnaturalearth)

out_dir <- "data/processed"

provinces <- ne_states(country = "Spain", returnclass = "sf") %>%
  select(name) %>%
  filter(!name %in% c("Ceuta", "Melilla"))

region_lookup <- tribble(
  ~name, ~region,
  "Almería", "Andalucía", "Cádiz", "Andalucía", "Córdoba", "Andalucía",
  "Granada", "Andalucía", "Huelva", "Andalucía", "Jaén", "Andalucía",
  "Málaga", "Andalucía", "Sevilla", "Andalucía",
  "Huesca", "Aragón", "Teruel", "Aragón", "Zaragoza", "Aragón",
  "Asturias", "Asturias",
  "Baleares", "Baleares",
  "Las Palmas", "Canarias", "Santa Cruz de Tenerife", "Canarias",
  "Cantabria", "Cantabria",
  "Ávila", "Castilla y León", "Burgos", "Castilla y León", "León", "Castilla y León",
  "Palencia", "Castilla y León", "Salamanca", "Castilla y León", "Segovia", "Castilla y León",
  "Soria", "Castilla y León", "Valladolid", "Castilla y León", "Zamora", "Castilla y León",
  "Albacete", "Castilla-La Mancha", "Ciudad Real", "Castilla-La Mancha", "Cuenca", "Castilla-La Mancha",
  "Guadalajara", "Castilla-La Mancha", "Toledo", "Castilla-La Mancha",
  "Barcelona", "Cataluña", "Gerona", "Cataluña", "Lérida", "Cataluña", "Tarragona", "Cataluña",
  "Alicante", "Comunidad Valenciana", "Castellón", "Comunidad Valenciana", "Valencia", "Comunidad Valenciana",
  "Badajoz", "Extremadura", "Cáceres", "Extremadura",
  "La Coruña", "Galicia", "Lugo", "Galicia", "Orense", "Galicia", "Pontevedra", "Galicia",
  "Madrid", "Madrid",
  "Murcia", "Murcia",
  "Navarra", "Navarra",
  "Álava", "País Vasco", "Gipuzkoa", "País Vasco", "Bizkaia", "País Vasco",
  "La Rioja", "La Rioja"
)

# installed wind capacity by region, 2022, MW -- AEE / Wikipedia
# https://en.wikipedia.org/wiki/Wind_power_in_Spain
# not from the Kaggle dataset, external context only: shows where turbines
# actually sit vs the 5 weather-observation cities used throughout this site
wind_capacity <- tribble(
  ~region, ~wind_mw,
  "Castilla y León", 6507.2,
  "Aragón", 4922.5,
  "Castilla-La Mancha", 4786.2,
  "Galicia", 3863.1,
  "Andalucía", 3543.8,
  "Navarra", 1351.9,
  "Cataluña", 1341.8,
  "Comunidad Valenciana", 1238.8,
  "Asturias", 695.5,
  "Canarias", 620.1,
  "La Rioja", 446.6,
  "Murcia", 262.0,
  "País Vasco", 153.3,
  "Extremadura", 39.4,
  "Cantabria", 35.3,
  "Baleares", 3.7,
  "Madrid", 0,
)

wind_regions <- provinces %>%
  left_join(region_lookup, by = "name") %>%
  group_by(region) %>%
  summarise(geometry = st_union(geometry), .groups = "drop") %>%
  st_simplify(dTolerance = 0.01, preserveTopology = TRUE) %>%
  left_join(wind_capacity, by = "region") %>%
  mutate(
    wind_mw = replace_na(wind_mw, 0),
    area_km2 = as.numeric(st_area(geometry)) / 1e6,
    wind_mw_per_1000km2 = wind_mw / area_km2 * 1000
  )

st_write(wind_regions, file.path(out_dir, "wind_regions.geojson"), delete_dsn = TRUE, quiet = TRUE)

message("Done. Wind region reference layer written to ", out_dir)
