CREATE TABLE IF NOT EXISTS stg.simrs_kunjungan (
  name text, age int, gender text, blood_type text,
  medical_condition text, date_of_admission date, doctor text,
  hospital text, insurance_provider text, billing_amount numeric(12,2),
  room_number int, admission_type text, discharge_date date,
  medication text, test_results text,
  load_timestamp timestamp DEFAULT now(),
  source_system text DEFAULT 'simrs_oltp'
);
