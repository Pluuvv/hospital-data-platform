DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_manajemen') THEN CREATE ROLE role_manajemen NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_analyst')   THEN CREATE ROLE role_analyst NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_dwh_admin') THEN CREATE ROLE role_dwh_admin NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'u_manajemen') THEN CREATE ROLE u_manajemen LOGIN PASSWORD 'GantiPass123' IN ROLE role_manajemen; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'u_analyst')   THEN CREATE ROLE u_analyst LOGIN PASSWORD 'GantiPass123' IN ROLE role_analyst; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'u_admin')     THEN CREATE ROLE u_admin LOGIN PASSWORD 'GantiPass123' IN ROLE role_dwh_admin; END IF;
END $$;

REVOKE ALL ON SCHEMA stg, dw, mart FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA stg, dw, mart FROM PUBLIC;

-- Manajemen: hanya baca mart
GRANT USAGE ON SCHEMA mart TO role_manajemen;
GRANT SELECT ON ALL TABLES IN SCHEMA mart TO role_manajemen;
ALTER DEFAULT PRIVILEGES IN SCHEMA mart GRANT SELECT ON TABLES TO role_manajemen;

-- Analyst: mart + dw tanpa dim_patient asli (hanya view ter-mask)
GRANT role_manajemen TO role_analyst;
GRANT USAGE ON SCHEMA dw TO role_analyst;
GRANT SELECT ON dw.fact_kunjungan, dw.dim_date, dw.dim_condition, dw.dim_admission_type, dw.dim_insurance, dw.v_dim_patient_masked TO role_analyst;

-- Admin: akses penuh
GRANT ALL ON SCHEMA stg, dw, mart TO role_dwh_admin;
GRANT ALL ON ALL TABLES IN SCHEMA stg, dw, mart TO role_dwh_admin;
