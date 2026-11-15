import os
import sys
from datetime import datetime

import psycopg2
from dotenv import load_dotenv

load_dotenv()

DDL_DQ_RESULTS = """
CREATE TABLE IF NOT EXISTS mart.dq_results (
    check_name text NOT NULL,
    layer text NOT NULL,
    expected numeric NOT NULL,
    actual numeric NOT NULL,
    status text NOT NULL,
    run_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
"""

DQ_CHECKS = [
    {
        "check_name": "Jumlah baris staging (stg.healthcare_raw)",
        "layer": "stg.healthcare_raw",
        "query": """
            SELECT 55500::numeric, COUNT(*)::numeric
            FROM stg.healthcare_raw;
        """,
    },
    {
        "check_name": "Jumlah baris fact_kunjungan",
        "layer": "dw.fact_kunjungan",
        "query": """
            SELECT 54860::numeric, COUNT(*)::numeric
            FROM dw.fact_kunjungan;
        """,
    },
    {
        "check_name": "Baris dibuang saat cleansing (staging - fact)",
        "layer": "dw.fact_kunjungan",
        "query": """
            SELECT 640::numeric,
                   (SELECT COUNT(*) FROM stg.healthcare_raw)
                     - (SELECT COUNT(*) FROM dw.fact_kunjungan);
        """,
    },
    {
        "check_name": "Foreign key kosong di fact",
        "layer": "dw.fact_kunjungan",
        "query": """
            SELECT 0::numeric, COUNT(*)::numeric
            FROM dw.fact_kunjungan
            WHERE admission_id IS NULL
               OR patient_key IS NULL
               OR admission_date_key IS NULL
               OR discharge_date_key IS NULL
               OR condition_key IS NULL
               OR admission_type_key IS NULL
               OR insurance_key IS NULL;
        """,
    },
    {
        "check_name": "Orphan foreign key (fact tanpa dimensi)",
        "layer": "dw.fact_kunjungan",
        "query": """
            SELECT 0::numeric, COUNT(*)::numeric
            FROM dw.fact_kunjungan f
            WHERE NOT EXISTS (SELECT 1 FROM dw.dim_patient p WHERE p.patient_key = f.patient_key)
               OR NOT EXISTS (SELECT 1 FROM dw.dim_date d WHERE d.date_key = f.admission_date_key)
               OR NOT EXISTS (SELECT 1 FROM dw.dim_date d WHERE d.date_key = f.discharge_date_key)
               OR NOT EXISTS (SELECT 1 FROM dw.dim_condition c WHERE c.condition_key = f.condition_key)
               OR NOT EXISTS (SELECT 1 FROM dw.dim_admission_type a WHERE a.admission_type_key = f.admission_type_key)
               OR NOT EXISTS (SELECT 1 FROM dw.dim_insurance i WHERE i.insurance_key = f.insurance_key);
        """,
    },
    {
        "check_name": "Grup baris duplikat di fact",
        "layer": "dw.fact_kunjungan",
        "query": """
            SELECT 0::numeric, COUNT(*)::numeric
            FROM (
                SELECT 1
                FROM dw.fact_kunjungan
                GROUP BY patient_key, admission_date_key, discharge_date_key,
                         condition_key, admission_type_key, insurance_key, doctor,
                         hospital, room_number, medication, test_results, billing_amount
                HAVING COUNT(*) > 1
            ) AS duplicate_groups;
        """,
    },
    {
        "check_name": "Billing negatif di fact",
        "layer": "dw.fact_kunjungan",
        "query": """
            SELECT 0::numeric, COUNT(*)::numeric
            FROM dw.fact_kunjungan
            WHERE billing_amount < 0;
        """,
    },
    {
        "check_name": "wait_minutes kosong",
        "layer": "dw.fact_kunjungan",
        "query": """
            SELECT 0::numeric, COUNT(*)::numeric
            FROM dw.fact_kunjungan
            WHERE wait_minutes IS NULL;
        """,
    },
    {
        "check_name": "wait_minutes di luar rentang tipe admisi",
        "layer": "dw.fact_kunjungan",
        "query": """
            SELECT 0::numeric, COUNT(*)::numeric
            FROM dw.fact_kunjungan f
            JOIN dw.dim_admission_type a ON a.admission_type_key = f.admission_type_key
            WHERE CASE LOWER(COALESCE(a.admission_type, ''))
                      WHEN 'emergency' THEN f.wait_minutes NOT BETWEEN 5 AND 40
                      WHEN 'urgent' THEN f.wait_minutes NOT BETWEEN 15 AND 90
                      WHEN 'elective' THEN f.wait_minutes NOT BETWEEN 30 AND 180
                      ELSE TRUE
                  END;
        """,
    },
    {
        "check_name": "length_of_stay di luar 1-30 hari",
        "layer": "dw.fact_kunjungan",
        "query": """
            SELECT 0::numeric, COUNT(*)::numeric
            FROM dw.fact_kunjungan
            WHERE length_of_stay IS NULL OR length_of_stay NOT BETWEEN 1 AND 30;
        """,
    },
    {
        "check_name": "Tanggal keluar lebih awal dari tanggal masuk",
        "layer": "dw.fact_kunjungan",
        "query": """
            SELECT 0::numeric, COUNT(*)::numeric
            FROM dw.fact_kunjungan f
            JOIN dw.dim_date admission_date ON admission_date.date_key = f.admission_date_key
            JOIN dw.dim_date discharge_date ON discharge_date.date_key = f.discharge_date_key
            WHERE discharge_date.full_date < admission_date.full_date;
        """,
    },
    {
        "check_name": "Total kunjungan mart = fact",
        "layer": "mart.kpi_kunjungan_bulanan",
        "query": """
            SELECT (SELECT COUNT(*)::numeric FROM dw.fact_kunjungan),
                   COALESCE(SUM(jumlah_kunjungan), 0)::numeric
            FROM mart.kpi_kunjungan_bulanan;
        """,
    },
    {
        "check_name": "Total pendapatan mart = fact",
        "layer": "mart.kpi_pendapatan_bulanan",
        "query": """
            SELECT (SELECT COALESCE(SUM(billing_amount), 0)::numeric
                    FROM dw.fact_kunjungan),
                   (SELECT COALESCE(ROUND(SUM(total_pendapatan)::numeric, 2), 0)::numeric
                    FROM mart.kpi_pendapatan_bulanan);
        """,
    },
    {
        "check_name": "Rata-rata waktu tunggu mart = fact",
        "layer": "mart.kpi_waktu_tunggu",
        "query": """
            SELECT (SELECT COALESCE(ROUND(AVG(wait_minutes)::numeric, 2), 0)::numeric
                    FROM dw.fact_kunjungan),
                   (SELECT CASE WHEN COALESCE(SUM(jumlah_kunjungan), 0) = 0 THEN 0::numeric
                                ELSE ROUND(SUM(total_menit_tunggu)::numeric / SUM(jumlah_kunjungan), 2)
                           END
                    FROM mart.kpi_waktu_tunggu);
        """,
    },
    {
        "check_name": "Okupansi di luar 0-100 persen",
        "layer": "mart.kpi_okupansi_harian",
        "query": """
            SELECT 0::numeric, COUNT(*)::numeric
            FROM mart.kpi_okupansi_harian
            WHERE okupansi_pct IS NULL OR okupansi_pct < 0 OR okupansi_pct > 100;
        """,
    },
    {
        "check_name": "Billing negatif di staging (data mentah)",
        "layer": "stg.healthcare_raw",
        "query": """
            SELECT 108::numeric, COUNT(*)::numeric
            FROM stg.healthcare_raw
            WHERE billing_amount < 0;
        """,
    },
]


