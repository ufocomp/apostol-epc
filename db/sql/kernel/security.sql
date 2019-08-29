--------------------------------------------------------------------------------
-- SECURITY --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.language -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.language (
    id		numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code	varchar(30) NOT NULL,
    name	varchar(50) NOT NULL,
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
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    type		char NOT NULL,
    username		varchar(50) NOT NULL,
    fullname		text,
    email		text,
    description		text,
    status		bit(4) DEFAULT B'0001' NOT NULL,
    created		timestamp DEFAULT NOW() NOT NULL,
    lock_date		timestamp DEFAULT NULL,
    expiry_date		timestamp DEFAULT NULL,
    pwhash		text DEFAULT NULL,
    passwordchange	boolean DEFAULT true NOT NULL,
    passwordnotchange	boolean DEFAULT false NOT NULL,
    CONSTRAINT ch_user_type CHECK (type IN ('G', 'U'))
);

COMMENT ON TABLE db.user IS 'Пользователи и группы системы.';

COMMENT ON COLUMN db.user.id IS 'Идентификатор';
COMMENT ON COLUMN db.user.type IS 'Тип пользователя: "U" - пользователь; "G" - группа';
COMMENT ON COLUMN db.user.username IS 'Наименование пользователя (login)';
COMMENT ON COLUMN db.user.fullname IS 'Полное наименование пользователя';
COMMENT ON COLUMN db.user.email IS 'Электронный адрес';
COMMENT ON COLUMN db.user.description IS 'Описание пользователя';
COMMENT ON COLUMN db.user.status IS 'Статус пользователя';
COMMENT ON COLUMN db.user.created IS 'Дата создания пользователя';
COMMENT ON COLUMN db.user.lock_date IS 'Дата блокировки пользователя';
COMMENT ON COLUMN db.user.expiry_date IS 'Дата окончания срока действия пароля';
COMMENT ON COLUMN db.user.pwhash IS 'Хеш пароля';
COMMENT ON COLUMN db.user.passwordchange IS 'Сменить пароль при следующем входе в систему (да/нет)';
COMMENT ON COLUMN db.user.passwordnotchange IS 'Установлен запрет на смену пароля самим пользователем (да/нет)';

CREATE UNIQUE INDEX ON db.user (type, username);
CREATE UNIQUE INDEX ON db.user (email);

CREATE INDEX ON db.user (type);
CREATE INDEX ON db.user (username);
CREATE INDEX ON db.user (username varchar_pattern_ops);
CREATE INDEX ON db.user (email);
CREATE INDEX ON db.user (email varchar_pattern_ops);

CREATE OR REPLACE FUNCTION db.ft_user_before_delete()
RETURNS trigger AS $$
BEGIN
  DELETE FROM db.iptable WHERE userid = OLD.ID;
  DELETE FROM db.user_ex WHERE userid = OLD.ID;
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
-- db.user_ex ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.user_ex (
    id			numeric(12) PRIMARY KEY,
    userid		numeric(12) NOT NULL,
    input_count		numeric DEFAULT 0 NOT NULL,
    input_last		timestamp DEFAULT NULL,
    input_error		numeric DEFAULT 0 NOT NULL,
    input_error_last	timestamp DEFAULT NULL,
    input_error_all	numeric DEFAULT 0 NOT NULL,
    lc_ip		inet,
    default_department	numeric(12),
    default_workplace	numeric(12),
    state               bit(3) DEFAULT B'000' NOT NULL,
    session_limit	integer DEFAULT 0 NOT NULL,
    CONSTRAINT fk_user_ex_userid FOREIGN KEY (userid) REFERENCES db.user(id)
);

COMMENT ON TABLE db.user_ex IS 'Дополнительная информация о пользователе системы.';

COMMENT ON COLUMN db.user_ex.id IS 'Идентификатор';
COMMENT ON COLUMN db.user_ex.userid IS 'Пользователь';
COMMENT ON COLUMN db.user_ex.input_count IS 'Счетчик входов';
COMMENT ON COLUMN db.user_ex.input_last IS 'Последний вход';
COMMENT ON COLUMN db.user_ex.input_error IS 'Текущие неудавшиеся входы';
COMMENT ON COLUMN db.user_ex.input_error_last IS 'Последний неудавшийся вход в систему';
COMMENT ON COLUMN db.user_ex.input_error_all IS 'Общее количество неудачных входов';
COMMENT ON COLUMN db.user_ex.lc_ip IS 'IP адрес последнего подключения';
COMMENT ON COLUMN db.user_ex.default_department IS 'Идентификатор подразделения по умолчанию';
COMMENT ON COLUMN db.user_ex.default_workplace IS 'Идентификатор рабочего места по умолчанию';
COMMENT ON COLUMN db.user_ex.state IS 'Состояние: 000 - Отключен; 001 - Подключен; 010 - локальный IP; 100 - доверительный IP';
COMMENT ON COLUMN db.user_ex.session_limit IS 'Максимально допустимое количество одновременно открытых сессий.';

--------------------------------------------------------------------------------
CREATE INDEX ON db.user_ex (userid);
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_user_ex_before_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NEW.ID IS NULL OR NEW.ID = 0 THEN
    SELECT NEW.USERID INTO NEW.ID;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_user_ex_before_insert
  BEFORE INSERT ON db.user_ex
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_user_ex_before_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_user_ex_state()
RETURNS trigger AS $$
DECLARE
  i		int;

  arrIp		text[];

  lHost		inet;

  nRange	int;

  vCode		varchar;

  nOnLine	int;
  nLocal	int;
  nTrust	int;

  bSuccess	boolean;

  nUserId	numeric;

  vData		Variant;

  r		record;
BEGIN
  nUserId := current_userid();

  IF nUserId IS NULL THEN
    RETURN NEW;
  END IF;

  nOnLine := 0;
  nLocal := 0;
  nTrust := 0;

  NEW.STATE := B'000';

  FOR r IN SELECT department, host FROM db.session WHERE userid = nUserId GROUP BY department, host
  LOOP
    r.host := coalesce(NEW.LC_IP, r.host);

    IF r.host IS NOT NULL THEN

      SELECT code INTO vCode FROM department WHERE id = r.department;

      IF found THEN

        vData := RegGetValue(RegOpenKey('CURRENT_CONFIG', 'CONFIG\Department' || E'\u005C' || vCode), 'LocalIP');

        IF vData.vString IS NOT NULL THEN
          arrIp := string_to_array_trim(vData.vString, ',');
        ELSE
          arrIp := string_to_array_trim('127.0.0.1, ::1', ',');
        END IF;

        bSuccess := false;
        FOR i IN 1..array_length(arrIp, 1)
        LOOP
          SELECT host INTO lHost FROM str_to_inet(arrIp[i]);

          bSuccess := r.host <<= lHost;

          EXIT WHEN coalesce(bSuccess, false);
        END LOOP;

        IF bSuccess THEN
          nLocal := nLocal + 1;
        END IF;

        vData := RegGetValue(RegOpenKey('CURRENT_CONFIG', 'CONFIG\Department' || E'\u005C' || vCode), 'EntrustedIP');

        IF vData.vString IS NOT NULL THEN
          arrIp := string_to_array_trim(vData.vString, ',');

          bSuccess := false;
          FOR i IN 1..array_length(arrIp, 1)
          LOOP
            SELECT host, range INTO lHost, nRange FROM str_to_inet(arrIp[i]);

            IF nRange IS NOT NULL THEN
              bSuccess := (r.host >= lHost) AND (r.host <= lHost + (nRange - 1));
            ELSE
              bSuccess := r.host <<= lHost;
            END IF;

            EXIT WHEN coalesce(bSuccess, false);
          END LOOP;

          IF bSuccess THEN
            nTrust := nTrust + 1;
          END IF;

        END IF;
      END IF;
    END IF;

    nOnLine := nOnLine + 1;
  END LOOP;

  IF nTrust > 0 THEN
    NEW.STATE := set_bit(NEW.STATE, 0, 1);
  END IF;

  IF nLocal > 0 THEN
    NEW.STATE := set_bit(NEW.STATE, 1, 1);
  END IF;

  IF (nOnLine - (nTrust + nLocal)) > 0 THEN
    NEW.STATE := set_bit(NEW.STATE, 2, 1);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_user_ex_state
  BEFORE UPDATE ON db.user_ex
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_user_ex_state();

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
  pType		char default 'A'
) RETURNS	text
AS $$
DECLARE
  r		record;
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
  i		int;

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
  r		record;
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

  r		record;
