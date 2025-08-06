library(dplyr) 
library(lubridate)
library(readr)
library(ggplot2)

# 1. Load CSV
data <- read_delim("E:/DATA.CSV", 
                   delim = ";", 
                   locale = locale(decimal_mark = ","))

# 2. Rename columns
colnames(data) <- c("Start", "End", "Distance", "Max_speed", "Avg_speed")

# 3. Convert time columns and create summary columns
data <- data %>%
  mutate(
    Start = dmy_hms(Start),
    End = dmy_hms(End),
    AvgTime = Start + (End - Start)/2,
    Time_10min = floor_date(AvgTime, "10 minutes"),
    Day = date(AvgTime)
  )

# 4. Sum distance per 10min block
summary_10min <- data %>%
  group_by(Time_10min) %>%
  summarise(Sum_distance_m = sum(Distance, na.rm = TRUE)) %>%
  arrange(Time_10min)

# 5. Filter by time interval
from <- ymd_hm("2025-07-31 00:00")
to <- ymd_hm("2025-08-06 12:00")

summary_filtered <- summary_10min %>%
  filter(Time_10min >= from & Time_10min <= to)

data_filtered <- data %>%
  filter(AvgTime >= from & AvgTime <= to)

# 6. Summary per day
summary_days <- data_filtered %>%
  group_by(Day) %>%
  summarise(
    Total_distance_m = sum(Distance, na.rm = TRUE),
    Mean_speed = mean(Avg_speed, na.rm = TRUE),
    Mean_max_speed = mean(Max_speed, na.rm = TRUE)
  )

# 7. Print daily summary
print(summary_days)

# 8. Plot
ggplot(summary_filtered, aes(x = Time_10min, y = Sum_distance_m)) +
  geom_col(fill = "steelblue") +
  labs(title = "Distance run at 10-minute intervals",
       x = "Time (10min blocks)",
       y = "Distance run [m]") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))



