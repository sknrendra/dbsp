#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
fi

BAK_FILE="${1:-uat_trim.bak}"
DB_NAME="${2:-DB_SP_SP}"
CONTAINER="dbsp-mssql"
SA_PASSWORD="${MSSQL_SA_PASSWORD:-YourStrong!Passw0rd}"
BACKUP_IN_CONTAINER="/backup/$(basename "$BAK_FILE")"

if [[ ! -f "$BAK_FILE" ]]; then
  echo "ERROR: backup file not found: $BAK_FILE" >&2
  exit 1
fi

if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" >/dev/null 2>&1; then
  echo "ERROR: container $CONTAINER not running. Run: docker compose up -d" >&2
  exit 1
fi

SQLCMD="/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -C"

DB_EXISTS=$(docker exec "$CONTAINER" $SQLCMD -h -1 -W -Q \
  "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name = N'$DB_NAME';" | tr -d '[:space:]')

if [[ "$DB_EXISTS" != "0" && "${FORCE_RESTORE:-0}" != "1" ]]; then
  echo "ERROR: database [$DB_NAME] already exists. Refusing to REPLACE it and wipe existing data." >&2
  echo "Re-run with FORCE_RESTORE=1 ./restore.sh ... to override." >&2
  exit 1
fi

echo "Reading file list from $BACKUP_IN_CONTAINER ..."
FILELIST=$(docker exec "$CONTAINER" $SQLCMD -h -1 -W -Q \
  "SET NOCOUNT ON; RESTORE FILELISTONLY FROM DISK = N'$BACKUP_IN_CONTAINER';")

DATA_LOGICAL=$(echo "$FILELIST" | awk '$0 !~ /^$/ {print $1; exit}')
LOG_LOGICAL=$(echo "$FILELIST" | awk '$0 !~ /^$/ {print $1}' | sed -n '2p')

if [[ -z "$DATA_LOGICAL" || -z "$LOG_LOGICAL" ]]; then
  echo "ERROR: could not parse logical file names from backup." >&2
  echo "$FILELIST" >&2
  exit 1
fi

echo "Data logical file: $DATA_LOGICAL"
echo "Log logical file:  $LOG_LOGICAL"
echo "Restoring database [$DB_NAME] ..."

docker exec "$CONTAINER" $SQLCMD -b -Q "
RESTORE DATABASE [$DB_NAME]
FROM DISK = N'$BACKUP_IN_CONTAINER'
WITH MOVE N'$DATA_LOGICAL' TO N'/var/opt/mssql/data/${DB_NAME}.mdf',
     MOVE N'$LOG_LOGICAL' TO N'/var/opt/mssql/data/${DB_NAME}_log.ldf',
     REPLACE, STATS = 10;
"

echo "Restore done: [$DB_NAME]"

for SCRIPT in "DB_SP_SP-migration-candidates.sql" "new_tables.sql" "TB_M_FUNCTION-seed.sql" "TB_M_PERMISSION-admin-super-tam-seed.sql" "surrounding-databases.sql"; do
  if [[ ! -f "$SCRIPT" ]]; then
    echo "ERROR: script not found: $SCRIPT" >&2
    exit 1
  fi
  echo "Running $SCRIPT ..."
  docker exec "$CONTAINER" $SQLCMD -b -d "$DB_NAME" -i "/backup/$SCRIPT"
  echo "Done: $SCRIPT"
done

# These target databases other than $DB_NAME on the same instance, so they run
# against an explicit -d. Order matters only within a database, and each script
# is idempotent, so re-running the whole block is safe.
#   DB_SP_PRO: migration-candidates (column adds) then new_tables_pro (creates)
#   DB_SP_INF: new_tables_inf (creates) -- the H02_04 GR Data Repair staging +
#              history tables, the only portal-written tables in that database.
# surrounding-databases.sql above creates DB_SP_PRO/INF/SUP/WRH themselves, so
# it must have run first (it is last in the $DB_NAME loop).
run_against() {
  local db="$1" script="$2"
  if [[ ! -f "$script" ]]; then
    echo "Skipping $script (not found)."
    return
  fi
  echo "Running $script against $db ..."
  docker exec "$CONTAINER" $SQLCMD -b -d "$db" -i "/backup/$script"
  echo "Done: $script"
}

run_against "DB_SP_PRO" "DB_SP_PRO-migration-candidates.sql"
run_against "DB_SP_PRO" "new_tables_pro.sql"
run_against "DB_SP_INF" "new_tables_inf.sql"

EXCEL_FILES=("DB_SP_INF.xlsx" "DB_SP_INF  II.xlsx" "TB_M_USER_PROC_ID.xlsx" "DB_SP_PRO.xlsx" "DB_SP_WRH.xlsx")
MISSING_EXCEL=0
for f in "${EXCEL_FILES[@]}"; do
  [[ -f "$f" ]] || MISSING_EXCEL=1
done

if [[ "$MISSING_EXCEL" -eq 1 ]]; then
  echo "Skipping Excel data load: one or more of ${EXCEL_FILES[*]} not found in $(pwd)."
else
  EXISTING_ROWS=$(docker exec "$CONTAINER" $SQLCMD -h -1 -W -d "$DB_NAME" -Q \
    "SET NOCOUNT ON; SELECT COUNT(*) FROM dbo.TB_M_USER_PROC_ID;" | tr -d '[:space:]')

  if [[ "$EXISTING_ROWS" != "0" ]]; then
    echo "Skipping Excel data load: dbo.TB_M_USER_PROC_ID already has $EXISTING_ROWS rows."
  else
    echo "Loading Excel data ..."
    if [[ ! -x ".venv/bin/python3" ]]; then
      python3 -m venv .venv
    fi
    if ! .venv/bin/python3 -c "import openpyxl, pymssql, dotenv" >/dev/null 2>&1; then
      .venv/bin/pip3 install -q -r scripts/requirements.txt
    fi
    .venv/bin/python3 scripts/load_excel_data.py --commit
    echo "Excel data load done."
  fi
fi
