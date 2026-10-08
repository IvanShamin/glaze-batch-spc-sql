#!/usr/bin/env bash
# Runs the whole pipeline: database -> SQL scripts -> exported CSVs -> control charts.
set -euo pipefail

docker compose up -d --wait

for script in sql/0*.sql; do
  echo "=== ${script}"
  docker compose exec -T -w /project db psql -U postgres -d glaze -v ON_ERROR_STOP=1 -f "${script}"
done

python src/plot_control_charts.py
