--------------------------------------------------------------------------------
-- SECURITY --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.language -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.language (
    id		    numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code	    varchar(30) NOT NULL,
    name	    varchar(50) NOT NULL,
    description	text
);

COMMENT ON TABLE db.language IS 'Язык.';

COMMENT ON COLUMN db.language.id IS 'Идентификатор';
COMMENT ON COLUMN db.language.code IS 'Код';
COMMENT ON COLUMN db.language.name IS 'Наименование';
COMMENT ON COLUMN db.language.description IS 'Описание';

CREATE UNIQUE INDEX idx_system_language_code ON db.language(code);

INSERT INTO db.language (code, name, description) VALUES ('ru', 'Русский', 'Русский язык');
INSERT INTO db.language (code, name, description) VALUES ('en', 'English', 'English');

--------------------------------------------------------------------------------
-- language --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW language
as
  SELECT * FROM db.language;

GRANT SELECT ON language TO administrator;

--------------------------------------------------------------------------------
-- db.user ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.user (
    id			        numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_USER'),
    type		        char NOT NULL,
    username            varchar(50) NOT NULL,
    fullname            text,
    phone               text,
    email               text,
    description         text,
    status              bit(4) DEFAULT B'0001' NOT NULL,
    created             timestamp DEFAULT NOW() NOT NULL,
    lock_date           timestamp DEFAULT NULL,
    expiry_date         timestamp DEFAULT NULL,
    pswhash             text DEFAULT NULL,
    passwordchange      boolean DEFAULT true NOT NULL,
    passwordnotchange   boolean DEFAULT false NOT NULL,
    CONSTRAINT ch_user_type CHECK (type IN ('G', 'U'))
);

COMMENT ON TABLE db.user IS 'Пользователи и группы системы.';

COMMENT ON COLUMN db.user.id IS 'Идентификатор';
COMMENT ON COLUMN db.user.type IS 'Тип пользователя: "U" - пользователь; "G" - группа';
COMMENT ON COLUMN db.user.username IS 'Наименование пользователя (login)';
COMMENT ON COLUMN db.user.fullname IS 'Полное наименование пользователя';
COMMENT ON COLUMN db.user.phone IS 'Телефон';
COMMENT ON COLUMN db.user.email IS 'Электронный адрес';
COMMENT ON COLUMN db.user.description IS 'Описание пользователя';
COMMENT ON COLUMN db.user.status IS 'Статус пользователя';
COMMENT ON COLUMN db.user.created IS 'Дата создания пользователя';
COMMENT ON COLUMN db.user.lock_date IS 'Дата блокировки пользователя';
COMMENT ON COLUMN db.user.expiry_date IS 'Дата окончания срока действия пароля';
COMMENT ON COLUMN db.user.pswhash IS 'Хеш пароля';
COMMENT ON COLUMN db.user.passwordchange IS 'Сменить пароль при следующем входе в систему (да/нет)';
COMMENT ON COLUMN db.user.passwordnotchange IS 'Установлен запрет на смену пароля самим пользователем (да/нет)';

CREATE UNIQUE INDEX ON db.user (type, username);
CREATE UNIQUE INDEX ON db.user (phone);
CREATE UNIQUE INDEX ON db.user (email);

CREATE INDEX ON db.user (type);
CREATE INDEX ON db.user (username);
CREATE INDEX ON db.user (username varchar_pattern_ops);
CREATE INDEX ON db.user (phone varchar_pattern_ops);
CREATE INDEX ON db.user (email varchar_pattern_ops);

CREATE OR REPLACE FUNCTION db.ft_user_before_delete()
RETURNS trigger AS $$
BEGIN
  DELETE FROM db.iptable WHERE userid = OLD.ID;
  DELETE FROM db.profile WHERE userid = OLD.ID;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_user_before_delete
  BEFORE DELETE ON db.user
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_user_before_delete();

--------------------------------------------------------------------------------
-- db.profile ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.profile (
    userid              numeric(12) PRIMARY KEY,
    input_count         numeric DEFAULT 0 NOT NULL,
    input_last          timestamp DEFAULT NULL,
    input_error         numeric DEFAULT 0 NOT NULL,
    input_error_last    timestamp DEFAULT NULL,
    input_error_all     numeric DEFAULT 0 NOT NULL,
    lc_ip               inet,
    default_area        numeric(12),
    default_interface   numeric(12),
    state               bit(3) DEFAULT B'000' NOT NULL,
    session_limit       integer DEFAULT 0 NOT NULL,
    email_verified      bool DEFAULT false,
    phone_verified      bool DEFAULT false,
    picture             text,
    CONSTRAINT fk_profile_userid FOREIGN KEY (userid) REFERENCES db.user(id)
);

COMMENT ON TABLE db.profile IS 'Дополнительная информация о пользователе системы.';

COMMENT ON COLUMN db.profile.userid IS 'Пользователь';
COMMENT ON COLUMN db.profile.input_count IS 'Счетчик входов';
COMMENT ON COLUMN db.profile.input_last IS 'Последний вход';
COMMENT ON COLUMN db.profile.input_error IS 'Текущие неудавшиеся входы';
COMMENT ON COLUMN db.profile.input_error_last IS 'Последний неудавшийся вход в систему';
COMMENT ON COLUMN db.profile.input_error_all IS 'Общее количество неудачных входов';
COMMENT ON COLUMN db.profile.lc_ip IS 'IP адрес последнего подключения';
COMMENT ON COLUMN db.profile.default_area IS 'Идентификатор подразделения по умолчанию';
COMMENT ON COLUMN db.profile.default_interface IS 'Идентификатор рабочего места по умолчанию';
COMMENT ON COLUMN db.profile.state IS 'Состояние: 000 - Отключен; 001 - Подключен; 010 - локальный IP; 100 - доверительный IP';
COMMENT ON COLUMN db.profile.session_limit IS 'Максимально допустимое количество одновременно открытых сессий.';
COMMENT ON COLUMN db.profile.email_verified IS 'Электронный адрес подтверждён.';
COMMENT ON COLUMN db.profile.phone_verified IS 'Телефон адрес подтверждён.';
COMMENT ON COLUMN db.profile.picture IS 'Логотип.';

--------------------------------------------------------------------------------
-- db.provider -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.provider (
    id          numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    type        char NOT NULL,
    code        text NOT NULL,
    name        text
);

COMMENT ON TABLE db.provider IS 'Поставщик.';

COMMENT ON COLUMN db.provider.id IS 'Идентификатор';
COMMENT ON COLUMN db.provider.type IS 'Тип: "I" - внутренний; "E" - внешний';
COMMENT ON COLUMN db.provider.code IS 'Код';
COMMENT ON COLUMN db.provider.name IS 'Наименование';

CREATE UNIQUE INDEX ON db.provider (type, code);

CREATE INDEX ON db.provider (type);
CREATE INDEX ON db.provider (code);
CREATE INDEX ON db.provider (code text_pattern_ops);

--------------------------------------------------------------------------------
-- VIEW Provider ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Provider
AS
  SELECT * FROM db.provider;

GRANT SELECT ON Provider TO administrator;

