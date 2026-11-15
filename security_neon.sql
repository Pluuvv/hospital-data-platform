CREATE ROLE role_manajemen NOLOGIN;
CREATE ROLE role_analyst NOLOGIN;
CREATE ROLE role_dwh_admin NOLOGIN;

CREATE ROLE u_manajemen LOGIN PASSWORD :'pwd';
GRANT role_manajemen TO u_manajemen;

REVOKE ALL ON SCHEMA dw, mart FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA dw, mart FROM PUBLIC;

GRANT USAGE ON SCHEMA mart TO role_manajemen, role_analyst, role_dwh_admin;
GRANT SELECT ON ALL TABLES IN SCHEMA mart TO role_manajemen, role_analyst;

GRANT USAGE ON SCHEMA dw TO role_analyst, role_dwh_admin;
GRANT SELECT ON dw.fact_kunjungan, dw.dim_date, dw.dim_condition,
  dw.dim_admission_type, dw.dim_insurance, dw.v_dim_patient_masked TO role_analyst;

GRANT ALL ON ALL TABLES IN SCHEMA dw, mart TO role_dwh_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA mart GRANT SELECT ON TABLES TO role_manajemen, role_analyst;
