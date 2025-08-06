library(dplyr) 
library(lubridate)
library(readr)
library(ggplot2)

# 1. Načtení CSV
data <- read_delim("E:/DATA.CSV", 
                   delim = ";", 
                   locale = locale(decimal_mark = ","))

# 2. Oprava názvů sloupců
colnames(data) <- c("Start", "End", "Distance", "Max_speed", "Avg_speed")

# 3. Převod časů
data <- data %>%
  mutate(
    Start = dmy_hms(Start),
    End = dmy_hms(End),
    AvgTime = Start + (End - Start)/2,
    Time_10min = floor_date(AvgTime, "10 minutes"),
    Day = date(AvgTime)  # nový sloupec s datem
  )

# 4. Souhrn po 10min blocích (pro graf)
souhrn <- data %>%
  group_by(Time_10min) %>%
  summarise(Sum_distance_m = sum(Distance, na.rm = TRUE)) %>%
  arrange(Time_10min)

# 5. Filtrování podle intervalu
od <- ymd_hm("2025-07-31 00:00")
do <- ymd_hm("2025-08-06 12:00")

souhrn_filtered <- souhrn %>%
  filter(Time_10min >= od & Time_10min <= do)

data_filtered <- data %>%
  filter(AvgTime >= od & AvgTime <= do)

# 6. Výpis souhrnu po dnech (distance, average speed, max speed)
souhrn_dny <- data_filtered %>%
  group_by(Day) %>%
  summarise(
    Total_distance_m = sum(Distance, na.rm = TRUE),
    Avg_speed = mean(Avg_speed, na.rm = TRUE),
    Avg_max_speed = mean(Max_speed, na.rm = TRUE)
  )

# 7. Výpis textově
print(souhrn_dny)

# 8. Graf
ggplot(souhrn_filtered, aes(x = Time_10min, y = Sum_distance_m)) +
  geom_col(fill = "steelblue") +
  labs(title = "Distance run at 10-minute intervals",
       x = "Time (10min blocks)",
       y = "Distance run [m]") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))


