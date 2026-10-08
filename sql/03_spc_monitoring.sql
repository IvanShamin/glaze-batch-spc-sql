-- 03_spc_monitoring.sql
-- Phase II: monitor every batch after the baseline against the frozen limits.
--
-- Two rules are evaluated per batch with window functions (one window per furnace):
--   point_alert : the batch value itself is outside centre +/- 3 sigma
--   mean_alert  : the mean of the last 5 batches (including the current one) is outside
--                 centre +/- 3 sigma / sqrt(5)  -> sensitive to small, persistent shifts
--
-- Nested structure:  windowed (window functions) -> joined (attach limits) -> flagged (apply rules)
-- spc_series    : all batches (baseline + monitoring), used for charts
-- spc_monitoring: monitoring phase only, used for alert reporting

CREATE OR REPLACE VIEW spc_series AS
WITH windowed AS (
    SELECT m.batch_id,
           m.furnace_id,
           m.produced_at,
           m.sio2_pct,
           ROW_NUMBER() OVER w                                               AS batch_seq,
           AVG(m.sio2_pct) OVER (w ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS mean_5,
           COUNT(*)        OVER (w ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS n_in_window
    FROM   batch_measurements AS m
    WINDOW w AS (PARTITION BY m.furnace_id ORDER BY m.produced_at, m.batch_id)
),
joined AS (
    SELECT w.*,
           b.center_line,
           b.lcl_individual, b.ucl_individual,
           b.lcl_mean5,      b.ucl_mean5,
           (w.batch_seq <= b.n_baseline) AS is_baseline
    FROM   windowed AS w
    JOIN   spc_baseline AS b USING (furnace_id)
),
flagged AS (
    SELECT j.*,
           (NOT j.is_baseline
            AND j.sio2_pct NOT BETWEEN j.lcl_individual AND j.ucl_individual)      AS point_alert,
           (NOT j.is_baseline
            AND j.n_in_window = 5
            AND j.mean_5 NOT BETWEEN j.lcl_mean5 AND j.ucl_mean5)                  AS mean_alert
    FROM   joined AS j
)
SELECT f.*,
       CASE WHEN point_alert AND mean_alert THEN 'POINT+MEAN5'
            WHEN point_alert                THEN 'POINT'
            WHEN mean_alert                 THEN 'MEAN5'
       END AS alert_type
FROM   flagged AS f;

CREATE OR REPLACE VIEW spc_monitoring AS
SELECT * FROM spc_series WHERE NOT is_baseline;

-- Every flagged batch, in chronological order per furnace
SELECT furnace_id,
       batch_id,
       batch_seq,
       produced_at::date          AS day,
       sio2_pct,
       ROUND(mean_5, 2)           AS mean_5,
       alert_type
FROM   spc_monitoring
WHERE  alert_type IS NOT NULL
ORDER  BY furnace_id, batch_seq;
