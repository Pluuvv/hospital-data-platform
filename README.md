# 🏥 Hospital Data Pipeline

> **End-to-end Data Engineering pipeline** untuk sistem data warehouse rumah sakit — mulai dari raw CSV hingga KPI mart yang siap divisualisasi.

---

## 📌 Latar Belakang

Sistem SIMRS (Sistem Informasi Manajemen Rumah Sakit) menghasilkan data kunjungan pasien dalam jumlah besar. Project ini membangun pipeline ETL yang mengubah data mentah tersebut menjadi **data warehouse berbasis dimensional model (Star Schema)**, kemudian menghasilkan **data mart KPI** untuk kebutuhan analitik operasional rumah sakit seperti:

- Tren kunjungan pasien per bulan
- Pendapatan per penyedia asuransi
- Waktu tunggu rata-rata per tipe admisi
- Tingkat okupansi tempat tidur harian

---

## 🏗️ Arsitektur Pipeline

```
Raw Data (CSV)
     │
     ▼
┌─────────────────┐
│  STAGING Layer  │  ← Load as-is, no transformation
│  stg.healthcare │
│      _raw       │
└────────┬────────┘
         │  Cleanse & Deduplicate
         ▼
┌──────────────────────────────────────────┐
│          DATA WAREHOUSE Layer            │
│            (Star Schema)                 │
│                                          │
│  dim_date   dim_patient  dim_condition   │
│  dim_admission_type  dim_insurance       │
│                                          │
│           fact_kunjungan                 │
└────────────────┬─────────────────────────┘
                 │  Aggregate & Compute KPIs
                 ▼
┌──────────────────────────────────────────┐
│            DATA MART Layer               │
│                                          │
│  mart.kpi_kunjungan_bulanan              │
│  mart.kpi_pendapatan_bulanan             │
│  mart.kpi_waktu_tunggu                   │
│  mart.kpi_okupansi_harian                │
└──────────────────────────────────────────┘
         │
         ▼
   Dashboard / BI Tool (Looker Studio)
```

---

## 🛠️ Tech Stack

| Komponen | Teknologi |
|---|---|
| Database | PostgreSQL 16 (via Docker) |
| ETL Orkestrasi | Pentaho Data Integration (PDI/Kettle) |
| Data Mart Build | Python (pandas, SQLAlchemy, psycopg2) |
| Containerisasi | Docker & Docker Compose |
| Visualisasi | Looker Studio |
| Environment | Python 3.13 + virtualenv |

---

## 📂 Struktur Project

```
hospital-pipeline/
├── 00_main.kjb                  # PDI Job utama (orkestrasi)
├── 01_load_staging.ktr          # PDI Transform: CSV → Staging
├── 02_load_dimensions.ktr       # PDI Transform: Staging → Dimensi DW
├── 03_load_fact.ktr             # PDI Transform: Staging → Fact Table
├── docker-compose.yml           # PostgreSQL container
├── dw_schema.sql                # DDL schema Data Warehouse
├── etl/
│   ├── schema.sql               # DDL lengkap (stg + dw)
│   └── build_mart.py           # Script Python build KPI mart
├── sql/
│   └── stg_simrs.sql           # DDL staging SIMRS
├── data/
│   └── raw/
│       └── healthcare_dataset.csv  # Data sumber (55.500 baris)
├── docs/
│   ├── kpi_kunjungan_bulanan.csv
│   ├── kpi_pendapatan_bulanan.csv
│   ├── kpi_waktu_tunggu.csv
│   ├── kpi_okupansi_harian.csv
│   ├── rejected_billing_negatif.csv  # Data quality log
│   └── looker/                  # CSV export untuk Looker Studio
└── logs/
    └── job_m3.log              # Log eksekusi PDI job
```

---

## 📊 Data & KPI

### Dataset Sumber
- **File:** `healthcare_dataset.csv`
- **Volume:** 55.500 baris raw → 54.860 baris valid
- **Periode:** Mei 2019 – Agustus 2024
- **Data Rejected:** 108 baris (billing_amount < 0 → masuk `rejected_billing_negatif.csv`)

### Schema Data Warehouse

**Dimensi:**
| Tabel | Baris | Deskripsi |
|---|---|---|
| `dw.dim_date` | 1.888 | Kalender lengkap dengan atribut waktu |
| `dw.dim_patient` | 54.944 | Profil pasien unik |
| `dw.dim_condition` | 6 | Kondisi medis (Arthritis, Asthma, Cancer, dll.) |
| `dw.dim_admission_type` | 3 | Elective, Emergency, Urgent |
| `dw.dim_insurance` | 5 | Aetna, Blue Cross, Cigna, Medicare, UnitedHealthcare |

