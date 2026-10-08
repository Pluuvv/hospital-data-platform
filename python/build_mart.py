import os
import pandas as pd
from sqlalchemy import create_engine

# ASSUMPTION: total bed capacity (the dataset has no capacity data)
KAPASITAS_BED = 600

PG_PASSWORD = os.environ["POSTGRES_PASSWORD"]   # same value as in .env
PG_HOST = os.getenv("PG_HOST", "localhost")
PG_PORT = os.getenv("PG_PORT", "5433")

engine = create_engine(
    f"postgresql+psycopg2://postgres:{PG_PASSWORD}@{PG_HOST}:{PG_PORT}/hospital_dw"
)

SQL = """
SELECT f.admission_id, f.wait_minutes, f.billing_amount,
       d1.full_date AS tgl_masuk, d2.full_date AS tgl_keluar,
       date_trunc('month', d1.full_date)::date AS bulan,
       c.medical_condition, a.admission_type, i.insurance_provider
FROM dw.fact_kunjungan f
JOIN dw.dim_date d1 ON d1.date_key = f.admission_date_key
JOIN dw.dim_date d2 ON d2.date_key = f.discharge_date_key
JOIN dw.dim_condition c ON c.condition_key = f.condition_key
JOIN dw.dim_admission_type a ON a.admission_type_key = f.admission_type_key
JOIN dw.dim_insurance i ON i.insurance_key = f.insurance_key
"""

df = pd.read_sql(SQL, engine)
df["tgl_masuk"] = pd.to_datetime(df["tgl_masuk"])
df["tgl_keluar"] = pd.to_datetime(df["tgl_keluar"])
df["bulan"] = pd.to_datetime(df["bulan"]).dt.date
df["wait_minutes"] = df["wait_minutes"].astype(int)
print("Rows read from dw:", len(df))

kunjungan = (df.groupby(["bulan", "admission_type", "medical_condition"])
               .size().reset_index(name="jumlah_kunjungan"))

pendapatan = (df.groupby(["bulan", "insurance_provider"])
                .agg(total_pendapatan=("billing_amount", "sum"),
                     rata_rata_tagihan=("billing_amount", "mean"),
                     jumlah_kunjungan=("admission_id", "count"))
                .round(2).reset_index())

# Wait time stored as total minutes (integer); the average is computed in the dashboard
tunggu = (df.groupby(["bulan", "admission_type"])
            .agg(jumlah_kunjungan=("admission_id", "count"),
                 total_menit_tunggu=("wait_minutes", "sum"))
            .reset_index())

# Daily occupancy = patients in-house that day / assumed bed capacity
idx = pd.date_range(df["tgl_masuk"].min(), df["tgl_keluar"].max())
masuk = df["tgl_masuk"].value_counts().reindex(idx, fill_value=0)
keluar = df["tgl_keluar"].value_counts().reindex(idx, fill_value=0)
dirawat = (masuk - keluar).cumsum()
start = df["tgl_masuk"].min() + pd.Timedelta(days=30)   # skip warm-up period
end = df["tgl_masuk"].max()
dirawat = dirawat[(dirawat.index >= start) & (dirawat.index <= end)]

okupansi = pd.DataFrame({
    "tanggal": dirawat.index.date,
    "pasien_dirawat": dirawat.values,
    "kapasitas_bed": KAPASITAS_BED,
})
okupansi["okupansi_pct"] = (okupansi["pasien_dirawat"] / KAPASITAS_BED * 100).round(2)

hasil = {
    "kpi_kunjungan_bulanan": kunjungan,
    "kpi_pendapatan_bulanan": pendapatan,
    "kpi_waktu_tunggu": tunggu,
    "kpi_okupansi_harian": okupansi,
}

os.makedirs("docs/looker", exist_ok=True)
for nama, tabel in hasil.items():
    tabel.to_sql(nama, engine, schema="mart", if_exists="replace", index=False)
    tabel.to_csv("docs/looker/" + nama + ".csv", index=False)
    print("mart." + nama, "->", len(tabel), "rows")

print("weighted avg wait time:",
      round(tunggu["total_menit_tunggu"].sum() / tunggu["jumlah_kunjungan"].sum(), 2))
