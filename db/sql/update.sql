\connect :dbname kernel

DROP SCHEMA IF EXISTS api CASCADE;

CREATE SCHEMA IF NOT EXISTS api AUTHORIZATION kernel;

\echo [M] Повторное создание объектов в базе данных :dbname для схем (api)

\ir './kernel/api_log.sql'
\ir './kernel/api.sql'
\ir './kernel/api_run.sql'

GRANT USAGE ON SCHEMA api TO daemon;
