\echo [M] Создание новой базы данных :dbname
\ir './kernel/database.sql'

ALTER DATABASE :dbname OWNER TO kernel;
GRANT ALL PRIVILEGES ON DATABASE :dbname TO kernel;

GRANT CONNECT ON DATABASE :dbname TO administrator;
