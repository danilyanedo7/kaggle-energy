library(ggplot2)
library(scales)

ink_primary <- "#0b0b0b"
ink_secondary <- "#52514e"
ink_muted <- "#898781"
grid_hairline <- "#e1e0d9"
surface <- "#fcfcfb"

# fixed stacking order bottom to top, keep this everywhere, don't re-sort by value
source_levels <- c("Fossil", "Nuclear", "Wind", "Hydro", "Solar", "Other")

source_colors <- c(
  "Fossil" = "#e34948",
  "Nuclear" = "#4a3aa7",
  "Wind" = "#1baf7a",
  "Hydro" = "#2a78d6",
  "Solar" = "#eda100",
  "Other" = ink_muted
)

seq_blue <- c("#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5", "#1c5cab", "#0d366b")

div_low <- "#2a78d6"
div_mid <- "#f0efec"
div_high <- "#e34948"

status_good <- "#0ca30c"
status_bad <- "#d03b3b"

theme_energy <- function(base_size = 12) {
  # don't set base_family to "system-ui" here, it's a CSS keyword not a real font
  # name and R's graphics device chokes on it (or silently drops all text)
  theme_minimal(base_size = base_size) %+replace%
    theme(
      plot.background = element_rect(fill = surface, color = NA),
      panel.background = element_rect(fill = surface, color = NA),
      panel.grid.major.y = element_line(color = grid_hairline, linewidth = 0.4),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      axis.line.x = element_line(color = "#c3c2b7", linewidth = 0.4),
      axis.ticks = element_blank(),
      axis.text = element_text(color = ink_muted, size = rel(0.85)),
      axis.title = element_text(color = ink_secondary, size = rel(0.9)),
      plot.title = element_text(color = ink_primary, face = "bold", size = rel(1.15),
        margin = margin(b = 4), hjust = 0),
      plot.subtitle = element_text(color = ink_secondary, size = rel(0.95),
        margin = margin(b = 12), hjust = 0),
      plot.caption = element_text(color = ink_muted, size = rel(0.75), hjust = 0,
        margin = margin(t = 8)),
      legend.position = "top",
      legend.justification = "left",
      legend.title = element_blank(),
      legend.text = element_text(color = ink_secondary, size = rel(0.85)),
      legend.key = element_blank(),
      strip.background = element_blank(),
      strip.text = element_text(color = ink_primary, face = "bold", size = rel(0.95)),
      plot.margin = margin(10, 16, 10, 10)
    )
}

theme_set(theme_energy())

mw_label <- function(x) label_number(scale = 1e-3, suffix = " GW")(x)
eur_label <- function(x) label_number(prefix = "€", suffix = "/MWh")(x)
