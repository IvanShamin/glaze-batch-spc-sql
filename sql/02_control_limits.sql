-- 02_control_limits.sql
-- Phase I of SPC: estimate the centre line and process sigma from a baseline period.
--
-- Baseline = the first 40 batches of every furnace, assumed to be "in control".
-- The limits are NOT recomputed from the window being tested; otherwise a drifting
-- process would drag its own limits along and never raise an alarm.
--
--   individual limits :  centre +/- 3 * sigma
--   5-batch mean      :  centre +/- 3 * sigma / sqrt(5)

CREATE OR REPLACE VIEW spc_baseline AS
WITH numbered AS (
    SELECT furnace_id,
           frit_code,
           sio2_pct,
           ROW_NUMBER() OVER (PARTITION BY furnace_id ORDER BY produced_at) AS batch_seq
    FROM   batch_measurements
),
stats AS (
    SELECT furnace_id,
           frit_code,
           COUNT(*)               AS n_baseline,
           AVG(sio2_pct)          AS center_line,
           STDDEV_SAMP(sio2_pct)  AS sigma
    FROM   numbered
    WHERE  batch_seq <= 40
    GROUP  BY furnace_id, frit_code
)
SELECT furnace_id,
       frit_code,
       n_baseline,
       center_line,
       sigma,
       center_line + 3 * sigma                AS ucl_individual,
       center_line - 3 * sigma                AS lcl_individual,
       center_line + 3 * sigma / SQRT(5.0)      AS ucl_mean5,
       center_line - 3 * sigma / SQRT(5.0)      AS lcl_mean5
FROM   stats;

SELECT furnace_id,
       frit_code,
       n_baseline,
       ROUND(center_line, 2)    AS center_line,
       ROUND(sigma, 3)          AS sigma,
       ROUND(lcl_individual, 2) AS lcl_individual,
       ROUND(ucl_individual, 2) AS ucl_individual,
       ROUND(lcl_mean5, 2)      AS lcl_mean5,
       ROUND(ucl_mean5, 2)      AS ucl_mean5
FROM   spc_baseline
ORDER  BY furnace_id;
