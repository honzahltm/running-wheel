library(dplyr) 
library(lubridate)
library(readr)
library(ggplot2)

# 1. Načtení CSV
data <- read_delim("E:/DATA.CSV", 
                   delim = ";", 
                   locale = locale(decimal_mark = ","))

# 2. Oprava názvů sloupců
colnames(data) <- c("Start", "Konec", "Vzdalenost", "Max_rychlost", "Prumerna_rychlost")

# 3. Převod časů
data <- data %>%
  mutate(
    Start = dmy_hms(Start),
    Konec = dmy_hms(Konec),
    PrumerCas = Start + (Konec - Start)/2,
    Cas_10min = floor_date(PrumerCas, "10 minutes"),
    Den = date(PrumerCas)  # nový sloupec s datem
  )

# 4. Souhrn po 10min blocích (pro graf)
souhrn <- data %>%
  group_by(Cas_10min) %>%
  summarise(Suma_vzdalenosti_m = sum(Vzdalenost, na.rm = TRUE)) %>%
  arrange(Cas_10min)

# 5. Filtrování podle intervalu
od <- ymd_hm("2025-07-31 00:00")
do <- ymd_hm("2025-08-06 12:00")

souhrn_filtered <- souhrn %>%
  filter(Cas_10min >= od & Cas_10min <= do)

data_filtered <- data %>%
  filter(PrumerCas >= od & PrumerCas <= do)

# 6. Výpis souhrnu po dnech (vzdálenost, průměrná rychlost, max rychlost)
souhrn_dny <- data_filtered %>%
  group_by(Den) %>%
  summarise(
    Celkova_vzdalenost_m = sum(Vzdalenost, na.rm = TRUE),
    Prumerna_rychlost = mean(Prumerna_rychlost, na.rm = TRUE),
    Prumerna_max_rychlost = mean(Max_rychlost, na.rm = TRUE)
  )

# 7. Výpis textově
print(souhrn_dny)

# 8. Graf
ggplot(souhrn_filtered, aes(x = Cas_10min, y = Suma_vzdalenosti_m)) +
  geom_col(fill = "steelblue") +
  labs(title = "Uběhlá vzdálenost po 10min intervalech",
       x = "Čas (10min bloky)",
       y = "Uběhlá vzdálenost [m]") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
