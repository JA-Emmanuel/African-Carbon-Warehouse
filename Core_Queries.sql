-- =============================================================================
-- African Carbon Data Warehouse — Core Queries
-- Run against: african_emissions_2024.db (SQLite)
-- Compatible with: DB Browser for SQLite, DBeaver, any SQLite client
-- Query tables are exported and visualizations done in Excel
-- =============================================================================


-- =============================================================================
-- ARTICLE 1: UNEQUAL EMITTERS: WHY AFRICA'S CARBON DIOXIDE STORY IS REALLY A 
-- A STORY ABOUT FOUR COUNTRIES.
-- =============================================================================

-- =============================================================================
-- QUESTION 1 : Which countries are most responsible for Africa's emissions?
-- =============================================================================

USE african_emissions_2024;

SELECT 
      country,
      year,
      fossil_co2_mt,
      fossil_co2_mt
      / SUM(fossil_co2_mt) OVER () *100 AS share_of_emissions
FROM greenhouse_gas_emissions
WHERE year = 2024
ORDER BY share_of_emissions DESC;

-- ======================================================================================
-- QUESTION 2 : Top 4 countries emissions and share vs Rest of Africa's Emissions & Share
-- =======================================================================================

WITH emissions_grouped AS (
    SELECT
        year,
        fossil_co2_mt,
        CASE
            WHEN country IN ('South Africa', 'Egypt', 'Algeria', 'Nigeria')
                THEN 'Top 4'
            ELSE 'Rest of Africa'
        END AS emission_group
    FROM greenhouse_gas_emissions
    WHERE year = 2024
)

SELECT
    emission_group,
    SUM(fossil_co2_mt) AS total_emissions,
    SUM(fossil_co2_mt)
        / SUM(SUM(fossil_co2_mt)) OVER () * 100 AS share_of_emissions
FROM emissions_grouped
GROUP BY emission_group;

-- ======================================================================================
-- QUESTION 3 : What Sector is Driving Carbon Dioxide Emissions in Africa's Top 4?
-- =======================================================================================

CREATE OR REPLACE VIEW v_top_4_emission_profile AS
SELECT 
      country_code, 
      country,
      gas_code,
      year,
      sector_name,
      emissions_mt
FROM 
    sectoral_emissions 
WHERE 
     country IN ('South Africa','Egypt','Algeria','Nigeria')
     AND gas_code = 'co2';
     
SELECT 
      country,
      sector_name,
      gas_code,
      emissions_mt,
      emissions_mt
      /SUM(emissions_mt) OVER (partition by country) * 100 AS sector_share_of_emissions
FROM 
     v_top_4_emission_profile
WHERE 
     year = 2024
ORDER BY 
	country, 
    emissions_mt DESC;


-- =============================================================================
-- ARTICLE 2: 36 of 49, How Transport Became Africa’s Defining Emissions Story.
-- =============================================================================

-- =================================================================================
-- QUESTION 1 : What is the ranking of each sector in the country according to 
-- its Carbon Emissionn Contribution for the year 2024?
-- =================================================================================
SELECT 
      country, 
      year, 
      sector_name, 
      emissions_mt, 
      RANK () OVER (partition by country ORDER BY emissions_mt desc) year_rank
FROM 
    sectoral_emissions
WHERE 
    year = '2024' 
    AND gas_code = 'co2';
    
-- ======================================================================================
-- QUESTION 2 : Which countries have Transport ranked first?
-- =======================================================================================

SELECT 
      country, 
      year, 
      emissions_mt, 
      year_rank
FROM( 
  SELECT 
      country, 
      year, 
      sector_name, 
      emissions_mt, 
      RANK () OVER (partition by country ORDER BY emissions_mt desc) year_rank
FROM 
    sectoral_emissions
WHERE 
    year = '2024' 
    AND gas_code = 'co2') as ranking
    
WHERE 
    year_rank = 1 
    AND sector_name= 'Transport'
ORDER BY 
	emissions_mt DESC; 

-- ==================================================================================================
-- QUESTION 3 : For these 36 Countries, what is the Transport Sector's Percentage share of emissions?
-- ===================================================================================================

SELECT country,
       year,
       sector_name,
       sector_rank,
       share_of_emissions
FROM(
    SELECT
      country, 
      year, 
      sector_name, 
      emissions_mt, 
      gas_code,
      RANK () OVER (partition by country, year ORDER BY emissions_mt desc) sector_rank,
      sum(emissions_mt) over (partition by year, country) year_total_emissions,
      ROUND((emissions_mt/sum(emissions_mt) over (partition by year, country))* 100 , 2) Share_of_emissions
FROM 
    sectoral_emissions
WHERE 
    gas_code ='co2') pct_change_rank
WHERE 
    sector_rank = 1
    AND sector_name ='Transport'
    AND year='2024'
ORDER BY share_of_emissions DESC;

-- =============================================================================
-- ARTICLE 3: The Inverted Emitter: Nigeria's Sixty-Megatonne Transport Problem
-- =============================================================================

