-- =============================================================================
-- African Carbon Data Warehouse
-- MySQL Schema
-- Author: Emmanuel John-Adeyemi
-- Organisation: Green Ledger Africa
-- Data source: EDGAR (Emissions Database for Global Atmospheric Research)
-- =============================================================================
-- Tables:
--   1. dim_time                  — year dimension with policy era flags
--   2. gas                       — gas code lookup table
--   3. greenhouse_gas_emissions  — country-level emissions fact table
--   4. sectoral_emissions        — sector-level emissions fact table
-- =============================================================================


-- =============================================================================
-- TABLE 1: dim_time
-- Purpose: Stores analytical flags for each year so queries can filter
--          by climate policy era without hardcoding year ranges.
-- Primary key: year
-- =============================================================================

CREATE TABLE IF NOT EXISTS dim_time (
    year                SMALLINT     NOT NULL PRIMARY KEY,  -- 1970–2024
    decade              VARCHAR(6),                         -- '1970s', '1980s'...
    un_sdg_period       VARCHAR(10),                        -- 'Pre-SDG' | 'SDG Era'
    paris_agreement_era TINYINT(1)                          -- 0 = Pre-Paris | 1 = Post-Paris (2016+)
);


-- =============================================================================
-- TABLE 2: gas
-- Purpose: Maps short gas codes to full gas names for readable query output.
--          Referenced by sectoral_emissions via foreign key on gas_code.
-- Primary key: gas_code
-- =============================================================================

CREATE TABLE IF NOT EXISTS gas (
    gas_code CHAR(4)     NOT NULL PRIMARY KEY,  -- 'CO2' | 'CH4' | 'N2O'
    gas_name VARCHAR(50) NOT NULL               -- 'Carbon Dioxide' | 'Methane' | 'Nitrous Oxide'
);

-- Pre-populate gas lookup values
INSERT IGNORE INTO gas (gas_code, gas_name) VALUES
    ('CO2', 'Carbon Dioxide'),
    ('CH4', 'Methane'),
    ('N2O', 'Nitrous Oxide');


-- =============================================================================
-- TABLE 3: greenhouse_gas_emissions
-- Purpose: Country-level emissions fact table.
--          One row per country per year — the primary analytical table
--          for tracking emission trends, carbon intensity and growth rates
--          across all 52 African economies from 1970 to 2024.
-- Primary key: country_code + year (composite)
-- =============================================================================

CREATE TABLE IF NOT EXISTS greenhouse_gas_emissions (
    country_code        CHAR(3)      NOT NULL,  -- ISO3 code e.g. NGA, ZAF, EGY
    country_name        VARCHAR(100) NOT NULL,  -- Full country name
    year                SMALLINT     NOT NULL,  -- 1970–2024

    -- Core emission measures
    fossil_co2_mt       FLOAT,                  -- Fossil CO₂ in megatonnes
    total_ghg_mt        FLOAT,                  -- All gases combined in megatonnes

    -- Intensity metrics
    carbon_intensity    FLOAT,                  -- CO₂ per unit of GDP (tCO₂/kUSD)
    co2_per_capita      FLOAT,                  -- CO₂ per person per year

    -- Growth metrics
    co2_growth_pct      FLOAT,                  -- Year-on-year CO₂ growth %

    -- Composite primary key: one row per country per year
    PRIMARY KEY (country_code, year)
);


-- =============================================================================
-- TABLE 4: sectoral_emissions
-- Purpose: Sector-level emissions fact table — the most granular table
--          in the warehouse. One row per country × year × sector × gas.
--          Covers 8 sectors and 3 gases across 52 countries (1970–2024).
-- Primary key: country_code + year + sector_name + gas_code (composite)
-- Foreign key: gas_code → gas(gas_code)
-- =============================================================================

CREATE TABLE IF NOT EXISTS sectoral_emissions (
    country_code CHAR(3)      NOT NULL,  -- ISO3 code e.g. NGA, ZAF, EGY
    country_name VARCHAR(100) NOT NULL,  -- Full country name
    year         SMALLINT     NOT NULL,  -- 1970–2024
    sector_name  VARCHAR(60)  NOT NULL,  -- Agriculture | Building | Fuel Exploitation |
                                         -- Industrial Combustion | Power Industry |
                                         -- Processes | Transport | Waste
    gas_code     CHAR(4)      NOT NULL,  -- CO2 | CH4 | N2O

    -- Core measure
    emissions_mt FLOAT,                  -- Emissions in megatonnes

    -- Composite primary key: one row per country × year × sector × gas
    PRIMARY KEY (country_code, year, sector_name, gas_code),

    -- Foreign key: gas_code must exist in the gas table
    FOREIGN KEY (gas_code) REFERENCES gas(gas_code)
);


-- =============================================================================
-- INDEXES
-- Added on commonly filtered columns to improve query performance
-- =============================================================================

CREATE INDEX idx_ghg_year
    ON greenhouse_gas_emissions(year);

CREATE INDEX idx_ghg_country
    ON greenhouse_gas_emissions(country_code);

CREATE INDEX idx_sectoral_year
    ON sectoral_emissions(year);

CREATE INDEX idx_sectoral_country
    ON sectoral_emissions(country_code);

CREATE INDEX  idx_sectoral_sector
    ON sectoral_emissions(sector_name);

CREATE INDEX idx_sectoral_gas
    ON sectoral_emissions(gas_code);


-- =============================================================================
-- END OF SCHEMA
-- =============================================================================
