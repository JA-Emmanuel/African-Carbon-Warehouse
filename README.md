# African Carbon Intensity Data Warehouse

An SQL data warehouse tracking GHG emissions across 52 African 
economies (1970–2024), powering research and articles published 
at [Green Ledger Africa](https://substack.com/@greenledgerafrica).

---

## What This Project Does

Builds an end-to-end ETL pipeline that extracts raw emissions 
data from EDGAR, transforms it using Python, and loads it into 
a structured MySQL database for analytical querying.

---

## Database Schema

| Table | Primary Key | Rows | Description |
|---|---|---|---|
| dim_time | year | 55 | Year flags — decade, SDG period, Paris Agreement era |
| gas | gas_code | 3 | CO2, CH4, N2O lookup table |
| greenhouse_gas_emissions | country_code + year + Carbon_intensity (emissions_per_GDP) + Carbon_per_capita| 2,860 | Country-level emission metrics |
| sectoral_emissions | country_code + year + sector + gas | 58,520 | Sector-level breakdown |

---

## Repository Contents

| File | Description |
|---|---|
| `african_carbon_warehouse.md` | Full ETL pipeline documentation — every step explained |
| `01_schema.sql` | MySQL schema — all tables, keys and foreign key constraints |
| `03_core_queries.sql` | Analytical SQL queries — window functions, CTEs, LAG() |
| `articles/ARTICLES.md` | Published research articles powered by this warehouse |

---

## Tools and Technologies

- **Python** — pandas, SQLAlchemy, mysql-connector
- **MySQL** — relational database and analytical querying
- **Jupyter** — ETL documentation and pipeline execution
- **EDGAR** — primary emissions data source

---

## Data Source

Emissions data sourced from EDGAR (Emissions Database for 
Global Atmospheric Research):  
https://edgar.jrc.ec.europa.eu

The raw Excel file is not included in this repository. 
Download the African country emissions datasets directly 
from EDGAR to reproduce this project. Full instructions 
are in `african_carbon_warehouse.md`.

---

## External API & Data Dictionary

In addition to EDGAR emissions data, this project fetches live 
economic and development indicators from the **World Bank Open 
Data API** (https://api.worldbank.org/v2), enriching the warehouse 
with a second analytical dimension.

**API endpoint used: https://api.worldbank.org/v2/country/%7Biso3_codes%7D/indicator/%7Bindicator_code%7D**

---

**World Bank Indicators fetched:**

| Column | Indicator Code | Description |
|---|---|---|
| gdp_growth_pct | NY.GDP.MKTP.KD.ZG | GDP growth % year-on-year |
| gdp_usd_bn | NY.GDP.MKTP.KD | GDP in constant 2015 USD billions |
| population | SP.POP.TOTL | Total population |
| urban_pop_pct | SP.URB.TOTL.IN.ZS | Urban population as % of total |
| fdi_pct_gdp | BX.KLT.DINV.WD.GD.ZS | FDI net inflows as % of GDP |

These indicators are stored in a dedicated `world_bank_indicators` 
table with `country_code + year` as the composite primary key — 
the same grain as `greenhouse_gas_emissions` — enabling direct 
joins between emissions and economic data.

**Full data dictionary:**

| Table | Column | Type | Description |
|---|---|---|---|
| greenhouse_gas_emissions | country_code | CHAR(3) | ISO3 country code e.g. NGA |
| greenhouse_gas_emissions | country_name | VARCHAR(100) | Full country name |
| greenhouse_gas_emissions | year | SMALLINT | 1970–2024 |
| greenhouse_gas_emissions | fossil_co2_mt | FLOAT | Fossil CO₂ in megatonnes |
| greenhouse_gas_emissions | total_ghg_mt | FLOAT | All gases combined in megatonnes |
| greenhouse_gas_emissions | carbon_intensity | FLOAT | CO₂ per unit of GDP |
| greenhouse_gas_emissions | co2_per_capita | FLOAT | CO₂ per person per year |
| greenhouse_gas_emissions | co2_growth_pct | FLOAT | Year-on-year CO₂ growth % |
| sectoral_emissions | country_code | CHAR(3) | ISO3 country code |
| sectoral_emissions | country_name | VARCHAR(100) | Full country name |
| sectoral_emissions | year | SMALLINT | 1970–2024 |
| sectoral_emissions | sector_name | VARCHAR(60) | Agriculture, Transport etc |
| sectoral_emissions | gas_code | CHAR(4) | CO2, CH4 or N2O |
| sectoral_emissions | emissions_mt | FLOAT | Emissions in megatonnes |
| world_bank_indicators | country_code | CHAR(3) | ISO3 country code |
| world_bank_indicators | country_name | VARCHAR(100) | Full country name |
| world_bank_indicators | year | SMALLINT | 1970–2024 |
| world_bank_indicators | gdp_growth_pct | FLOAT | GDP growth % YoY |
| world_bank_indicators | gdp_usd_bn | FLOAT | GDP constant 2015 USD billions |
| world_bank_indicators | population | BIGINT | Total population |
| world_bank_indicators | urban_pop_pct | FLOAT | Urban population % |
| world_bank_indicators | fdi_pct_gdp | FLOAT | FDI net inflows % of GDP |
| dim_time | year | SMALLINT | 1970–2024 — primary key |
| dim_time | decade | VARCHAR(6) | 1970s, 1980s, 1990s... |
| dim_time | un_sdg_period | VARCHAR(10) | 'Pre-SDG' or 'SDG Era' (2015+) |
| dim_time | paris_agreement_era | TINYINT(1) | 0 = Pre-Paris, 1 = Post-Paris (2016+) |

---

## Key Analyses

The analytical queries in `03_core_queries.sql` cover:

- Top CO₂ emitters by year across 52 African economies
- Sector breakdown — dominant emission source per country
- Deep dive into Africa's Transport Sector
- Inspection of emissions from Africa's Top four emitting economies
- and others...

---

## Published Articles

This warehouse powers an ongoing series of expert articles 
on African emissions and climate policy.

→ [View all published articles](articles/articles.md)  
→ [Green Ledger Africa](https://substack.com/@greenledgerafrica)

---

## How to Reproduce This Project

1. Clone the repository
2. Download EDGAR African emissions data from https://edgar.jrc.ec.europa.eu
3. Install dependencies:

```
pip install pandas sqlalchemy mysql-connector-python openpyxl
```

4. Set up MySQL and update credentials in `african_carbon_warehouse.md`
5. Follow the ETL steps in `african_carbon_warehouse.md` section by section

---

## Author

**Emmanuel John-Adeyemi**  
Climate Data Analyst | Green Ledger Africa  
[LinkedIn](https://www.linkedin.com/in/emmanuel-john-adeyemi/)
[Substack](https://substack.com/@emmanuelja)
