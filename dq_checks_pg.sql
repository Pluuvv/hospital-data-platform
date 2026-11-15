\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE IF NOT EXISTS mart.dq_results (
    check_name text NOT NULL,
    layer text NOT NULL,
    expected numeric NOT NULL,
    actual numeric NOT NULL,
    status text NOT NULL,
    run_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

TRUNCATE TABLE mart.dq_results;

INSERT INTO mart.dq_results (check_name, layer, expected, actual, status)
SELECT 'Jumlah baris staging (stg.healthcare_raw)', 'stg.healthcare_raw',
       result.expected, result.actual,
       CASE WHEN result.actual = result.expected THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT 55500::numeric AS expected, COUNT(*)::numeric AS actual
    FROM stg.healthcare_raw
) AS result;

INSERT INTO mart.dq_results (check_name, layer, expected, actual, status)
SELECT 'Jumlah baris fact_kunjungan', 'dw.fact_kunjungan',
       result.expected, result.actual,
       CASE WHEN result.actual = result.expected THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT 54860::numeric AS expected, COUNT(*)::numeric AS actual
    FROM dw.fact_kunjungan
) AS result;

INSERT INTO mart.dq_results (check_name, layer, expected, actual, status)
SELECT 'Baris dibuang saat cleansing (staging - fact)', 'dw.fact_kunjungan',
       result.expected, result.actual,
       CASE WHEN result.actual = result.expected THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT 640::numeric AS expected,
           (SELECT COUNT(*) FROM stg.healthcare_raw)
             - (SELECT COUNT(*) FROM dw.fact_kunjungan) AS actual
) AS result;

INSERT INTO mart.dq_results (check_name, layer, expected, actual, status)
SELECT 'Foreign key kosong di fact', 'dw.fact_kunjungan',
       result.expected, result.actual,
       CASE WHEN result.actual = result.expected THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT 0::numeric AS expected, COUNT(*)::numeric AS actual
    FROM dw.fact_kunjungan
    WHERE admission_id IS NULL
       OR patient_key IS NULL
       OR admission_date_key IS NULL
       OR discharge_date_key IS NULL
       OR condition_key IS NULL
       OR admission_type_key IS NULL
       OR insurance_key IS NULL
) AS result;

INSERT INTO mart.dq_results (check_name, layer, expected, actual, status)
SELECT 'Orphan foreign key (fact tanpa dimensi)', 'dw.fact_kunjungan',
       result.expected, result.actual,
       CASE WHEN result.actual = result.expected THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT 0::numeric AS expected, COUNT(*)::numeric AS actual
    FROM dw.fact_kunjungan f
    WHERE NOT EXISTS (SELECT 1 FROM dw.dim_patient p WHERE p.patient_key = f.patient_key)
       OR NOT EXISTS (SELECT 1 FROM dw.dim_date d WHERE d.date_key = f.admission_date_key)
       OR NOT EXISTS (SELECT 1 FROM dw.dim_date d WHERE d.date_key = f.discharge_date_key)
       OR NOT EXISTS (SELECT 1 FROM dw.dim_condition c WHERE c.condition_key = f.condition_key)
       OR NOT EXISTS (SELECT 1 FROM dw.dim_admission_type a WHERE a.admission_type_key = f.admission_type_key)
       OR NOT EXISTS (SELECT 1 FROM dw.dim_insurance i WHERE i.insurance_key = f.insurance_key)
) AS result;

INSERT INTO mart.dq_results (check_name, layer, expected, actual, status)
SELECT 'Grup baris duplikat di fact', 'dw.fact_kunjungan',
       result.expected, result.actual,
       CASE WHEN result.actual = result.expected THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT 0::numeric AS expected, COUNT(*)::numeric AS actual
    FROM (
        SELECT 1
        FROM dw.fact_kunjungan
        GROUP BY patient_key, admission_date_key, discharge_date_key,
                 condition_key, admission_type_key, insurance_key, doctor,
                 hospital, room_number, medication, test_results, billing_amount
        HAVING COUNT(*) > 1
    ) AS duplicate_groups
) AS result;

INSERT INTO mart.dq_results (check_name, layer, expected, actual, status)
SELECT 'Billing negatif di fact', 'dw.fact_kunjungan',
       result.expected, result.actual,
       CASE WHEN result.actual = result.expected THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT 0::numeric AS expected, COUNT(*)::numeric AS actual
    FROM dw.fact_kunjungan
    WHERE billing_amount < 0
) AS result;

INSERT INTO mart.dq_results (check_name, layer, expected, actual, status)
SELECT 'wait_minutes kosong', 'dw.fact_kunjungan',
       result.expected, result.actual,
       CASE WHEN result.actual = result.expected THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT 0::numeric AS expected, COUNT(*)::numeric AS actual
    FROM dw.fact_kunjungan
    WHERE wait_minutes IS NULL
) AS result;

