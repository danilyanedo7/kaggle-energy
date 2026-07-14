library(tidyverse)
library(lubridate)

raw_dir <- "data/raw"
out_dir <- "data/processed"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

energy_raw <- read_csv(file.path(raw_dir, "energy_dataset.csv"),
  col_types = cols(time = col_datetime(format = ""), .default = col_guess()))
weather_raw <- read_csv(file.path(raw_dir, "weather_features.csv"),
  col_types = cols(dt_iso = col_datetime(format = ""), .default = col_guess()))

energy <- energy_raw %>%
  distinct(time, .keep_all = TRUE) %>%
  arrange(time)

weather <- weather_raw %>%
  rename(time = dt_iso) %>%
  distinct(city_name, time, .keep_all = TRUE) %>%
  arrange(city_name, time)

# renewable = hydro + wind + solar + biomass + other renewable + geothermal + marine
# waste is NOT counted as renewable, goes into other instead
fossil_cols <- c("generation fossil brown coal/lignite", "generation fossil coal-derived gas",
  "generation fossil gas", "generation fossil hard coal", "generation fossil oil",
  "generation fossil oil shale", "generation fossil peat")
hydro_cols <- c("generation hydro pumped storage aggregated", "generation hydro pumped storage consumption",
  "generation hydro run-of-river and poundage", "generation hydro water reservoir")
wind_cols <- c("generation wind onshore", "generation wind offshore")
solar_col <- "generation solar"
other_ren_cols <- c("generation biomass", "generation other renewable", "generation geothermal", "generation marine")
other_cols <- c("generation other", "generation waste")
nuclear_col <- "generation nuclear"

existing <- function(cols) intersect(cols, names(energy))

energy_mix <- energy %>%
  mutate(across(all_of(existing(c(fossil_cols, hydro_cols, wind_cols, solar_col,
    other_ren_cols, other_cols, nuclear_col))), ~ replace_na(., 0))) %>%
  mutate(
    fossil = rowSums(across(all_of(existing(fossil_cols)))),
    nuclear = .data[[nuclear_col]],
    hydro = rowSums(across(all_of(existing(hydro_cols)))),
    wind = rowSums(across(all_of(existing(wind_cols)))),
    solar = .data[[solar_col]],
    other_renewable = rowSums(across(all_of(existing(other_ren_cols)))),
    other = rowSums(across(all_of(existing(other_cols)))),
    renewable = hydro + wind + solar + other_renewable,
    total_generation = fossil + nuclear + hydro + wind + solar + other_renewable + other,
    renewable_share = if_else(total_generation > 0, renewable / total_generation, NA_real_)
  ) %>%
  select(time, fossil, nuclear, hydro, wind, solar, other_renewable, other,
    renewable, total_generation, renewable_share,
    total_load_actual = `total load actual`,
    total_load_forecast = `total load forecast`,
    price_actual = `price actual`,
    price_day_ahead = `price day ahead`)

# metro-area population, approximate, used only as relative weights below
city_coords <- tribble(
  ~city_name, ~lat, ~lon, ~population,
  "Madrid", 40.4168, -3.7038, 6700000,
  "Barcelona", 41.3874, 2.1686, 5500000,
  "Valencia", 39.4699, -0.3763, 1600000,
  "Seville", 37.3891, -5.9845, 1500000,
  "Bilbao", 43.2630, -2.9350, 1000000
)

# population-weighted instead of a flat mean across cities: Madrid and Barcelona
# should count for more of "how Spain feels" than Bilbao does
weather_national <- weather %>%
  mutate(city_name = str_trim(city_name)) %>%
  left_join(city_coords %>% select(city_name, population), by = "city_name") %>%
  group_by(time) %>%
  summarise(
    temp_c = weighted.mean(temp, w = population, na.rm = TRUE) - 273.15,
    wind_speed = mean(wind_speed, na.rm = TRUE),
    humidity = mean(humidity, na.rm = TRUE),
    clouds_all = mean(clouds_all, na.rm = TRUE),
    .groups = "drop"
  )

hourly <- energy_mix %>%
  left_join(weather_national, by = "time") %>%
  mutate(
    date = as_date(with_tz(time, "Europe/Madrid")),
    hour_local = hour(with_tz(time, "Europe/Madrid")),
    month = floor_date(date, "month"),
    year = year(date),
    wday_local = wday(with_tz(time, "Europe/Madrid"), label = TRUE, week_start = 1)
  )

write_rds(hourly, file.path(out_dir, "hourly.rds"), compress = "xz")

