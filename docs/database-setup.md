# Local Database Setup

This guide builds a local copy of `hospital_dw` on Windows from the repository's schema, source CSV, and ETL jobs. It does not download the team's Neon database or use a database dump.

## Prerequisites

- Git
- Docker Desktop, running
- Python 3.10 or later
- Pentaho Data Integration (Spoon) 9.x

## 1. Clone the repository

In PowerShell:

```powershell
git clone https://github.com/Pluuvv/hospital-data-platform.git
Set-Location hospital-data-platform
```

The source dataset is in `data\raw\healthcare_dataset.csv`.

## 2. Start PostgreSQL

```powershell
docker compose up -d
docker compose ps
```

Compose creates a local PostgreSQL 16 database with these development settings:

| Setting | Value |
|---|---|
| Host | `localhost` |
| Port | `5433` |
| Database | `hospital_dw` |
| User | `postgres` |
| Password | `postgres123` |

These credentials are for local development only; do not use them for a public or production database.

## 3. Initialize the schema

Run this on a fresh local database:

```powershell
docker cp .\etl\schema.sql hospital-pg:/tmp/schema.sql
docker exec hospital-pg psql -U postgres -d hospital_dw -f /tmp/schema.sql
```

**Warning:** `etl\schema.sql` drops and recreates the `stg` and `dw` schemas. Do not rerun it on a database whose data you want to keep.

## 4. Fix Pentaho paths for this computer

The PDI files contain absolute paths from the original computer. Before running the job, open the files in Spoon and update:

1. In `01_load_staging.ktr`, set the CSV Input file to the cloned repository's `data\raw\healthcare_dataset.csv`.
2. In `00_main.kjb`, update the transformation file paths for `02_load_dimensions.ktr` and `03_load_fact.ktr` to their locations in this clone.
3. Confirm the `hospital_dw` database connection uses `localhost`, port `5433`, database `hospital_dw`, user `postgres`, and password `postgres123`.
4. Save the files, open `00_main.kjb`, and run the job.

The main job reloads the staging data and truncates the DW fact and dimension tables before reloading them. Only run it when you intend to rebuild those tables.

After it finishes, verify the staging and fact counts:

```powershell
docker exec hospital-pg psql -U postgres -d hospital_dw -c "SELECT (SELECT count(*) FROM stg.healthcare_raw) AS staging, (SELECT count(*) FROM dw.fact_kunjungan) AS fact;"
```

Expected counts for this project dataset: `staging = 55500`, `fact = 54860`.

## 5. Build the KPI mart

Create a Python virtual environment and install the project dependencies:

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python etl\build_mart.py
```

The script builds the four KPI tables in the `mart` schema and writes CSV exports under `docs\looker`.

## 6. Run data quality checks

Create a local `.env` file and configure the local database connection:

```powershell
Copy-Item .env.example .env
notepad .env
```

Set these values in `.env`:

```dotenv
DB_HOST=localhost
DB_PORT=5433
DB_NAME=hospital_dw
DB_USER=postgres
DB_PASS=postgres123
DB_SSLMODE=prefer
```

Run the Python checks:

```powershell
python dq_checks_pg.py
```

Alternatively, run the SQL checks:

```powershell
docker cp .\dq_checks_pg.sql hospital-pg:/tmp/dq_checks_pg.sql
docker exec hospital-pg psql -U postgres -d hospital_dw -f /tmp/dq_checks_pg.sql
```

Both runners use the same 16 checks and replace the previous snapshot in `mart.dq_results`. They do not update or delete records in `stg` or `dw`. The row-count targets and synthetic `wait_minutes` ranges are specific to this project dataset. Keep `.env` private; it is for local credentials and must not be committed.

## 7. Connect a database client

In DBeaver or pgAdmin, use host `localhost`, port `5433`, database `hospital_dw`, user `postgres`, and the local development password `postgres123`.

Each teammate who follows this guide gets a separate local database. To access one shared Neon database, ask its project owner to grant access and share connection settings privately. Do not put Neon credentials in GitHub or in this guide.

## Stop PostgreSQL

To stop the local database while preserving its volume:

```powershell
docker compose down
```

Do not add `-v` unless you intend to delete the database volume and its contents.
