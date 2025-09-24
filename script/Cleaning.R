## install and load necessary packages
#install.packages(c("readxl", "dplyr", "writexl"))
library(readxl)
library(dplyr)
library(writexl)
library(tidyr)
library(lubridate)

# Function to read all sheets from an Excel file
read_all_sheets <- function(file_path) {
  sheets <- excel_sheets(file_path)
  sheet_list <- lapply(sheets, function(sheet) {
    read_excel(file_path, sheet = sheet)
  })
  return(sheet_list)
}

## read all sheets from each file
file1_sheets <- read_all_sheets("C:/Users/thaib/OneDrive/Documents/Office of Sustainability/Morris Fleet Fuel/Ethanol Billing 2022.xlsx")
file2_sheets <- read_all_sheets("C:/Users/thaib/OneDrive/Documents/Office of Sustainability/Morris Fleet Fuel/Ethanol Billing 2023.xlsx")
file3_sheets <- read_all_sheets("C:/Users/thaib/OneDrive/Documents/Office of Sustainability/Morris Fleet Fuel/Ethanol Billing 2024.xlsx")

##standardize all column data types
standardize_types <- function(df_list) {
  df_list <- lapply(df_list, function(df) {
    df %>% mutate(across(everything(), as.character))
  })
  return(df_list)
}

file1_sheets <- standardize_types(file1_sheets)
file2_sheets <- standardize_types(file2_sheets)
file3_sheets <- standardize_types(file3_sheets)


# Combine all sheets into a single data frame
all_sheets <- c(file1_sheets, file2_sheets, file3_sheets)
combined_data <- bind_rows(all_sheets)


# Clean the data by removing rows with missing date data
combined_data <- combined_data %>%
  filter(!is.na(Date))

# Drop columns with any NA values 
combined_data <- combined_data %>% 
  select_if(~ !any(is.na(.)))

# Save the cleaned data to a new Excel file
write_xlsx(combined_data, "Ethanol Billing Combined.xlsx")
########################################################################


########################################################################

ethanol_billing <- read_excel("Ethanol Billing Combined.xlsx")
head(ethanol_billing)

inventory_list <- read_excel("Morris Compiled Inventory List.xlsx")
head(inventory_list)

if ("Department" %in% colnames(ethanol_billing)) { ethanol_billing <- ethanol_billing %>% select(-Department)}

ethanol_billing <- left_join(ethanol_billing, inventory_list %>% 
                               select(`Veh#`, `Dept- from Morris`), by = "Veh#") 
ethanol_billing <- ethanol_billing %>% rename(Department = `Dept- from Morris`)
write_xlsx(ethanol_billing, "Ethanol Billing Combined.xlsx")

##### reading excel files
#ethanol_billing <- read_excel("Ethanol Billing Combined.xlsx", col_types = c(rep("text", 13)))
#ethanol_billing <- ethanol_billing %>% mutate(Dpt = ifelse(is.na(Dpt), "None", Dpt))
ethanol_billing <- read_excel("Ethanol Billing Combined.xlsx")
inventory_list <- read_excel("Morris Compiled Inventory List.xlsx")
grounds_inventory <- read_excel("Grounds Equipment Inventory.xlsx", col_types = c(rep("text")))


write_xlsx(ethanol_billing, "Ethanol Billing Combined.xlsx")


# Updated function to prepend '0' to 5-digit Veh# values only if Type is empty
#add_leading_zero <- function(veh, type) {
# if (is.na(type) & nchar(veh) == 5) {
#    return(paste0("0", veh))
#  } else {
#    return(veh)
#  }
#}


# Apply the function to the Veh# column based on Type column
#ethanol_billing <- ethanol_billing %>%
  #mutate(`Veh#` = mapply(add_leading_zero, `Veh#`, Type))

# Fill in the missing Type column values
ethanol_billing <- ethanol_billing %>%
  mutate(Type = ifelse(is.na(Type) & `Veh#` %in% inventory_list$`Veh#`, 'On Road', Type))

##get number of empty Type rows
empty_type_count <- ethanol_billing %>% filter(is.na(Type) | Type == "") %>% nrow()