def get_connection():
    required = ("DB_HOST", "DB_USER", "DB_PASS")
    missing = [name for name in required if not os.getenv(name)]
    if missing:
        raise ValueError(
            "Missing environment variables: "
            + ", ".join(missing)
            + ". Copy .env.example to .env and fill in the database settings."
        )

    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=os.getenv("DB_PORT", "5433"),
        dbname=os.getenv("DB_NAME", "hospital_dw"),
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASS"],
        sslmode=os.getenv("DB_SSLMODE", "prefer"),
    )


def run_dq_checks():
    conn = None
    try:
        conn = get_connection()
        with conn:
            with conn.cursor() as cur:
                cur.execute(DDL_DQ_RESULTS)
                cur.execute("TRUNCATE TABLE mart.dq_results;")

                run_timestamp = datetime.now()
                results = []
                for check in DQ_CHECKS:
                    cur.execute(check["query"])
                    expected, actual = cur.fetchone()
                    status = "PASS" if actual == expected else "FAIL"

                    cur.execute(
                        """
                        INSERT INTO mart.dq_results
                            (check_name, layer, expected, actual, status, run_at)
                        VALUES (%s, %s, %s, %s, %s, %s);
                        """,
                        (
                            check["check_name"],
                            check["layer"],
                            expected,
                            actual,
                            status,
                            run_timestamp,
                        ),
                    )
                    results.append((check["check_name"], expected, actual, status))

        print(f"\n=== HASIL DATA QUALITY CHECK ({run_timestamp:%Y-%m-%d %H:%M:%S}) ===")
        print(f"{'CHECK NAME':<48} | {'EXPECTED':>12} | {'ACTUAL':>12} | {'STATUS':<6}")
        print("-" * 88)
        for name, expected, actual, status in results:
            print(f"{name:<48} | {str(expected):>12} | {str(actual):>12} | {status:<6}")
        print("-" * 88)
        failed = sum(row[3] == "FAIL" for row in results)
        print(f"Total: {len(results)} checks; {len(results) - failed} PASS; {failed} FAIL.")
        return 1 if failed else 0
    except (psycopg2.Error, ValueError) as exc:
        print(f"[ERROR] Gagal menjalankan DQ checks: {exc}", file=sys.stderr)
        return 1
    finally:
        if conn is not None:
            conn.close()


if __name__ == "__main__":
    raise SystemExit(run_dq_checks())
