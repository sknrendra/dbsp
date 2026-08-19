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

## Notes

- `uat_trim.bak` is gitignored — not tracked in this repo.
- SA password is hardcoded for local/dev use only. Change it before any shared or production use.
