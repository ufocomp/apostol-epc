\echo [M] Создание новой базы данных :dbname
\ir './kernel/database.sql'

\echo [M] Создание пользователей kernel, admin и daemon
\ir './kernel/users.sql'
