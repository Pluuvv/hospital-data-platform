CREATE TABLE IF NOT EXISTS mart.dq_results (
  check_name text,
  layer      text,
  expected   numeric,
  actual     numeric,
  status     text,
  run_at     timestamp DEFAULT now()
);
TRUNCATE mart.dq_results;

INSERT INTO mart.dq_results (check_name, layer, expected, actual, status)
SELECT name, layer, exp, act,
       CASE WHEN abs(act - exp) < 0.011 THEN 'PASS' ELSE 'FAIL' END
FROM (
  SELECT 'Jumlah baris staging (stg.simrs_kunjungan)' AS name, 'stg' AS layer, 55500::numeric AS exp,
         (SELECT count(*) FROM stg.simrs_kunjungan)::numeric AS act
  UNION ALL SELECT 'Jumlah baris fact_kunjungan', 'dw', 54860,
         (SELECT count(*) FROM dw.fact_kunjungan)
  UNION ALL SELECT 'Baris dibuang saat cleansing (staging - fact)', 'dw', 640,
         (SELECT count(*) FROM stg.simrs_kunjungan) - (SELECT count(*) FROM dw.fact_kunjungan)
  UNION ALL SELECT 'Foreign key kosong di fact', 'dw', 0,
         (SELECT count(*) FROM dw.fact_kunjungan WHERE patient_key IS NULL OR admission_date_key IS NULL OR discharge_date_key IS NULL OR condition_key IS NULL OR admission_type_key IS NULL OR insurance_key IS NULL)
  UNION ALL SELECT 'Orphan foreign key (fact tanpa dimensi)', 'dw', 0,
         (SELECT count(*) FROM dw.fact_kunjungan f WHERE
            NOT EXISTS (SELECT 1 FROM dw.dim_patient x WHERE x.patient_key = f.patient_key)
         OR NOT EXISTS (SELECT 1 FROM dw.dim_date x WHERE x.date_key = f.admission_date_key)
         OR NOT EXISTS (SELECT 1 FROM dw.dim_date x WHERE x.date_key = f.discharge_date_key)
         OR NOT EXISTS (SELECT 1 FROM dw.dim_condition x WHERE x.condition_key = f.condition_key)
         OR NOT EXISTS (SELECT 1 FROM dw.dim_admission_type x WHERE x.admission_type_key = f.admission_type_key)
         OR NOT EXISTS (SELECT 1 FROM dw.dim_insurance x WHERE x.insurance_key = f.insurance_key))
  UNION ALL SELECT 'Grup baris duplikat di fact', 'dw', 0,
         (SELECT count(*) FROM (SELECT 1 FROM dw.fact_kunjungan GROUP BY patient_key, admission_date_key, discharge_date_key, condition_key, admission_type_key, insurance_key, doctor, hospital, room_number, medication, test_results, billing_amount HAVING count(*) > 1) d)
  UNION ALL SELECT 'Billing negatif di fact', 'dw', 0,
         (SELECT count(*) FROM dw.fact_kunjungan WHERE billing_amount < 0)
  UNION ALL SELECT 'wait_minutes kosong', 'dw', 0,
         (SELECT count(*) FROM dw.fact_kunjungan WHERE wait_minutes IS NULL)
  UNION ALL SELECT 'wait_minutes di luar rentang tipe admisi', 'dw', 0,
         (SELECT count(*) FROM dw.fact_kunjungan f JOIN dw.dim_admission_type a ON a.admission_type_key = f.admission_type_key
          WHERE (a.admission_type = 'Emergency' AND f.wait_minutes NOT BETWEEN 5 AND 40)
             OR (a.admission_type = 'Urgent'    AND f.wait_minutes NOT BETWEEN 15 AND 90)
             OR (a.admission_type = 'Elective'  AND f.wait_minutes NOT BETWEEN 30 AND 180))
  UNION ALL SELECT 'length_of_stay di luar 1-30 hari', 'dw', 0,
         (SELECT count(*) FROM dw.fact_kunjungan WHERE length_of_stay IS NULL OR length_of_stay NOT BETWEEN 1 AND 30)
  UNION ALL SELECT 'Tanggal keluar lebih awal dari tanggal masuk', 'dw', 0,
         (SELECT count(*) FROM dw.fact_kunjungan f JOIN dw.dim_date a ON a.date_key = f.admission_date_key JOIN dw.dim_date d ON d.date_key = f.discharge_date_key WHERE d.full_date < a.full_date)
  UNION ALL SELECT 'Total kunjungan mart = fact', 'mart', 54860,
         (SELECT coalesce(sum(jumlah_kunjungan),0) FROM mart.kpi_kunjungan_bulanan)
  UNION ALL SELECT 'Total pendapatan mart = fact', 'mart',
         (SELECT sum(billing_amount) FROM dw.fact_kunjungan),
         (SELECT round(sum(total_pendapatan)::numeric, 2) FROM mart.kpi_pendapatan_bulanan)
  UNION ALL SELECT 'Rata-rata waktu tunggu mart = fact', 'mart',
         (SELECT round(avg(wait_minutes)::numeric, 2) FROM dw.fact_kunjungan),
         (SELECT round(sum(total_menit_tunggu)::numeric / sum(jumlah_kunjungan), 2) FROM mart.kpi_waktu_tunggu)
  UNION ALL SELECT 'Okupansi di luar 0-100 persen', 'mart', 0,
         (SELECT count(*) FROM mart.kpi_okupansi_harian WHERE okupansi_pct < 0 OR okupansi_pct > 100)
) t;

INSERT INTO mart.dq_results (check_name, layer, expected, actual, status)
SELECT 'Billing negatif di staging (data mentah)', 'stg', 108, n,
       CASE WHEN n = 108 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT count(*)::numeric AS n FROM stg.simrs_kunjungan WHERE billing_amount::numeric < 0) s;
