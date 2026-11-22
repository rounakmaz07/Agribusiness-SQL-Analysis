-- Agribusiness Performance Analysis (SQLite-compatible)
-- Dataset is synthetic and intended for learning/demo purposes.
-- Units: area=acres; production=tonnes; costs/revenue=INR; selling_price_per_kg=INR/kg.
PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS production;
DROP TABLE IF EXISTS farms;

CREATE TABLE farms (
    farm_id TEXT PRIMARY KEY,
    farm_name TEXT NOT NULL
);

CREATE TABLE production (
    record_id INTEGER PRIMARY KEY,
    farm_id TEXT NOT NULL REFERENCES farms(farm_id),
    crop TEXT NOT NULL,
    season TEXT NOT NULL,
    area_acres REAL NOT NULL CHECK(area_acres > 0),
    production_tonnes REAL NOT NULL CHECK(production_tonnes >= 0),
    seed_cost REAL NOT NULL DEFAULT 0,
    fertilizer_cost REAL NOT NULL DEFAULT 0,
    labor_cost REAL NOT NULL DEFAULT 0,
    irrigation_cost REAL NOT NULL DEFAULT 0,
    other_cost REAL NOT NULL DEFAULT 0,
    selling_price_per_kg REAL NOT NULL CHECK(selling_price_per_kg >= 0)
);

-- Populate farms and production using the INSERT statements in the companion
-- CSV/data appendix in the report, or load the supplied CSV into these tables.
-- Example CSV import in SQLite CLI:
-- .mode csv
-- .import farms.csv farms
-- .import production.csv production

-- Q1. Data quality: detect incomplete or impossible records.
SELECT * FROM production
WHERE area_acres <= 0 OR production_tonnes < 0
   OR seed_cost < 0 OR fertilizer_cost < 0 OR labor_cost < 0
   OR irrigation_cost < 0 OR other_cost < 0;

-- Q2. Base KPI by crop: weighted yield, total cost, cost/kg, revenue, profit, margin.
WITH base AS (
  SELECT crop,
         SUM(area_acres) AS area_acres,
         SUM(production_tonnes) AS production_tonnes,
         SUM(seed_cost + fertilizer_cost + labor_cost + irrigation_cost + other_cost) AS total_cost,
         SUM(production_tonnes * 1000.0 * selling_price_per_kg) AS revenue
  FROM production
  GROUP BY crop
)
SELECT crop, area_acres, production_tonnes,
       production_tonnes / NULLIF(area_acres,0) AS yield_tonnes_per_acre,
       total_cost,
       total_cost / NULLIF(production_tonnes * 1000.0,0) AS cost_per_kg,
       revenue, revenue - total_cost AS profit,
       (revenue - total_cost) / NULLIF(revenue,0) AS profit_margin
FROM base
ORDER BY profit DESC;

-- Q3. Seasonal trend: weighted yield and cost per kg by season.
SELECT season,
       SUM(area_acres) AS area_acres,
       SUM(production_tonnes) AS production_tonnes,
       SUM(production_tonnes) / NULLIF(SUM(area_acres),0) AS yield_tonnes_per_acre,
       SUM(seed_cost + fertilizer_cost + labor_cost + irrigation_cost + other_cost) AS total_cost,
       SUM(seed_cost + fertilizer_cost + labor_cost + irrigation_cost + other_cost)
         / NULLIF(SUM(production_tonnes) * 1000.0,0) AS cost_per_kg
FROM production
GROUP BY season
ORDER BY season;

-- Q4. Farm-level efficiency: compare weighted yield and cost/kg.
SELECT f.farm_name, p.crop,
       SUM(p.production_tonnes) / NULLIF(SUM(p.area_acres),0) AS yield_tonnes_per_acre,
       SUM(p.seed_cost + p.fertilizer_cost + p.labor_cost + p.irrigation_cost + p.other_cost)
         / NULLIF(SUM(p.production_tonnes) * 1000.0,0) AS cost_per_kg
FROM production p
JOIN farms f ON f.farm_id = p.farm_id
GROUP BY f.farm_name, p.crop
ORDER BY p.crop, yield_tonnes_per_acre DESC;

-- Q5. Cost composition: identify the largest operating cost category.
SELECT 'Seed' AS cost_category, SUM(seed_cost) AS amount FROM production
UNION ALL SELECT 'Fertilizer', SUM(fertilizer_cost) FROM production
UNION ALL SELECT 'Labor', SUM(labor_cost) FROM production
UNION ALL SELECT 'Irrigation', SUM(irrigation_cost) FROM production
UNION ALL SELECT 'Other', SUM(other_cost) FROM production
ORDER BY amount DESC;

-- Q6. Profitability by crop and season.
SELECT crop, season,
       SUM(production_tonnes * 1000.0 * selling_price_per_kg) AS revenue,
       SUM(seed_cost + fertilizer_cost + labor_cost + irrigation_cost + other_cost) AS total_cost,
       SUM(production_tonnes * 1000.0 * selling_price_per_kg)
         - SUM(seed_cost + fertilizer_cost + labor_cost + irrigation_cost + other_cost) AS profit
FROM production
GROUP BY crop, season
ORDER BY profit DESC;

-- Q7. Rank crop-season combinations by yield (SQLite window function).
SELECT crop, season, yield_tonnes_per_acre,
       RANK() OVER (PARTITION BY crop ORDER BY yield_tonnes_per_acre DESC) AS yield_rank
FROM (
  SELECT crop, season,
         SUM(production_tonnes) / NULLIF(SUM(area_acres),0) AS yield_tonnes_per_acre
  FROM production
  GROUP BY crop, season
);

-- Q8. Overall business dashboard.
SELECT SUM(production_tonnes) / NULLIF(SUM(area_acres),0) AS overall_yield_tonnes_per_acre,
       SUM(seed_cost + fertilizer_cost + labor_cost + irrigation_cost + other_cost)
         / NULLIF(SUM(production_tonnes) * 1000.0,0) AS overall_cost_per_kg,
       SUM(production_tonnes * 1000.0 * selling_price_per_kg) AS revenue,
       SUM(production_tonnes * 1000.0 * selling_price_per_kg)
         - SUM(seed_cost + fertilizer_cost + labor_cost + irrigation_cost + other_cost) AS profit
FROM production;
