-- 04_alert_summary.sql
-- One row per furnace: how many alarms did each rule raise and when did the first one occur?

SELECT furnace_id,
       COUNT(*)                                          AS monitored_batches,
       COUNT(*) FILTER (WHERE point_alert)               AS point_alerts,
       COUNT(*) FILTER (WHERE mean_alert)                AS mean5_alerts,
       MIN(batch_seq) FILTER (WHERE mean_alert)          AS first_mean5_alert_seq,
       MIN(batch_seq) FILTER (WHERE point_alert)         AS first_point_alert_seq,
       MIN(produced_at) FILTER (WHERE alert_type IS NOT NULL)::date AS first_alert_day,
       ROUND(100.0 * COUNT(*) FILTER (WHERE alert_type IS NOT NULL) / COUNT(*), 1) AS pct_batches_flagged
FROM   spc_monitoring
GROUP  BY furnace_id
ORDER  BY furnace_id;
