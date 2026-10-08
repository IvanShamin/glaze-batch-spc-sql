-- 01_schema_and_load.sql
-- Creates the batch table and loads the synthetic frit batch analyses.
-- Run from the project root (the CSV path below is relative to it).

SET client_min_messages = warning;   -- silence "does not exist, skipping" notices on a fresh database

DROP VIEW  IF EXISTS spc_monitoring;
DROP VIEW  IF EXISTS spc_series;
DROP VIEW  IF EXISTS spc_baseline;
DROP TABLE IF EXISTS batch_measurements;

CREATE TABLE batch_measurements (
    batch_id     text PRIMARY KEY,
    furnace_id   text          NOT NULL,
    frit_code    text          NOT NULL,   -- one frit campaign per furnace in this dataset
    produced_at  timestamp     NOT NULL,
    sio2_pct     numeric(5, 2) NOT NULL,   -- wt-%, XRF analysis of the batch sample
    al2o3_pct    numeric(5, 2) NOT NULL,
    zro2_pct     numeric(5, 2) NOT NULL,
    loi_pct      numeric(5, 2) NOT NULL    -- loss on ignition
);

\copy batch_measurements FROM 'data/frit_batches.csv' WITH (FORMAT csv, HEADER true)

-- sanity check: 4 furnaces x 125 batches
SELECT furnace_id,
       frit_code,
       COUNT(*)                 AS batches,
       MIN(produced_at)::date   AS first_day,
       MAX(produced_at)::date   AS last_day
FROM   batch_measurements
GROUP  BY furnace_id, frit_code
ORDER  BY furnace_id;
