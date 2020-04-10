--------------------------------------------------------------------------------
-- db.client -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.client (
    Id			numeric(12) PRIMARY KEY,
    Document	numeric(12) NOT NULL,
    Code		varchar(30) NOT NULL,
    UserId		numeric(12),
    Phone		jsonb,
    Email		jsonb,
    Info		jsonb,
    CONSTRAINT fk_client_document FOREIGN KEY (document) REFERENCES db.document(id),
    CONSTRAINT fk_client_user FOREIGN KEY (userid) REFERENCES db.user(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.client IS 'Клиент.';

COMMENT ON COLUMN db.client.id IS 'Идентификатор';
COMMENT ON COLUMN db.client.document IS 'Документ';
COMMENT ON COLUMN db.client.code IS 'Код клиента';
COMMENT ON COLUMN db.client.userid IS 'Учетная запись клиента';
COMMENT ON COLUMN db.client.phone IS 'Справочник телефонов';
COMMENT ON COLUMN db.client.email IS 'Электронные адреса';
COMMENT ON COLUMN db.client.info IS 'Дополнительная информация';

--------------------------------------------------------------------------------

CREATE INDEX ON db.client (document);

CREATE UNIQUE INDEX ON db.client (userid);
CREATE UNIQUE INDEX ON db.client (code);

CREATE INDEX ON db.client USING GIN (phone jsonb_path_ops);
CREATE INDEX ON db.client USING GIN (email jsonb_path_ops);
CREATE INDEX ON db.client USING GIN (info jsonb_path_ops);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_client_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NEW.ID IS NULL OR NEW.ID = 0 THEN
    SELECT NEW.DOCUMENT INTO NEW.ID;
  END IF;

  IF NEW.CODE IS NULL OR NEW.CODE = '' THEN
    NEW.CODE := 'C:' || LPAD(TRIM(TO_CHAR(NEW.ID, '999999999999')), 10, '0');
  END IF;

  RAISE DEBUG 'Создан клиент Id: %', NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_client_insert
  BEFORE INSERT ON db.client
  FOR EACH ROW
  EXECUTE PROCEDURE ft_client_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_client_update()
RETURNS trigger AS $$
DECLARE
  nParent	numeric;
BEGIN
  IF OLD.USERID IS NULL AND NEW.USERID IS NOT NULL THEN
    PERFORM CheckObjectAccess(NEW.id, B'010', NEW.USERID);
    SELECT parent INTO nParent FROM db.object WHERE id = NEW.DOCUMENT;
    IF nParent IS NOT NULL THEN
      PERFORM CheckObjectAccess(nParent, B'010', NEW.USERID);
    END IF;
    UPDATE db.object SET owner = NEW.USERID WHERE id = NEW.DOCUMENT;
  END IF;

  RAISE DEBUG 'Обнавлён клиент Id: %', NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_client_update
  BEFORE UPDATE ON db.client
  FOR EACH ROW
  EXECUTE PROCEDURE ft_client_update();

--------------------------------------------------------------------------------
-- db.client_name --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.client_name (
    Id			    numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    Client		    numeric(12) NOT NULL,
    Lang		    numeric(12) NOT NULL,
    Name		    text NOT NULL,
    Short		    text,
    First		    text,
    Last		    text,
    Middle		    text,
    validFromDate	timestamp DEFAULT NOW() NOT NULL,
    ValidToDate		timestamp DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL,
    CONSTRAINT fk_client_name_client FOREIGN KEY (client) REFERENCES db.client(id),
    CONSTRAINT fk_client_name_lang FOREIGN KEY (lang) REFERENCES db.language(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.client_name IS 'Наименование клиента.';

COMMENT ON COLUMN db.client_name.client IS 'Идентификатор клиента';
COMMENT ON COLUMN db.client_name.lang IS 'Язык';
COMMENT ON COLUMN db.client_name.name IS 'Полное наименование компании/Ф.И.О.';
COMMENT ON COLUMN db.client_name.short IS 'Краткое наименование компании';
COMMENT ON COLUMN db.client_name.first IS 'Имя';
COMMENT ON COLUMN db.client_name.last IS 'Фамилия';
COMMENT ON COLUMN db.client_name.middle IS 'Отчество';
COMMENT ON COLUMN db.client_name.validfromdate IS 'Дата начала периода действия';
COMMENT ON COLUMN db.client_name.validtodate IS 'Дата окончания периода действия';

--------------------------------------------------------------------------------

CREATE INDEX ON db.client_name (client);
CREATE INDEX ON db.client_name (lang);
CREATE INDEX ON db.client_name (name);
CREATE INDEX ON db.client_name (name text_pattern_ops);
CREATE INDEX ON db.client_name (short);
CREATE INDEX ON db.client_name (short text_pattern_ops);
CREATE INDEX ON db.client_name (first);
CREATE INDEX ON db.client_name (first text_pattern_ops);
CREATE INDEX ON db.client_name (last);
CREATE INDEX ON db.client_name (last text_pattern_ops);
CREATE INDEX ON db.client_name (middle);
CREATE INDEX ON db.client_name (middle text_pattern_ops);
CREATE INDEX ON db.client_name (first, last, middle);

CREATE INDEX ON db.client_name (lang, validfromdate, validtodate);

CREATE UNIQUE INDEX ON db.client_name (client, lang, validfromdate, validtodate);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_client_name_insert_update()
RETURNS trigger AS $$
DECLARE
  nUserId	NUMERIC;
BEGIN
  IF NEW.Lang IS NULL THEN
    NEW.Lang := current_language();
  END IF;

  IF NEW.Name IS NULL THEN
    IF NEW.Last IS NOT NULL THEN
      NEW.Name := NEW.Last;
    END IF;

    IF NEW.First IS NOT NULL THEN
      IF NEW.Name IS NULL THEN
        NEW.Name := NEW.First;
      ELSE
        NEW.Name := NEW.Name || ' ' || NEW.First;
      END IF;
    END IF;

    IF NEW.Middle IS NOT NULL THEN
      IF NEW.Name IS NOT NULL THEN
        NEW.Name := NEW.Name || ' ' || NEW.Middle;
      END IF;
    END IF;
  END IF;

  IF NEW.Name IS NULL THEN
    NEW.Name := 'Клиент ' || TRIM(TO_CHAR(NEW.Client, '999999999999'));
  END IF;

  UPDATE db.object SET label = NEW.Name WHERE Id = NEW.Client;

  SELECT UserId INTO nUserId FROM db.client WHERE Id = NEW.Client;
  IF nUserId IS NOT NULL THEN
    UPDATE db.user SET FullName = NEW.Name WHERE Id = nUserId;
  END IF;

  --RAISE DEBUG '[%] [%] %, %, %, %', TG_OP, NEW.client, NEW.name, NEW.short, NEW.first, NEW.last, NEW.middle;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_client_name_insert_update
  BEFORE INSERT OR UPDATE ON db.client_name
  FOR EACH ROW
  EXECUTE PROCEDURE ft_client_name_insert_update();

--------------------------------------------------------------------------------
-- FUNCTION NewClientName ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет/обновляет наименование клиента.
 * @param {numeric} pClient - Идентификатор клиента
 * @param {text} pName - Полное наименование компании/Ф.И.О.
 * @param {text} pFirst - Имя
 * @param {text} pLast - Фамилия
 * @param {text} pMiddle - Отчество
 * @param {text} pShort - Краткое наименование компании
 * @param {varchar} pLangCode - Код языка: VLanguage
 * @param {timestamp} pDateFrom - Дата изменения
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION NewClientName (
  pClient	    numeric,
  pName		    text,
  pShort	    text default null,
  pFirst	    text default null,
  pLast		    text default null,
  pMiddle	    text default null,
  pLangCode	    varchar default language_code(),
  pDateFrom	    timestamp default oper_date()
) RETURNS 	    void
AS $$
DECLARE
  nId		    numeric;
  nLang		    numeric;

  dtDateFrom    timestamp;
  dtDateTo 	    timestamp;
BEGIN
  nId := null;

  SELECT id INTO nLang FROM db.language WHERE code = coalesce(pLangCode, 'ru');

  IF not found THEN
    PERFORM IncorrectLanguageCode(pLangCode);
  END IF;

  -- получим дату значения в текущем диапозоне дат
  SELECT max(validFromDate), max(ValidToDate) INTO dtDateFrom, dtDateTo
    FROM db.client_name
   WHERE Client = pClient
     AND Lang = nLang
     AND validFromDate <= pDateFrom
     AND ValidToDate > pDateFrom;

  IF dtDateFrom = pDateFrom THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.client_name SET name = pName, short = pShort, first = pFirst, last = pLast, middle = pMiddle
     WHERE Client = pClient
       AND Lang = nLang
       AND validFromDate <= pDateFrom
       AND ValidToDate > pDateFrom;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.client_name SET ValidToDate = pDateFrom
     WHERE Client = pClient
       AND Lang = nLang
       AND validFromDate <= pDateFrom
       AND ValidToDate > pDateFrom;

    INSERT INTO db.client_name (client, lang, name, short, first, last, middle, validfromdate, validtodate)
    VALUES (pClient, nLang, pName, pShort, pFirst, pLast, pMiddle, pDateFrom, coalesce(dtDateTo, MAXDATE()));
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditClientName -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет/обновляет наименование клиента (вызывает метод действия 'edit').
 * @param {numeric} pClient - Идентификатор клиента
 * @param {text} pName - Полное наименование компании/Ф.И.О.
 * @param {text} pShort - Краткое наименование компании
 * @param {text} pFirst - Имя
 * @param {text} pLast - Фамилия
 * @param {text} pMiddle - Отчество
 * @param {varchar} pLangCode - Код языка: VLanguage
 * @param {timestamp} pDateFrom - Дата изменения
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION EditClientName (
  pClient	    numeric,
  pName		    text,
  pShort	    text default null,
  pFirst	    text default null,
  pLast		    text default null,
  pMiddle	    text default null,
  pLangCode	    varchar default language_code(),
  pDateFrom	    timestamp default oper_date()
) RETURNS 	    void
AS $$
DECLARE
  nMethod	    numeric;

  vHash		    text;
  cHash		    text;

  r		        record;
BEGIN
  SELECT * INTO r FROM GetClientNames(pClient, pLangCode, pDateFrom);

  pName := coalesce(pName, r.name);
  pShort := coalesce(pShort, r.short, '<null>');
  pFirst := coalesce(pFirst, r.first, '<null>');
  pLast := coalesce(pLast, r.last, '<null>');
  pMiddle := coalesce(pMiddle, r.middle, '<null>');

  vHash := encode(digest(pName || pShort || pFirst || pLast || pMiddle, 'md5'), 'hex');
  cHash := encode(digest(r.name || coalesce(r.short, '<null>') || coalesce(r.first, '<null>') || coalesce(r.last, '<null>') || coalesce(r.middle, '<null>'), 'md5'), 'hex');

  IF vHash <> cHash THEN
    PERFORM NewClientName(pClient, pName, CheckNull(pShort), CheckNull(pFirst), CheckNull(pLast), CheckNull(pMiddle), pLangCode, pDateFrom);

    nMethod := GetMethod(GetObjectClass(pClient), null, GetAction('edit'));
    PERFORM ExecuteMethod(pClient, nMethod);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetClientNames -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает наименование клиента.
 * @param {numeric} pClient - Идентификатор клиента
 * @param {varchar} pLangCode - Код языка: VLanguage
 * @param {timestamp} pDate - Дата
 * @out param {text} name - Полное наименование компании/Ф.И.О.
 * @out param {text} first - Имя
 * @out param {text} last - Фамилия
 * @out param {text} middle - Отчество
 * @out param {text} short - Краткое наименование компании
 */
CREATE OR REPLACE FUNCTION GetClientNames (
  pClient	    numeric,
  pLangCode	    varchar default language_code(),
  pDate		    timestamp default oper_date()
) RETURNS	    db.client_name
AS $$
DECLARE
  result        db.client_name%rowtype;
  nLang		    numeric;
BEGIN
  SELECT id INTO nLang FROM db.language WHERE code = coalesce(pLangCode, 'ru');

  IF NOT FOUND THEN
    PERFORM IncorrectLanguageCode(pLangCode);
  END IF;

  SELECT * INTO result
    FROM db.client_name n
   WHERE n.client = pClient
     AND n.lang = nLang
     AND n.validFromDate <= pDate
     AND n.ValidToDate > pDate;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetClientName ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает полное наименование клиента.
 * @param {numeric} pClient - Идентификатор клиента
 * @param {varchar} pLangCode - Код языка: VLanguage
 * @param {timestamp} pDate - Дата
 * @return {(text|null|exception)}
 */
CREATE OR REPLACE FUNCTION GetClientName (
  pClient	numeric,
  pLangCode	varchar default language_code(),
  pDate		timestamp default oper_date()
) RETURNS	text
AS $$
DECLARE
  vName		text;
BEGIN
  SELECT name INTO vName FROM GetClientNames(pClient, pLangCode, pDate);

  RETURN vName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetClientShortName -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает краткое наименование клиента.
 * @param {numeric} pClient - Идентификатор клиента
 * @param {varchar} pLangCode - Код языка: VLanguage
 * @param {timestamp} pDate - Дата
 * @return {(text|null|exception)}
 */
CREATE OR REPLACE FUNCTION GetClientShortName (
  pClient	numeric,
  pLangCode	varchar default language_code(),
  pDate		timestamp default oper_date()
) RETURNS	text
AS $$
DECLARE
  vShort	text;
BEGIN
  SELECT short INTO vShort FROM GetClientNames(pClient, pLangCode, pDate);

  RETURN vShort;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClient ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт нового клиента
 * @param {numeric} pParent - Ссылка на родительский объект: VObject.Parent | null
 * @param {numeric} pType - Тип: VClientType.Id
 * @param {varchar} pCode - ИНН - для юридического лица | null
 * @param {numeric} pUserId - Пользователь (users): Учётная запись клиента
 * @param {jsonb} pPhone - Справочник телефонов
 * @param {jsonb} pEmail - Электронные адреса
 * @param {jsonb} pAddress - Почтовые адреса
 * @param {jsonb} pInfo - Дополнительная информация
 * @param {text} pDescription - Описание
 * @return {numeric} - Id клиента
 */
CREATE OR REPLACE FUNCTION CreateClient (
  pParent	    numeric,
  pType		    numeric,
  pCode		    varchar,
  pUserId	    numeric default null,
  pPhone	    jsonb default null,
  pEmail	    jsonb default null,
  pInfo         jsonb default null,
  pDescription	text default null
) RETURNS 	    numeric
AS $$
DECLARE
  nId		    numeric;
  nClient	    numeric;
  nDocument	    numeric;

  nClass	    numeric;
  nMethod	    numeric;
BEGIN
  SELECT class INTO nClass FROM type WHERE id = pType;

  IF nClass IS NULL OR GetClassCode(nClass) <> 'client' THEN
    PERFORM IncorrectClassType();
  END IF;

  SELECT id INTO nId FROM db.client WHERE code = pCode;

  IF found THEN
    PERFORM ClientCodeExists(pCode);
  END IF;

  nDocument := CreateDocument(pParent, pType, null, pDescription);

  INSERT INTO db.client (id, document, code, userid, phone, email, info)
  VALUES (nDocument, nDocument, pCode, pUserId, pPhone, pEmail, pInfo)
  RETURNING id INTO nClient;

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nClient, nMethod);

  RETURN nClient;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditClient ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет основные параметры клиента.
 * @param {numeric} pId - Идентификатор клиента
 * @param {numeric} pParent - Ссылка на родительский объект: VObject.Parent | null
 * @param {numeric} pType - Тип: VClientType.Id
 * @param {varchar} pCode - ИНН - для юридического лица | null
 * @param {numeric} pUserId - Пользователь (users): Учётная запись клиента
 * @param {jsonb} pPhone - Справочник телефонов
 * @param {jsonb} pEmail - Электронные адреса
 * @param {jsonb} pInfo - Дополнительная информация
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditClient (
  pId		    numeric,
  pParent	    numeric default null,
  pType		    numeric default null,
  pCode		    varchar default null,
  pUserId	    numeric default null,
  pPhone	    jsonb default null,
  pEmail	    jsonb default null,
  pInfo         jsonb default null,
  pDescription	text default null
) RETURNS 	    void
AS $$
DECLARE
  nId		    numeric;
  nClass	    numeric;
  nMethod	    numeric;

  -- current
  cParent	    numeric;
  cType		    numeric;
  cCode		    varchar;
  cUserId	    numeric;
  cDescription	text;
BEGIN
  SELECT parent, type INTO cParent, cType FROM db.object WHERE id = pId;
  SELECT description INTO cDescription FROM db.document WHERE id = pId;
  SELECT code, userid INTO cCode, cUserId FROM db.client WHERE id = pId;

  pParent := coalesce(pParent, cParent, 0);
  pType := coalesce(pType, cType);
  pCode := coalesce(pCode, cCode);
  pUserId := coalesce(pUserId, cUserId, 0);
  pDescription := coalesce(pDescription, cDescription, '<null>');

  IF pCode <> cCode THEN
    SELECT id INTO nId FROM db.client WHERE code = pCode;
    IF found THEN
      PERFORM ClientCodeExists(pCode);
    END IF;
  END IF;

  IF pParent <> coalesce(cParent, 0) THEN
    UPDATE db.object SET parent = CheckNull(pParent) WHERE id = pId;
  END IF;

  IF pType <> cType THEN
    UPDATE db.object SET type = pType WHERE id = pId;
  END IF;

  IF pDescription <> coalesce(cDescription, '<null>') THEN
    UPDATE db.document SET description = CheckNull(pDescription) WHERE id = pId;
  END IF;

  UPDATE db.client
     SET Code = pCode,
         UserId = CheckNull(pUserId),
         Phone = CheckNull(coalesce(pPhone, Phone, '<null>')),
         Email = CheckNull(coalesce(pEmail, Email, '<null>')),
         Info = CheckNull(coalesce(pInfo, Info, '<null>'))
   WHERE Id = pId;

  nClass := GetObjectClass(pId);
  nMethod := GetMethod(nClass, null, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetClient -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetClient (
  pCode		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.client WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetClientUserId -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetClientUserId (
  pClient	numeric
) RETURNS	numeric
AS $$
DECLARE
  nUserId	numeric;
BEGIN
  SELECT userid INTO nUserId FROM db.client WHERE id = pClient;
  RETURN nUserId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ClientName ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ClientName (Id, Client, Lang, LangCode, LangName, LangDesc,
  FullName, ShortName, LastName, FirstName, MiddleName, validFromDate, ValidToDate
)
AS
  SELECT n.id, n.client, n.lang, l.code, l.name, l.description,
         n.name, n.short, n.last, n.first, n.middle, n.validfromdate, n.validtodate
    FROM db.client_name n INNER JOIN db.language l ON l.id = n.lang;

GRANT SELECT ON ClientName TO administrator;

--------------------------------------------------------------------------------
-- Client ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Client (Id, Document, Code, UserId,
  FullName, ShortName, LastName, FirstName, MiddleName,
  Phone, Email, Info,
  Lang, LangCode, LangName, LangDesc
)
AS
  WITH lc AS (
    SELECT id FROM db.language WHERE code = language_code()
  )
  SELECT c.id, c.document, c.code, c.userid,
         n.name, n.short, n.last, n.first, n.middle,
         c.phone, c.email, c.info,
         n.lang, l.code, l.name, l.description
    FROM db.client c INNER JOIN db.client_name n ON n.client = c.id AND n.validfromdate <= now() AND n.validtodate > now()
                     INNER JOIN lc               ON n.lang = lc.id
                     INNER JOIN db.language l    ON l.id = n.lang;

GRANT SELECT ON Client TO administrator;

--------------------------------------------------------------------------------
-- ObjectClient ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectClient (Id, Object, Parent,
  Essence, EssenceCode, EssenceName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, UserId,
  FullName, ShortName, LastName, FirstName, MiddleName,
  Phone, Email, Info,
  Lang, LangCode, LangName, LangDesc,
  Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName
)
AS
  SELECT c.id, d.object, d.parent,
         d.essence, d.essencecode, d.essencename,
         d.class, d.classcode, d.classlabel,
         d.type, d.typecode, d.typename, d.typedescription,
         c.code, c.userid,
         c.fullname, c.shortname, c.lastname, c.firstname, c.middlename,
         c.phone, c.email, c.info,
         c.lang, c.langcode, c.langname, c.langdesc,
         d.label, d.description,
         d.statetype, d.statetypecode, d.statetypename,
         d.state, d.statecode, d.statelabel, d.lastupdate,
         d.owner, d.ownercode, d.ownername, d.created,
         d.oper, d.opercode, d.opername, d.operdate,
         d.area, d.areacode, d.areaname
    FROM Client c INNER JOIN ObjectDocument d ON d.id = c.document;

GRANT SELECT ON ObjectClient TO administrator;
