############################################################
# University of Minnesota Morris – Ethanol Fleet Analysis
# Goal:
#   - Clean and merge ethanol billing data with vehicle list
#   - Standardize vehicle types (On Road vs Off Road)
#   - Ensure consistent department mapping across sources
#   - Calculate mileage and summarize annual fuel usage

# Key Challenges:
#   - Vehicle IDs inconsistent (5 vs 6 digits, missing zeros, text IDs)
#   - Departments coded differently across systems (Dpt, Usage, vehicle list)
#   - Missing values for Type and Department required business-rule assumptions
#
# Deliverables:
#   - Cleaned dataset for analysis ("Ethanol Billing Combined Clean.xlsx")
#   - Annual fuel usage summary by fiscal year, department and other variables to highlight EV Transition Opportunities
############################################################


## install and load necessary packages
#install.packages(c("readxl", "dplyr", "writexl", "tidyr", "lubridate", "stringr"))
library(readxl)
library(dplyr)
library(writexl)
library(tidyr)
library(lubridate)
library(stringr)

##### reading excel files
ethanol_billing <- read_excel("Ethanol Billing Combined.xlsx")
vehicle_list <- read_excel("Compiled vehicle List.xlsx")

##remame the Vehicle ID column in both tables
ethanol_billing <- ethanol_billing %>%
  rename(Vehicle_ID = 'Veh#')
vehicle_list <- vehicle_list %>% 
  rename(Vehicle_ID = 'Veh#')

## merge Vehicle ID, Department and Make Model column from vehicle list to ensure accuracy
ethanol_billing <- left_join(ethanol_billing, vehicle_list %>% 
                               select(Vehicle_ID, `Dept- from Morris`, `Make Model`), by = "Vehicle_ID") 

## rename the department and make model column
ethanol_billing <- ethanol_billing %>% rename(Department = `Dept- from Morris`)
ethanol_billing <- ethanol_billing %>% rename(Make_Model = `Make Model`)



## Business rule: Vehicle IDs with 5–6 digits correspond to licensed "On Road" vehicles.  
## Any non-numeric or irregular IDs represent equipment classified as "Off Road."
## This distinction is important for separating fleet compliance vs. facilities equipment usage.

##create 'Type' column with NA values
ethanol_billing <- ethanol_billing %>%
  mutate(Type = NA)

## assign On Road Vehicle type if Vehicle ID exists in Vehicle List
ethanol_billing <- ethanol_billing %>%
  mutate(Type = ifelse(is.na(Type) & Vehicle_ID %in% vehicle_list$Vehicle_ID, 'On Road', Type))

## assign Off Road Vehicle type if Vehicle ID is not a 5 or 6 digit number (Text data)
ethanol_billing <- ethanol_billing %>%
  mutate(Type = ifelse(!grepl("^\\d{5,6}$", as.character(Vehicle_ID)), 'Off Road', Type))



### Since the Ethanol Billing file were a result combining multiple sources of collecting 
    #fuel usage, vehicle IDs may have missing leading zero on certain records.
##get unique Vehicle ID with empty Type rows to see which vehicle does not exist in vehicle list
unique_empty_type_veh <- ethanol_billing %>% filter(is.na(Type) | Type == "") %>% select(Vehicle_ID) %>% distinct()

## add leading 0 to 5-digit Vehicle_IDs (while ignoring Vehicle ID that has text in it)
ethanol_billing <- ethanol_billing %>%
  mutate(Vehicle_ID = ifelse(grepl("^\\d{5}$", Vehicle_ID), paste0("0", Vehicle_ID), Vehicle_ID))

## assign On Road Vehicle type if Vehicle ID exists in Vehicle List (again after adding leading 0 to Vehicle ID)
ethanol_billing <- ethanol_billing %>%
  mutate(Type = ifelse(is.na(Type) & Vehicle_ID %in% vehicle_list$Vehicle_ID, 'On Road', Type))

##get unique Vehicle ID with empty Type rows to see which vehicle does not exist in vehicle list
unique_empty_type_veh <- ethanol_billing %>% filter(is.na(Type) | Type == "") %>% select(Vehicle_ID) %>% distinct()


## fill the Type column with 'Other' for rows with missing Type, these vehicles' actual Type are unknown
ethanol_billing <- ethanol_billing %>%
  mutate(Type = ifelse(is.na(Type) | Type == "", "Other", Type))

### Since the Ethanol Billing file were a result combining multiple sources of collecting 
#fuel usage, DPT column exists in a few files and does not in other files
## Department field cleaned in 3 passes:
##   1. Fill missing Dept from official Dpt codes (Transaction Detail)
##   2. Fill from Usage column for On Road/Other vehicles
##   3. Fill from Usage column for Off Road vehicles
## This ensures every record is assigned a consistent department.

## fill in Department based on dpt column from Transaction Detail Report
ethanol_billing <- ethanol_billing %>% 
  mutate(Department = case_when(
    Dpt == "UMMFLEET" ~ "Rental Fleet",
    Dpt %in% c("Police", "UMMPARK") ~ "Public Safety",
    Dpt %in% c("FMCNST", "UMMFM") ~ "Facilities Management",
    TRUE ~ Department
  ))

