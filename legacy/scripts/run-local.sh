#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
mkdir -p logs

ENGINE=$(command -v podman >/dev/null 2>&1 && echo podman || echo docker)
if [ "$ENGINE" = podman ] && ! podman info >/dev/null 2>&1; then podman machine start; fi
set -a; source .env; set +a

$ENGINE compose up -d
echo "Waiting for Oracle..."
for i in $(seq 1 90); do
  $ENGINE exec na-oracle /opt/oracle/healthcheck.sh >/dev/null 2>&1 && break
  [ "$i" -eq 90 ] && { echo "Oracle not ready; see '$ENGINE logs na-oracle'" >&2; exit 1; }
  sleep 2
done

export ConnectionStrings__Oracle="User Id=na_app;Password=${APP_USER_PASSWORD};Data Source=localhost:1522/FREEPDB1;"

dotnet build
pids=()
dotnet run --no-build --project src/Na.MockExternalApis > logs/mock.log 2>&1 & pids+=("$!")
dotnet run --no-build --project src/Na.Worker           > logs/worker.log 2>&1 & pids+=("$!")
dotnet run --no-build --project src/Na.Api              > logs/api.log 2>&1 & pids+=("$!")
trap 'kill "${pids[@]}" 2>/dev/null' EXIT INT TERM

echo "API http://localhost:5100  Mock http://localhost:5101  (logs/*.log, Ctrl+C to stop)"
wait
