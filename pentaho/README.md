# Pentaho Data Integration (Spoon) files

Put the four files here (from the project Drive folder):

| File | Purpose |
|---|---|
| `01_load_staging.ktr` | Reads the CSV, renames columns to snake_case, loads raw data into `stg.healthcare_raw` |
| `02_load_dimensions.ktr` | Loads 5 dimension tables from staging using a NOT EXISTS pattern (safe to re-run) |
| `03_load_fact.ktr` | Dedupes, filters negative billing, derives `length_of_stay`, looks up dimension keys, loads `dw.fact_kunjungan` |
| `00_main.kjb` | Orchestration job: truncates the warehouse, then runs 01 → 02 → 03 in order |

Database connection name: `hospital_dw` (PostgreSQL, host `localhost`, port `5433`, database `hospital_dw`).
Tested with Pentaho Data Integration Community Edition 9.4.0.0-343.
