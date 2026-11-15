-- Run this compatibility entry point with psql; the canonical checks live in dq_checks_pg.sql.
\set ON_ERROR_STOP on
\ir dq_checks_pg.sql
