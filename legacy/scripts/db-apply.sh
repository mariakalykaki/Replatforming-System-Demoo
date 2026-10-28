#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

ENGINE=$(command -v podman >/dev/null 2>&1 && echo podman || echo docker)
set -a; source .env; set +a

echo "Waiting for Oracle..."
for i in $(seq 1 90); do
  OUT=$(echo "SELECT 'READY' FROM dual;" | $ENGINE exec -i na-oracle sqlplus -s -L na_app/"$APP_USER_PASSWORD"@localhost:1521/FREEPDB1 2>/dev/null || true)
  if [[ "$OUT" == *READY* ]]; then break; fi
  [ "$i" -eq 90 ] && { echo "Oracle did not become ready; see '$ENGINE logs na-oracle'." >&2; exit 1; }
  sleep 3
done

run() {
  { echo "WHENEVER SQLERROR EXIT SQL.SQLCODE"; echo "SET DEFINE OFF FEEDBACK OFF"; cat "$1"; echo; echo "EXIT;"; } |
    $ENGINE exec -i na-oracle sqlplus -s na_app/"$APP_USER_PASSWORD"@localhost:1521/FREEPDB1
}

for f in database/schema/*.sql;  do echo "schema   $f"; run "$f"; done
for f in database/packages/*.pks; do echo "spec     $f"; run "$f"; done
for f in database/packages/*.pkb; do echo "body     $f"; run "$f"; done

echo "Checking for PL/SQL compile errors (expect none)..."
ERRORS=$(echo "SET HEADING OFF
SELECT name || ' line ' || line || ': ' || text FROM user_errors ORDER BY name, sequence;" | run /dev/stdin | sed '/^$/d')
if [ -n "$ERRORS" ]; then echo "$ERRORS" >&2; echo "PL/SQL compile errors above." >&2; exit 1; fi

for f in database/seed/00[1-3]_*.sql; do echo "seed     $f"; run "$f"; done

echo "Reachability check (expect no rows)..."
run database/seed/004_validate_reachability.sql
echo "Done."
