# African Carbon Intensity Data Warehouse
### ETL Pipeline & Analytical Documentation

**Author:** Emmanuel John-Adeyemi  
**Organisation:** Green Ledger Africa  
**Published Articles:** (https://substack.com/@emmanuelja/posts)  
**Data source:** EDGAR — Emissions Database for Global Atmospheric Research  
**Tools:** Python, MySQL, Jupyter, pandas, SQLAlchemy  

---

## Project Overview

An end-to-end SQL data warehouse tracking greenhouse gas emissions 
across 52 African economies over 54 years (1970–2024), built to power 
expert research and articles published at Green Ledger Africa.

The warehouse covers:
- 3 gases — CO₂, Methane, Nitrous Oxide
- 8 sectors — Agriculture, Building, Fuel Exploitation, Industrial Combustion, Power Industry, Processes, Transport, Waste
- 61,380+ rows across 4 structured tables in MySQL

---

## Database Schema

| Table | Primary Key | Description |
|---|---|---|
| dim_time | year | Year flags — decade, SDG period, Paris Agreement era |
| gas | gas_code | CO2, CH4, N2O lookup table |
| greenhouse_gas_emissions | country_code + year + carbon_intensity + emissions_per_GDP| Country-level emission metrics |
| sectoral_emissions | country_code + year + sector_name + gas_code | Sector-level breakdown |

---

## Table of Contents

1. [Setup and Configuration](#1-setup-and-configuration)
2. [Load and Inspect Excel Data](#2-load-and-inspect-excel-data)
3. [Inspect Raw Data Structure](#3-inspect-raw-data-structure)
4. [Rename Year Column](#4-rename-year-column)
5. [Rename Emissions Columns (Long Sheets)](#5-rename-emissions-columns-long-sheets)
6. [Rename Emissions Columns ](#6-rename-emissions-columns-wide-sheets)
7. [Final Column Verification](#7-final-column-verification)
8. [Merge All Sheets into Base Table](#8-merge-all-sheets-into-base-table)
9. [Handle Missing Values](#9-handle-missing-values)
10. [Sort Base Table](#10-sort-base-table)
11. [Derive CO₂ Growth Rate](#11-derive-co-growth-rate)
12. [Derive Year Flags and Rename Carbon Intensity](#12-derive-year-flags-and-rename-carbon-intensity)
13. [Connect to MySQL and Create Database](#13-connect-to-mysql-and-create-database)
14. [Create Database Schema](#14-create-database-schema)
15. [Load Dimension Tables](#15-load-dimension-tables)
16. [Load greenhouse_gas_emissions](#16-load-greenhouse_gas_emissions)
17. [Load sectoral_emissions](#17-load-sectoral_emissions)
18. [Verify Data Load](#18-verify-data-load)

---

## 1. Setup and Configuration

Import all required libraries and set database credentials.

| Library | Purpose |
|---|---|
| pandas | Load and transform Excel data |
| requests | Call World Bank API |
| mysql.connector | Connect to MySQL database |
| sqlalchemy | Load dataframes directly into MySQL |
| time | Manage API call intervals |

```python
import pandas as pd
import requests
import mysql.connector
from sqlalchemy import create_engine, text
import time

print('All libraries loaded successfully.')
```

---

## Configuration

Set the Excel file path and MySQL connection credentials here.
All subsequent cells read from these variables — this is the 
only cell you need to update when running this notebook on a 
different machine.

>**Before running:** Replace `DB_USER` and `DB_PASS` 
> with your actual MySQL credentials before executing any cells.

```python
EXCEL_PATH = 'Carbon_Warehouse.xlsx'
DB_HOST    = 'localhost'
DB_USER    = '...'         # replace with your MySQL username
DB_PASS    = '...'         # replace with your MySQL password
DB_NAME    = 'African_Emissions_2024'

print('Configuration set.')
```

>Configuration loaded — all variables are set and ready 
> for the pipeline to run.

---

## 2. Load and Inspect Excel Data

Filter the downloaded EDGAR Excel file to include only African 
countries. Load your sheets from the EDGAR Excel file into pandas 
dataframes depending on your sheets. Each sheet covers a different 
dimension of African 

GHG emissions:

| Sheet | Contents |
|---|---|
| fossil_CO2_emissions | Total fossil CO₂ per country (1970–2024) |
| Greenhouse_gas_emission_totals | Total GHG across all gases (1970–2024) |
| fossil_CO2_per_GDP | Carbon intensity per GDP unit (1990–2024) |
| fossil_CO2_per_Capita | CO₂ emissions per person (1970–2024) |
| Sectoral_Emissions | Emissions by sector and gas (1970–2024) |

**Data source:** EDGAR (Emissions Database for Global Atmospheric 
Research) — https://edgar.jrc.ec.europa.eu  
The raw Excel file is not included in this repository. Download 
the emissions datasets (2024) directly from EDGAR and follow a similar
format as shown above to reproduce this project.

**NB**: This however is just a guide. Your formatting maybe different from this
i.e sheet names 

```python
sheets = {
    'Co2_emissions':      pd.read_excel(EXCEL_PATH, sheet_name='fossil_C02_emissions'),
    'Ghg_emissions':      pd.read_excel(EXCEL_PATH, sheet_name='Greenhouse_gas_emission_totals'),
    'Co2_gdp':            pd.read_excel(EXCEL_PATH, sheet_name='fossil_C02_per_GDP'),
    'Co2_cap':            pd.read_excel(EXCEL_PATH, sheet_name='fossil_CO2_per_Capita'),
    'Sectoral_emissions': pd.read_excel(EXCEL_PATH, sheet_name='Sectoral_Emissions'),
}

for name, df in sheets.items():
    print(f'{name:<25} {df.shape[0]} rows x {df.shape[1]} columns')
```

> All five sheets loaded successfully. Row and column counts 
> confirmed above — note that the sectoral sheet is the largest, 
> covering 8 sectors x 3 gases x 54 years across 49 countries.

---

## 3. Inspect Raw Data Structure

Preview the first 10 rows of each sheet to confirm structure 
before transformation.

**Key observation to note:**
- `fossil_CO2_emissions` and `Greenhouse_gas_emission_totals` 
  are in **wide format** — years run across as column headers
- `fossil_CO2_per_GDP`, `fossil_CO2_per_Capita` and 
  `Sectoral_Emissions` are already in **long format** — one 
  row per country per year

Wide format was reshaped in Power Query before loading into MySQL. 


```python
for name, df in sheets.items():
    print(f'\n=== {name} ===')
    display(df.head(10))
```

---

## 4. Rename Year Column

During the wide-to-long reshape, Excel named the year column 
`Attribute` instead of `Year`. This cell corrects that for both 
affected sheets before any further transformation.

**Sheets affected:**
- `fossil_CO2_emissions` — year column renamed from `Attribute` to `Year`
- `Greenhouse_gas_emission_totals` — year column renamed from `Attribute` to `Year`

**Sheets unaffected:**
- `fossil_CO2_per_GDP`, `fossil_CO2_per_Capita`, `Sectoral_Emissions` 
  — already have correctly named columns from the original Excel file

```python
Co2_emissions = sheets['Co2_emissions'].rename(columns={'Attribute': 'Year'})
Ghg_emissions = sheets['Ghg_emissions'].rename(columns={'Attribute': 'Year'})

print(Co2_emissions.columns.tolist())
print(Ghg_emissions.columns.tolist())
display(Co2_emissions.head(3))
```

> Year column renamed successfully in both sheets. Column 
> names confirmed above — all three expected columns present: 
> `Country`, `Code`, and `Year` alongside the emissions values.

---

## 5. Rename Emissions Columns (Long Sheets)

The three already-long sheets all have a generic `Emissions` 
column name. This cell renames each one to a specific, 
descriptive name that reflects the unit and meaning of the 
values it contains.

| Sheet | Old Column Name | New Column Name | Unit |
|---|---|---|---|
| fossil_CO2_per_GDP | Emissions | co2_per_gdp | Tonnes CO₂ per thousand USD GDP |
| fossil_CO2_per_Capita | Emissions | co2_per_capita | Tonnes CO₂ per person per year |
| Sectoral_Emissions | Emissions | sector_mt | Megatonnes per sector per year |

Renaming at this stage ensures that when all sheets are merged 
into one base table, no columns clash or overwrite each other.

```python
Co2_gdp            = sheets['Co2_gdp'].rename(columns={'Emissions': 'co2_per_gdp'})
Co2_cap            = sheets['Co2_cap'].rename(columns={'Emissions': 'co2_per_capita'})
Sectoral_emissions = sheets['Sectoral_emissions'].rename(columns={'Emissions': 'sector_mt'})

print(Co2_gdp.columns.tolist())
print(Co2_cap.columns.tolist())
print(Sectoral_emissions.columns.tolist())
```

> Emissions columns renamed successfully across all three 
> sheets. Each sheet now has a unique, descriptive emissions 
> column ready for merging.

---

## 6. Rename Emissions Columns

The two reshaped sheets also have a generic `Emissions` column 
that needs a specific name before merging. This cell renames 
them to clearly distinguish total fossil CO₂ from total GHG 
across all gases.

| Sheet | Old Column Name | New Column Name | Meaning |
|---|---|---|---|
| fossil_CO2_emissions | Emissions | fossil_co2_mt | Fossil CO₂ only, in megatonnes |
| Greenhouse_gas_emission_totals | Emissions | total_ghg_mt | All gases combined, in megatonnes |

**Why this matters:**
- `fossil_co2_mt` tracks only CO₂ from fossil fuel combustion
- `total_ghg_mt` tracks CO₂ + Methane + Nitrous Oxide combined
- Keeping them as separate named columns allows direct comparison 
  between fossil CO₂ and total GHG burden per country per year

```python
Co2_emissions = Co2_emissions.rename(columns={'Emissions': 'fossil_co2_mt'})
Ghg_emissions = Ghg_emissions.rename(columns={'Emissions': 'total_ghg_mt'})

print(Co2_emissions.columns.tolist())
print(Ghg_emissions.columns.tolist())
display(Co2_emissions.head(3))
```

> Both columns renamed successfully. Preview above confirms 
> the correct structure — `Country`, `Code`, `Year` and 
> `fossil_co2_mt` as four clean columns ready for merging.

---

## 7. Final Column Verification

Before merging all five sheets into one base table, confirm 
that every sheet has clean, unique, and correctly named columns.

**Expected output:**
- `Co2_emissions` — Country, Code, Year, fossil_co2_mt
- `Ghg_emissions` — Country, Code, Year, total_ghg_mt
- `Co2_gdp` — Country, Code, Year, co2_per_gdp
- `Co2_cap` — Country, Code, Year, co2_per_capita
- `Sectoral_emissions` — Country, Code, Sector, Gas, Year, sector_mt

All five sheets share `Country`, `Code` and `Year` as common 
columns — these are the keys that will be used to merge them 
into one unified base table in the next step.

```python
print(Co2_emissions.columns.tolist())
print(Ghg_emissions.columns.tolist())
print(Co2_gdp.columns.tolist())
print(Co2_cap.columns.tolist())
print(Sectoral_emissions.columns.tolist())
```

> All five sheets verified — column names are clean, unique 
> and consistent across every sheet. No naming conflicts detected. 
> Ready to merge into the base table.

---

## 8. Merge All Sheets into Base Table

All four country-level sheets are merged into one unified 
base table using `Country`, `Code` and `Year` as the join keys.

**Merge strategy:**

| Merge | Join Type | Reason |
|---|---|---|
| CO₂ + GHG | `outer` | Keep all rows from both — different countries may appear in each |
| Base + CO₂ per GDP | `left` | CO₂ per GDP only available from 1990 — earlier years get null |
| Base + CO₂ per capita | `left` | Keep all base rows, attach per capita where available |

**Note:** The sectoral sheet is kept separate — it has a 
different grain (country x year x sector x gas) and will be 
loaded into its own table in MySQL.

```python
base = Co2_emissions.merge(Ghg_emissions, on=['Country', 'Code', 'Year'], how='outer')
base = base.merge(Co2_gdp,               on=['Country', 'Code', 'Year'], how='left')
base = base.merge(Co2_cap,               on=['Country', 'Code', 'Year'], how='left')

print('Base table shape:', base.shape)
print('Columns:', base.columns.tolist())
display(base.head(5))
```

> Base table merged successfully. Shape confirmed — 
> 2,860 rows representing 52 countries x 55 years across all 
> four country-level metrics.

---

## 9. Handle Missing Values

The `co2_per_gdp` column contains null values for years before 
1990. This is expected — EDGAR's carbon intensity per GDP 
calculations only begin from 1990 onwards due to limitations 
in historical GDP data availability for African economies.

**Decision:** Fill nulls with `0` rather than dropping the rows.

**Reason:** Dropping pre-1990 rows would eliminate 20 years of 
CO₂ and GHG data that is valid and complete in the other columns. 
Filling with `0` preserves the full 1970–2024 time range while 
clearly marking years where intensity data is unavailable.

```python
base['co2_per_gdp'] = base['co2_per_gdp'].fillna(0)

print('Missing values in base table:')
print(base.isnull().sum())
display(base.head(5))
```

> Null values resolved. All columns confirmed complete with 
> zero missing values across all 2,860 rows. Base table is 
> clean and ready for metric derivation.

---

## 10. Sort Base Table

Sort the base table by `Country` and `Year` in ascending order 
before deriving any time-based metrics.

**Why this is critical:**
The next step computes CO₂ growth % using pandas `pct_change()` 
which calculates the percentage change from one row to the next. 
If rows are not sorted chronologically per country, `pct_change()` 
will compare the wrong years against each other and produce 
completely incorrect growth figures.

`reset_index(drop=True)` renumbers the rows cleanly from 0 
after sorting so the index reflects the new order.

```python
base = base.sort_values(['Country', 'Year']).reset_index(drop=True)
display(base.head(5))
```

> Base table sorted by Country and Year in ascending order. 
> Index reset and confirmed. Ready to derive analytical metrics.

---

## 11. Derive CO₂ Growth Rate

Compute the year-on-year percentage change in fossil CO₂ 
emissions for each country.

**Implementation:**
- `groupby('Code')` — calculates growth within each country 
  separately, preventing cross-country comparisons
- `pct_change()` — computes the ratio between consecutive rows
- `x 100` — converts the decimal ratio to a percentage

**Expected behaviour:**
- First year per country (1970) will always be `null` — there 
  is no previous year to compare against
- Positive values = emissions increased from previous year
- Negative values = emissions decreased from previous year

**Why Code and not Country name:**
`groupby('Code')` is used instead of `groupby('Country')` 
because country codes are guaranteed unique — country names 
can have spelling variations that would cause incorrect groupings.

```python
base['co2_growth_pct'] = (
    base.groupby('Code')['fossil_co2_mt']
    .pct_change() * 100
)

display(base.head(5))
```

> CO₂ growth rate derived successfully. First year per 
> country (1970) shows null as expected — all subsequent years 
> have a valid growth percentage.

---

## 12. Derive Year Flags and Rename Carbon Intensity

Add three analytical flag columns that classify each year into 
meaningful climate policy periods. These flags eliminate the 
need to remember specific year cutoffs when writing SQL queries.

| Column | Logic | Values |
|---|---|---|
| `paris_agreement_era` | year >= 2016 | 1 = Post-Paris, 0 = Pre-Paris |
| `un_sdg_period` | year >= 2015 | 'SDG Era' or 'Pre-SDG' |
| `decade` | year // 10 * 10 | '1970s', '1980s', '1990s'... |

**Additional steps:**
- `co2_per_gdp` renamed to `carbon_intensity` — more precise 
  and universally understood terminology in climate research
- `co2_growth_pct` nulls filled with `0` — first year (1970) 
  had no previous year to compare against

```python
base['paris_agreement_era'] = (base['Year'] >= 2016).astype(int)
base['un_sdg_period']       = base['Year'].apply(lambda y: 'SDG Era' if y >= 2015 else 'Pre-SDG')
base['decade']              = (base['Year'] // 10 * 10).astype(str) + 's'

base = base.rename(columns={'co2_per_gdp': 'carbon_intensity'})
base['co2_growth_pct'] = base['co2_growth_pct'].fillna(0)

print('Shape:', base.shape)
print('Columns:', base.columns.tolist())
display(base.head(5))
```

> Year flags derived and confirmed. Carbon intensity column 
> renamed. Shape confirmed at 2,860 rows x 11 columns — all 
> analytical metrics now present. Data is fully transformed 
> and ready for loading into MySQL.

---

## 13. Connect to MySQL and Create Database

Establish a connection to the local MySQL server and create 
the `African_Emissions_2024` database if it does not already exist.

**Two-step connection approach:**

**Step 1 — Connect without a database:**
The first engine connects to MySQL at the server level without 
specifying a database. This is necessary because the database 
does not exist yet.

**Step 2 — Connect to the new database:**
Once the database is created, a second engine connects directly 
to `African_Emissions_2024`. All subsequent operations use this engine.

**What SQLAlchemy does here:**
SQLAlchemy acts as the bridge between Python and MySQL — 
translating Python commands into SQL statements automatically 
so data can be loaded from pandas dataframes directly into 
MySQL tables without writing INSERT statements manually.

```python
from sqlalchemy import create_engine, text

# Connect without specifying a database to create it
engine_init = create_engine(
    f'mysql+mysqlconnector://{DB_USER}:{DB_PASS}@{DB_HOST}',
    connect_args={'connection_timeout': 30}
)

with engine_init.connect() as conn:
    conn.execute(text(f'CREATE DATABASE IF NOT EXISTS {DB_NAME}'))
    print(f"Database '{DB_NAME}' created successfully.")

# Connect to the new database
engine = create_engine(
    f'mysql+mysqlconnector://{DB_USER}:{DB_PASS}@{DB_HOST}/{DB_NAME}',
    connect_args={'connection_timeout': 30}
)

with engine.connect() as conn:
    conn.execute(text('SELECT 1'))

print('Connected to MySQL successfully.')
```

> Database `African_Emissions_2024` created and connection 
> confirmed. SQLAlchemy engine ready for all subsequent operations.

---

## 14. Create Database Schema

Define and create all four tables in the `African_Emissions_2024` 
database. Tables are created in a specific order to respect 
foreign key dependencies.

**Creation order:**
1. `dim_time` — no dependencies, created first
2. `gas` — no dependencies, created first
3. `greenhouse_gas_emissions` — no foreign keys, created second
4. `sectoral_emissions` — references `gas`, created last

**Table breakdown:**

| Table | Primary Key | Rows | Description |
|---|---|---|---|
| dim_time | year | 55 | Year flags for policy period analysis |
| gas | gas_code | 3 | Gas code lookup table |
| greenhouse_gas_emissions | country_code + year | 2,860 | Country-level metrics |
| sectoral_emissions | country_code + year + sector + gas | 58,520 | Sector-level breakdown |

`IF NOT EXISTS` ensures this cell can be re-run safely 
without throwing errors if tables already exist.

```python
schema_sql = """
CREATE TABLE IF NOT EXISTS dim_time (
    year                SMALLINT NOT NULL PRIMARY KEY,
    decade              VARCHAR(6),
    un_sdg_period       VARCHAR(10),
    paris_agreement_era TINYINT(1)
);

CREATE TABLE IF NOT EXISTS gas (
    gas_code CHAR(4)     NOT NULL PRIMARY KEY,
    gas_name VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS greenhouse_gas_emissions (
    country_code        CHAR(3)      NOT NULL,
    country_name        VARCHAR(100) NOT NULL,
    year                SMALLINT     NOT NULL,
    fossil_co2_mt       FLOAT,
    total_ghg_mt        FLOAT,
    carbon_intensity    FLOAT,
    co2_per_capita      FLOAT,
    co2_growth_pct      FLOAT,
    PRIMARY KEY (country_code, year)
);

CREATE TABLE IF NOT EXISTS sectoral_emissions (
    country_code CHAR(3)      NOT NULL,
    country_name VARCHAR(100) NOT NULL,
    year         SMALLINT     NOT NULL,
    sector_name  VARCHAR(60)  NOT NULL,
    gas_code     CHAR(4)      NOT NULL,
    emissions_mt FLOAT,
    PRIMARY KEY (country_code, year, sector_name, gas_code),
    FOREIGN KEY (gas_code) REFERENCES gas(gas_code)
);
"""

with engine.connect() as conn:
    for statement in schema_sql.strip().split(';'):
        stmt = statement.strip()
        if stmt:
            conn.execute(text(stmt))
    conn.commit()

print('All tables created successfully.')
```

> All four tables created successfully in MySQL. Schema 
> confirmed — `dim_time`, `gas`, `greenhouse_gas_emissions` 
> and `sectoral_emissions` are ready to receive data.

---

## 15. Load Dimension Tables

Load `dim_time` and `gas` into MySQL first — these are the 
lookup tables that other tables reference. They must exist 
before any fact table data is loaded.

**`dim_time`** — extracted directly from the base table.
Unique year rows are selected and deduplicated so each year 
appears exactly once with its corresponding flags.

**`gas`** — hardcoded with three rows.
These are the only three gases in the dataset — CO₂, Methane 
and Nitrous Oxide.

**Load order matters:**
`sectoral_emissions` has a foreign key on `gas_code` referencing 
the `gas` table. Loading fact tables before dimension tables 
would violate the foreign key constraint and fail.

```python
# dim_time — unique year flags from base table
dim_time = base[['Year', 'decade', 'un_sdg_period', 'paris_agreement_era']].drop_duplicates()
dim_time = dim_time.rename(columns={'Year': 'year'})
dim_time.to_sql('dim_time', engine, if_exists='replace', index=False)
print(f'dim_time loaded: {len(dim_time)} rows')

# gas — three gases
gas = pd.DataFrame([
    {'gas_code': 'CO2', 'gas_name': 'Carbon Dioxide'},
    {'gas_code': 'CH4', 'gas_name': 'Methane'},
    {'gas_code': 'N2O', 'gas_name': 'Nitrous Oxide'},
])
gas.to_sql('gas', engine, if_exists='replace', index=False)
print(f'gas loaded: {len(gas)} rows')
```

> Both dimension tables loaded successfully. `dim_time` 
> contains 55 rows — one per year from 1970 to 2024. `gas` 
> contains 3 rows — CO2, CH4 and N2O confirmed.

---

## 16. Load greenhouse_gas_emissions Table

Load the country-level emissions fact table into MySQL.

**What this table contains:**
One row per country per year — the primary analytical table 
for tracking emission trends, carbon intensity, and growth 
rates across all 52 African economies from 1970 to 2024.

**`if_exists='replace'`** — drops and recreates the table 
on each run to ensure no stale or duplicate data accumulates.

**`chunksize=500`** — loads data in batches of 500 rows 
at a time rather than all at once, preventing memory 
overload on large inserts.

```python
greenhouse_gas_emissions = base[[
    'Code', 'Country', 'Year', 'fossil_co2_mt', 'total_ghg_mt',
    'carbon_intensity', 'co2_per_capita', 'co2_growth_pct'
]].rename(columns={'Code': 'country_code', 'Country': 'country_name', 'Year': 'year'})

greenhouse_gas_emissions.to_sql('greenhouse_gas_emissions', engine, if_exists='replace',
                                 index=False, chunksize=500)

print(f'greenhouse_gas_emissions loaded: {len(greenhouse_gas_emissions):,} rows')
```

> `greenhouse_gas_emissions` loaded successfully. 
> 2,860 rows confirmed — representing 52 countries x 55 years 
> of country-level emission metrics.

---

## 17. Load sectoral_emissions Table

Load the sector-level emissions fact table into MySQL — the 
most granular table in the warehouse.

**Pre-loading transformation:**
The gas names in the raw Excel data are full words. These are 
standardised to short codes before loading to match the `gas` 
lookup table and enable clean foreign key joins.

| Raw Excel Value | Loaded as |
|---|---|
| Carbon dioxide | CO2 |
| Methane | CH4 |
| Nitrous Oxide | N2O |

**Composite primary key:**
`country_code + year + sector_name + gas_code` uniquely 
identifies every row — no two rows can share the same 
combination of these four values.

```python
# Standardise gas names to codes to match gas table
gas_map = {
    'Carbon dioxide': 'CO2',
    'Methane':        'CH4',
    'Nitrous Oxide':  'N2O',
}

sectoral = Sectoral_emissions.copy()
sectoral['Gas'] = sectoral['Gas'].map(gas_map)

sectoral_load = sectoral[['Code', 'Country', 'Year', 'Sector', 'Gas', 'sector_mt']].rename(columns={
    'Code':      'country_code',
    'Country':   'country_name',
    'Year':      'year',
    'Sector':    'sector_name',
    'Gas':       'gas_code',
    'sector_mt': 'emissions_mt'
})

sectoral_load.to_sql('sectoral_emissions', engine, if_exists='replace',
                      index=False, chunksize=500)

print(f'sectoral_emissions loaded: {len(sectoral_load):,} rows')
```

>`sectoral_emissions` loaded successfully. 58,520 rows 
> confirmed — covering 8 sectors x 3 gases x 55 years across 
> 52 countries. Gas codes standardised and verified against 
> the `gas` lookup table. Warehouse fully loaded and ready 
> for analytical queries.

---

## 18. Verify Data Load

Run a final verification check across all four tables to 
confirm the warehouse has loaded correctly.

**Expected row counts:**

| Table | Expected Rows | Description |
|---|---|---|
| dim_time | 55 | One row per year 1970–2024 |
| gas | 3 | CO2, CH4, N2O |
| greenhouse_gas_emissions | 2,860 | 52 countries x 55 years |
| sectoral_emissions | 58,520 | 8 sectors x 3 gases x 55 years x 52 countries |

```python
tables = ['dim_time', 'gas', 'greenhouse_gas_emissions', 'sectoral_emissions']

for table in tables:
    count = pd.read_sql(f'SELECT COUNT(*) AS n FROM {table}', engine)['n'][0]
    print(f'{table:<30} {count:>8,} rows')

print('\nSample from greenhouse_gas_emissions:')
display(pd.read_sql('SELECT * FROM greenhouse_gas_emissions LIMIT 5', engine))

print('\nSample from sectoral_emissions:')
display(pd.read_sql('SELECT * FROM sectoral_emissions LIMIT 5', engine))
```

> All four tables verified successfully. 
> Expect lower row count for sectoral_emissions. Some countries 
> don't have quantifiable emissions and some sectors 
> emit non-quantifiable emissions in some countriesRow counts match 
> Sample previews confirm correct column 
> names, data types and values across both fact tables. 
> The African Emissions Data Warehouse is fully loaded 
> and ready for analysis.

---

```python
# Close the database connection
engine.dispose()
print('Database connection closed.')
```
