-- 05_export_results.sql
-- Writes the result tables to output/ (used by src/plot_control_charts.py).

\copy (SELECT furnace_id, frit_code, n_baseline, ROUND(center_line, 3) AS center_line, ROUND(sigma, 3) AS sigma, ROUND(lcl_individual, 3) AS lcl_individual, ROUND(ucl_individual, 3) AS ucl_individual, ROUND(lcl_mean5, 3) AS lcl_mean5, ROUND(ucl_mean5, 3) AS ucl_mean5 FROM spc_baseline ORDER BY furnace_id) TO 'output/control_limits.csv' WITH (FORMAT csv, HEADER true)

\copy (SELECT furnace_id, batch_id, batch_seq, produced_at, sio2_pct, ROUND(mean_5, 3) AS mean_5, ROUND(center_line, 3) AS center_line, ROUND(lcl_individual, 3) AS lcl_individual, ROUND(ucl_individual, 3) AS ucl_individual, ROUND(lcl_mean5, 3) AS lcl_mean5, ROUND(ucl_mean5, 3) AS ucl_mean5, is_baseline, point_alert, mean_alert, alert_type FROM spc_series ORDER BY furnace_id, batch_seq) TO 'output/spc_series.csv' WITH (FORMAT csv, HEADER true)

\copy (SELECT furnace_id, batch_id, batch_seq, produced_at, sio2_pct, ROUND(mean_5, 3) AS mean_5, alert_type FROM spc_monitoring WHERE alert_type IS NOT NULL ORDER BY furnace_id, batch_seq) TO 'output/alerts.csv' WITH (FORMAT csv, HEADER true)