BEGIN
  SELECT session_limit INTO nLimit FROM db.user_ex WHERE userid = pUserId;

  IF coalesce(nLimit, 0) > 0 THEN

    SELECT count(*) INTO nCount FROM db.session WHERE userid = pUserId;

    FOR r IN SELECT key FROM db.session WHERE userid = pUserId ORDER BY created
    LOOP
      EXIT WHEN nCount = 0;
      EXIT WHEN nCount < nLimit;

      PERFORM Logout(r.key);

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

CREATE OR REPLACE VIEW users (Id, UserName, FullName, Email, Description,
  PasswordChange, PasswordNotChange, Status, CDate, LDate, EDate, System,
  InputCount, InputLast, InputError, InputErrorLast, InputErrorAll, lcip,
  LoginStatus, SessionLimit
)
AS
  SELECT u.id, u.username, u.fullname, u.email, u.description,
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
         e.input_count, e.input_last, e.input_error, e.input_error_last, e.input_error_all,
         e.lc_ip,
         CASE
         WHEN e.state & B'111' = B'111' THEN 'online (all)'
         WHEN e.state & B'110' = B'110' THEN 'online (local & trust)'
         WHEN e.state & B'101' = B'101' THEN 'online (ext & trust)'
         WHEN e.state & B'011' = B'011' THEN 'online (ext & local)'
         WHEN e.state & B'100' = B'100' THEN 'online (trust)'
         WHEN e.state & B'010' = B'010' THEN 'online (local)'
         WHEN e.state & B'001' = B'001' THEN 'online (ext)'
         ELSE 'offline'
         END,
         e.session_limit
    FROM db.user u INNER JOIN db.user_ex e on e.userid = u.id
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
-- db.department_type ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.department_type (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code		varchar(30) NOT NULL,
    name		varchar(50)
);

COMMENT ON TABLE db.department_type IS 'Тип подразделения.';

COMMENT ON COLUMN db.department_type.id IS 'Идентификатор';
COMMENT ON COLUMN db.department_type.code IS 'Код типа подразделения';
COMMENT ON COLUMN db.department_type.name IS 'Наименование кода типа подразделения';

CREATE UNIQUE INDEX ON db.department_type (code);

INSERT INTO db.department_type (code, name) VALUES ('root', 'Корень');
INSERT INTO db.department_type (code, name) VALUES ('main', 'Головная организация');
INSERT INTO db.department_type (code, name) VALUES ('branch', 'Филиал');
INSERT INTO db.department_type (code, name) VALUES ('depart', 'Отделение');
INSERT INTO db.department_type (code, name) VALUES ('aof', 'Дополнительный офис');

--------------------------------------------------------------------------------
-- DepartmentType --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW DepartmentType
AS
  SELECT * FROM db.department_type;

GRANT SELECT ON DepartmentType TO administrator;

