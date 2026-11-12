CREATE SCHEMA IF NOT EXISTS dw;

CREATE TABLE IF NOT EXISTS dw.dim_date (
  date_key int PRIMARY KEY, full_date date UNIQUE NOT NULL,
  year int, quarter int, month int, month_name text,
  day int, weekday int, weekday_name text, is_weekend boolean
);
CREATE TABLE IF NOT EXISTS dw.dim_patient (
  patient_key serial PRIMARY KEY, name text, age int, gender text, blood_type text
);
CREATE TABLE IF NOT EXISTS dw.dim_condition (
  condition_key serial PRIMARY KEY, medical_condition text UNIQUE NOT NULL
);
CREATE TABLE IF NOT EXISTS dw.dim_admission_type (
  admission_type_key serial PRIMARY KEY, admission_type text UNIQUE NOT NULL
);
CREATE TABLE IF NOT EXISTS dw.dim_insurance (
  insurance_key serial PRIMARY KEY, insurance_provider text UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS dw.fact_kunjungan (
  admission_id bigserial PRIMARY KEY,
  patient_key int REFERENCES dw.dim_patient(patient_key),
  admission_date_key int REFERENCES dw.dim_date(date_key),
  discharge_date_key int REFERENCES dw.dim_date(date_key),
  condition_key int REFERENCES dw.dim_condition(condition_key),
  admission_type_key int REFERENCES dw.dim_admission_type(admission_type_key),
  insurance_key int REFERENCES dw.dim_insurance(insurance_key),
  doctor text, hospital text, room_number int,
  medication text, test_results text,
  length_of_stay int, wait_minutes int, billing_amount numeric(12,2)
);