--------------------------------------------------------------------------------
-- AddProvider -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddProvider (
  pType		    char,
  pCode		    varchar,
  pName		    varchar DEFAULT null
) RETURNS 	    numeric
AS $$
DECLARE
  nId		    numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.provider (type, code, name) VALUES (pType, pCode, pName)
  RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetProvider --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetProvider (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.provider WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetProviderCode ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetProviderCode (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM db.provider WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.issuer -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.issuer (
    id          numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    provider    numeric(12) NOT NULL,
    code        text NOT NULL,
    name        text,
    CONSTRAINT fk_issuer_provider FOREIGN KEY (provider) REFERENCES db.provider(id)
);

COMMENT ON TABLE db.issuer IS 'Издатель.';

COMMENT ON COLUMN db.issuer.id IS 'Идентификатор';
COMMENT ON COLUMN db.issuer.provider IS 'Поставщик';
COMMENT ON COLUMN db.issuer.code IS 'Код';
COMMENT ON COLUMN db.issuer.name IS 'Наименование';

CREATE UNIQUE INDEX ON db.issuer (provider, code);

CREATE INDEX ON db.issuer (provider);
CREATE INDEX ON db.issuer (code);
CREATE INDEX ON db.issuer (code text_pattern_ops);

--------------------------------------------------------------------------------
-- VIEW Issuer -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Issuer
AS
  SELECT * FROM db.issuer;

GRANT SELECT ON Issuer TO administrator;

--------------------------------------------------------------------------------
-- AddIssuer -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddIssuer (
  pProvider     numeric,
  pCode		    varchar,
  pName		    varchar
) RETURNS 	    numeric
AS $$
DECLARE
  nId		    numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.issuer (provider, code, name) VALUES (pProvider, pCode, pName)
  RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetIssuer ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetIssuer (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.issuer WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetIssuerCode ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetIssuerCode (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM db.issuer WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.algorithm ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.algorithm (
    id          numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code        text NOT NULL,
    name        text
);

COMMENT ON TABLE db.algorithm IS 'Алгоритмы хеширования.';

COMMENT ON COLUMN db.algorithm.id IS 'Идентификатор';
COMMENT ON COLUMN db.algorithm.code IS 'Код';
COMMENT ON COLUMN db.algorithm.name IS 'Наименование (как в pgcrypto)';

CREATE INDEX ON db.algorithm (code);

--------------------------------------------------------------------------------
-- VIEW Algorithm --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Algorithm
AS
  SELECT * FROM db.algorithm;

GRANT SELECT ON Algorithm TO administrator;

--------------------------------------------------------------------------------
-- AddAlgorithm ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddAlgorithm (
  pCode		    varchar,
  pName		    varchar
) RETURNS 	    numeric
AS $$
DECLARE
  nId		    numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.algorithm (code, name) VALUES (pCode, pName)
  RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAlgorithm -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAlgorithm (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.algorithm WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAlgorithmCode ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAlgorithmCode (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM db.algorithm WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAlgorithmName ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAlgorithmName (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vName		text;
BEGIN
  SELECT name INTO vName FROM db.algorithm WHERE id = pId;
  RETURN vName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.audience -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.audience (
    id          numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    provider    numeric(12) NOT NULL,
    algorithm   numeric(12) NOT NULL,
    code        text NOT NULL,
    secret      text NOT NULL,
    name        text,
    CONSTRAINT fk_audience_provider FOREIGN KEY (provider) REFERENCES db.provider(id)
);

COMMENT ON TABLE db.audience IS 'Аудитория.';

COMMENT ON COLUMN db.audience.id IS 'Идентификатор';
COMMENT ON COLUMN db.audience.provider IS 'Поставщик';
COMMENT ON COLUMN db.audience.algorithm IS 'Алгоритм хеширования';
COMMENT ON COLUMN db.audience.code IS 'Код';
COMMENT ON COLUMN db.audience.secret IS 'Секрет';
COMMENT ON COLUMN db.audience.name IS 'Наименование';

CREATE UNIQUE INDEX ON db.audience (provider, code);

CREATE INDEX ON db.audience (provider);
CREATE INDEX ON db.audience (code);
CREATE INDEX ON db.audience (code text_pattern_ops);

--------------------------------------------------------------------------------
-- VIEW Audience ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Audience
AS
  SELECT * FROM db.audience;

GRANT SELECT ON Audience TO administrator;

--------------------------------------------------------------------------------
-- CreateAudience --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateAudience (
  pProvider     numeric,
  pAlgorithm    numeric,
  pCode		    text,
  pSecret       text,
  pName		    text DEFAULT null
) RETURNS 	    numeric
AS $$
DECLARE
  nId		    numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.audience (provider, algorithm, code, secret, name) VALUES (pProvider, pAlgorithm, pCode, pSecret, pName)
  RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAudience --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAudience (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.audience WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAudienceCode ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAudienceCode (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM db.audience WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.auth ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.auth (
    id          numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    userId      numeric(12) NOT NULL,
    audience    numeric(12) NOT NULL,
    code        text NOT NULL,
    created     timestamp DEFAULT NOW() NOT NULL,
    CONSTRAINT fk_auth_userid FOREIGN KEY (userid) REFERENCES db.user(id),
    CONSTRAINT fk_auth_audience FOREIGN KEY (audience) REFERENCES db.audience(id)
);

COMMENT ON TABLE db.auth IS 'Авторизаия пользователей из внешних систем.';

COMMENT ON COLUMN db.auth.id IS 'Идентификатор';
COMMENT ON COLUMN db.auth.userId IS 'Пользователь';
COMMENT ON COLUMN db.auth.audience IS 'Аудитория';
COMMENT ON COLUMN db.auth.code IS 'Идентификатор внешнего пользователя';
COMMENT ON COLUMN db.auth.created IS 'Дата создания';

CREATE UNIQUE INDEX ON db.auth (audience, code);

CREATE INDEX ON db.auth (userId);
CREATE INDEX ON db.auth (audience);
CREATE INDEX ON db.auth (code);

--------------------------------------------------------------------------------
-- VIEW Auth -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Auth
AS
  SELECT * FROM db.auth;

GRANT SELECT ON Auth TO administrator;

--------------------------------------------------------------------------------
-- CreateAuth ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateAuth (
  pUserId       numeric,
  pAudience     numeric,
  pCode		    varchar
) RETURNS 	    numeric
AS $$
DECLARE
  nId		    numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.auth (userId, audience, code) VALUES (pUserId, pAudience, pCode)
  RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAuth ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAuth (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.auth WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- TABLE db.iptable ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.iptable (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    type		char DEFAULT 'A' NOT NULL,
    userid		numeric(12) NOT NULL,
    addr		inet NOT NULL,
    range		int,
    CONSTRAINT ch_ip_table_type CHECK (type IN ('A', 'D')),
    CONSTRAINT ch_ip_table_range CHECK (range BETWEEN 1 AND 255),
    CONSTRAINT fk_ip_table_userid FOREIGN KEY (userid) REFERENCES db.user(id)
);

COMMENT ON TABLE db.iptable IS 'Таблица IP адресов.';

COMMENT ON COLUMN db.iptable.id IS 'Идентификатор';
COMMENT ON COLUMN db.iptable.type IS 'Тип: A - allow; D - denied';
COMMENT ON COLUMN db.iptable.userid IS 'Пользователь';
COMMENT ON COLUMN db.iptable.addr IS 'IP-адрес';
COMMENT ON COLUMN db.iptable.range IS 'Диапазон. Количество адресов.';

CREATE INDEX idx_ip_table_type ON db.iptable (type);
CREATE INDEX idx_ip_table_userid ON db.iptable (userid);

--------------------------------------------------------------------------------
-- VIEW iptable ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW iptable (Id, Type, UserId, Addr, Range)
AS
  SELECT id, type, userid, addr, range
    FROM db.iptable;

GRANT SELECT ON iptable TO administrator;

--------------------------------------------------------------------------------
-- GetIPTableStr ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetIPTableStr (
  pUserId	numeric,
  pType		char DEFAULT 'A'
) RETURNS	text
AS $$
DECLARE
  r		    record;
  ip		integer[4];
  vHost		text;
  aResult	text[];
BEGIN
  FOR r IN SELECT * FROM db.iptable WHERE userid = pUserId AND type = pType
  LOOP
    IF r.range IS NOT NULL THEN
      vHost := host(r.addr) || '-' || host(r.addr + r.range - 1);
    ELSE
      CASE masklen(r.addr)
      WHEN 8 THEN
        ip := inet_to_array(r.addr);
        ip[1] := null;
        ip[2] := null;
        ip[3] := null;
        vHost := array_to_string(ip, '.', '*');
      WHEN 16 THEN
        ip := inet_to_array(r.addr);
        ip[2] := null;
        ip[3] := null;
        vHost := array_to_string(ip, '.', '*');
      WHEN 24 THEN
        ip := inet_to_array(r.addr);
        ip[3] := null;
        vHost := array_to_string(ip, '.', '*');
      WHEN 32 THEN
        vHost := host(r.addr);
      ELSE
        vHost := text(r.addr);
      END CASE;
    END IF;

    aResult := array_append(aResult, vHost);
  END LOOP;

  RETURN array_to_string(aResult, ', ');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetIPTableStr ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetIPTableStr (
  pUserId	numeric,
  pType		char,
  pIpTable	text
) RETURNS	void
AS $$
DECLARE
  i		    int;

  vStr		text;
  arrIp		text[];

  iHost		inet;
  nRange	int;
BEGIN
  pType := coalesce(pType, 'A');

  DELETE FROM db.iptable WHERE type = pType AND userid = pUserId;

  vStr := NULLIF(pIpTable, '');
  IF vStr IS NOT NULL THEN

    arrIp := string_to_array_trim(vStr, ',');

    FOR i IN 1..array_length(arrIp, 1)
    LOOP
      SELECT host, range INTO iHost, nRange FROM str_to_inet(arrIp[i]);

      INSERT INTO db.iptable (type, userid, addr, range)
      VALUES (pType, pUserId, iHost, nRange);
    END LOOP;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckIPTable ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckIPTable (
  pUserId	numeric,
  pType		char,
  pHost		inet
) RETURNS	boolean
AS $$
DECLARE
  r		    record;
  passed	boolean;
BEGIN
  FOR r IN SELECT * FROM db.iptable WHERE type = pType AND userid = pUserId
  LOOP
    IF r.range IS NOT NULL THEN
      passed := (pHost >= r.addr) AND (pHost <= r.addr + (r.range - 1));
    ELSE
      passed := pHost <<= r.addr;
    END IF;

    EXIT WHEN coalesce(passed, false);
  END LOOP;

  RETURN passed;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckIPTable ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckIPTable (
  pUserId	numeric,
  pHost		inet
) RETURNS	boolean
AS $$
DECLARE
  denied	boolean;
  allow		boolean;
BEGIN
  denied := coalesce(CheckIPTable(pUserId, 'D', pHost), false);

  IF NOT denied THEN
    allow := coalesce(CheckIPTable(pUserId, 'A', pHost), true);
  ELSE
    allow := NOT denied;
  END IF;

  IF NOT allow THEN
    PERFORM SetErrorMessage('Ограничен доступ по IP-адресу.');
  END IF;

  RETURN allow;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckSessionLimit -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckSessionLimit (
  pUserId	numeric
) RETURNS	void
AS $$
DECLARE
  nCount	integer;
  nLimit	integer;

  r		    record;
BEGIN
  SELECT session_limit INTO nLimit FROM db.profile WHERE userid = pUserId;

  IF coalesce(nLimit, 0) > 0 THEN

    SELECT count(*) INTO nCount FROM db.session WHERE userid = pUserId;

    FOR r IN SELECT key FROM db.session WHERE userid = pUserId ORDER BY created
    LOOP
      EXIT WHEN nCount = 0;
      EXIT WHEN nCount < nLimit;

      PERFORM SessionOut(r.key, false, 'Превышен лимит.');

      nCount := nCount - 1;
    END LOOP;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- users -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW users (Id, UserName, FullName, Phone, Email, Description,
  PasswordChange, PasswordNotChange, Status, CDate, LDate, EDate, System,
  InputCount, InputLast, InputError, InputErrorLast, InputErrorAll, lcip,
  LoginStatus, SessionLimit
)
AS
  SELECT u.id, u.username, u.fullname, u.phone, u.email, u.description,
         u.passwordchange, u.passwordnotchange,
         CASE
         WHEN u.status & B'1100' = B'1100' THEN 'expired & locked'
         WHEN u.status & B'1000' = B'1000' THEN 'expired'
         WHEN u.status & B'0100' = B'0100' THEN 'locked'
         WHEN u.status & B'0010' = B'0010' THEN 'active'
         WHEN u.status & B'0001' = B'0001' THEN 'open'
         ELSE 'undefined'
         END,
         u.created, u.lock_date, u.expiry_date,
         CASE (SELECT p.rolname FROM pg_roles p WHERE p.rolname = lower(u.username))
         WHEN u.username THEN 'yes'
         ELSE 'no'
         END,
         p.input_count, p.input_last, p.input_error, p.input_error_last, p.input_error_all,
         p.lc_ip,
         CASE
         WHEN p.state & B'111' = B'111' THEN 'online (all)'
         WHEN p.state & B'110' = B'110' THEN 'online (local & trust)'
         WHEN p.state & B'101' = B'101' THEN 'online (ext & trust)'
         WHEN p.state & B'011' = B'011' THEN 'online (ext & local)'
         WHEN p.state & B'100' = B'100' THEN 'online (trust)'
         WHEN p.state & B'010' = B'010' THEN 'online (local)'
         WHEN p.state & B'001' = B'001' THEN 'online (ext)'
         ELSE 'offline'
         END,
         p.session_limit
    FROM db.user u INNER JOIN db.profile p on p.userid = u.id
   WHERE u.type = 'U';

GRANT SELECT ON users TO administrator;

--------------------------------------------------------------------------------
-- groups ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW groups (Id, UserName, FullName, Description, System)
AS
  SELECT u.id, u.username, u.fullname, u.description,
         CASE (SELECT p.rolname FROM pg_roles p WHERE p.rolname = lower(u.username))
         WHEN u.username THEN 'yes'
         ELSE 'no'
         END
    FROM db.user u
   WHERE u.type = 'G';

GRANT SELECT ON groups TO administrator;

--------------------------------------------------------------------------------
-- member_group ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.member_group (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    userid		numeric(12) NOT NULL,
    member		numeric(12) NOT NULL,
    CONSTRAINT fk_mg_userid FOREIGN KEY (userid) REFERENCES db.user(id),
    CONSTRAINT fk_mg_member FOREIGN KEY (member) REFERENCES db.user(id)
);

COMMENT ON TABLE db.member_group IS 'Членство в группах.';

COMMENT ON COLUMN db.member_group.id IS 'Идентификатор';
COMMENT ON COLUMN db.member_group.userid IS 'Группа';
COMMENT ON COLUMN db.member_group.member IS 'Участник';

CREATE INDEX ON db.member_group (userid);
CREATE INDEX ON db.member_group (member);

--------------------------------------------------------------------------------
-- MemberGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MemberGroup (Id, UserId, UserType, UserName, UserFullName, UserDesc,
  MemberId, MemberType, MemberName, MemberFullName, MemberDesc
)
AS
  SELECT mg.id, mg.userid,
         CASE g.type
         WHEN 'G' THEN 'group'
         WHEN 'U' THEN 'user'
         END, g.username, g.fullname, g.description,
         mg.member,
         CASE u.type
         WHEN 'G' THEN 'group'
         WHEN 'U' THEN 'user'
         END, u.username, u.fullname, u.description
    FROM db.member_group mg INNER JOIN db.user g ON g.id = mg.userid
                            INNER JOIN db.user u ON u.id = mg.member;

GRANT SELECT ON MemberGroup TO administrator;

--------------------------------------------------------------------------------
-- db.area_type ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.area_type (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code		varchar(30) NOT NULL,
    name		varchar(50)
);

COMMENT ON TABLE db.area_type IS 'Тип зоны.';

COMMENT ON COLUMN db.area_type.id IS 'Идентификатор';
COMMENT ON COLUMN db.area_type.code IS 'Код';
COMMENT ON COLUMN db.area_type.name IS 'Наименование';

CREATE UNIQUE INDEX ON db.area_type (code);

INSERT INTO db.area_type (code, name) VALUES ('root', 'Корень');
INSERT INTO db.area_type (code, name) VALUES ('default', 'По умолчанию');
INSERT INTO db.area_type (code, name) VALUES ('main', 'Головной офис');
INSERT INTO db.area_type (code, name) VALUES ('department', 'Подразделение');
INSERT INTO db.area_type (code, name) VALUES ('ship', 'Корабль');

--------------------------------------------------------------------------------
-- AreaType --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AreaType
AS
  SELECT * FROM db.area_type;

GRANT SELECT ON AreaType TO administrator;

--------------------------------------------------------------------------------
-- GetAreaType -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAreaType (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT Id INTO nId FROM db.area_type WHERE Code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.area ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.area (
    id              numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    parent          numeric(12) DEFAULT NULL,
    type            numeric(12) NOT NULL,
    code            varchar(30) NOT NULL,
    name            varchar(50) NOT NULL,
    description     text,
    validFromDate   timestamp DEFAULT NOW() NOT NULL,
    validToDate     timestamp,
    CONSTRAINT fk_area_parent FOREIGN KEY (parent) REFERENCES db.area(id),
    CONSTRAINT fk_area_type FOREIGN KEY (type) REFERENCES db.area_type(id)
);

COMMENT ON TABLE db.area IS 'Зона.';

COMMENT ON COLUMN db.area.id IS 'Идентификатор';
COMMENT ON COLUMN db.area.parent IS 'Ссылка на родительский узел';
COMMENT ON COLUMN db.area.type IS 'Тип';
COMMENT ON COLUMN db.area.code IS 'Код';
COMMENT ON COLUMN db.area.name IS 'Наименование';
COMMENT ON COLUMN db.area.description IS 'Описание';
COMMENT ON COLUMN db.area.validFromDate IS 'Дата начала действаия';
COMMENT ON COLUMN db.area.validToDate IS 'Дата окончания действия';

CREATE INDEX ON db.area (parent);
CREATE INDEX ON db.area (type);

CREATE UNIQUE INDEX ON db.area (code);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_area_before_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NEW.ID = NEW.PARENT THEN
    NEW.PARENT := GetArea('default');
  END IF;

  RAISE DEBUG 'Создана зона Id: %', NEW.ID;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_area_before_insert
  BEFORE INSERT ON db.area
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_area_before_insert();

--------------------------------------------------------------------------------
-- Area ------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Area (Id, Parent, Type, TypeCode, TypeName,
  Code, Name, Description, validFromDate, validToDate
)
as
  SELECT d.id, d.parent, d.type, t.code, t.name, d.code, d.name,
         d.description, d.validFromDate, d.validToDate
    FROM db.area d INNER JOIN db.area_type t ON t.id = d.type;

GRANT SELECT ON Area TO administrator;

--------------------------------------------------------------------------------
-- db.member_area --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.member_area (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    area		numeric(12) NOT NULL,
    member		numeric(12) NOT NULL,
    CONSTRAINT fk_md_area FOREIGN KEY (area) REFERENCES db.area(id),
    CONSTRAINT fk_md_member FOREIGN KEY (member) REFERENCES db.user(id)
);

COMMENT ON TABLE db.member_area IS 'Участники зоны.';

COMMENT ON COLUMN db.member_area.id IS 'Идентификатор';
COMMENT ON COLUMN db.member_area.area IS 'Подразделение';
COMMENT ON COLUMN db.member_area.member IS 'Участник';

CREATE INDEX ON db.member_area (area);
CREATE INDEX ON db.member_area (member);

CREATE UNIQUE INDEX ON db.member_area (area, member);

--------------------------------------------------------------------------------
-- MemberArea ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MemberArea (Id, Area, Code, Name, Description,
  MemberId, MemberType, MemberName, MemberFullName, MemberDesc
)
AS
  SELECT md.id, md.area, d.code, d.name, d.description,
         md.member, u.type, u.username, u.fullname, u.description
    FROM db.member_area md INNER JOIN db.area d ON d.id = md.area
                           INNER JOIN db.user u ON u.id = md.member;

GRANT SELECT ON MemberArea TO administrator;

--------------------------------------------------------------------------------
-- db.interface ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.interface (
    id              numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    sid             varchar(18) NOT NULL,
    name            varchar(50) NOT NULL,
    description		text
);

COMMENT ON TABLE db.interface IS 'Интерфейсы.';

COMMENT ON COLUMN db.interface.id IS 'Идентификатор';
COMMENT ON COLUMN db.interface.sid IS 'Строковый идентификатор';
COMMENT ON COLUMN db.interface.name IS 'Наименование';
COMMENT ON COLUMN db.interface.description IS 'Описание';

CREATE UNIQUE INDEX ON db.interface (sid);
CREATE INDEX ON db.interface (name);

CREATE OR REPLACE FUNCTION db.ft_interface()
RETURNS trigger AS $$
BEGIN
  IF NEW.SID IS NULL THEN
    SELECT 'I:1:1:' || TRIM(TO_CHAR(NEW.ID, '999999999999')) INTO NEW.SID;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_interface
  BEFORE INSERT ON db.interface
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_interface();

--------------------------------------------------------------------------------
-- Interface -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Interface
as
  SELECT * FROM db.interface;

GRANT SELECT ON Interface TO administrator;

--------------------------------------------------------------------------------
-- db.member_interface ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.member_interface (
    id          numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    interface   numeric(12) NOT NULL,
    member      numeric(12) NOT NULL,
    CONSTRAINT fk_mi_interface FOREIGN KEY (interface) REFERENCES db.interface(id),
    CONSTRAINT fk_mi_member FOREIGN KEY (member) REFERENCES db.user(id)
);

COMMENT ON TABLE db.member_interface IS 'Участники интерфеса.';

COMMENT ON COLUMN db.member_interface.id IS 'Идентификатор';
COMMENT ON COLUMN db.member_interface.interface IS 'Интерфейс';
COMMENT ON COLUMN db.member_interface.member IS 'Участник';

CREATE INDEX ON db.member_interface (interface);
CREATE INDEX ON db.member_interface (member);

CREATE UNIQUE INDEX ON db.member_interface (interface, member);

--------------------------------------------------------------------------------
-- MemberInterface -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MemberInterface (Id, Interface, SID, InterfaceName, InterfaceDesc,
  MemberId, MemberType, MemberName, MemberFullName, MemberDesc
)
AS
  SELECT mwp.id, mwp.interface, wp.sid, wp.name, wp.description,
         mwp.member, u.type, u.username, u.fullname, u.description
    FROM db.member_interface mwp INNER JOIN db.interface wp ON wp.id = mwp.interface
                                 INNER JOIN db.user u ON u.id = mwp.member;

GRANT SELECT ON MemberInterface TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION StrPwKey -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StrPwKey (
  pUserId	    numeric,
  pAgent        text,
  pCreated	    timestamp
) RETURNS	    text
AS $$
DECLARE
  vPswHash	    text;
  vStrPwKey	    text DEFAULT null;
BEGIN
  SELECT pswhash INTO vPswHash FROM db.user WHERE id = pUserId;

  IF found THEN
    vStrPwKey := '{' || IntToStr(pUserId) || '-' || vPswHash || '-' || encode(digest(pAgent, 'sha1'), 'hex') || '-' || current_database() || '-' || DateToStr(pCreated, 'YYYYMMDDHH24MISS') || '}';
  END IF;

  RETURN encode(digest(vStrPwKey, 'sha1'), 'hex');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION StrTokenKey --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StrTokenKey (
  pPrev         numeric,
  pSession      text,
  pSalt			text,
  pDateFrom     timestamp,
  pDateTo       timestamp DEFAULT MAXDATE()
) RETURNS	    text
AS $$
BEGIN
  RETURN encode(digest('{' || coalesce(IntToStr(pPrev), '000000000000') || '-' || pSession || '-' || pSalt || '-' || DateToStr(pDateFrom, 'YYYYMMDDHH24MISS') || '-' || (localtimestamp - pDateTo <= INTERVAL '5 second')::text || '}', 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SessionKey ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SessionKey (
  pPwKey        text,
  pPassKey      text
) RETURNS       text
AS $$
DECLARE
  vSession	    text DEFAULT null;
BEGIN
  IF pPwKey IS NOT NULL THEN
    vSession := encode(hmac(pPwKey, pPassKey, 'sha1'), 'hex');
  END IF;

  RETURN vSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION TokenKey -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION TokenKey (
  pStrKey       text,
  pPassKey      text
) RETURNS       text
AS $$
BEGIN
  RETURN encode(hmac(pStrKey, pPassKey, 'sha1'), 'hex');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GenSecretKey -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GenSecretKey (
  pSize         integer DEFAULT 48
)
RETURNS         text
AS $$
BEGIN
  RETURN encode(gen_random_bytes(pSize), 'base64');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GenTokenKey --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GenTokenKey (
  pPassKey      text
) RETURNS       text
AS $$
BEGIN
  RETURN encode(hmac(GenSecretKey(), pPassKey, 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetSignature ----------------------------------------------------------------
--------------------------------------------------------------------------------
/*
 * @param {text} pPath - Путь
 * @param {double precision} pNonce - Время в миллисекундах
 * @param {json} pJson - Данные
 * @param {text} pSecret - Секретный ключ
 * @return {text}
 */
CREATE OR REPLACE FUNCTION GetSignature (
  pPath	        text,
  pNonce        double precision,
  pJson         json,
  pSecret       text
) RETURNS	    text
AS $$
BEGIN
  RETURN encode(hmac(pPath || trim(to_char(pNonce, '9999999999999999')) || coalesce(pJson, 'null'), pSecret, 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.token --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.token (
    id              numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_TOKEN'),
    prev            numeric(12),
    session         varchar(40) NOT NULL,
    key             varchar(40) NOT NULL,
    token           text NOT NULL,
    salt			text NOT NULL,
    agent           text NOT NULL,
    host            inet,
    validFromDate	timestamp DEFAULT NOW() NOT NULL,
    validToDate		timestamp DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL,
    CONSTRAINT fk_token_prev FOREIGN KEY (prev) REFERENCES db.token(id)
);

COMMENT ON TABLE db.token IS 'Токены.';

COMMENT ON COLUMN db.token.id IS 'Идентификатор';
COMMENT ON COLUMN db.token.prev IS 'Предыдущий идентификатор';
COMMENT ON COLUMN db.token.session IS 'Сессия';
COMMENT ON COLUMN db.token.key IS 'Ключ';
COMMENT ON COLUMN db.token.token IS 'Токен';
COMMENT ON COLUMN db.token.salt IS 'Случайное значение соли для ключа';
COMMENT ON COLUMN db.token.agent IS 'Клиентское приложение';
COMMENT ON COLUMN db.token.host IS 'IP адрес подключения';
COMMENT ON COLUMN db.token.validFromDate IS 'Дата начала действаия';
COMMENT ON COLUMN db.token.validToDate IS 'Дата окончания действия';

CREATE INDEX ON db.token (prev);

CREATE UNIQUE INDEX ON db.token (key);
CREATE UNIQUE INDEX ON db.token (session, validFromDate, validToDate);

--------------------------------------------------------------------------------
-- token -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW token
AS
  SELECT id, prev, session, key, agent, host, validFromDate, validToDate
    FROM db.token;

GRANT SELECT ON token TO administrator;

--------------------------------------------------------------------------------
-- AddToken --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddToken (
  pPrev         numeric,
  pSession      text,
  pKey          text,
  pSalt         text,
  pAgent        text,
  pHost         inet,
  pToken        text,
  pDateFrom     timestamp DEFAULT localtimestamp
) RETURNS       numeric
AS $$
DECLARE
  nId           numeric;
  dtDateFrom 	timestamp;
  dtDateTo      timestamp;
BEGIN
  -- получим дату значения в текущем диапозоне дат
  SELECT id, validFromDate, validToDate INTO nId, dtDateFrom, dtDateTo
    FROM db.token
   WHERE session = pSession
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(dtDateFrom, MINDATE()) = pDateFrom THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.token SET key = pKey, salt = pSalt, agent = pAgent, host = pHost, token = pToken
     WHERE session = pSession
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.token SET validToDate = pDateFrom
     WHERE session = pSession
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    INSERT INTO db.token (prev, session, key, salt, agent, host, token, validFromDate, validToDate)
    VALUES (pPrev, pSession, pKey, pSalt, pAgent, pHost, pToken, pDateFrom, coalesce(dtDateTo, pDateFrom + INTERVAL '60 day'))
    RETURNING id INTO nId;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetTokenKey -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetTokenKey (
  pId       numeric
) RETURNS 	text
AS $$
DECLARE
  vKey		text;
BEGIN
  SELECT key INTO vKey FROM db.token WHERE id = pId;
  RETURN vKey;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewToken --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewToken (
  pPrev         numeric,
  pSession      text,
  pSecret       text,
  pSalt			text,
  pAgent        text,
  pHost         inet,
  pCreated      timestamp
) RETURNS       numeric
AS $$
DECLARE
  vKey          text;
  vStrKey       text;
BEGIN
  vStrKey := StrTokenKey(pPrev, pSession, pSalt, pCreated);
  vKey := TokenKey(vStrKey, pSecret);
  RETURN AddToken(pPrev, pSession, vKey, pSalt, pAgent, pHost, crypt(vStrKey, gen_salt('md5')), pCreated);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.session ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.session (
    key         varchar(40) PRIMARY KEY NOT NULL,
    token       numeric(12) NOT NULL,
    suid        numeric(12) NOT NULL,
    userid      numeric(12) NOT NULL,
    lang        numeric(12) NOT NULL,
    area        numeric(12) NOT NULL,
    interface   numeric(12) NOT NULL,
    oper_date   timestamp DEFAULT NULL,
    created     timestamp DEFAULT NOW() NOT NULL,
    updated     timestamp DEFAULT NOW() NOT NULL,
    pwkey       text NOT NULL,
    secret      text NOT NULL,
    salt		text NOT NULL,
    agent       text NOT NULL,
    host        inet,
    CONSTRAINT fk_session_token FOREIGN KEY (token) REFERENCES db.token(id),
    CONSTRAINT fk_session_suid FOREIGN KEY (suid) REFERENCES db.user(id),
    CONSTRAINT fk_session_userid FOREIGN KEY (userid) REFERENCES db.user(id),
    CONSTRAINT fk_session_lang FOREIGN KEY (lang) REFERENCES db.language(id),
    CONSTRAINT fk_session_area FOREIGN KEY (area) REFERENCES db.area(id),
    CONSTRAINT fk_session_interface FOREIGN KEY (interface) REFERENCES db.interface(id)
);

COMMENT ON TABLE db.session IS 'Сессии пользователей.';

COMMENT ON COLUMN db.session.key IS 'Хеш ключа сессии';
COMMENT ON COLUMN db.session.token IS 'Идентификатор токена';
COMMENT ON COLUMN db.session.suid IS 'Пользователь сессии';
COMMENT ON COLUMN db.session.userid IS 'Пользователь';
COMMENT ON COLUMN db.session.lang IS 'Язык';
COMMENT ON COLUMN db.session.area IS 'Зона';
COMMENT ON COLUMN db.session.interface IS 'Рабочие место';
COMMENT ON COLUMN db.session.oper_date IS 'Дата операционного дня';
COMMENT ON COLUMN db.session.created IS 'Дата и время создания сессии';
COMMENT ON COLUMN db.session.updated IS 'Дата и время последнего обновления сессии';
COMMENT ON COLUMN db.session.pwkey IS 'Ключ сессии';
COMMENT ON COLUMN db.session.salt IS 'Случайное значение соли для ключа аутентификации';
COMMENT ON COLUMN db.session.agent IS 'Клиентское приложение';
COMMENT ON COLUMN db.session.host IS 'IP адрес подключения';

CREATE UNIQUE INDEX ON db.session (token);

CREATE INDEX ON db.session (suid);
CREATE INDEX ON db.session (userid);

--------------------------------------------------------------------------------
-- FUNCTION ft_session_before --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_session_before()
RETURNS TRIGGER
AS $$
DECLARE
  nId	    numeric;
  vAgent    text;
BEGIN
  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  ELSIF (TG_OP = 'UPDATE') THEN
    IF OLD.key <> NEW.key THEN
      RAISE DEBUG 'Hacking alert: key (% <> %).', OLD.key, NEW.key;
      RETURN NULL;
    END IF;

    IF OLD.secret <> NEW.secret THEN
      RAISE DEBUG 'Hacking alert: secret (% <> %).', OLD.secret, NEW.secret;
      RETURN NULL;
    END IF;

    IF OLD.pwkey <> NEW.pwkey THEN
      RAISE DEBUG 'Hacking alert: pwkey (% <> %).', OLD.pwkey, NEW.pwkey;
      RETURN NULL;
    END IF;

    IF OLD.suid <> NEW.suid THEN
      RAISE DEBUG 'Hacking alert: suid (% <> %).', OLD.suid, NEW.suid;
      RETURN NULL;
    END IF;

    IF OLD.created <> NEW.created THEN
      RAISE DEBUG 'Hacking alert: created (% <> %).', OLD.created, NEW.created;
      RETURN NULL;
    END IF;

    IF NEW.salt IS NULL THEN
	  NEW.salt := OLD.salt;
    END IF;

    IF (NEW.updated - OLD.updated) > INTERVAL '1 day' THEN
      NEW.salt := gen_salt('md5');
    END IF;

    IF NEW.salt <> OLD.salt THEN
      NEW.token := NewToken(OLD.token, NEW.key, NEW.secret, NEW.salt, NEW.agent, NEW.host, NEW.updated);
    END IF;

    IF OLD.area <> NEW.area THEN
      SELECT id INTO nID FROM db.member_area WHERE area = NEW.area AND member = NEW.userid;
      IF NOT found THEN
        NEW.area := OLD.area;
      END IF;
    END IF;

    IF OLD.interface <> NEW.interface THEN
      SELECT id INTO nId
        FROM db.member_interface
       WHERE interface = NEW.interface
         AND member IN (
           SELECT NEW.userid
           UNION ALL
           SELECT userid FROM db.member_group WHERE MEMBER = NEW.userid
         );

      IF NOT found THEN
        NEW.interface := OLD.interface;
      END IF;
    END IF;

    RETURN NEW;
  ELSIF (TG_OP = 'INSERT') THEN
    IF NEW.suid IS NULL THEN
      NEW.suid := NEW.userid;
    END IF;

    IF NEW.secret IS NULL THEN
      NEW.secret := GenSecretKey();
    END IF;

    IF NEW.agent IS NULL THEN
      SELECT application_name INTO vAgent FROM pg_stat_activity WHERE pid = pg_backend_pid();
      NEW.agent := coalesce(vAgent, current_database());
    END IF;

    IF NEW.pwkey IS NULL THEN
      NEW.pwkey := crypt(StrPwKey(NEW.suid, NEW.agent, NEW.created), gen_salt('md5'));
    END IF;

    NEW.key := SessionKey(NEW.pwkey, SecretKey());

    NEW.salt := gen_salt('md5');

    IF NEW.token IS NULL THEN
      NEW.token := NewToken(null, NEW.key, NEW.secret, NEW.salt, NEW.agent, NEW.host, NEW.updated);
    END IF;

    IF NEW.lang IS NULL THEN
      SELECT id INTO NEW.lang FROM db.language WHERE code = 'ru';
    END IF;

    IF NEW.area IS NULL THEN

      NEW.area := GetDefaultArea(NEW.userid);

    ELSE

      SELECT id INTO nId
        FROM db.member_area
       WHERE area = NEW.area
         AND member IN (
           SELECT NEW.userid
            UNION ALL
           SELECT userid FROM db.member_group WHERE member = NEW.userid
         );

      IF NOT found THEN
        NEW.area := NULL;
      END IF;
    END IF;

    IF NEW.interface IS NULL THEN

      NEW.interface := GetDefaultInterface(NEW.userid);

    ELSE

      SELECT id INTO nId
        FROM db.member_interface
       WHERE interface = NEW.interface
         AND member IN (
           SELECT NEW.userid
            UNION ALL
           SELECT userid FROM db.member_group WHERE member = NEW.userid
         );

      IF NOT found THEN
        SELECT id INTO NEW.interface FROM db.interface WHERE sid = 'I:1:0:0';
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = db, kernel, pg_temp;

CREATE TRIGGER t_session_before
  BEFORE INSERT OR UPDATE OR DELETE ON db.session
  FOR EACH ROW EXECUTE PROCEDURE db.ft_session_before();

--------------------------------------------------------------------------------
-- FUNCTION ft_session_after ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_session_after()
RETURNS TRIGGER
AS $$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    DELETE FROM db.token WHERE session = OLD.key;
    RETURN OLD;
  ELSIF (TG_OP = 'UPDATE') THEN
    IF OLD.userid <> NEW.userid THEN
      PERFORM SetUserId(NEW.userid);
    END IF;
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_session_after
  AFTER UPDATE OR DELETE ON db.session
  FOR EACH ROW EXECUTE PROCEDURE db.ft_session_after();

--------------------------------------------------------------------------------
-- session ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW session
AS
  SELECT s.key, s.token, s.userid, s.suid, u.username, u.fullname, s.created,
         s.updated, u.inputlast, s.agent, s.host, u.lcip, u.status, u.loginstatus
    FROM db.session s INNER JOIN users u ON s.userid = u.id;

GRANT SELECT ON session TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION SafeSetVar ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SafeSetVar (
  pName		text,
  pValue	text
) RETURNS	void
AS $$
BEGIN
  PERFORM set_config('auth.' || pName, pValue, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SafeGetVar ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SafeGetVar (
  pName 	text
) RETURNS   text
AS $$
BEGIN
  RETURN NULLIF(current_setting('auth.' || pName), '');
EXCEPTION
WHEN syntax_error_or_access_rule_violation THEN
  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetSessionKey ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetSessionKey (
  pValue	text
) RETURNS	void
AS $$
BEGIN
  PERFORM SafeSetVar('session', pValue);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetSessionKey ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetSessionKey()
RETURNS		text
AS $$
BEGIN
  RETURN SafeGetVar('session');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetUserId ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetUserId (
  pValue	numeric
) RETURNS	void
AS $$
BEGIN
  PERFORM SafeSetVar('user', trim(to_char(pValue, '999999990000')));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetUserId ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetUserId()
RETURNS		numeric
AS $$
BEGIN
  RETURN to_number(SafeGetVar('user'), '999999990000');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SecretKey ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SecretKey() RETURNS text
AS $$
DECLARE
  vDafaultKey	text DEFAULT 'uAt5p2Hl%f8WaCpr$sB3vEk9';
  vSecretKey	text DEFAULT SafeGetVar('secret');
BEGIN
  RETURN coalesce(vSecretKey, vDafaultKey);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_session ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает ключ текущей сессии.
 * @return {text} - Ключ сессии
 */
CREATE OR REPLACE FUNCTION current_session()
RETURNS		text
AS $$
DECLARE
  vSession	text;
BEGIN
  SELECT key INTO vSession FROM db.session WHERE key = GetSessionKey();
  IF found THEN
    RETURN vSession;
  END IF;
  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_key --------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * Возвращает текущий ключ аутентификации.
 * @return {text} - Ключ сессии
 */
CREATE OR REPLACE FUNCTION current_key (
  pSession      text DEFAULT current_session()
)
RETURNS		    text
AS $$
DECLARE
  vKey          text;
BEGIN
  SELECT t.key INTO vKey
    FROM db.session s INNER JOIN db.token t ON s.token = t.id
   WHERE s.key = pSession;

  RETURN vKey;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_secret -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает секретный ключ сессии (тсс... никому не говорить 😉 !!!).
 * @param {text} pSession - Ключ сессии
 * @return {text}
 */
CREATE OR REPLACE FUNCTION session_secret (
  pSession	text DEFAULT current_session()
)
RETURNS		text
AS $$
DECLARE
  vSecret	text;
BEGIN
  SELECT secret INTO vSecret FROM db.session WHERE key = pSession;
  RETURN vSecret;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_agent ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает агента сессии.
 * @param {text} pSession - Ключ сессии
 * @return {text}
 */
CREATE OR REPLACE FUNCTION session_agent (
  pSession	text DEFAULT current_session()
)
RETURNS		text
AS $$
DECLARE
  vAgent	text;
BEGIN
  SELECT agent INTO vAgent FROM db.session WHERE key = pSession;
  RETURN vAgent;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_host -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает IP адрес подключения.
 * @param {text} pSession - Ключ сессии
 * @return {text} - IP адрес
 */
CREATE OR REPLACE FUNCTION session_host (
  pSession	text DEFAULT current_session()
)
RETURNS		text
AS $$
DECLARE
  iHost		inet;
BEGIN
  SELECT host INTO iHost FROM db.session WHERE key = pSession;
  RETURN host(iHost);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_userid -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор пользователя сеанса.
 * @param {text} pSession - Ключ сессии
 * @return {id} - Идентификатор пользователя: users.id
 */
CREATE OR REPLACE FUNCTION session_userid (
  pSession	text DEFAULT current_session()
)
RETURNS		numeric
AS $$
DECLARE
  nUserId	numeric;
BEGIN
  SELECT suid INTO nUserId FROM db.session WHERE key = pSession;
  RETURN nUserId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_userid -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор текущего пользователя.
 * @return {id} - Идентификатор пользователя: users.id
 */
CREATE OR REPLACE FUNCTION current_userid()
RETURNS		numeric
AS $$
DECLARE
  nUserId	numeric;
BEGIN
  nUserId := GetUserId();
  IF nUserId IS NULL THEN
    SELECT userid INTO nUserId FROM db.session WHERE key = current_session();
    PERFORM SetUserId(nUserId);
  END IF;
  RETURN nUserId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_username ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает имя пользователя сеанса.
 * @param {text} pSession - Ключ сессии
 * @return {text} - Имя (username) пользователя: users.username
 */
CREATE OR REPLACE FUNCTION session_username (
  pSession	text DEFAULT current_session()
)
RETURNS		text
AS $$
DECLARE
  vUserName	text;
BEGIN
  SELECT username INTO vUserName FROM users WHERE id = session_userid(pSession);
  RETURN vUserName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_username ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает имя текущего пользователя.
 * @return {text} - Имя (username) пользователя: users.username
 */
CREATE OR REPLACE FUNCTION current_username()
RETURNS		text
AS $$
DECLARE
  vUserName	text;
BEGIN
  SELECT username INTO vUserName FROM users WHERE id = current_userid();
  RETURN vUserName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetCurrentUserId ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет идентификатор текущего пользователя в активном сеансе
 * @param {numeric} pUserId - Идентификатор нового пользователя
 * @param {text} pPassword - Пароль текущего пользователя
 * @param {text} pSession - Ключ сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetCurrentUserId (
  pUserId	numeric,
  pPassword	text,
  pSession	text DEFAULT current_session()
) RETURNS	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1000, session_userid()) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  IF CheckPassword(session_username(), pPassword) THEN
    UPDATE db.session SET userid = pUserId WHERE key = pSession;
  ELSE
    RAISE EXCEPTION '%', GetErrorMessage();
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SubstituteUser -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет текущего пользователя в активном сеансе на указанного пользователя
 * @param {text} pUserName - Имя пользователь для подстановки
 * @param {text} pPassword - Пароль текущего пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SubstituteUser (
  pUserName	text,
  pPassword	text
) RETURNS	void
AS $$
BEGIN
  PERFORM SetCurrentUserId(GetUser(pUserName), pPassword);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetSessionArea -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetSessionArea (
  pArea 	numeric,
  pSession	text DEFAULT current_session()
) RETURNS 	void
AS $$
BEGIN
  UPDATE db.session SET area = pArea WHERE key = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetSessionArea -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetSessionArea (
  pSession	text DEFAULT current_session()
)
RETURNS 	numeric
AS $$
DECLARE
  nArea	    numeric;
BEGIN
  SELECT area INTO nArea FROM db.session WHERE key = pSession;
  RETURN nArea;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_area -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION current_area (
  pSession	text DEFAULT current_session()
)
RETURNS 	numeric
AS $$
BEGIN
  RETURN GetSessionArea(pSession);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetSessionInterface ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetSessionInterface (
  pInterface 	numeric,
  pSession	    text DEFAULT current_session()
) RETURNS 	    void
AS $$
BEGIN
  UPDATE db.session SET interface = pInterface WHERE key = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetSessionInterface ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetSessionInterface (
  pSession	    text DEFAULT current_session()
)
RETURNS 	    numeric
AS $$
DECLARE
  nInterface    numeric;
BEGIN
  SELECT interface INTO nInterface FROM db.session WHERE key = pSession;
  RETURN nInterface;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_interface --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION current_interface (
  pSession	text DEFAULT current_session()
)
RETURNS 	numeric
AS $$
BEGIN
  RETURN GetSessionInterface(pSession);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetOperDate --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает дату операционного дня.
 * @param {timestamp} pOperDate - Дата операционного дня
 * @param {text} pSession - Ключ сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetOperDate (
  pOperDate 	timestamp,
  pSession	    text DEFAULT current_session()
) RETURNS 	    void
AS $$
BEGIN
  UPDATE db.session SET oper_date = pOperDate WHERE key = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetOperDate --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает дату операционного дня.
 * @param {timestamptz} pOperDate - Дата операционного дня
 * @param {text} pSession - Ключ сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetOperDate (
  pOperDate 	timestamptz,
  pSession	    text DEFAULT current_session()
) RETURNS 	    void
AS $$
BEGIN
  UPDATE db.session SET oper_date = pOperDate WHERE key = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetOperDate --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает дату операционного дня.
 * @param {text} pSession - Ключ сессии
 * @return {timestamp} - Дата операционного дня
 */
CREATE OR REPLACE FUNCTION GetOperDate (
  pSession	text DEFAULT current_session()
)
RETURNS 	timestamp
AS $$
DECLARE
  dtOperDate	timestamp;
BEGIN
  SELECT oper_date INTO dtOperDate FROM db.session WHERE key = pSession;
  RETURN dtOperDate;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION oper_date ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает дату операционного дня.
 * @param {text} pSession - Ключ сессии
 * @return {timestamp} - Дата операционного дня
 */
CREATE OR REPLACE FUNCTION oper_date (
  pSession	text DEFAULT current_session()
)
RETURNS 	timestamp
AS $$
DECLARE
  dtOperDate	timestamp;
BEGIN
  dtOperDate := GetOperDate(pSession);
  IF dtOperDate IS NULL THEN
    dtOperDate := now();
  END IF;
  RETURN dtOperDate;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetLanguage --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает по идентификатору текущий язык.
 * @param {id} pLang - Идентификатор языка
 * @param {text} pSession - Ключ сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetLanguage (
  pLang		numeric,
  pSession	text DEFAULT current_session()
) RETURNS	void
AS $$
BEGIN
  UPDATE db.session SET lang = pLang WHERE key = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetLanguage --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает по коду текущий язык.
 * @param {text} pCode - Код языка
 * @param {text} pSession - Ключ сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetLanguage (
  pCode		text DEFAULT 'ru',
  pSession	text DEFAULT current_session()
) RETURNS	void
AS $$
DECLARE
  nLang		numeric;
BEGIN
  SELECT id INTO nLang FROM db.language WHERE code = pCode;
  IF found THEN
    PERFORM SetLanguage(nLang, pSession);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetLanguage --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор текущего языка.
 * @param {text} pSession - Ключ сессии
 * @return {numeric} - Идентификатор языка.
 */
CREATE OR REPLACE FUNCTION GetLanguage (
  pSession	text DEFAULT current_session()
)
RETURNS		numeric
AS $$
DECLARE
  nLang		numeric;
BEGIN
  SELECT lang INTO nLang FROM db.session WHERE key = pSession;
  RETURN nLang;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION language_code ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает код текущего языка.
 * @param {text} pSession - Ключ сессии
 * @return {text} - Код языка
 */
CREATE OR REPLACE FUNCTION language_code (
  pSession	text DEFAULT current_session()
)
RETURNS		text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM db.language WHERE id = GetLanguage(pSession);
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_language ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор текущего языка.
 * @param {text} pSession - Ключ сессии
 * @return {numeric} - Идентификатор языка.
 */
CREATE OR REPLACE FUNCTION current_language (
  pSession	text DEFAULT current_session()
)
RETURNS		numeric
AS $$
BEGIN
  RETURN GetLanguage(pSession);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- IsUserRole ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Проверяет роль пользователя.
 * @param {numeric} pRole - Идентификатор роли (группы)
 * @param {numeric} pUser - Идентификатор пользователя (учётной записи)
 * @return {boolean}
 */
CREATE OR REPLACE FUNCTION IsUserRole (
  pRole		numeric,
  pUser		numeric DEFAULT current_userid()
) RETURNS	boolean
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.member_group WHERE userid = pRole AND member = pUser;

  RETURN nId IS NOT NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- IsUserRole ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Проверяет роль пользователя.
 * @param {text} pRole - Код роли (группы)
 * @param {text} pUser - Код пользователя (учётной записи)
 * @return {boolean}
 */
CREATE OR REPLACE FUNCTION IsUserRole (
  pRole		text,
  pUser		text DEFAULT current_username()
) RETURNS	boolean
AS $$
DECLARE
  nUserId	numeric;
  nRoleId	numeric;
BEGIN
  SELECT id INTO nUserId FROM users WHERE username = pUser;
  SELECT id INTO nRoleId FROM groups WHERE username = pRole;

  RETURN IsUserRole(nRoleId, nUserId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateUser ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт учётную запись пользователя.
 * @param {varchar} pUserName - Пользователь
 * @param {text} pPassword - Пароль
 * @param {text} pFullName - Полное имя
 * @param {text} pPhone - Телефон
 * @param {text} pEmail - Электронный адрес
 * @param {text} pDescription - Описание
 * @param {boolean} pPasswordChange - Сменить пароль при следующем входе в систему
 * @param {boolean} pPasswordNotChange - Установить запрет на смену пароля самим пользователем
 * @param {numeric} pArea - Зона
 * @return {(id|exception)} - Id учётной записи или ошибку
 */
CREATE OR REPLACE FUNCTION CreateUser (
  pUserName             varchar,
  pPassword             text,
  pFullName             text,
  pPhone                text,
  pEmail                text,
  pDescription          text DEFAULT null,
  pPasswordChange       boolean DEFAULT true,
  pPasswordNotChange    boolean DEFAULT false,
  pArea                 numeric DEFAULT current_area()
) RETURNS               numeric
AS $$
DECLARE
  nUserId		        numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO nUserId FROM users WHERE username = lower(pUserName);

  IF found THEN
    PERFORM RoleExists(pUserName);
  END IF;

  INSERT INTO db.user (type, username, fullname, phone, email, description, passwordchange, passwordnotchange)
  VALUES ('U', pUserName, pFullName, pPhone, pEmail, pDescription, pPasswordChange, pPasswordNotChange)
  RETURNING id INTO nUserId;

  INSERT INTO db.profile (userid) VALUES (nUserId);

  IF NULLIF(pPassword, '') IS NOT NULL THEN
    PERFORM SetPassword(nUserId, pPassword);
  END IF;

  PERFORM AddMemberToInterface(nUserId, GetInterface('I:1:0:0'));

  IF pArea IS NOT NULL THEN
    PERFORM AddMemberToArea(nUserId, pArea);
  END IF;

  RETURN nUserId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт группу.
 * @param {varchar} pGroupName - Группа
 * @param {text} pFullName - Полное имя
 * @param {text} pDescription - Описание
 * @return {(id|exception)} - Id группы или ошибку
 */
CREATE OR REPLACE FUNCTION CreateGroup (
  pGroupName    varchar,
  pFullName     text,
  pDescription	text
) RETURNS	    numeric
AS $$
DECLARE
  nGroupId	    numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO nGroupId FROM groups WHERE username = lower(pGroupName);

  IF found THEN
    PERFORM RoleExists(pGroupName);
  END IF;

  INSERT INTO db.user (type, username, fullname, description)
  VALUES ('G', pGroupName, pFullName, pDescription) RETURNING Id INTO nGroupId;

  RETURN nGroupId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateUser ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет учётную запись пользователя.
 * @param {id} pId - Идентификатор учетной записи пользователя
 * @param {varchar} pUserName - Пользователь
 * @param {text} pPassword - Пароль
 * @param {text} pFullName - Полное имя
 * @param {text} pPhone - Телефон
 * @param {text} pEmail - Электронный адрес
 * @param {text} pDescription - Описание
 * @param {boolean} pPasswordChange - Сменить пароль при следующем входе в систему
 * @param {boolean} pPasswordNotChange - Установить запрет на смену пароля самим пользователем
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION UpdateUser (
  pId                   numeric,
  pUserName             varchar,
  pPassword             text DEFAULT null,
  pFullName             text DEFAULT null,
  pPhone                text DEFAULT null,
  pEmail                text DEFAULT null,
  pDescription          text DEFAULT null,
  pPasswordChange       boolean DEFAULT null,
  pPasswordNotChange    boolean DEFAULT null
) RETURNS		        void
AS $$
DECLARE
  r			            users%rowtype;
BEGIN
  IF session_user <> 'kernel' THEN
    IF pId <> current_userid() THEN
      IF NOT IsUserRole(1001)  THEN
        PERFORM AccessDenied();
      END IF;
    END IF;
  END IF;

  SELECT * INTO r FROM users WHERE id = pId;

  IF r.username IN ('admin', 'daemon', 'apibot', 'mailbot') THEN
    IF r.username <> lower(pUserName) THEN
      PERFORM SystemRoleError();
    END IF;
  END IF;

  IF found THEN
    pPhone := coalesce(pPhone, r.phone);
    pEmail := coalesce(pEmail, r.email);
    pDescription := coalesce(pDescription, r.description);
    pPasswordChange := coalesce(pPasswordChange, r.passwordchange);
    pPasswordNotChange := coalesce(pPasswordNotChange, r.passwordnotchange);

    UPDATE db.user
       SET username = coalesce(pUserName, username),
           fullname = coalesce(pFullName, fullname),
           phone = CheckNull(pPhone),
           email = CheckNull(pEmail),
           description = CheckNull(pDescription),
           passwordchange = pPasswordChange,
           passwordnotchange = pPasswordNotChange
     WHERE Id = pId;

    IF pPassword IS NOT NULL AND pPassword <> '' THEN
      PERFORM SetPassword(pId, pPassword);
    END IF;
  ELSE
    PERFORM UserNotFound(pId);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет учётные данные группы.
 * @param {id} pId - Идентификатор группы
 * @param {varchar} pGroupName - Группа
 * @param {text} pFullName - Полное имя
 * @param {text} pDescription - Описание
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION UpdateGroup (
  pId           numeric,
  pGroupName    varchar,
  pFullName     text,
  pDescription  text
) RETURNS       void
AS $$
DECLARE
  vGroupName    varchar;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT username INTO vGroupName FROM db.user WHERE id = pId;

  IF vGroupName IN ('administrator', 'operator', 'user') THEN
    IF vGroupName <> lower(pGroupName) THEN
      PERFORM SystemRoleError();
    END IF;
  END IF;

  UPDATE db.user
     SET username = coalesce(pGroupName, username),
         fullname = coalesce(pFullName, fullname),
         description = coalesce(pDescription, description)
   WHERE Id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteUser ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет учётную запись пользователя.
 * @param {id} pId - Идентификатор учётной записи пользователя
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION DeleteUser (
  pId		numeric
) RETURNS	void
AS $$
DECLARE
  vUserName	varchar;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  IF pId = current_userid() THEN
    PERFORM DeleteUserError();
  END IF;

  SELECT username INTO vUserName FROM db.user WHERE id = pId;

  IF vUserName IN ('admin', 'daemon', 'apibot', 'mailbot') THEN
    PERFORM SystemRoleError();
  END IF;

  IF found THEN
    DELETE FROM db.aou WHERE userid = pId;

    DELETE FROM db.member_area WHERE member = pId;
    DELETE FROM db.member_interface WHERE member = pId;
    DELETE FROM db.member_group WHERE member = pId;
    DELETE FROM db.profile WHERE userid = pId;
    DELETE FROM db.user WHERE id = pId;
  ELSE
    PERFORM UserNotFound(pId);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteUser ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет учётную запись пользователя.
 * @param {varchar} pUserName - Пользователь (login)
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION DeleteUser (
  pUserName	varchar
) RETURNS	void
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.user WHERE type = 'U' AND username = pUserName;

  IF NOT found THEN
    PERFORM UserNotFound(pUserName);
  END IF;

  PERFORM DeleteUser(nId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет группу.
 * @param {id} pId - Идентификатор группы
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION DeleteGroup (
  pId		    numeric
) RETURNS	    void
AS $$
DECLARE
  vGroupName    varchar;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT username INTO vGroupName FROM db.user WHERE id = pId;

  IF vGroupName IN ('administrator', 'manager', 'operator', 'external') THEN
    PERFORM SystemRoleError();
  END IF;

  DELETE FROM db.member_area WHERE member = pId;
  DELETE FROM db.member_interface WHERE member = pId;
  DELETE FROM db.member_group WHERE userid = pId;
  DELETE FROM db.profile WHERE userid = pId;
  DELETE FROM db.user WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет группу.
 * @param {varchar} pGroupName - Группа
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION DeleteGroup (
  pGroupName    varchar
) RETURNS       void
AS $$
BEGIN
  PERFORM DeleteGroup(GetGroup(pGroupName));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetUser ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор пользователя по имени пользователя.
 * @param {varchar} pUserName - Пользователь
 * @return {id}
 */
CREATE OR REPLACE FUNCTION GetUser (
  pUserName	varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.user WHERE type = 'U' AND username = pUserName;

  IF NOT found THEN
    PERFORM UserNotFound(pUserName);
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetGroup --------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор группы по наименованию.
 * @param {varchar} pGroupName - Группа
 * @return {id}
 */
CREATE OR REPLACE FUNCTION GetGroup (
  pGroupName	varchar
) RETURNS	    numeric
AS $$
DECLARE
  nId		    numeric;
BEGIN
  SELECT id INTO nId FROM db.user WHERE type = 'G' AND username = pGroupName;

  IF NOT found THEN
    PERFORM UnknownRoleName(pGroupName);
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetPassword -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает пароль пользователя.
 * @param {id} pId - Идентификатор пользователя
 * @param {text} pPassword - Пароль
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetPassword (
  pId			    numeric,
  pPassword		    text
) RETURNS		    void
AS $$
DECLARE
  nUserId		    numeric;
  bPasswordChange	boolean;
  r			        record;
BEGIN
  nUserId := current_userid();

  IF session_user <> 'kernel' THEN
    IF pId <> nUserId THEN
      IF NOT IsUserRole(1001) THEN
        PERFORM AccessDenied();
      END IF;
    END IF;
  END IF;

  SELECT username, passwordchange, passwordnotchange INTO r FROM users WHERE id = pId;

  IF found THEN
    bPasswordChange := r.PasswordChange;

    IF pId = nUserId THEN
      IF r.PasswordNotChange THEN
        PERFORM UserPasswordChange();
      END IF;

      IF r.PasswordChange THEN
        bPasswordChange := false;
      END IF;
    END IF;

    UPDATE db.user
       SET passwordchange = bPasswordChange,
           pswhash = crypt(pPassword, gen_salt('md5'))
     WHERE id = pId;
  ELSE
    PERFORM UserNotFound(pId);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ChangePassword --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет пароль пользователя.
 * @param {numeric} pId - Идентификатор учетной записи
 * @param {text} pOldPass - Старый пароль
 * @param {text} pNewPass - Новый пароль
 * @return {void}
 */
CREATE OR REPLACE FUNCTION ChangePassword (
  pId		numeric,
  pOldPass	text,
  pNewPass	text
) RETURNS	boolean
AS $$
DECLARE
  r		record;
BEGIN
  SELECT username, system INTO r FROM users WHERE id = pId;

  IF found THEN
    IF CheckPassword(r.username, pOldPass) THEN

      PERFORM SetPassword(pId, pNewPass);

      IF r.system THEN
        EXECUTE 'ALTER ROLE ' || r.username || ' WITH PASSWORD ' || quote_literal(pNewPass);
      END IF;

      RETURN true;
    END IF;
  ELSE
    PERFORM UserNotFound(pId);
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- UserLock --------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Блокирует учётную запись пользователя.
 * @param {id} pId - Идентификатор учётной записи пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION UserLock (
  pId		numeric
) RETURNS	void
AS $$
DECLARE
  nId		numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF pId <> current_userid() THEN
      IF NOT IsUserRole(1001) THEN
        PERFORM AccessDenied();
      END IF;
    END IF;
  END IF;

  SELECT id INTO nId FROM users WHERE id = pId;

  IF found THEN
    UPDATE db.user SET status = set_bit(set_bit(status, 3, 0), 1, 1), lock_date = now() WHERE id = pId;
  ELSE
    PERFORM UserNotFound(pId);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UserUnLock ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Снимает блокировку с учётной записи пользователя.
 * @param {id} pId - Идентификатор учётной записи пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION UserUnLock (
  pId		numeric
) RETURNS	void
AS $$
DECLARE
  nId		numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO nId FROM users WHERE id = pId;

  IF found THEN
    UPDATE db.user SET status = B'0001', lock_date = null, expiry_date = null WHERE id = pId;
  ELSE
    PERFORM UserNotFound(pId);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddMemberToGroup ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет пользователя в группу.
 * @param {id} pMember - Идентификатор пользователя
 * @param {id} pGroup - Идентификатор группы
 * @return {void}
 */
CREATE OR REPLACE FUNCTION AddMemberToGroup (
  pMember	numeric,
  pGroup	numeric
) RETURNS	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.member_group (userid, member) VALUES (pGroup, pMember);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteGroupForMember --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет группу для пользователя.
 * @param {id} pMember - Идентификатор пользователя
 * @param {id} pGroup - Идентификатор группы, при null удаляет все группы для указанного пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DeleteGroupForMember (
  pMember	numeric,
  pGroup	numeric DEFAULT null
) RETURNS	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_group WHERE userid = coalesce(pGroup, userid) AND member = pMember;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteMemberFromGroup -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет пользователя из группу.
 * @param {id} pGroup - Идентификатор группы
 * @param {id} pMember - Идентификатор пользователя, при null удаляет всех пользователей из указанной группы
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DeleteMemberFromGroup (
  pGroup	numeric,
  pMember	numeric DEFAULT null
) RETURNS	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_group WHERE userid = pGroup AND member = coalesce(pMember, member);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetUserName -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetUserName (
  pId		numeric
) RETURNS	text
AS $$
DECLARE
  vUserName	text;
BEGIN
  SELECT username INTO vUserName FROM db.user WHERE id = pId AND type = 'U';
  RETURN vUserName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetGroupName ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetGroupName (
  pId		numeric
) RETURNS	text
AS $$
DECLARE
  vGroupName	text;
BEGIN
  SELECT username INTO vGroupName FROM db.user WHERE id = pId AND type = 'G';
  RETURN vGroupName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateArea ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateArea (
  pParent	    numeric,
  pType		    numeric,
  pCode		    varchar,
  pName		    varchar,
  pDescription	text DEFAULT null
) RETURNS 	    numeric
AS $$
DECLARE
  nId		    numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.area (parent, type, code, name, description)
  VALUES (coalesce(pParent, GetArea('root')), pType, pCode, pName, pDescription) RETURNING Id INTO nId;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditArea --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditArea (
  pId			    numeric,
  pParent		    numeric DEFAULT null,
  pType			    numeric DEFAULT null,
  pCode			    varchar DEFAULT null,
  pName			    varchar DEFAULT null,
  pDescription		text DEFAULT null,
  pValidFromDate	timestamptz DEFAULT null,
  pValidToDate		timestamptz DEFAULT null
) RETURNS void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  IF pId = GetArea('root') THEN
    UPDATE db.area
       SET name = coalesce(pName, name),
           description = coalesce(pDescription, description)
     WHERE id = pId;
  ELSE
    UPDATE db.area
       SET parent = coalesce(pParent, parent),
           type = coalesce(pType, type),
           code = coalesce(pCode, code),
           name = coalesce(pName, name),
           description = coalesce(pDescription, description),
           validFromDate = coalesce(pValidFromDate, validFromDate),
           validToDate = coalesce(pValidToDate, validToDate)
     WHERE id = pId;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteArea ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteArea (
  pId			numeric
) RETURNS       void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.area WHERE Id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetArea ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetArea (
  pCode		text
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.area WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAreaCode -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAreaCode (
  pId		numeric
) RETURNS	varchar
AS $$
DECLARE
  vCode		varchar;
BEGIN
  SELECT code INTO vCode FROM db.area WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAreaName -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAreaName (
  pId		numeric
) RETURNS	varchar
AS $$
DECLARE
  vName		varchar;
BEGIN
  SELECT name INTO vName FROM db.area WHERE id = pId;
  RETURN vName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddMemberToArea -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddMemberToArea (
  pMember	numeric,
  pArea		numeric
) RETURNS   void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.member_area (area, member) VALUES (pArea, pMember);
exception
  when OTHERS THEN
    null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteAreaForMember ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет подразделение для пользователя.
 * @param {id} pMember - Идентификатор пользователя
 * @param {id} pArea - Идентификатор подразделения, при null удаляет все подразделения для указанного пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DeleteAreaForMember (
  pMember	numeric,
  pArea		numeric DEFAULT null
) RETURNS   void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_area WHERE area = coalesce(pArea, area) AND member = pMember;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteMemberFromArea --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет пользователя из подразделения.
 * @param {id} pArea - Идентификатор подразделения
 * @param {id} pMember - Идентификатор пользователя, при null удаляет всех пользователей из указанного подразделения
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DeleteMemberFromArea (
  pArea		numeric,
  pMember	numeric DEFAULT null
) RETURNS   void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_area WHERE area = pArea AND member = coalesce(pMember, member);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetArea ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetArea (
  pArea	        numeric,
  pMember	    numeric DEFAULT current_userid(),
  pSession	    text DEFAULT current_session()
) RETURNS	    void
AS $$
DECLARE
  nId		    numeric;
  vUserName     varchar;
  vDepName      text;
BEGIN
  vDepName := GetAreaName(pArea);
  IF vDepName IS NULL THEN
    PERFORM AreaError();
  END IF;

  vUserName := GetUserName(pMember);
  IF vDepName IS NULL THEN
    PERFORM UserNotFound(pMember);
  END IF;

  SELECT id INTO nId FROM db.member_area WHERE area = pArea AND member = pMember;
  IF NOT found THEN
    PERFORM UserNotMemberArea(vUserName, vDepName);
  END IF;

  UPDATE db.session SET area = pArea WHERE key = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetDefaultArea --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetDefaultArea (
  pArea	    numeric DEFAULT current_area(),
  pMember	numeric DEFAULT current_userid()
) RETURNS	void
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId
    FROM db.member_area
   WHERE area = pArea
     AND member IN (
       SELECT pMember
        UNION ALL
       SELECT userid FROM db.member_group WHERE member = pMember
     );

  IF found THEN
    UPDATE db.profile SET default_area = pArea WHERE userid = pMember;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetDefaultArea --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetDefaultArea (
  pMember   numeric DEFAULT current_userid()
) RETURNS	numeric
AS $$
DECLARE
  nDefault	numeric;
  nArea	    numeric;
BEGIN
  SELECT default_area INTO nDefault FROM db.profile WHERE userid = pMember;

  SELECT area INTO nArea
    FROM db.member_area
   WHERE area = nDefault
     AND member IN (
       SELECT pMember
        UNION ALL
       SELECT userid FROM db.member_group WHERE member = pMember
     );

  IF NOT found THEN
    SELECT MIN(area) INTO nArea
      FROM db.member_area
     WHERE member = pMember;
  END IF;

  RETURN nArea;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateInterface -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateInterface (
  pName		    varchar,
  pDescription	text
) RETURNS 	    numeric
AS $$
DECLARE
  nId		    numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.interface (name, description)
  VALUES (pName, pDescription) RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateInterface -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION UpdateInterface (
  pId		    numeric,
  pName		    varchar,
  pDescription	text
) RETURNS 	    void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  UPDATE db.interface SET Name = pName, Description = pDescription WHERE Id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteInterface -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteInterface (
  pId		numeric
) RETURNS 	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.interface WHERE Id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddMemberToInterface --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddMemberToInterface (
  pMember	numeric,
  pInterface	numeric
) RETURNS 	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.member_interface (interface, member) VALUES (pInterface, pMember);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteInterfaceForMember ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteInterfaceForMember (
  pMember	    numeric,
  pInterface	numeric DEFAULT null
) RETURNS       void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_interface WHERE interface = coalesce(pInterface, interface) AND member = pMember;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteMemberFromInterface ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteMemberFromInterface (
  pInterface	numeric,
  pMember	    numeric DEFAULT null
) RETURNS       void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_interface WHERE interface = pInterface AND member = coalesce(pMember, member);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetInterfaceSID -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetInterfaceSID (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vSID		text;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT sid INTO vSID FROM db.interface WHERE id = pId;

  RETURN vSID;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetInterface ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetInterface (
  pSID		text
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.interface WHERE SID = pSID;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetInterfaceName ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetInterfaceName (
  pId		numeric
) RETURNS 	varchar
AS $$
DECLARE
  vName		varchar;
BEGIN
  SELECT name INTO vName FROM db.interface WHERE id = pId;

  RETURN vName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetInterface ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetInterface (
  pInterface	numeric,
  pMember	    numeric DEFAULT current_userid(),
  pSession	    text DEFAULT current_session()
) RETURNS	    void
AS $$
DECLARE
  nId		    numeric;
  vUserName     varchar;
  vInterface    text;
BEGIN
  vInterface := GetInterfaceName(pInterface);
  IF vInterface IS NULL THEN
    PERFORM InterfaceError();
  END IF;

  vUserName := GetUserName(pMember);
  IF vUserName IS NULL THEN
    PERFORM UserNotFound(pMember);
  END IF;

  SELECT id INTO nId
    FROM db.member_interface
   WHERE interface = pInterface
     AND member IN (
       SELECT pMember
       UNION ALL
       SELECT userid FROM db.member_group WHERE member = pMember
     );
  IF NOT found THEN
    PERFORM UserNotMemberInterface(vUserName, vInterface);
  END IF;

  UPDATE db.session SET interface = pInterface WHERE key = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetDefaultInterface ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetDefaultInterface (
  pInterface	numeric DEFAULT current_interface(),
  pMember	    numeric DEFAULT current_userid()
) RETURNS	    void
AS $$
DECLARE
  nId		    numeric;
BEGIN
  SELECT id INTO nId
    FROM db.member_interface
   WHERE interface = pInterface
     AND member IN (
       SELECT pMember
        UNION ALL
       SELECT userid FROM db.member_group WHERE member = pMember
     );

  IF found THEN
    UPDATE db.profile SET default_interface = pInterface WHERE userid = pMember;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetDefaultInterface ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetDefaultInterface (
  pMember	    numeric DEFAULT current_userid()
) RETURNS	    numeric
AS $$
DECLARE
  nDefault	    numeric;
  nInterface	numeric;
BEGIN
  SELECT default_interface INTO nDefault FROM db.profile WHERE userid = pMember;

  SELECT interface INTO nInterface
    FROM db.member_interface
   WHERE interface = nDefault
     AND member IN (
       SELECT pMember
        UNION ALL
       SELECT userid FROM db.member_group WHERE member = pMember
     );

  IF NOT found THEN
    SELECT id INTO nInterface FROM interface WHERE sid = 'I:1:0:0';
  END IF;

  RETURN nInterface;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckOffline ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckOffline (
  pOffTime	INTERVAL DEFAULT '5 minute'
) RETURNS	void
AS $$
BEGIN
  UPDATE db.profile
     SET state = B'000'
   WHERE state <> B'000'
     AND userid IN (
       SELECT userid FROM db.session WHERE userid <> (SELECT id FROM db.user WHERE username = 'apibot') AND updated < now() - pOffTime
     );
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AUTHENTICATE ----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- CheckPassword ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckPassword (
  pUserName	text,
  pPassword	text
) RETURNS 	boolean
AS $$
DECLARE
  passed 	boolean;
BEGIN
  SELECT (pswhash = crypt(pPassword, pswhash)) INTO passed
    FROM db.user
   WHERE username = pUserName;

  IF found THEN
    IF passed THEN
      PERFORM SetErrorMessage('Успешно.');
    ELSE
      PERFORM SetErrorMessage('Пароль не прошёл проверку.');
    END IF;
  ELSE
    PERFORM SetErrorMessage('Пользователь не найден.');
  END IF;

  RETURN coalesce(passed, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ValidSession ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ValidSession (
  pSession	    text DEFAULT current_session()
) RETURNS 	    boolean
AS $$
DECLARE
  passed 	    boolean;
BEGIN
  SELECT (pwkey = crypt(StrPwKey(suid, agent, created), pwkey)) INTO passed
    FROM db.session
   WHERE key = pSession;

  IF found THEN
    IF passed THEN
      PERFORM SetErrorMessage('Успешно.');
    ELSE
      PERFORM SetErrorMessage('Ключ сессии не прошёл проверку.');
    END IF;
  ELSE
    PERFORM SetErrorMessage('Ключ сессии не найден.');
  END IF;

  RETURN coalesce(passed, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ValidToken ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ValidToken (
  pSession      text,
  pKey          text
) RETURNS 	    bool
AS $$
DECLARE
  passed 	    boolean;
BEGIN
  SELECT (token = crypt(StrTokenKey(prev, pSession, salt, validFromDate, validToDate), token)) INTO passed
    FROM db.token
   WHERE key = pKey;

  IF found THEN
    IF passed THEN
      PERFORM SetErrorMessage('Успешно.');
    ELSE
      PERFORM SetErrorMessage('Токен не прошл проверку. Сессия скомпрометирована.');
    END IF;
  ELSE
    PERFORM SetErrorMessage('Сессия не найдена.');
  END IF;

  RETURN coalesce(passed, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SessionIn ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Вход в систему по ключу сессии.
 * @param {text} pSession - Сессия
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @param {text} pSalt - Случайное значение соли для ключа аутентификации
 * @return {text} - Ключ. Если вернёт null вызвать GetErrorMessage для просмотра сообщения об ошибке.
 */
CREATE OR REPLACE FUNCTION SessionIn (
  pSession      text,
  pAgent        text DEFAULT null,
  pHost		    inet DEFAULT null,
  pSalt			text DEFAULT null
)
RETURNS 	    text
AS $$
DECLARE
  up	        db.user%rowtype;

  nUserId	    numeric DEFAULT null;
  nToken        numeric DEFAULT null;
  nArea	        numeric DEFAULT null;
  nInterface    numeric DEFAULT null;

  vAgent       text;
BEGIN
  SELECT application_name INTO vAgent FROM pg_stat_activity WHERE pid = pg_backend_pid();

  pAgent := coalesce(pAgent, vAgent, current_database());

  UPDATE db.session SET updated = localtimestamp, agent = pAgent, host = pHost, salt = pSalt WHERE key = pSession
  RETURNING token INTO nToken;

  IF ValidSession(pSession) THEN

    IF NOT coalesce(pSession = GetSessionKey(), false) THEN

      SELECT userid, area, interface
        INTO nUserId, nArea, nInterface
        FROM db.session
       WHERE key = pSession;

      SELECT * INTO up FROM db.user WHERE id = nUserId;

      IF NOT found THEN
        PERFORM LoginError();
      END IF;

      IF get_bit(up.status, 1) = 1 THEN
        PERFORM UserLockError();
      END IF;

      IF up.lock_date IS NOT NULL AND up.lock_date <= now() THEN
        PERFORM UserLockError();
      END IF;

      IF get_bit(up.status, 0) = 1 THEN
        PERFORM PasswordExpiryError();
      END IF;

      IF up.expiry_date IS NOT NULL AND up.expiry_date <= now() THEN
        PERFORM PasswordExpiryError();
      END IF;

      IF NOT CheckIPTable(up.id, pHost) THEN
        PERFORM LoginIPTableError(pHost);
      END IF;

      PERFORM SetSessionKey(pSession);
      PERFORM SetUserId(up.id);

      UPDATE db.user SET status = set_bit(set_bit(status, 3, 0), 2, 1) WHERE id = up.id;

      UPDATE db.profile
         SET input_last = now(),
             lc_ip = coalesce(pHost, lc_ip)
       WHERE userid = up.id;
    END IF;

    RETURN GetTokenKey(nToken);
  END IF;

  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Login -----------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Вход в систему по паре имя пользователя и пароль.
 * @param {text} pUserName - Пользователь (login)
 * @param {text} pPassword - Пароль
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {text} - Сессия. Если вернёт null вызвать GetErrorMessage для просмотра сообщения об ошибке.
 */
CREATE OR REPLACE FUNCTION Login (
  pUserName     text,
  pPassword     text,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       text
AS $$
DECLARE
  up            db.user%rowtype;

  nArea         numeric DEFAULT null;
  nInterface    numeric DEFAULT null;

  vSession      text DEFAULT null;
BEGIN
  IF NULLIF(pUserName, '') IS NULL THEN
    PERFORM LoginError();
  END IF;

  IF NULLIF(pPassword, '') IS NULL THEN
    PERFORM LoginError();
  END IF;

  SELECT * INTO up FROM db.user WHERE type = 'U' AND username = pUserName;

  IF NOT found THEN
    PERFORM LoginError();
  END IF;

  IF get_bit(up.status, 1) = 1 THEN
    PERFORM UserLockError();
  END IF;

  IF up.lock_date IS NOT NULL AND up.lock_date <= now() THEN
    PERFORM UserLockError();
  END IF;

  IF get_bit(up.status, 0) = 1 THEN
    PERFORM PasswordExpiryError();
  END IF;

  IF up.expiry_date IS NOT NULL AND up.expiry_date <= now() THEN
    PERFORM PasswordExpiryError();
  END IF;

  nArea := GetDefaultArea(up.id);
  nInterface := GetDefaultInterface(up.id);

  IF NOT CheckIPTable(up.id, pHost) THEN
    PERFORM LoginIPTableError(pHost);
  END IF;

  IF CheckPassword(pUserName, pPassword) THEN

    PERFORM CheckSessionLimit(up.id);

    INSERT INTO db.session (userid, area, interface, agent, host)
    VALUES (up.id, nArea, nInterface, pAgent, pHost)
    RETURNING key INTO vSession;

    IF vSession IS NULL THEN
      PERFORM AccessDenied();
    END IF;

    PERFORM SetSessionKey(vSession);
    PERFORM SetUserId(up.id);

    UPDATE db.user SET status = set_bit(set_bit(status, 3, 0), 2, 1) WHERE id = up.id;

    UPDATE db.profile
       SET input_error = 0,
           input_count = input_count + 1,
           input_last = now(),
           lc_ip = pHost
     WHERE userid = up.id;

  ELSE

    PERFORM SetSessionKey(null);
    PERFORM SetUserId(null);

    PERFORM LoginError();

  END IF;

  INSERT INTO db.log (type, code, username, session, text)
  VALUES ('M', 1001, pUserName, vSession, 'Вход в систему.');

  RETURN vSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SignIn ----------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Вход в систему.
 * @param {text} pUserName - Пользователь (login)
 * @param {text} pPassword - Пароль
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {text} - Сессия. Если вернёт null вызвать GetErrorMessage для просмотра сообщения об ошибке.
 */
CREATE OR REPLACE FUNCTION SignIn (
  pUserName     text,
  pPassword     text,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       text
AS $$
DECLARE
  up            db.user%rowtype;

  nInputError   integer;

  message       text;
BEGIN
  PERFORM SetErrorMessage('Успешно.');

  BEGIN
    RETURN Login(pUserName, pPassword, pAgent, pHost);
  EXCEPTION
  WHEN others THEN
    GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;

    PERFORM SetSessionKey(null);
    PERFORM SetUserId(null);

    PERFORM SetErrorMessage(message);

    SELECT * INTO up FROM db.user WHERE type = 'U' AND username = pUserName;

    IF found THEN
      UPDATE db.profile
         SET input_error = input_error + 1,
             input_error_last = now(),
             input_error_all = input_error_all + 1
       WHERE userid = up.id;

      SELECT input_error INTO nInputError FROM db.profile WHERE userid = up.id;

      IF found THEN
        IF nInputError >= 3 THEN
          PERFORM UserLock(up.id);
        END IF;
      END IF;

      INSERT INTO db.log (type, code, username, text)
      VALUES ('E', 3001, pUserName, message);
    END IF;

    RETURN null;
  END;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SessionOut ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выход из системы по ключу сессии.
 * @param {text} pSession - Сессия
 * @param {boolean} pCloseAll - Закрыть все сессии
 * @param {text} pMessage - Сообщение
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SessionOut (
  pSession      text,
  pCloseAll     boolean,
  pMessage      text DEFAULT null
) RETURNS 	    boolean
AS $$
DECLARE
  nUserId	    numeric;
  nCount	    integer;

  message	    text;
BEGIN
  IF ValidSession(pSession) THEN

    message := 'Выход из системы';

    SELECT userid INTO nUserId FROM db.session WHERE key = pSession;

    IF pCloseAll THEN
      DELETE FROM db.session WHERE userid = nUserId;
      message := message || ' (с закрытием всех активных сессий)';
    ELSE
      DELETE FROM db.session WHERE key = pSession;
    END IF;

    SELECT count(key) INTO nCount FROM db.session WHERE userid = nUserId;

    IF nCount = 0 THEN
      UPDATE db.user SET status = set_bit(set_bit(status, 3, 1), 2, 0) WHERE id = nUserId;
    END IF;

    UPDATE db.profile SET state = B'000' WHERE userid = nUserId;

    message := message || coalesce('. ' || pMessage, '.');

    INSERT INTO db.log (type, code, username, session, text)
    VALUES ('M', 1002, GetUserName(nUserId), pSession, message);

    PERFORM SetErrorMessage(message);
    PERFORM SetSessionKey(null);
    PERFORM SetUserId(null);

    RETURN true;
  END IF;

  RAISE EXCEPTION '%', GetErrorMessage();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SignOut ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выход из системы по ключу сессии.
 * @param {text} pSession - Сессия
 * @param {boolean} pCloseAll - Закрыть все сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SignOut (
  pSession      text DEFAULT current_session(),
  pCloseAll     boolean DEFAULT false
) RETURNS 	    boolean
AS $$
DECLARE
  nUserId	    numeric;
  message	    text;
BEGIN
  RETURN SessionOut(pSession, pCloseAll);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;

  SELECT userid INTO nUserId FROM db.session WHERE key = pSession;

  IF found THEN
    INSERT INTO db.log (type, code, username, session, text)
    VALUES ('E', 3002, GetUserName(nUserId), pSession, 'Выход из системы. ' || message);
  END IF;

  PERFORM SetSessionKey(null);
  PERFORM SetUserId(null);

  PERFORM SetErrorMessage(message);

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION Authenticate -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Аутентификация.
 * @param {text} pSession - Сессия
 * @param {text} pKey - Ключ аутентификации
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {text} - Новый ключ аутентификации. Если вернёт null вызвать GetErrorMessage для просмотра сообщения об ошибке.
 */
CREATE OR REPLACE FUNCTION Authenticate (
  pSession	    text,
  pKey          text,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
)
RETURNS 	    text
AS $$
DECLARE
  vKey          text;
  nUserId	    numeric;
  message	    text;
BEGIN
  IF ValidToken(pSession, pKey) THEN
    vKey := SessionIn(pSession, pAgent, pHost, gen_salt('md5'));
  ELSE
    PERFORM SessionOut(pSession, false, GetErrorMessage());
  END IF;

  RETURN vKey;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;

  PERFORM SetSessionKey(null);
  PERFORM SetUserId(null);

  PERFORM SetErrorMessage(message);

  SELECT userid INTO nUserId FROM db.session WHERE key = pSession;

  IF found THEN
    INSERT INTO db.log (type, code, username, session, text)
    VALUES ('E', 3003, GetUserName(nUserId), pSession, message);
  END IF;

  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION Authorize ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Авторизовать.
 * @param {text} pSession - Сессия
 * @return {bool} - Если вернёт false вызвать GetErrorMessage для просмотра сообщения об ошибке.
 */
CREATE OR REPLACE FUNCTION Authorize (
  pSession	    text
)
RETURNS 	    bool
AS $$
BEGIN
  RETURN ValidSession(pSession);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