--------------------------------------------------------------------------------
-- GetDepartmentType -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetDepartmentType (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT Id INTO nId FROM db.department_type WHERE Code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.department ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.department (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    parent		numeric(12) DEFAULT NULL,
    type		numeric(12) NOT NULL,
    code		varchar(30) NOT NULL,
    name		varchar(50) NOT NULL,
    description		text,
    validfromdate	timestamp DEFAULT NOW() NOT NULL,
    validtodate		timestamp,
    CONSTRAINT fk_department_parent FOREIGN KEY (parent) REFERENCES db.department(id),
    CONSTRAINT fk_department_type FOREIGN KEY (type) REFERENCES db.department_type(id)
);

COMMENT ON TABLE db.department IS 'Подразделения.';

COMMENT ON COLUMN db.department.id IS 'Идентификатор';
COMMENT ON COLUMN db.department.parent IS 'Ссылка на родительский узел подразделения';
COMMENT ON COLUMN db.department.type IS 'Тип подразделения';
COMMENT ON COLUMN db.department.code IS 'Код подразделения';
COMMENT ON COLUMN db.department.name IS 'Наименование подразделения';
COMMENT ON COLUMN db.department.description IS 'Описание подразделения';
COMMENT ON COLUMN db.department.validfromdate IS 'Дата открытия';
COMMENT ON COLUMN db.department.validtodate IS 'Дата закрытия';

CREATE INDEX ON db.department (parent);
CREATE INDEX ON db.department (type);

CREATE UNIQUE INDEX ON db.department (code);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_department_before_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NEW.ID = NEW.PARENT THEN
    NEW.PARENT := GetDepartment('root');
  END IF;

  RAISE DEBUG 'Создано подразделение Id: %', NEW.ID;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_department_before_insert
  BEFORE INSERT ON db.department
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_department_before_insert();

--------------------------------------------------------------------------------
-- Department ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Department (Id, Parent, Type, TypeCode, TypeName, 
  Code, Name, Description, ValidFromDate, ValidToDate
)
as
  SELECT d.id, d.parent, d.type, t.code, t.name, d.code, d.name, 
         d.description, d.validfromdate, d.validtodate
    FROM db.department d INNER JOIN db.department_type t ON t.id = d.type;

GRANT SELECT ON Department TO administrator;

--------------------------------------------------------------------------------
-- db.member_department --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.member_department (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    department		numeric(12) NOT NULL,
    member		numeric(12) NOT NULL,
    CONSTRAINT fk_md_department FOREIGN KEY (department) REFERENCES db.department(id),
    CONSTRAINT fk_md_member FOREIGN KEY (member) REFERENCES db.user(id)
);

COMMENT ON TABLE db.member_department IS 'Членство в подразделениях.';

COMMENT ON COLUMN db.member_department.id IS 'Идентификатор';
COMMENT ON COLUMN db.member_department.department IS 'Подразделение';
COMMENT ON COLUMN db.member_department.member IS 'Участник';

CREATE INDEX ON db.member_department (department);
CREATE INDEX ON db.member_department (member);

CREATE UNIQUE INDEX ON db.member_department (department, member);

--------------------------------------------------------------------------------
-- MemberDepartment ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MemberDepartment (Id, Department, Code, Name, Description,
  MemberId, MemberType, MemberName, MemberFullName, MemberDesc 
)
AS
  SELECT md.id, md.department, d.code, d.name, d.description,
         md.member, u.type, u.username, u.fullname, u.description
    FROM db.member_department md INNER JOIN db.department d ON d.id = md.department
                              INNER JOIN db.user u ON u.id = md.member;

GRANT SELECT ON MemberDepartment TO administrator;

--------------------------------------------------------------------------------
-- db.workplace ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.workplace (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    sid			varchar(18) NOT NULL,
    name		varchar(50) NOT NULL,
    description		text
);

COMMENT ON TABLE db.workplace IS 'Рабочие места.';

COMMENT ON COLUMN db.workplace.id IS 'Идентификатор';
COMMENT ON COLUMN db.workplace.sid IS 'Строковый идентификатор';
COMMENT ON COLUMN db.workplace.name IS 'Наименование рабочего места';
COMMENT ON COLUMN db.workplace.description IS 'Описание рабочего места';

CREATE UNIQUE INDEX ON db.workplace (sid);
CREATE INDEX ON db.workplace (name);

CREATE OR REPLACE FUNCTION db.ft_workplace()
RETURNS trigger AS $$
BEGIN
  IF NEW.SID IS NULL THEN
    SELECT 'W:1:1:' || TRIM(TO_CHAR(NEW.ID, '999999999999')) INTO NEW.SID;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_workplace
  BEFORE INSERT ON db.workplace
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_workplace();

--------------------------------------------------------------------------------
-- Workplace -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Workplace
as
  SELECT * FROM db.workplace;

GRANT SELECT ON Workplace TO administrator;

--------------------------------------------------------------------------------
-- db.member_workplace ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.member_workplace (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    workplace		numeric(12) NOT NULL,
    member		numeric(12) NOT NULL,
    CONSTRAINT FK_MW_WORKPLACE FOREIGN KEY (workplace) REFERENCES db.workplace(id),
    CONSTRAINT FK_MW_MEMBER FOREIGN KEY (MEMBER) REFERENCES db.user(id)
);

COMMENT ON TABLE db.member_workplace IS 'Членство в рабочих местах.';

COMMENT ON COLUMN db.member_workplace.id IS 'Идентификатор';
COMMENT ON COLUMN db.member_workplace.workplace IS 'Робочее место';
COMMENT ON COLUMN db.member_workplace.member IS 'Участник';

CREATE INDEX ON db.member_workplace (workplace);
CREATE INDEX ON db.member_workplace (member);

CREATE UNIQUE INDEX ON db.member_workplace (workplace, member);

--------------------------------------------------------------------------------
-- MemberWorkPlace -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MemberWorkPlace (Id, WorkPlace, SID, WorkPlaceName, WorkPlaceDesc,
  MemberId, MemberType, MemberName, MemberFullName, MemberDesc
)
AS
  SELECT mwp.id, mwp.workplace, wp.sid, wp.name, wp.description,
         mwp.member, u.type, u.username, u.fullname, u.description
    FROM db.member_workplace mwp INNER JOIN db.workplace wp ON wp.id = mwp.workplace
                                 INNER JOIN db.user u ON u.id = mwp.member;

GRANT SELECT ON MemberWorkPlace TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION StrPwKey -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StrPwKey (
  pUserId	numeric,
  pCreated	timestamp,
  pHost		inet
) RETURNS	text
AS $$
DECLARE
  vUserName	text;
  vStrPwKey	text default null;
BEGIN
  vUserName := GetUserName(pUserId);

  IF vUserName IS NOT NULL THEN
    vStrPwKey := '{' || IntToStr(pUserId) || ':' || vUserName || ':' || current_database() || ':' || DateToStr(pCreated, 'YYMMDDHH24MISS') || ':' || coalesce(host(pHost), '<null>') || '}';
  END IF;

  RETURN vStrPwKey;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SessionKey ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SessionKey (
  pPwKey	text,
  pPassKey	text
) RETURNS	text
AS $$
DECLARE
  vSessionKey	text default null;
BEGIN
  IF pPwKey IS NOT NULL THEN
    vSessionKey := encode(hmac(pPwKey, pPassKey, 'sha1'), 'hex');
  END IF;

  RETURN vSessionKey;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.session ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.session (
    key			varchar(40) PRIMARY KEY NOT NULL,
    suid                numeric(12) NOT NULL,
    userid		numeric(12) NOT NULL,
    pwkey		text NOT NULL,
    lang		numeric(12) NOT NULL,
    department		numeric(12) NOT NULL,
    workplace		numeric(12) NOT NULL,
    oper_date		timestamp DEFAULT NULL,
    created		timestamp DEFAULT NOW() NOT NULL,
    last_update		timestamp DEFAULT NOW() NOT NULL,
    host		inet,
    CONSTRAINT fk_session_suid FOREIGN KEY (suid) REFERENCES db.user(id),
    CONSTRAINT fk_session_userid FOREIGN KEY (userid) REFERENCES db.user(id),
    CONSTRAINT fk_session_lang FOREIGN KEY (lang) REFERENCES db.language(id),
    CONSTRAINT fk_session_department FOREIGN KEY (department) REFERENCES db.department(id),
    CONSTRAINT fk_session_workplace FOREIGN KEY (workplace) REFERENCES db.workplace(id)
);

COMMENT ON TABLE db.session IS 'Сессии пользователей.';

COMMENT ON COLUMN db.session.key IS 'Хеш ключа';
COMMENT ON COLUMN db.session.suid IS 'Пользователь сессии';
COMMENT ON COLUMN db.session.userid IS 'Пользователь';
COMMENT ON COLUMN db.session.pwkey IS 'Ключ';
COMMENT ON COLUMN db.session.lang IS 'Язык';
COMMENT ON COLUMN db.session.department IS 'Подразделение';
COMMENT ON COLUMN db.session.workplace IS 'Рабочие место';
COMMENT ON COLUMN db.session.oper_date IS 'Дата операционного дня';
COMMENT ON COLUMN db.session.created IS 'Дата и время создания сессии';
COMMENT ON COLUMN db.session.last_update IS 'Дата и время последнего обновления сессии';
COMMENT ON COLUMN db.session.host IS 'IP адрес подключения';

CREATE INDEX ON db.session (suid);
CREATE INDEX ON db.session (userid);
CREATE INDEX ON db.session (created);
CREATE INDEX ON db.session (last_update);

--------------------------------------------------------------------------------
-- FUNCTION ft_session ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_session()
RETURNS TRIGGER
AS $$
DECLARE
  nId	NUMERIC;
BEGIN
  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  ELSIF (TG_OP = 'UPDATE') THEN
    IF OLD.KEY <> NEW.KEY THEN
      RAISE DEBUG 'Hacking alert: key (% <> %).', OLD.KEY, NEW.KEY;
      RETURN NULL;
    END IF;

    IF OLD.PWKEY <> NEW.PWKEY THEN
      RAISE DEBUG 'Hacking alert: pwkey (% <> %).', OLD.PWKEY, NEW.KEY;
      RETURN NULL;
    END IF;

    IF OLD.SUID <> NEW.SUID THEN
      RAISE DEBUG 'Hacking alert: suid (% <> %).', OLD.SUID, NEW.SUID;
      RETURN NULL;
    END IF;

    IF OLD.CREATED <> NEW.CREATED THEN
      RAISE DEBUG 'Hacking alert: created (% <> %).', OLD.CREATED, NEW.CREATED;
      RETURN NULL;
    END IF;

    IF OLD.DEPARTMENT <> NEW.DEPARTMENT THEN
      SELECT ID INTO nID FROM MEMBER_DEPARTMENT WHERE DEPARTMENT = NEW.DEPARTMENT AND MEMBER = NEW.USERID;
      IF NOT FOUND THEN
        NEW.DEPARTMENT := OLD.DEPARTMENT;
      END IF;
    END IF;

    IF OLD.WORKPLACE <> NEW.WORKPLACE THEN
      SELECT ID INTO nID
        FROM MEMBER_WORKPLACE
       WHERE WORKPLACE = NEW.WORKPLACE
         AND MEMBER IN (
           SELECT NEW.USERID
           UNION ALL
           SELECT USERID FROM MEMBER_GROUP WHERE MEMBER = NEW.USERID
         );

      IF NOT FOUND THEN
        NEW.WORKPLACE := OLD.WORKPLACE;
      END IF;
    END IF;

    RETURN NEW;
  ELSIF (TG_OP = 'INSERT') THEN
    IF NEW.SUID IS NULL THEN
      NEW.SUID := NEW.USERID;
    END IF;

    IF NEW.PWKEY IS NULL THEN
      NEW.PWKEY := crypt(StrPwKey(NEW.SUID, NEW.CREATED, NEW.HOST), gen_salt('md5'));
    END IF;

    IF NEW.PWKEY IS NOT NULL THEN
      NEW.KEY := SessionKey(NEW.PWKEY, SecretKey());
    END IF;

    IF NEW.LANG IS NULL THEN
      SELECT ID INTO NEW.LANG FROM db.language WHERE CODE = 'ru';
    END IF;

    IF NEW.DEPARTMENT IS NULL THEN

      NEW.DEPARTMENT := GetDefaultDepartment(NEW.USERID);

    ELSE

      SELECT id INTO nID
        FROM member_department
       WHERE department = NEW.DEPARTMENT
         AND member IN (
           SELECT NEW.USERID
            UNION ALL
           SELECT userid FROM member_group WHERE member = NEW.USERID
         );

      IF NOT FOUND THEN
        NEW.DEPARTMENT := NULL;
      END IF;
    END IF;

    IF NEW.WORKPLACE IS NULL THEN

      NEW.WORKPLACE := GetDefaultWorkPlace(NEW.USERID);

    ELSE

      SELECT id INTO nID
        FROM member_workplace
       WHERE workplace = NEW.WORKPLACE
         AND member IN (
           SELECT NEW.USERID
            UNION ALL
           SELECT userid FROM member_group WHERE member = NEW.USERID
         );

      IF NOT FOUND THEN
        SELECT id INTO NEW.WORKPLACE FROM workplace WHERE sid = 'W:1:0:0';
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = db, kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_session_before_insert
  BEFORE INSERT OR UPDATE OR DELETE ON db.session
  FOR EACH ROW EXECUTE PROCEDURE db.ft_session();

--------------------------------------------------------------------------------
-- FUNCTION ft_after_update ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_session_after_update()
RETURNS TRIGGER
AS $$
BEGIN
  IF OLD.USERID <> NEW.USERID THEN
    PERFORM SetUserId(NEW.USERID);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_session_after_update
  AFTER UPDATE ON db.session
  FOR EACH ROW EXECUTE PROCEDURE db.ft_session_after_update();

--------------------------------------------------------------------------------
-- session ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW session
AS
  SELECT s.key, s.userid, s.suid, u.username, u.fullname, s.created,
         s.last_update,  u.inputlast, s.host, u.lcip, u.status, u.loginstatus
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
  PERFORM set_config('token.' || pName, pValue, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SafeGetVar ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SafeGetVar (
  pName 	text
) RETURNS text
AS $$
DECLARE
  vValue text;
BEGIN
  SELECT INTO vValue current_setting('token.' || pName);

  IF vValue <> '' THEN
    RETURN vValue;
  END IF;

  RETURN NULL;
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
  PERFORM SafeSetVar('session_key', pValue);
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
  RETURN SafeGetVar('session_key');
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
  PERFORM SafeSetVar('user_id', to_char(pValue, '999999999990'));
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
  RETURN to_number(SafeGetVar('user_id'), '999999999990');
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
  vDafaultKey	text default 'lAn4sF3#kdGzE5c*Ht1x';
  vSecretKey	text default SafeGetVar('secret_key');
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
  vSessionKey	text;
BEGIN
  SELECT key INTO vSessionKey FROM db.session WHERE key = GetSessionKey();
  IF FOUND THEN
    RETURN vSessionKey;
  END IF;
  RETURN NULL;
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
  pSession	text default current_session()
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
  pSession	text default current_session()
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
  pSession	text default current_session()
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
  pSession	text default current_session()
) RETURNS	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
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
-- FUNCTION SetSessionDepartment -----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetSessionDepartment (
  pDepartment 	numeric,
  pSession	text default current_session()
) RETURNS 	void
AS $$
BEGIN
  UPDATE db.session SET department = pDepartment WHERE key = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetSessionDepartment -----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetSessionDepartment (
  pSession	text default current_session()
)
RETURNS 	numeric
AS $$
DECLARE
  nDepartment	numeric;
BEGIN
  SELECT department INTO nDepartment FROM db.session WHERE key = pSession;
  RETURN nDepartment;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_department -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION current_department (
  pSession	text default current_session()
)
RETURNS 	numeric
AS $$
BEGIN
  RETURN GetSessionDepartment(pSession);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetSessionWorkplace ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetSessionWorkplace (
  pWorkplace 	numeric,
  pSession	text default current_session()
) RETURNS 	void
AS $$
BEGIN
  UPDATE db.session SET workplace = pWorkplace WHERE key = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetSessionWorkplace ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetSessionWorkplace (
  pSession	text default current_session()
)
RETURNS 	numeric
AS $$
DECLARE
  nWorkplace	numeric;
BEGIN
  SELECT workplace INTO nWorkplace FROM db.session WHERE key = pSession;
  RETURN nWorkplace;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_workplace --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION current_workplace (
  pSession	text default current_session()
)
RETURNS 	numeric
AS $$
BEGIN
  RETURN GetSessionWorkplace(pSession);
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
  pSession	text default current_session()
) RETURNS 	void
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
  pSession	text default current_session()
) RETURNS 	void
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
  pSession	text default current_session()
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
  pSession	text default current_session()
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
  pSession	text default current_session()
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
  pCode		text default 'ru',
  pSession	text default current_session()
) RETURNS	void
AS $$
DECLARE
  nLang		numeric;