-- =============================================================================
-- Question 1 : Sectors and their Contributions to Africa's Carbon Emissions.
-- =============================================================================

SELECT 
    sector_name,
    gas_code,
    year,
    SUM(emissions_mt) AS total_emissions,
    ROUND(
        SUM(emissions_mt) * 100.0 / 
        SUM(SUM(emissions_mt)) OVER (),
        2
    ) AS share_pct
FROM sectoral_emissions
WHERE year = 2024
  AND gas_code = 'co2'
GROUP BY 
     sector_name, 
     gas_code, 
     year
ORDER BY total_emissions DESC;

-- ==========================================================================
-- Question 2 : How has the Transport Sector in Africa fared in relation to 
-- Carbon Emissions over the past decade?
-- ==========================================================================

WITH yearly_emissions AS (
    SELECT
        sector_name,
        year,
        gas_code,
        SUM(emissions_mt) AS total_emissions
    FROM sectoral_emissions
    WHERE gas_code = 'co2'
      AND sector_name = 'Transport'
    GROUP BY
        sector_name,
        year,
        gas_code
),

yearly_comparison AS (
    SELECT
        sector_name,
        year,
        gas_code,
        total_emissions,

        LAG(total_emissions) OVER (
            ORDER BY year
        ) AS prev_year_emissions,

        LEAD(total_emissions) OVER (
            ORDER BY year
        ) AS next_year_emissions

    FROM yearly_emissions
)

SELECT

    year,
    total_emissions,

    ROUND(
        (total_emissions - prev_year_emissions)
        / prev_year_emissions * 100,
        2
    ) AS pct_diff

FROM yearly_comparison
WHERE year > 1999
ORDER BY year;

-- =====================================================================================
-- Question 3 : Where Does Nigeria's Transport Sector Emissions Rank Amongst the 36/49 
-- Countries in Africa who have The Transport Sector as their Leading Emitting Sector?
-- =====================================================================================

SELECT
    country,
    year,
    sector_name,
    sector_rank,
    emissions_mt,
    share_of_emissions
FROM (
    SELECT
        country,
        year,
        sector_name,
        emissions_mt,
        gas_code,
        RANK() OVER (
            PARTITION BY country, year
            ORDER BY emissions_mt DESC
        ) AS sector_rank,
        SUM(emissions_mt) OVER (
            PARTITION BY country, year
        ) AS year_total_emissions,
        ROUND(
            emissions_mt
            / SUM(emissions_mt) OVER (
                PARTITION BY country, year
            ) * 100,
            2
        ) AS share_of_emissions
    FROM sectoral_emissions
    WHERE gas_code = 'co2'
) AS pct_change_rank
WHERE sector_rank = 1
  AND sector_name = 'Transport'
  AND year = 2024
ORDER BY emissions_mt DESC;

-- ==============================================================================================
-- Question 4 : How Much Does Each Sector in Nigeria Contribute to its Carbon Emissions in 2024?
-- ==============================================================================================

SELECT 
      country, 
      gas_code, 
      sector_name,
      emissions_mt,
      emissions_mt
      /SUM(emissions_mt) OVER (partition by country) *100 AS share_pct
FROM 
    sectoral_emissions
WHERE 
      country = 'Nigeria' 
      AND year = 2024
      AND gas_code = 'co2';

-- ===========================================================================
-- QUESTION 5 : How Does Nigeria’s Transport Sector Share 
-- Compare with Those of Africa’s Other Top Four Emitting Economies?
-- ===========================================================================

SELECT
    country,
    sector_name,
    year,
    gas_code,
    emissions_mt,
    sector_share_of_emissions
FROM (
    SELECT
        country,
        year,
        sector_name,
        gas_code,
        emissions_mt,
        ROUND(
            emissions_mt
            / SUM(emissions_mt) OVER (
                PARTITION BY country
            ) * 100,
            2
        ) AS sector_share_of_emissions
    FROM sectoral_emissions
    WHERE gas_code = 'co2'
      AND year = 2024
      AND country IN (
          'South Africa',
          'Egypt',
          'Nigeria',
          'Algeria'
      )
) AS emissions_share
WHERE sector_name = 'Transport'
ORDER BY sector_share_of_emissions DESC;

-- ===========================================================================
-- QUESTION 5 : How Does Nigeria’s Transport Sector Share 
-- Compare with The Other Sectors of Africa’s Other Top Four Emitting Economies?
-- ===========================================================================

SELECT
    country,
    sector_name,
    year,
    gas_code,
    emissions_mt,
    sector_share_of_emissions
FROM (
    SELECT
        country,
        year,
        sector_name,
        gas_code,
        emissions_mt,
        ROUND(
            emissions_mt
            / SUM(emissions_mt) OVER (
                PARTITION BY country
            ) * 100,
            2
        ) AS sector_share_of_emissions
    FROM sectoral_emissions
    WHERE gas_code = 'co2'
      AND year = 2024
      AND country IN (
          'South Africa',
          'Egypt',
          'Nigeria',
          'Algeria'
      )
) AS emissions_share
ORDER BY sector_share_of_emissions DESC;