##get unique Veh# with empty Type rows
unique_empty_type_veh <- ethanol_billing %>% filter(is.na(Type) | Type == "") %>% select(`Veh#`) %>% distinct()

# Fill the Type column with 'Other' for rows with missing Type
ethanol_billing <- ethanol_billing %>%
  mutate(Type = ifelse(is.na(Type) | Type == "", "Other", Type))


##fill in department based on dpt colunm from transaction detail report
ethanol_billing <- ethanol_billing %>% 
  mutate(Department = case_when(
    is.na(Department) & Dpt == "UMMFLEET" ~ "Rental Fleet",
    is.na(Department) & Dpt %in% c("Police", "UMMPARK") ~ "Public Safety",
    is.na(Department) & Dpt %in% c("FMCNST", "UMMFM") ~ "Facilities Management",
    TRUE ~ Department
  ))

##fill in department based on usage column
ethanol_billing <- ethanol_billing %>% 
  mutate(Department = case_when(
    is.na(Department) & Type %in% c('On Road', 'Other') & tolower(Usage) == 'fleet' ~ 'Rental Fleet',
    is.na(Department) & tolower(Usage) == 'public safety' ~ 'Public Safety',
    is.na(Department) & Type %in% c('On Road', 'Other') & !tolower(Usage) %in% c('fleet', 'public safety') ~ 'Facilities Management',
    TRUE ~ Department
  ))

ethanol_billing <- ethanol_billing %>% 
  mutate(Department = case_when(
    is.na(Department) & Type %in% c('Off Road') & tolower(Usage) == 'fleet' ~ 'Rental Fleet',
    is.na(Department) & Type %in% c('Off Road') & tolower(Usage) == 'orl' ~ 'Office of Res Life',
    is.na(Department) & Type %in% c('Off Road') & tolower(Usage) == 'athletics' ~ 'Athletics',
    is.na(Department) & Type %in% c('Off Road') & tolower(Usage) == 'public safety' ~ 'Public Safety',
    is.na(Department) & Type %in% c('Off Road') ~ 'Facilities Management',
    TRUE ~ Department
  ))

##change any 'carp' to Carp/Paint
ethanol_billing <- ethanol_billing %>%
  mutate(Usage = ifelse(grepl("carp", Usage, ignore.case = TRUE), "Carp/Paint", Usage))

##get unique Usage values based on Department
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



# Add the 'Duty' column to ethanol_billing by matching 'Veh#'
ethanol_billing <- ethanol_billing %>%
  left_join(inventory_list %>% select(`Veh#`, Duty), by = "Veh#")

# Add the 'Model Year' column to ethanol_billing by matching 'Veh#' and getting the 'Year' column from inventory_list
ethanol_billing <- ethanol_billing %>%
  left_join(inventory_list %>% select(`Veh#`, Year) %>% rename(`Model Year` = Year), by = "Veh#")


ethanol_billing <- ethanol_billing %>% left_join(inventory_list %>% select(`Veh#`, Fuel_Efficiency), by = "Veh#")

## convert Gallons and Fuel_Efficiency columns to numeric
ethanol_billing <- ethanol_billing %>%
  mutate(Gallons = as.numeric(Gallons),
         Fuel_Efficiency = as.numeric(Fuel_Efficiency))

## create the Mileage column
ethanol_billing <- ethanol_billing %>%
  mutate(Mileage = Gallons * Fuel_Efficiency)

# Convert Date to Date format and calculate FY as a two-digit year
ethanol_billing <- ethanol_billing %>%
  mutate(Date = as.Date(Date, format = "%Y-%m-%d"),
         FY = ifelse(month(Date) >= 7, year(Date) + 1, year(Date)),
         FY = substr(as.character(FY), 3, 4)) # Extract last two digits of the year


ethanol_billing <- ethanol_billing %>% mutate(FY = ifelse(is.na(Date), 23, FY))

ethanol_summary <- ethanol_billing %>%
  group_by(FY) %>%
  summarise(Total_Gallons = sum(Gallons, na.rm = TRUE))

print(ethanol_summary)


## display the results
head(ethanol_billing)

write_xlsx(ethanol_billing, "Ethanol Billing Combined.xlsx")
