############################################################
# University of Minnesota Morris – Fleet Prioritization Score
# Goal:
#   - Rank vehicles for electrification priority
#   - Based on fuel use, utilization, age, EV availability
#   - Scope: FY22–FY24 totals (one record per Vehicle_ID)
############################################################

library(readxl)
library(dplyr)
library(writexl)
library(lubridate)

## helper function: min–max scaling to 0–100
scale_0_100 <- function(x) {
  rng <- range(x, na.rm = TRUE)
  if (diff(rng) == 0) {
    return(rep(50, length(x)))
  } else {
    return(100 * (x - rng[1]) / (rng[2] - rng[1]))
  }
}

##### reading excel files
ethanol_billing_clean <- read_excel("Ethanol Billing Combined Clean.xlsx")


### filter On Road vehicles across FY22–FY24 and calculate miles
onroad_data <- ethanol_billing_clean %>%
  filter(FY %in% c("22","23","24"),
         Type %in% c("On Road", "Other")) %>%
  mutate(Miles = Gallons * Fuel_Efficiency)

### aggregate totals across all three years (per Vehicle_ID)
unit_summary <- onroad_data %>%
  group_by(Vehicle_ID, Department, Duty, `Model Year`, Make_Model) %>%
  summarise(
    Total_Gallons = sum(Gallons, na.rm = TRUE),
    Total_Miles   = sum(Miles,   na.rm = TRUE),
    Fill_Count    = n(),
    .groups = "drop"
  )

### fuel use score: share of gallons across all vehicles
unit_summary <- unit_summary %>%
  mutate(FuelUse_score = ifelse(sum(Total_Gallons, na.rm = TRUE) > 0,
                                100 * Total_Gallons / sum(Total_Gallons, na.rm = TRUE), 0))

### utilization score: miles scaled 0–100 across all vehicles
unit_summary <- unit_summary %>%
  mutate(Utilization_score = scale_0_100(Total_Miles))

### vehicle age: as of FY24 (latest year in scope)
unit_summary <- unit_summary %>%
  mutate(Age_yrs = pmax(0, 2024 - as.numeric(`Model Year`)),
         Age_score = scale_0_100(Age_yrs))

### EV fit lookup table (based on 2025 market availability)
evfit_table <- tibble(
  Duty = c("Sedan","SUV","Passenger Van","Cargo Van",
           "Light Truck","Medium Truck"),
  EVFit_score = c(90, 80, 65, 70, 55, 40)
)

unit_summary <- unit_summary %>%
  left_join(evfit_table, by = "Duty") %>%
  mutate(EVFit_score = ifelse(is.na(EVFit_score), 60, EVFit_score))

### winter suitability table (optional)
## AAA (2019), DOE Idaho Lab (2019): EV range drops 25–40% in cold
winter_table <- tibble(
  Duty = c("Sedan","SUV","Passenger Van","Cargo Van",
           "Light Truck","Medium Truck"),
  Winter_score = c(80, 75, 65, 60, 55, 50)
)

unit_summary <- unit_summary %>%
  left_join(winter_table, by = "Duty") %>%
  mutate(Winter_score = ifelse(is.na(Winter_score), 60, Winter_score))

### composite priority score (weights sum to 1.0)
unit_summary <- unit_summary %>%
  mutate(
    Priority = 0.30*Age_score +
      0.25*FuelUse_score +
      0.20*Utilization_score +
      0.20*EVFit_score +
      0.05*Winter_score
  )


### top 10 vehicles overall (highest composite score)
top10 <- unit_summary %>%
  arrange(desc(Priority)) %>%
  slice_head(n = 10)
s
### department summary for context (average priority, unit counts)
dept_summary <- unit_summary %>%
  group_by(Department) %>%
  summarise(
    Avg_Priority = round(mean(Priority, na.rm = TRUE),1),
    High_Priority = sum(Priority >= 70, na.rm = TRUE),
    Units = n(),
    .groups = "drop"
  ) %>%
  arrange(desc(Avg_Priority))

### export outputs for reporting / dashboard
write_xlsx(unit_summary, "EV Transition Priortization.xlsx")
write_xlsx(top10, "Top10_Priority.xlsx")