BEGIN
  SELECT id INTO nLang FROM db.language WHERE code = pCode;
  IF FOUND THEN
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
  pSession	text default current_session()
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
  pSession	text default current_session()
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
  pSession	text default current_session()
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

CREATE OR REPLACE FUNCTION IsUserRole (
  pRole		numeric,
  pUser		numeric default current_userid()
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

CREATE OR REPLACE FUNCTION IsUserRole (
  pRole		text,
  pUser		text default current_username()
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
 * @param {varchar} pEmail - Электронный адрес
 * @param {text} pDescription - Описание
 * @param {boolean} pPasswordChange - Сменить пароль при следующем входе в систему
 * @param {boolean} pPasswordNotChange - Установить запрет на смену пароля самим пользователем
 * @param {numeric} pDepartment - Подразделение
 * @return {(id|exception)} - Id учётной записи или ошибку
 */
CREATE OR REPLACE FUNCTION CreateUser (
  pUserName		varchar,
  pPassword		text,
  pFullName		text,
  pEmail		varchar,
  pDescription		text default null,
  pPasswordChange	boolean default true,
  pPasswordNotChange	boolean default false,
  pDepartment   	numeric default current_department()
) RETURNS		numeric
AS $$
DECLARE
  nUserId		numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO nUserId FROM users WHERE username = lower(pUserName);

  IF found THEN
    PERFORM RoleExists(pUserName);
  END IF;

  INSERT INTO db.user (type, username, fullname, email, description, passwordchange, passwordnotchange)
  VALUES ('U', pUserName, pFullName, pEmail, pDescription, pPasswordChange, pPasswordNotChange)
  RETURNING id INTO nUserId;

  INSERT INTO db.user_ex (userid) VALUES (nUserId);

  IF pPassword IS NOT NULL AND pPassword <> '' THEN
    PERFORM SetPassword(nUserId, pPassword);
  END IF;

  PERFORM AddMemberToWorkPlace(nUserId, GetWorkPlace('W:1:0:0'));

  IF pDepartment IS NOT NULL THEN
    PERFORM AddMemberToDepartment(nUserId, pDepartment);
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
  pGroupName	varchar,
  pFullName	text,
  pDescription	text
) RETURNS	numeric
AS $$
DECLARE
  nGroupId	numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO nGroupId FROM groups WHERE username = lower(pGroupName);

  IF found THEN
    PERFORM RoleExists(pGroupName);
  END IF;

  INSERT INTO db.user (type, username, fullname, description)
  VALUES ('G', pGroupName, pFullName, pDescription) returning Id INTO nGroupId;

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
 * @param {varchar} pEmail - Электронный адрес
 * @param {text} pDescription - Описание
 * @param {boolean} pPasswordChange - Сменить пароль при следующем входе в систему
 * @param {boolean} pPasswordNotChange - Установить запрет на смену пароля самим пользователем
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION UpdateUser (
  pId			numeric,
  pUserName		varchar,
  pPassword		text default null,
  pFullName		text default null,
  pEmail		varchar default null,
  pDescription		text default null,
  pPasswordChange	boolean default null,
  pPasswordNotChange	boolean default null
) RETURNS		void
AS $$
DECLARE
  r			users%rowtype;
BEGIN
  IF session_user <> 'kernel' THEN
    IF pId <> current_userid() THEN
      IF NOT IsUserRole('administrator')  THEN
        PERFORM AccessDenied();
      END IF;
    END IF;
  END IF;

  SELECT * INTO r FROM users WHERE id = pId;

  IF r.username IN ('admin', 'daemon', 'apibot') THEN
    IF r.username <> lower(pUserName) THEN
      PERFORM SystemRoleError();
    END IF;
  END IF;

  IF found THEN
    pEmail := coalesce(pEmail, r.email);
    pDescription := coalesce(pDescription, r.description);
    pPasswordChange := coalesce(pPasswordChange, r.passwordchange);
    pPasswordNotChange := coalesce(pPasswordNotChange, r.passwordnotchange);

    UPDATE db.user
       SET username = coalesce(pUserName, username),
           fullname = coalesce(pFullName, fullname),
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
  pId		numeric,
  pGroupName	varchar,
  pFullName	text,
  pDescription	text
) RETURNS	void
AS $$
DECLARE
  vGroupName	varchar;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT username INTO vGroupName FROM db.user WHERE id = pId;

  IF vGroupName IN ('administrator', 'manager', 'operator', 'external') THEN
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
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  IF pId = current_userid() THEN
    PERFORM DeleteUserError();
  END IF;

  SELECT username INTO vUserName FROM db.user WHERE id = pId;

  IF vUserName IN ('admin', 'daemon', 'mailbot', 'apibot') THEN
    PERFORM SystemRoleError();
  END IF;

  IF FOUND THEN
    DELETE FROM db.member_department WHERE member = pId;
    DELETE FROM db.member_workplace WHERE member = pId;
    DELETE FROM db.member_group WHERE member = pId;
    DELETE FROM db.user_ex WHERE userid = pId;
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

  IF not found THEN
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
  pId		numeric
) RETURNS	void
AS $$
DECLARE
  vGroupName	varchar;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT username INTO vGroupName FROM db.user WHERE id = pId;

  IF vGroupName IN ('administrator', 'manager', 'operator', 'external') THEN
    PERFORM SystemRoleError();
  END IF;

  DELETE FROM db.member_department WHERE member = pId;
  DELETE FROM db.member_workplace WHERE member = pId;
  DELETE FROM db.member_group WHERE userid = pId;
  DELETE FROM db.user_ex WHERE userid = pId;
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
  pGroupName	varchar
) RETURNS	void
AS $$
DECLARE
  nId		numeric;
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

  IF NOT FOUND THEN
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
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.user WHERE type = 'G' AND username = pGroupName;

  IF NOT FOUND THEN
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
  pId			numeric,
  pPassword		text
) RETURNS		void
AS $$
DECLARE
  nUserId		numeric;
  bPasswordChange	boolean;
  r			record;
