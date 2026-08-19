# dbsp

MSSQL + DBGate stack with a restore script for `uat_trim.bak`.

## Services

- **mssql** — SQL Server 2022, port `1433`, user `sa` / password `YourStrong!Passw0rd`
- **dbgate** — web UI at [http://localhost:8085](http://localhost:8085), preconfigured connection to `mssql`

## Setup

```bash
cd /home/spadmin/dbsp
docker compose up -d
```

Wait for `mssql` to report healthy before restoring:

```bash
docker inspect -f '{{.State.Health.Status}}' dbsp-mssql
```

Make sure the backup file is readable by the container user (uid `10001`). It's mounted from the project root at `/backup`:

```bash
chmod 644 uat_trim.bak
```

## Restore

```bash
./restore.sh [bak_file=uat_trim.bak] [db_name=DB_SP_SP]
```

Example:

```bash
./restore.sh uat_trim.bak DB_SP_SP
```

The script reads logical file names from the backup via `RESTORE FILELISTONLY`, then runs `RESTORE DATABASE ... WITH MOVE, REPLACE` into the `mssql` data volume.

## Load Excel data

`DB_SP_INF.xlsx`, `DB_SP_INF  II.xlsx` (26 sheets total, one per table in `DB_SP_INF`) and `TB_M_USER_PROC_ID.xlsx` (loads into `DB_SP_SP.dbo.TB_M_USER_PROC_ID`) are loaded via `scripts/load_excel_data.py`. Same gitignore treatment as `uat_trim.bak` — scp these 3 files into the repo root on the target server first.

```bash
python3 -m venv .venv
.venv/bin/pip install -r scripts/requirements.txt
.venv/bin/python3 scripts/load_excel_data.py            # dry run — validates, no writes
.venv/bin/python3 scripts/load_excel_data.py --commit    # actually inserts
```

Defaults assume `mssql` is reachable at `localhost:1433` with the SA password above; override via `MSSQL_HOST` / `MSSQL_PORT` / `MSSQL_SA_PASSWORD` env vars if different. The script is idempotent to run in dry-run mode but **not** safe to `--commit` twice — it does a plain `INSERT`, so re-running against already-loaded tables will duplicate rows or violate the `TB_M_USER_PROC_ID` identity range.

## Notes

- `uat_trim.bak` and `*.xlsx` are gitignored — not tracked in this repo.
- SA password is hardcoded for local/dev use only. Change it before any shared or production use.
