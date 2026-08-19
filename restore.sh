#!/usr/bin/env bash
set -euo pipefail

BAK_FILE="${1:-uat_trim.bak}"
DB_NAME="${2:-DB_SP_SP}"
CONTAINER="dbsp-mssql"
SA_PASSWORD="YourStrong!Passw0rd"
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

for SCRIPT in "DB_SP_SP-migration-candidates.sql" "surrounding-databases.sql"; do
  if [[ ! -f "$SCRIPT" ]]; then
    echo "ERROR: script not found: $SCRIPT" >&2
    exit 1
  fi
  echo "Running $SCRIPT ..."
  docker exec "$CONTAINER" $SQLCMD -b -d "$DB_NAME" -i "/backup/$SCRIPT"
  echo "Done: $SCRIPT"
done