BEGIN
  nUserId := current_userid();

  IF session_user <> 'kernel' THEN
    IF pId <> nUserId THEN
      IF NOT IsUserRole('administrator') THEN
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
           pwhash = crypt(pPassword, gen_salt('md5'))
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
      IF NOT IsUserRole('administrator') THEN
        PERFORM AccessDenied();
      END IF;
    END IF;
  END IF;

  SELECT id INTO nId FROM users WHERE id = pId;

  IF FOUND THEN
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
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO nId FROM users WHERE id = pId;

  IF FOUND THEN
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
    IF NOT IsUserRole('administrator') THEN
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
  pGroup	numeric default null
) RETURNS	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
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
  pMember	numeric default null
) RETURNS	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
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
-- CreateDepartment ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateDepartment (
  pParent	numeric,
  pType		numeric,
  pCode		varchar,
  pName		varchar,
  pDescription	text default null
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.department (parent, type, code, name, description)
  VALUES (coalesce(pParent, GetDepartment('root')), pType, pCode, pName, pDescription) returning Id INTO nId;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditDepartment --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditDepartment (
  pId			numeric,
  pParent		numeric default null,
  pType			numeric default null,
  pCode			varchar default null,
  pName			varchar default null,
  pDescription		text default null,
  pValidFromDate	timestamptz default null,
  pValidToDate		timestamptz default null
) RETURNS void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  IF pId = GetDepartment('root') THEN
    UPDATE db.department
       SET name = coalesce(pName, name),
           description = coalesce(pDescription, description)
     WHERE id = pId;
  ELSE
    UPDATE db.department
       SET parent = coalesce(pParent, parent),
           type = coalesce(pType, type),
           code = coalesce(pCode, code),
           name = coalesce(pName, name),
           description = coalesce(pDescription, description),
           validfromdate = coalesce(pValidFromDate, validfromdate),
           validtodate = coalesce(pValidToDate, validtodate)
     WHERE id = pId;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteDepartment ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteDepartment (
  pId			numeric
) RETURNS void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.department WHERE Id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetDepartment ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetDepartment (
  pCode		text
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.department WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetDepartmentCode -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetDepartmentCode (
  pId		numeric
) RETURNS	varchar
AS $$
DECLARE
  vCode		varchar;
BEGIN
  SELECT code INTO vCode FROM db.department WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetDepartmentName -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetDepartmentName (
  pId		numeric
) RETURNS	varchar
AS $$
DECLARE
  vName		varchar;
BEGIN
  SELECT name INTO vName FROM db.department WHERE id = pId;
  RETURN vName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddMemberToDepartment -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddMemberToDepartment (
  pMember		numeric,
  pDepartment		numeric
) RETURNS void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.member_department (department, member) VALUES (pDepartment, pMember);
exception
  when OTHERS THEN
    null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteDepartmentForMember ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет подразделение для пользователя.
 * @param {id} pMember - Идентификатор пользователя
 * @param {id} pDepartment - Идентификатор подразделения, при null удаляет все подразделения для указанного пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DeleteDepartmentForMember (
  pMember		numeric,
  pDepartment		numeric default null
) RETURNS void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_department WHERE department = coalesce(pDepartment, department) AND member = pMember;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteMemberFromDepartment --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет пользователя из подразделения.
 * @param {id} pDepartment - Идентификатор подразделения
 * @param {id} pMember - Идентификатор пользователя, при null удаляет всех пользователей из указанного подразделения
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DeleteMemberFromDepartment (
  pDepartment		numeric,
  pMember		numeric default null
) RETURNS void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_department WHERE department = pDepartment AND member = coalesce(pMember, member);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetDepartment ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetDepartment (
  pDepartment	numeric,
  pMember	numeric default current_userid(),
  pSession	text default current_session()
) RETURNS	void
AS $$
DECLARE
  nId		numeric;
  vUserName     varchar;
  vDepName      text;
BEGIN
  vDepName := GetDepartmentName(pDepartment);
  IF vDepName IS NULL THEN
    PERFORM DepartmentError();
  END IF;

  vUserName := GetUserName(pMember);
  IF vDepName IS NULL THEN
    PERFORM UserNotFound(pMember);
  END IF;

  SELECT id INTO nId FROM db.member_department WHERE department = pDepartment AND member = pMember;
  IF NOT FOUND THEN
    PERFORM UserNotMemberDepartment(vUserName, vDepName);
  END IF;

  UPDATE db.session SET department = pDepartment WHERE key = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetDefaultDepartment --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetDefaultDepartment (
  pDepartment	numeric default current_department(),
  pMember	numeric default current_userid()
) RETURNS	void
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId
    FROM db.member_department
   WHERE department = pDepartment
     AND member IN (
       SELECT pMember
        UNION ALL
       SELECT userid FROM db.member_group WHERE member = pMember
     );

  IF found THEN
    UPDATE db.user_ex SET default_department = pDepartment WHERE userid = pMember;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetDefaultDepartment --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetDefaultDepartment (
  pMember	numeric default current_userid()
) RETURNS	numeric
AS $$
DECLARE
  nDefault	numeric;
  nDepartment	numeric;
BEGIN
  SELECT default_department INTO nDefault FROM db.user_ex WHERE userid = pMember;

  SELECT department INTO nDepartment
    FROM db.member_department
   WHERE department = nDefault
     AND member IN (
       SELECT pMember
        UNION ALL
       SELECT userid FROM db.member_group WHERE member = pMember
     );

  IF not found THEN
    SELECT MIN(department) INTO nDepartment
      FROM db.member_department
     WHERE member = pMember;
  END IF;

  RETURN nDepartment;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateWorkPlace -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateWorkPlace (
  pName		varchar,
  pDescription	text
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.workplace (name, description)
  VALUES (pName, pDescription) returning Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateWorkPlace -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION UpdateWorkPlace (
  pId		numeric,
  pName		varchar,
  pDescription	text
) RETURNS 	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  UPDATE db.workplace SET Name = pName, Description = pDescription WHERE Id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteWorkPlace -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteWorkPlace (
  pId		numeric
) RETURNS 	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.workplace WHERE Id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddMemberToWorkPlace --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddMemberToWorkPlace (
  pMember	numeric,
  pWorkPlace	numeric
) RETURNS 	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.member_workplace (workplace, member) VALUES (pWorkPlace, pMember);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteWorkPlaceForMember ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteWorkPlaceForMember (
  pMember	numeric,
  pWorkPlace	numeric default null
) RETURNS void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_workplace WHERE workplace = coalesce(pWorkPlace, workplace) AND member = pMember;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteMemberFromWorkPlace ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteMemberFromWorkPlace (
  pWorkPlace	numeric,
  pMember	numeric default null
) RETURNS void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_workplace WHERE workplace = pWorkPlace AND member = coalesce(pMember, member);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetWorkPlaceSID -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetWorkPlaceSID (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vSID		text;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT sid INTO vSID FROM db.workplace WHERE id = pId;

  RETURN vSID;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetWorkPlace ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetWorkPlace (
  pSID		text
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.workplace WHERE SID = pSID;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetWorkPlaceName ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetWorkPlaceName (
  pId		numeric
) RETURNS 	varchar
AS $$
DECLARE
  vName		varchar;
BEGIN
  SELECT name INTO vName FROM db.workplace WHERE id = pId;

  RETURN vName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetWorkPlace ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetWorkPlace (
  pWorkPlace	numeric,
  pMember	numeric default current_userid(),
  pSession	text default current_session()
) RETURNS	void
AS $$
DECLARE
  nId		numeric;
  vUserName     varchar;
  vWorkPlace    text;
BEGIN
  vWorkPlace := GetWorkPlaceName(pWorkPlace);
  IF vWorkPlace IS NULL THEN
    PERFORM WorkPlaceError();
  END IF;

  vUserName := GetUserName(pMember);
  IF vUserName IS NULL THEN
    PERFORM UserNotFound(pMember);
  END IF;

  SELECT id INTO nId
    FROM db.member_workplace
   WHERE workplace = pWorkPlace
     AND member IN (
       SELECT pMember
       UNION ALL
       SELECT userid FROM db.member_group WHERE member = pMember
     );
  IF NOT FOUND THEN
    PERFORM UserNotMemberWorkPlace(vUserName, vWorkPlace);
  END IF;

  UPDATE db.session SET workplace = pWorkPlace WHERE key = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetDefaultWorkPlace ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetDefaultWorkPlace (
  pWorkPlace	numeric default current_workplace(),
  pMember	numeric default current_userid()
) RETURNS	void
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId
    FROM db.member_workplace
   WHERE workplace = pWorkPlace
     AND member IN (
       SELECT pMember
        UNION ALL
       SELECT userid FROM db.member_group WHERE member = pMember
     );

  IF found THEN
    UPDATE db.user_ex SET default_workplace = pWorkPlace WHERE userid = pMember;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetDefaultWorkPlace ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetDefaultWorkPlace (
  pMember	numeric default current_userid()
) RETURNS	numeric
AS $$
DECLARE
  nDefault	numeric;
  nWorkPlace	numeric;
BEGIN
  SELECT default_workplace INTO nDefault FROM db.user_ex WHERE userid = pMember;

  SELECT workplace INTO nWorkPlace
    FROM db.member_workplace
   WHERE workplace = nDefault
     AND member IN (
       SELECT pMember
        UNION ALL
       SELECT userid FROM db.member_group WHERE member = pMember
     );

  IF not found THEN
    SELECT id INTO nWorkPlace FROM workplace WHERE sid = 'W:1:0:0';
  END IF;

  RETURN nWorkPlace;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckOffline ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckOffline (
  pOffTime	INTERVAL DEFAULT '5 min'
) RETURNS	void
AS $$
BEGIN
  UPDATE db.user_ex
     SET state = B'000'
   WHERE state <> B'000'
     AND userid IN (
       SELECT userid FROM db.session WHERE userid <> (SELECT id FROM db.user WHERE username = 'apibot') AND last_update < now() - pOffTime
     );
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- LOGIN -----------------------------------------------------------------------
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
  SELECT (pwhash = crypt(pPassword, pwhash)) INTO passed
    FROM db.user
   WHERE username = pUserName;

  IF not found THEN
    PERFORM SetErrorMessage('Пользователь не найден.');
    RETURN false;
  END IF;

  IF passed THEN
    PERFORM SetErrorMessage('Успешно.');
  ELSE
    PERFORM SetErrorMessage('Пароль не прошёл проверку.');
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
  pSession	text default current_session(),
  pHost		inet default null
) RETURNS 	boolean
AS $$
DECLARE
  passed 	boolean;
BEGIN
  SELECT (key = SessionKey(crypt(StrPwKey(suid, created, coalesce(pHost, host)), pwkey), SecretKey())) INTO passed
    FROM db.session
   WHERE key = pSession;

  IF NOT FOUND THEN
    PERFORM SetErrorMessage('Ключ сессии не найден.');
    RETURN false;
  END IF;

  IF passed THEN
    PERFORM SetErrorMessage('Успешно.');
  ELSE
    PERFORM SetErrorMessage('Ключ сессии не прошёл проверку.');
  END IF;

  RETURN coalesce(passed, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SessionLogin -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Вход в систему по ключу сессии/Смена подразделения и/или рабочего места.
 * @param {text} pSession - Ключ сессии
 * @param {inet} pHost - IP адрес
 * @return {boolean} - Если вернет false вызвать GetErrorMessage для просмотра сообщения об ошибки
 */
CREATE OR REPLACE FUNCTION SessionLogin (
  pSession	text,
  pHost		inet default null
)
RETURNS 	boolean
AS $$
DECLARE
  profile	db.user%rowtype;

  nUserId	numeric default null;
  nDepartment	numeric default null;
  nWorkPlace	numeric default null;

  iHost		inet default null;
  lHost		inet default null;

  message	text;

  vDepName	text;
  vWorkPlace	text;
BEGIN
  SELECT userid, host, department, workplace
    INTO nUserId, iHost, nDepartment, nWorkPlace
    FROM db.session
   WHERE key = pSession;

  IF found THEN

    lHost := coalesce(pHost, iHost, inet_client_addr());

    IF coalesce(pSession = GetSessionKey(), false) AND iHost = lHost THEN

      PERFORM SetSessionKey(pSession);
      PERFORM SetUserId(nUserId);

      UPDATE db.session SET last_update = now() WHERE key = pSession;

      RETURN true;
    END IF;

    IF ValidSession(pSession) THEN

      SELECT * INTO profile FROM db.user WHERE id = nUserId;

      IF not found THEN
        PERFORM LoginError();
      END IF;

      IF get_bit(profile.status, 1) = 1 THEN
        PERFORM UserLockError();
      END IF;

      IF profile.lock_date IS NOT NULL AND profile.lock_date <= now() THEN
        PERFORM UserLockError();
      END IF;

      IF get_bit(profile.status, 0) = 1 THEN
        PERFORM PasswordExpiryError();
      END IF;

      IF profile.expiry_date IS NOT NULL AND profile.expiry_date <= now() THEN
        PERFORM PasswordExpiryError();
      END IF;

      IF NOT CheckIpTable(profile.id, lHost) THEN
        PERFORM LoginIpTableError(lHost);
      END IF;

      PERFORM SetSessionKey(pSession);
      PERFORM SetUserId(profile.id);

      UPDATE db.user SET status = set_bit(set_bit(status, 3, 0), 2, 1) WHERE id = profile.id;

      UPDATE db.user_ex
         SET input_last = now(),
             lc_ip = coalesce(pHost, lc_ip)
       WHERE userid = profile.id;

      UPDATE db.session SET last_update = now() WHERE key = pSession;

      RETURN true;
    END IF;
  END IF;

  PERFORM SessionLoginError();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;

  PERFORM SetSessionKey(null);
  PERFORM SetUserId(null);

  PERFORM SetErrorMessage(message);

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- LoginEx ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Вход в систему.
 * @param {text} pUserName - Пользователь (login)
 * @param {text} pPassword - Пароль
 * @param {inet} pHost - IP адрес
 * @return {(text|exception)} - Ключ сессии
 */
CREATE OR REPLACE FUNCTION LoginEx (
  pUserName	text,
  pPassword	text,
  pHost		inet
) RETURNS	text
AS $$
DECLARE
  profile	db.user%rowtype;

  nDepartment	numeric default null;
  nWorkPlace	numeric default null;

  vSessionKey	text default null;
BEGIN
  IF pUserName = '' OR pUserName IS NULL THEN
    PERFORM LoginError();
  END IF;

  IF pPassword = '' OR pPassword IS NULL THEN
    PERFORM LoginError();
  END IF;

  SELECT * INTO profile FROM db.user WHERE type = 'U' AND username = pUserName;

  IF NOT FOUND THEN
    PERFORM LoginError();
  END IF;

  IF get_bit(profile.status, 1) = 1 THEN
    PERFORM UserLockError();
  END IF;

  IF profile.lock_date IS NOT NULL AND profile.lock_date <= now() THEN
    PERFORM UserLockError();
  END IF;

  IF get_bit(profile.status, 0) = 1 THEN
    PERFORM PasswordExpiryError();
  END IF;

  IF profile.expiry_date IS NOT NULL AND profile.expiry_date <= now() THEN
    PERFORM PasswordExpiryError();
  END IF;

  nDepartment := GetDefaultDepartment(profile.id);
  nWorkPlace := GetDefaultWorkPlace(profile.id);

  IF NOT CheckIpTable(profile.id, pHost) THEN
    PERFORM LoginIpTableError(pHost);
  END IF;

  IF CheckPassword(pUserName, pPassword) THEN

    PERFORM CheckSessionLimit(profile.id);

    INSERT INTO db.session (userid, department, workplace, host)
    VALUES (profile.id, nDepartment, nWorkPlace, pHost)
    RETURNING key INTO vSessionKey;

    IF vSessionKey IS NULL THEN
      PERFORM AccessDenied();
    END IF;

    PERFORM SetSessionKey(vSessionKey);
    PERFORM SetUserId(profile.id);

    UPDATE db.user SET status = set_bit(set_bit(status, 3, 0), 2, 1) WHERE id = profile.id;

    UPDATE db.user_ex
       SET input_error = 0,
           input_count = input_count + 1,
           input_last = now(),
           lc_ip = pHost
     WHERE userid = profile.id;

  ELSE

    PERFORM SetSessionKey(null);
    PERFORM SetUserId(null);

    PERFORM LoginError();

  END IF;

  INSERT INTO db.log (object, type, code, username, session, text)
  VALUES (NULL, 'M', 1001, pUserName, vSessionKey, 'Вход в систему.');

  RETURN vSessionKey;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Login -----------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Вход в систему.
 * @param {text} pUserName - Пользователь (login)
 * @param {text} pPassword - Пароль
 * @param {inet} pHost - IP адрес
 * @return {(text|null)} - Ключ сессии. Если вернет NULL вызвать GetErrorMessage для просмотра сообщения об ошибки
 */
CREATE OR REPLACE FUNCTION Login (
  pUserName	text,
  pPassword	text,
  pHost		inet default null
) RETURNS	text
AS $$
DECLARE
  profile	db.user%rowtype;
  profile_ex	db.user_ex%rowtype;

  message	text;
BEGIN
  pHost := coalesce(pHost, inet_client_addr());

  PERFORM SetErrorMessage('Успешно.');

  BEGIN
    RETURN LoginEx(pUserName, pPassword, pHost);
  EXCEPTION
  WHEN others THEN
    GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;

    PERFORM SetSessionKey(null);
    PERFORM SetUserId(null);

    PERFORM SetErrorMessage(message);

    SELECT * INTO profile FROM db.user WHERE type = 'U' AND username = pUserName;

    IF FOUND THEN
      UPDATE db.user_ex
         SET input_error = input_error + 1,
             input_error_last = now(),
             input_error_all = input_error_all + 1
       WHERE userid = profile.id;

      SELECT * INTO profile_ex FROM db.user_ex WHERE userid = profile.id;

      IF FOUND THEN
        IF profile_ex.input_error >= 3 THEN
          PERFORM UserLock(profile.id);
        END IF;
      END IF;
    END IF;

    INSERT INTO db.log (object, type, code, username, text)
    VALUES (NULL, 'E', 3001, pUserName, message);
  END;

  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Logout ----------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выход из системы.
 * @param {text} pSession - Ключ сессии
 * @param {boolean} pLogoutAll - Закрыть все сессии
 * @return {boolean} - Если вернет false вызвать GetErrorMessage для просмотра сообщения об ошибки
 */
CREATE OR REPLACE FUNCTION Logout (
  pSession	text default current_session(),
  pLogoutAll	boolean default false
) RETURNS 	boolean
AS $$
DECLARE
  bValid	boolean;
  nUserId	numeric;
  nCount	integer;
  message	text;
BEGIN
  SELECT userid INTO nUserId FROM db.session WHERE key = pSession;

  bValid := ValidSession(pSession);

  IF bValid THEN

    message := 'Выход из системы';

    IF pLogoutAll THEN
      DELETE FROM db.session WHERE userid = nUserId;
      message := message || ' (с закрытием всех активных сессий)';
    ELSE
      DELETE FROM db.session WHERE key = pSession;
    END IF;

    SELECT count(*) INTO nCount FROM db.session WHERE userid = nUserId;

    IF nCount = 0 THEN
      UPDATE db.user SET status = set_bit(set_bit(status, 3, 1), 2, 0) WHERE id = nUserId;
    END IF;

    UPDATE db.user_ex SET state = B'000' WHERE userid = nUserId;

    INSERT INTO db.log (object, type, code, username, session, text)
    VALUES (NULL, 'M', 1002, GetUserName(nUserId), pSession, message || '.');
  END IF;

  PERFORM SetSessionKey(null);
  PERFORM SetUserId(null);

  RETURN bValid;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;

  PERFORM SetSessionKey(null);
  PERFORM SetUserId(null);

  PERFORM SetErrorMessage(message);

  INSERT INTO db.log (object, type, code, username, session, text)
  VALUES (NULL, 'E', 3002, GetUserName(nUserId), pSession, 'Выход из системы.');

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

INSERT INTO db.workplace (sid, name, description) VALUES ('W:1:0:0', 'Все', 'Все пользователи системы');
INSERT INTO db.workplace (sid, name, description) VALUES ('W:1:0:1', 'Администраторы', 'Рабочее место для администраторов системы');
INSERT INTO db.workplace (sid, name, description) VALUES ('W:1:0:2', 'Менеджеры', 'Рабочее место для менеджеров системы');
INSERT INTO db.workplace (sid, name, description) VALUES ('W:1:0:3', 'Инженеры', 'Рабочее место для инженеров системы');
INSERT INTO db.workplace (sid, name, description) VALUES ('W:1:0:4', 'Операторы', 'Рабочее место для операторов системы');
INSERT INTO db.workplace (sid, name, description) VALUES ('W:1:0:5', 'Пользователи', 'Рабочее место для пользователей системы');

SELECT CreateDepartment(null, GetDepartmentType('root'), 'root', 'Все подразделения');

SELECT AddMemberToWorkPlace(CreateGroup('administrator', 'Администраторы', 'Группа для администраторов системы'), GetWorkPlace('W:1:0:1'));
SELECT AddMemberToWorkPlace(CreateGroup('manager', 'Менеджеры', 'Группа для менеджеров системы'), GetWorkPlace('W:1:0:2'));
SELECT AddMemberToWorkPlace(CreateGroup('engineer', 'Инженеры', 'Группа для инженеров системы'), GetWorkPlace('W:1:0:3'));
SELECT AddMemberToWorkPlace(CreateGroup('operator', 'Операторы', 'Группа для операторов системы'), GetWorkPlace('W:1:0:4'));
SELECT AddMemberToWorkPlace(CreateGroup('user', 'Пользователи', 'Группа для внешних пользователей системы'), GetWorkPlace('W:1:0:5'));

SELECT AddMemberToGroup(CreateUser('admin', 'admin', 'Администратор', null, 'Администратор системы', true, false, GetDepartment('root')), GetGroup('administrator'));
SELECT CreateUser('daemon', 'daemon', 'Демон', null, 'Пользователь для API');
SELECT CreateUser('apibot', 'apibot', 'Системная служба', null, 'API клиент');
SELECT CreateUser('mailbot', 'mailbot', 'Почтовый клиент', null, 'Почтовый клиент');
