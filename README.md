# UMN Morris Fleet Fuel Usage & EV Transition Analysis

## 📌 Project Overview
This was a project I lead during my time as a Sustainability Data Analyst Intern at the University of Minnesota.
The project analyzes **three years of fleet ethanol billing data (FY22–FY24)** from the University of Minnesota - Morris Campus to identify **opportunities for electrification**.  
I consolidated billing records, standardized vehicle information, and developed a **prioritization framework** to rank vehicles for EV replacement.  

**Tools:** Excel, R (dplyr, tidyr, lubridate, readxl, writexl), Tableau  
**Deliverables:** Clean dataset, Tableau dashboard, prioritization scorecard  

---

## 🎯 Problem Statement
UMN as a system is committed to **carbon neutrality by 2050**.  
The Morris fleet contributes significantly to campus emissions, but **no unified dataset** existed for decision-making.  
This project answers:  
- Which departments and vehicle types consume the most fuel?  
- How do usage patterns compare across model years?  
- Which vehicles are the **best EV replacement candidates**?  

---

## 🔄 Data Workflow
Raw data: ethanol billing records (FY22–FY24), vehicle inventory list, grounds equipment list.  

**Key Cleaning Steps:**
- Standardized **Vehicle_IDs** (fixed leading zeros, merged across systems).  
- Classified **On Road vs Off Road** based on ID structure.  
- Harmonized **department codes** using already available `Dpt` and `Usage` columns.  
- Added vehicle attributes: **Duty Type, Model Year, Fuel Efficiency**.  
- Created derived fields: **Mileage = Gallons × Fuel Efficiency**, **Fiscal Year (FY)**.  

📂 Clean dataset exported as:  
`/data/processed/Ethanol Billing Combined Clean.xlsx`  

Scripts:  
- [`01_cleaning.R`](scripts/01_cleaning.R)  
- [`02_prioritization.R`](scripts/02_prioritization.R)  

---

## 📊 Dashboard & Visuals
All visualizations built in **Tableau**. Packaged workbook:  
[`Morris Fleet Fuel Tableau Public Dashboard`](https://public.tableau.com/app/profile/thai.bui1819/viz/MorrisFleetFuel/Dashboard?publish=yes) 

### Key Insights:
1. **Fuel Usage by Department**
   ![](figures/dept_usage.png)  
   Facilities Management and Rental Fleet together consume ~85% of total gallons.  

2. **Duty Type**
   ![](figures/duty_type.png)  
   SUVs and Sedans has the highest fuel usage per vehicle → strong EV pilot candidates.  

3. **FM Sub-Departments**
   ![](figures/fm_subdept.png)  
   HVAC vehicles dominate Facilities’ fuel use.  

4. **Model Year**
   ![](figures/model_year.png)  
   Pre-2015 vehicles are inefficient; 2018–21 vehicles are heavily utilized.  

5. **Utilization vs Efficiency by Department**
   ![](figures/scatter_usage_efficiency.png)  
   Facilities Management's vehicles has the highest fuel usage as a fleet as well as per vehicle

6. **Top Fuel-Consuming Vehicles**
   ![](figures/treemap_topvehicles.png)  
   Top 10 Vehicles in Fuel Usage identified on a treemap and categorized by Department  

---

## 🧮 Prioritization Framework
I created a composite score to rank vehicles for EV replacement:  
Priority Score = (0.30 * Age) + (0.25 * FuelUse) + (0.2 * Utilization) + (0.2 * EVFit) + (0.05 * Winter Suitability)
- **FuelUse**: share of total gallons (0–100).  
- **Utilization**: miles/year (estimated).  
- **Age**: years since model year (the older the vehicle, the higher the score)  
- **EVFit**: availiblity of EV products by duty type (e.g., sedans = high, medium trucks = low).  
- **Winter Suitability**: cold-weather reliability proxy.

📂 Outputs:  
- [`Top10_Priority.xlsx`](output/Top10_Priority.xlsx) — top 15 vehicles with recommended action.  
- [`Unit Summary.xlsx`](output/Dept_Priority.xlsx) — the entire list of vehicles and their Prioritation Score 

## ✅ Recommendations
- **Departments**: Focus electrification pilots in **Facilities Management** and **Rental Fleet**.  
- **Vehicle Types**: Start with **SUVs, Sedans, and Cargo Vans**.  
- **Top 10 Vehicles**: Start looking at opportunities within this list.
- Delay electrification of **Medium Trucks** until commercial EV options improve.

## ⚠️ Limitations
- Fuel billing records were collected across multiple sources without a standardized process, resulting in inconsistent IDs and department codes.
- There were a considerable number of null values in certain niche fields (e.g., usage notes, sub-department tags), requiring assumptions and business rules to fill gaps.
- Mileage estimated from fuel efficiency × gallons (no odometer data).  
- Charger proximity not yet included.  
- Winter suitability values based on secondary research (AAA 2019, DOE INL 2019).  
- Raw billing data not uploaded due to privacy.  

---

👤 **Author**: Thai Bui  
📧 [LinkedIn](https://www.linkedin.com/in/thai-hoang-bui) 
