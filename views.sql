CREATE OR REPLACE VIEW mart.v_kunjungan_detail AS
SELECT
  f.admission_id,
  d.full_date            AS tanggal_masuk,
  d.year                 AS tahun,
  d.month                AS bulan,
  to_char(d.full_date, 'YYYY-MM') AS tahun_bulan,
  c.medical_condition    AS kondisi_medis,
  a.admission_type       AS tipe_admisi,
  i.insurance_provider   AS asuransi,
  p.gender               AS jenis_kelamin,
  CASE
    WHEN p.age < 18 THEN '0-17'
    WHEN p.age < 35 THEN '18-34'
    WHEN p.age < 50 THEN '35-49'
    WHEN p.age < 65 THEN '50-64'
    ELSE '65+'
  END                    AS kelompok_umur,
  f.length_of_stay,
  f.wait_minutes,
  f.billing_amount
FROM dw.fact_kunjungan f
JOIN dw.dim_date           d ON d.date_key           = f.admission_date_key
JOIN dw.dim_condition      c ON c.condition_key      = f.condition_key
JOIN dw.dim_admission_type a ON a.admission_type_key = f.admission_type_key
JOIN dw.dim_insurance      i ON i.insurance_key      = f.insurance_key
JOIN dw.dim_patient        p ON p.patient_key        = f.patient_key;

CREATE OR REPLACE VIEW dw.v_dim_patient_masked AS
SELECT
  patient_key,
  left(md5('hospital_salt_m4' || name), 10) AS patient_hash,
  CASE
    WHEN age < 18 THEN '0-17'
    WHEN age < 35 THEN '18-34'
    WHEN age < 50 THEN '35-49'
    WHEN age < 65 THEN '50-64'
    ELSE '65+'
  END AS kelompok_umur,
  gender,
  blood_type
FROM dw.dim_patient;
