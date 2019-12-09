SET plpgsql.extra_warnings TO 'shadowed_variables';

GRANT CONNECT ON DATABASE :dbname TO administrator;

ALTER DATABASE :dbname OWNER TO kernel;
GRANT ALL PRIVILEGES ON DATABASE :dbname TO kernel;

\connect :dbname kernel

CREATE SCHEMA IF NOT EXISTS db AUTHORIZATION kernel;
CREATE SCHEMA IF NOT EXISTS kernel AUTHORIZATION kernel;
CREATE SCHEMA IF NOT EXISTS api AUTHORIZATION kernel;
CREATE SCHEMA IF NOT EXISTS ocpp AUTHORIZATION kernel;

\connect :dbname postgres

CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA kernel;

\connect :dbname kernel

\echo [M] Создание объектов в базе данных :dbname под kernel
\ir './kernel/kernel.conf'

GRANT USAGE ON SCHEMA kernel TO administrator;
GRANT USAGE ON SCHEMA kernel TO admin;

GRANT USAGE ON SCHEMA api TO daemon;
GRANT USAGE ON SCHEMA ocpp TO ocpp;

\connect :dbname admin

\echo [M] Ввод первоначальных данных в базе данных :dbname под admin
\ir './kernel/admin.sql'