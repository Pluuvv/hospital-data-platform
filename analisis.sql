\echo === PER KONDISI
SELECT kondisi_medis, count(*) AS kunjungan, round(avg(length_of_stay),2) AS alos, round(avg(billing_amount),2) AS avg_tagihan FROM mart.v_kunjungan_detail GROUP BY 1 ORDER BY 2 DESC;
\echo === PER ASURANSI
SELECT asuransi, count(*) AS kunjungan, round(sum(billing_amount),2) AS pendapatan, round(avg(billing_amount),2) AS avg_tagihan FROM mart.v_kunjungan_detail GROUP BY 1 ORDER BY 3 DESC;
\echo === PER TIPE ADMISI
SELECT tipe_admisi, count(*) AS kunjungan, round(avg(wait_minutes),2) AS avg_tunggu, round(avg(length_of_stay),2) AS alos, round(avg(billing_amount),2) AS avg_tagihan FROM mart.v_kunjungan_detail GROUP BY 1 ORDER BY 3 DESC;
\echo === PER TAHUN
SELECT tahun, count(*) AS kunjungan, round(sum(billing_amount),2) AS pendapatan FROM mart.v_kunjungan_detail GROUP BY 1 ORDER BY 1;
\echo === KELOMPOK UMUR x GENDER
SELECT kelompok_umur, jenis_kelamin, count(*) AS kunjungan FROM mart.v_kunjungan_detail GROUP BY 1,2 ORDER BY 1,2;
\echo === OKUPANSI
SELECT round(avg(okupansi_pct)::numeric,2) AS rata2, round(min(okupansi_pct)::numeric,2) AS minimum, round(max(okupansi_pct)::numeric,2) AS maksimum, min(tanggal) AS dari, max(tanggal) AS sampai FROM mart.kpi_okupansi_harian;
\echo === KUNJUNGAN PER BULAN (3 tertinggi lalu 3 terendah)
(SELECT tahun_bulan, count(*) AS kunjungan FROM mart.v_kunjungan_detail GROUP BY 1 ORDER BY 2 DESC LIMIT 3)
UNION ALL
(SELECT tahun_bulan, count(*) FROM mart.v_kunjungan_detail GROUP BY 1 ORDER BY 2 ASC LIMIT 3);
\echo === REKONSILIASI (Tabel 3.3)
SELECT (SELECT count(*) FROM mart.v_kunjungan_detail) AS total_kunjungan, (SELECT sum(billing_amount) FROM mart.v_kunjungan_detail) AS total_pendapatan, (SELECT round(avg(billing_amount),2) FROM mart.v_kunjungan_detail) AS avg_tagihan, (SELECT round(avg(length_of_stay),2) FROM mart.v_kunjungan_detail) AS alos, (SELECT round(avg(wait_minutes),2) FROM mart.v_kunjungan_detail) AS avg_tunggu, (SELECT round(avg(okupansi_pct)::numeric,2) FROM mart.kpi_okupansi_harian) AS bor;
