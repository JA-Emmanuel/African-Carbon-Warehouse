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

→ [View all published articles](articles/ARTICLES.md)  
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