INSERT INTO mart.dq_results (check_name, layer, expected, actual, status)
SELECT 'wait_minutes di luar rentang tipe admisi', 'dw.fact_kunjungan',
       result.expected, result.actual,
       CASE WHEN result.actual = result.expected THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT 0::numeric AS expected, COUNT(*)::numeric AS actual
    FROM dw.fact_kunjungan f
    JOIN dw.dim_admission_type a ON a.admission_type_key = f.admission_type_key
    WHERE CASE LOWER(COALESCE(a.admission_type, ''))
              WHEN 'emergency' THEN f.wait_minutes NOT BETWEEN 5 AND 40
              WHEN 'urgent' THEN f.wait_minutes NOT BETWEEN 15 AND 90
              WHEN 'elective' THEN f.wait_minutes NOT BETWEEN 30 AND 180
              ELSE TRUE
          END
) AS result;

INSERT INTO mart.dq_results (check_name, layer, expected, actual, status)
SELECT 'length_of_stay di luar 1-30 hari', 'dw.fact_kunjungan',
       result.expected, result.actual,
       CASE WHEN result.actual = result.expected THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT 0::numeric AS expected, COUNT(*)::numeric AS actual
    FROM dw.fact_kunjungan
    WHERE length_of_stay IS NULL OR length_of_stay NOT BETWEEN 1 AND 30
) AS result;

INSERT INTO mart.dq_results (check_name, layer, expected, actual, status)
SELECT 'Tanggal keluar lebih awal dari tanggal masuk', 'dw.fact_kunjungan',
       result.expected, result.actual,
       CASE WHEN result.actual = result.expected THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT 0::numeric AS expected, COUNT(*)::numeric AS actual
    FROM dw.fact_kunjungan f
    JOIN dw.dim_date admission_date ON admission_date.date_key = f.admission_date_key
    JOIN dw.dim_date discharge_date ON discharge_date.date_key = f.discharge_date_key
    WHERE discharge_date.full_date < admission_date.full_date
) AS result;

INSERT INTO mart.dq_results (check_name, layer, expected, actual, status)
SELECT 'Total kunjungan mart = fact', 'mart.kpi_kunjungan_bulanan',
       result.expected, result.actual,
       CASE WHEN result.actual = result.expected THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT (SELECT COUNT(*)::numeric FROM dw.fact_kunjungan) AS expected,
           COALESCE(SUM(jumlah_kunjungan), 0)::numeric AS actual
    FROM mart.kpi_kunjungan_bulanan
) AS result;

INSERT INTO mart.dq_results (check_name, layer, expected, actual, status)
SELECT 'Total pendapatan mart = fact', 'mart.kpi_pendapatan_bulanan',
       result.expected, result.actual,
       CASE WHEN result.actual = result.expected THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT (SELECT COALESCE(SUM(billing_amount), 0)::numeric
            FROM dw.fact_kunjungan) AS expected,
           (SELECT COALESCE(ROUND(SUM(total_pendapatan)::numeric, 2), 0)::numeric
            FROM mart.kpi_pendapatan_bulanan) AS actual
) AS result;

INSERT INTO mart.dq_results (check_name, layer, expected, actual, status)
SELECT 'Rata-rata waktu tunggu mart = fact', 'mart.kpi_waktu_tunggu',
       result.expected, result.actual,
       CASE WHEN result.actual = result.expected THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT (SELECT COALESCE(ROUND(AVG(wait_minutes)::numeric, 2), 0)::numeric
            FROM dw.fact_kunjungan) AS expected,
           (SELECT CASE WHEN COALESCE(SUM(jumlah_kunjungan), 0) = 0 THEN 0::numeric
                        ELSE ROUND(SUM(total_menit_tunggu)::numeric / SUM(jumlah_kunjungan), 2)
                   END
            FROM mart.kpi_waktu_tunggu) AS actual
) AS result;

INSERT INTO mart.dq_results (check_name, layer, expected, actual, status)
SELECT 'Okupansi di luar 0-100 persen', 'mart.kpi_okupansi_harian',
       result.expected, result.actual,
       CASE WHEN result.actual = result.expected THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT 0::numeric AS expected, COUNT(*)::numeric AS actual
    FROM mart.kpi_okupansi_harian
    WHERE okupansi_pct IS NULL OR okupansi_pct < 0 OR okupansi_pct > 100
) AS result;

INSERT INTO mart.dq_results (check_name, layer, expected, actual, status)
SELECT 'Billing negatif di staging (data mentah)', 'stg.healthcare_raw',
       result.expected, result.actual,
       CASE WHEN result.actual = result.expected THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT 108::numeric AS expected,
           COUNT(*)::numeric AS actual
    FROM stg.healthcare_raw
    WHERE billing_amount < 0
) AS result;

COMMIT;

SELECT check_name, layer, expected, actual, status, run_at
FROM mart.dq_results
ORDER BY check_name;

SELECT CASE WHEN EXISTS (
    SELECT 1 FROM mart.dq_results WHERE status = 'FAIL'
) THEN 'true' ELSE 'false' END AS has_failures \gset

\if :has_failures
    \echo Data quality checks failed; inspect mart.dq_results.
    \quit 1
\endif