## fill in department based on Usage column 
ethanol_billing <- ethanol_billing %>% 
  mutate(Department = case_when(
    Type %in% c('On Road', 'Other') & tolower(Usage) == 'fleet' ~ 'Rental Fleet',
    tolower(Usage) == 'public safety' ~ 'Public Safety',
    Type %in% c('On Road', 'Other') & !tolower(Usage) %in% c('fleet', 'public safety') ~ 'Facilities Management',
    TRUE ~ Department
  ))

ethanol_billing <- ethanol_billing %>% 
  mutate(Department = case_when(
    Type %in% c('Off Road') & tolower(Usage) == 'fleet' ~ 'Rental Fleet',
    Type %in% c('Off Road') & tolower(Usage) == 'orl' ~ 'Office of Res Life',
    Type %in% c('Off Road') & tolower(Usage) == 'athletics' ~ 'Athletics',
    Type %in% c('Off Road') & tolower(Usage) == 'public safety' ~ 'Public Safety',
    Type %in% c('Off Road') ~ 'Facilities Management',
    TRUE ~ Department
  ))

##change any 'carp' to Carp/Paint
ethanol_billing <- ethanol_billing %>%
  mutate(Usage = ifelse(grepl("carp", Usage, ignore.case = TRUE), "Carp/Paint", Usage))

## quick diagnostic steps to validate classification results and highlight unmapped IDs/usage values for further review
unique_fm_usage <- ethanol_billing %>%
  filter(Type %in% c('Other', 'On Road') & Department == 'Facilities Management') %>%
  select(Usage) %>%
  distinct()
unique_fm_onroad <- ethanol_billing %>%
  filter(Type %in% c('Other', 'On Road')) %>%
  select(Usage, Department) %>%
  distinct()

unique_usage_offroad <- ethanol_billing %>% 
  filter(Type %in% c('Off Road')) %>% select(Usage, Department) %>% 
  distinct()

## change language of Truck Duty Type for better interpretation
vehicle_list <- vehicle_list %>%
  mutate(Duty = case_when(
    Duty == "Medium" ~ "Medium Truck",
    Duty == "Light"  ~ "Light Truck",
    TRUE             ~ Duty   # keep all other values unchanged
  ))

## add the 'Duty' column to ethanol_billing by matching 'Vehicle ID'
ethanol_billing <- ethanol_billing %>%
  left_join(vehicle_list %>% select(Vehicle_ID, Duty), by = "Vehicle_ID")

## add the 'Model Year' column to ethanol_billing by matching 'Vehicle ID' and getting the 'Year' column from vehicle_list
ethanol_billing <- ethanol_billing %>%
  left_join(vehicle_list %>% select(Vehicle_ID, Year) %>% rename(`Model Year` = Year), by = "Vehicle_ID")


ethanol_billing <- ethanol_billing %>% left_join(vehicle_list %>% select(Vehicle_ID, Fuel_Efficiency), by = "Vehicle_ID")

## convert Gallons and Fuel_Efficiency columns to numeric
ethanol_billing <- ethanol_billing %>%
  mutate(Gallons = as.numeric(Gallons),
         Fuel_Efficiency = as.numeric(Fuel_Efficiency))

## create the Mileage column
ethanol_billing <- ethanol_billing %>%
  mutate(Mileage = Gallons * Fuel_Efficiency)

## convert Date to Date format and calculate FY as a two-digit year (Fiscal Year starts at July)
ethanol_billing <- ethanol_billing %>%
  mutate(Date = as.Date(Date, format = "%Y-%m-%d"),
         FY = ifelse(month(Date) >= 7, year(Date) + 1, year(Date)),
         FY = substr(as.character(FY), 3, 4)) # Extract last two digits of the year

## default any missing dates to FY23 (known gap from billing records).
ethanol_billing <- ethanol_billing %>% mutate(FY = ifelse(is.na(Date), 23, FY))

ethanol_summary <- ethanol_billing %>%
  group_by(FY) %>%
  summarise(Total_Gallons = sum(Gallons, na.rm = TRUE))

print(ethanol_summary)

## con-catting Year, Make and Model Column
ethanol_billing <- ethanol_billing %>%
  mutate(Year_Make_Model = paste(`Model Year`, Make_Model, sep = " "))


## display the results
head(ethanol_billing)

write_xlsx(ethanol_billing, "Ethanol Billing Combined Clean.xlsx")

## Final output:
##   - "Ethanol Billing Combined Clean.xlsx" = cleaned dataset
##   - ethanol_summary printed in console = annual gallons by fiscal year
## Ready for downstream analysis or dashboarding.


### ARCHIVE CODE
# Updated function to prepend '0' to 5-digit Vehicle ID values only if Type is empty
#add_leading_zero <- function(veh, type) {
#if (is.na(type) & nchar(veh) == 5) {
#    return(paste0("0", veh))
# } else {
#    return(veh)
#  }
#}
# Apply the function to the Vehicle ID column based on Type column
#ethanol_billing <- ethanol_billing %>%
#mutate(Vehicle_ID = mapply(add_leading_zero, Vehicle_ID, Type))