monthly_mix <- hourly %>%
  group_by(month) %>%
  summarise(
    across(c(fossil, nuclear, hydro, wind, solar, other_renewable, other), \(x) sum(x, na.rm = TRUE)),
    total_generation = sum(total_generation, na.rm = TRUE),
    price_actual = mean(price_actual, na.rm = TRUE),
    total_load_actual = mean(total_load_actual, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(renewable_share = (hydro + wind + solar + other_renewable) / total_generation)

write_csv(monthly_mix, file.path(out_dir, "monthly_mix.csv"))

daily <- hourly %>%
  group_by(date) %>%
  summarise(
    renewable_share = sum(renewable, na.rm = TRUE) / sum(total_generation, na.rm = TRUE),
    fossil = sum(fossil, na.rm = TRUE),
    nuclear = sum(nuclear, na.rm = TRUE),
    hydro = sum(hydro, na.rm = TRUE),
    wind = sum(wind, na.rm = TRUE),
    solar = sum(solar, na.rm = TRUE),
    total_generation = sum(total_generation, na.rm = TRUE),
    price_actual = mean(price_actual, na.rm = TRUE),
    total_load_actual = mean(total_load_actual, na.rm = TRUE),
    temp_c = mean(temp_c, na.rm = TRUE),
    wind_speed = mean(wind_speed, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(daily, file.path(out_dir, "daily.csv"))

hourly_profile <- hourly %>%
  mutate(season = case_when(
    month(date) %in% c(12, 1, 2) ~ "Winter",
    month(date) %in% c(3, 4, 5) ~ "Spring",
    month(date) %in% c(6, 7, 8) ~ "Summer",
    TRUE ~ "Autumn"
  )) %>%
  group_by(season, hour_local) %>%
  summarise(
    load = mean(total_load_actual, na.rm = TRUE),
    price = mean(price_actual, na.rm = TRUE),
    renewable_share = sum(renewable, na.rm = TRUE) / sum(total_generation, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(season = factor(season, levels = c("Winter", "Spring", "Summer", "Autumn")))

write_csv(hourly_profile, file.path(out_dir, "hourly_profile.csv"))

# per city, per day: lets the dashboard link a map click to that city's own
# temperature trend instead of just the national blend
city_daily <- weather %>%
  mutate(city_name = str_trim(city_name), date = as_date(with_tz(time, "Europe/Madrid"))) %>%
  group_by(city_name, date) %>%
  summarise(temp_c = mean(temp, na.rm = TRUE) - 273.15, .groups = "drop")

write_csv(city_daily, file.path(out_dir, "city_daily.csv"))

city_summary <- weather %>%
  mutate(city_name = str_trim(city_name)) %>%
  group_by(city_name) %>%
  summarise(
    avg_temp_c = mean(temp, na.rm = TRUE) - 273.15,
    # 99th/1st pctile instead of true max/min, a few sensor-glitch rows blow way past
    # anything physically plausible for Spain (pressure column even hits 1,008,371 hPa)
    max_temp_c = quantile(temp_max, 0.99, na.rm = TRUE) - 273.15,
    min_temp_c = quantile(temp_min, 0.01, na.rm = TRUE) - 273.15,
    avg_wind_speed = mean(wind_speed, na.rm = TRUE),
    avg_humidity = mean(humidity, na.rm = TRUE),
    pct_clear = mean(weather_main == "clear", na.rm = TRUE) * 100,
    pct_rain = mean(weather_main %in% c("rain", "drizzle", "thunderstorm"), na.rm = TRUE) * 100,
    n_obs = n(),
    .groups = "drop"
  ) %>%
  inner_join(city_coords, by = "city_name")

write_csv(city_summary, file.path(out_dir, "city_summary.csv"))

quality_log <- tibble(
  check = c(
    "Raw energy rows",
    "Energy rows after de-dup",
    "Raw weather rows",
    "Weather rows after de-dup",
    "Energy timestamps with any NA generation column (pre-fill)",
    "Date range"
  ),
  value = c(
    as.character(nrow(energy_raw)),
    as.character(nrow(energy)),
    as.character(nrow(weather_raw)),
    as.character(nrow(weather)),
    as.character(sum(!complete.cases(energy_raw %>% select(all_of(existing(c(fossil_cols, hydro_cols, wind_cols, solar_col, other_ren_cols, other_cols, nuclear_col))))))),
    paste(min(hourly$date), "to", max(hourly$date))
  )
)

write_csv(quality_log, file.path(out_dir, "quality_log.csv"))

message("Done. Processed files written to ", out_dir)
