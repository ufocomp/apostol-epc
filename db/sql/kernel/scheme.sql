CREATE SCHEMA IF NOT EXISTS db AUTHORIZATION kernel;
CREATE SCHEMA IF NOT EXISTS kernel AUTHORIZATION kernel;
CREATE SCHEMA IF NOT EXISTS registry AUTHORIZATION kernel;
CREATE SCHEMA IF NOT EXISTS api AUTHORIZATION kernel;
CREATE SCHEMA IF NOT EXISTS daemon AUTHORIZATION kernel;

CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA kernel;
CREATE EXTENSION IF NOT EXISTS pgjwt SCHEMA kernel;

GRANT USAGE ON SCHEMA kernel TO administrator;
GRANT USAGE ON SCHEMA registry TO administrator;
GRANT USAGE ON SCHEMA api TO administrator;
GRANT USAGE ON SCHEMA daemon TO daemon;