**Fakta:**
| Tabel | Baris | Total Billing |
|---|---|---|
| `dw.fact_kunjungan` | 54.860 | \$1.404.121.599,97 |

### KPI Mart Output

| Mart Table | Baris | Deskripsi |
|---|---|---|
| `mart.kpi_kunjungan_bulanan` | 1.098 | Kunjungan per bulan, tipe admisi, kondisi medis |
| `mart.kpi_pendapatan_bulanan` | 305 | Pendapatan per bulan & asuransi |
| `mart.kpi_waktu_tunggu` | 183 | Total menit tunggu per bulan & tipe admisi |
| `mart.kpi_okupansi_harian` | 1.797 | Okupansi harian (avg ~77,58%) |

---

## 🚀 Cara Menjalankan

### Prerequisites
- Docker Desktop (running)
- Python 3.10+ dengan virtualenv
- Pentaho Data Integration 9.x (untuk `.ktr`/`.kjb`)

### 1. Jalankan Database

```bash
docker compose up -d
```

Ini akan menjalankan PostgreSQL 16 di port `5433` dengan:
- Database: `hospital_dw`
- User: `postgres`
- Password: `postgres123`

### 2. Setup Python Environment

```bash
python -m venv .venv
.venv\Scripts\activate        # Windows
pip install pandas sqlalchemy psycopg2-binary
```

### 3. Inisialisasi Schema

```bash
docker exec -i hospital-pg psql -U postgres -d hospital_dw < etl/schema.sql
```

### 4. Jalankan ETL Pipeline (Pentaho)

Buka Pentaho Spoon, lalu jalankan `00_main.kjb`. Job ini secara berurutan menjalankan:
1. `01_load_staging.ktr` — Load CSV ke staging
2. `02_load_dimensions.ktr` — Populate dimensi DW
3. `03_load_fact.ktr` — Populate fact table

### 5. Build KPI Mart

```bash
python etl/build_mart.py
```

Output: 4 tabel di schema `mart` + CSV export di `docs/looker/`

### 6. Verifikasi Data

```bash
docker exec hospital-pg psql -U postgres -d hospital_dw -c "
SELECT 'stg'            AS layer, count(*) FROM stg.healthcare_raw
UNION ALL SELECT 'fact', count(*) FROM dw.fact_kunjungan
UNION ALL SELECT 'mart_kunjungan', count(*) FROM mart.kpi_kunjungan_bulanan;"
```

---

## 🔍 Data Quality

Pipeline menerapkan beberapa rules data quality:

| Rule | Penanganan |
|---|---|
| `billing_amount < 0` | Di-reject ke `rejected_billing_negatif.csv` (108 baris) |
| Duplikat pasien | Deduped menggunakan `UNIQUE INDEX` pada `(name, age, gender, blood_type)` |
| NULL pada FK | Validasi post-load: `0 null keys` dari 54.860 baris |
| Length of Stay | Dikompute dari `discharge_date - date_of_admission` (range: 1–30 hari) |
| Wait Minutes | Di-generate deterministik dari `admission_id` |

---

## 📈 Key Insights

- **Total Pendapatan:** \$1,4 Miliar (periode 2019–2024)
- **Rata-rata Waktu Tunggu:** ~59,6 menit per kunjungan
- **Rata-rata Okupansi:** ~77,58% (asumsi kapasitas 600 tempat tidur)
- **Distribusi Tipe Admisi:** Elective / Emergency / Urgent merata
- **Top Kondisi Medis:** Arthritis, Asthma, Cancer, Diabetes, Hypertension, Obesity

---

## 📝 Catatan Desain

- **Staging Layer** menyimpan data as-is dari sumber (termasuk yang dirty) untuk auditability
- **wait_minutes** di-generate karena dataset asli tidak memiliki data waktu tunggu
- **Kapasitas bed (600)** adalah asumsi karena dataset tidak menyertakan data kapasitas rumah sakit
- **Okupansi** dihitung dari kumulatif pasien yang masuk dikurangi yang keluar per hari

---

## 👩‍💻 Author

**Rizkya Permata**  
Data Engineering — Semester 5  
Universitas [Nama Universitas]

---

> *"Turn raw data into actionable insights."*
