--------------------------------------------------------------------------------
-- REGISTER --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS register AUTHORIZATION kernel;

--------------------------------------------------------------------------------

CREATE TABLE register.key (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REGISTER'),
    root		numeric(12),
    parent		numeric(12),
    key			text NOT NULL,
    level		integer NOT NULL,
    CONSTRAINT fk_register_key_root FOREIGN KEY (root) REFERENCES register.key(id),
    CONSTRAINT fk_register_key_parent FOREIGN KEY (parent) REFERENCES register.key(id)
);

COMMENT ON TABLE register.key IS 'Реестр (ключ).';

COMMENT ON COLUMN register.key.id IS 'Идентификатор';
COMMENT ON COLUMN register.key.root IS 'Идентификатор корневого узла';
COMMENT ON COLUMN register.key.parent IS 'Идентификатор родительского узла';
COMMENT ON COLUMN register.key.key IS 'Ключ';
COMMENT ON COLUMN register.key.level IS 'Уровень вложенности';

CREATE INDEX register_key_root ON register.key (root);
CREATE INDEX register_key_parent ON register.key (parent);
CREATE INDEX register_key_key ON register.key (key);
CREATE INDEX register_key_level ON register.key (level);

CREATE UNIQUE INDEX register_key_unique ON register.key (root, parent, key);

--------------------------------------------------------------------------------
-- REGISTER_VALUE --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE register.value (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REGISTER'),
    key			numeric(12) NOT NULL,
    vname		text NOT NULL,
    vtype		integer NOT NULL,
    vinteger		integer,
    vnumeric		numeric,
    vdatetime		timestamp,
    vstring		text,
    vboolean		boolean,
    CONSTRAINT ch_register_value_type CHECK (vtype BETWEEN 0 AND 4),
    CONSTRAINT fk_register_value_key FOREIGN KEY (key) REFERENCES register.key(id)
);

COMMENT ON TABLE register.value IS 'Реестр (значение).';

COMMENT ON COLUMN register.value.id IS 'Идентификатор';
COMMENT ON COLUMN register.value.key IS 'Идентификатор ключа';
COMMENT ON COLUMN register.value.vname IS 'Имя значения';
COMMENT ON COLUMN register.value.vtype IS 'Тип данных';
COMMENT ON COLUMN register.value.vinteger IS 'Целое число: vtype = 0';
COMMENT ON COLUMN register.value.vnumeric IS 'Число с произвольной точностью: vtype = 1';
COMMENT ON COLUMN register.value.vdatetime IS 'Дата и время: vtype = 2';
COMMENT ON COLUMN register.value.vstring IS 'Строка: vtype = 3';
COMMENT ON COLUMN register.value.vboolean IS 'Логический: vtype = 4';

--------------------------------------------------------------------------------

CREATE INDEX register_value_key ON register.value (key);
CREATE INDEX register_value_name ON register.value (vname);

CREATE UNIQUE INDEX register_value_unique ON register.value (key, vname);

--------------------------------------------------------------------------------
-- FUNCTION reg_key_to_array ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION reg_key_to_array (
  pKey		text
) RETURNS 	text[]
AS $$
DECLARE
  i		integer;
  arKey		text[];
  vStr		text;
  vKey		text;
BEGIN
  vKey := pKey;

  IF NULLIF(vKey, '') IS NOT NULL THEN

    i := StrPos(vKey, E'\u005C');
    WHILE i > 0 LOOP
      vStr := SubStr(vKey, 1, i - 1);

      IF NULLIF(vStr, '') IS NOT NULL THEN
        arKey := array_append(arKey, vStr);
      END IF;

      vKey := SubStr(vKey, i + 1);
      i := StrPos(vKey, E'\u005C');
    END LOOP;

    IF NULLIF(vKey, '') IS NOT NULL THEN
      arKey := array_append(arKey, vKey);
    END IF;
  END IF;

  RETURN arKey;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION get_reg_key --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_reg_key (
  pKey		numeric
) RETURNS	text
AS $$
DECLARE
  vKey		text;
  r		record;
BEGIN
  FOR r IN 
    WITH RECURSIVE keytree(id, parent, key) AS (
      SELECT id, parent, key FROM register.key WHERE id = pKey
    UNION ALL
      SELECT k.id, k.parent, k.key
        FROM register.key k INNER JOIN keytree kt ON kt.parent = k.id
       WHERE k.root IS NOT NULL
    )
    SELECT key FROM keytree
  LOOP
    IF vKey IS NULL THEN
      vKey := r.key;
    ELSE
     vKey := r.key || E'\u005C' || vKey;
    END IF;
  END LOOP;

  RETURN vKey;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- get_reg_value ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_reg_value (
  pId		numeric
) RETURNS	Variant 
AS $$
  SELECT vtype, vinteger, vnumeric, vdatetime, vstring, vboolean 
    FROM register.value 
   WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegEnumKey ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegEnumKey (
  pId		numeric
) RETURNS	SETOF register.key
AS $$
  SELECT * FROM register.key WHERE parent = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegEnumValue ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegEnumValue (
  pKey		numeric,
  OUT id	numeric,
  OUT key	numeric,
  OUT vname	text,
  OUT value	Variant
) RETURNS	SETOF record
AS $$
  SELECT id, key, vname, get_reg_value(id) FROM register.value WHERE key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegEnumValueEx --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegEnumValueEx (
  pKey		numeric
) RETURNS	SETOF register.value
AS $$
  SELECT * FROM register.value WHERE key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegQueryValue ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegQueryValue (
  pId		numeric
) RETURNS	Variant
AS $$
  SELECT get_reg_value(id) FROM register.value WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegQueryValueEx -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegQueryValueEx (
  pId		numeric
) RETURNS	register.value
AS $$
  SELECT * FROM register.value WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegGetValue -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegGetValue (
  pKey		numeric,
  pValueName	text
) RETURNS	Variant
AS $$
  SELECT get_reg_value(id) FROM register.value WHERE key = pKey AND vname = pValueName
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegGetValueEx ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegGetValueEx (
  pKey		numeric,
  pValueName	text
) RETURNS	register.value
AS $$
  SELECT * FROM register.value WHERE key = pKey AND vname = pValueName
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegSetValue -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegSetValue (
  pKey		numeric,
  pValueName	text,
  pData		Variant
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM register.value WHERE id = pKey;

  IF not found THEN

    SELECT id INTO nId FROM register.value WHERE key = pKey AND vname = coalesce(pValueName, 'default');

    IF not found THEN

      INSERT INTO register.value (key, vname, vtype, vinteger, vnumeric, vdatetime, vstring, vboolean)
      VALUES (pKey, pValueName, pData.vType, pData.vInteger, pData.vNumeric, pData.vDateTime, pData.vString, pData.vBoolean)
      RETURNING id INTO nId;

    ELSE

      UPDATE register.value 
         SET vtype = coalesce(pData.vType, vtype), 
             vinteger = coalesce(pData.vInteger, vinteger), 
             vnumeric = coalesce(pData.vNumeric, vnumeric), 
             vdatetime = coalesce(pData.vDateTime, vdatetime), 
             vstring = coalesce(pData.vString, vstring), 
             vboolean = coalesce(pData.vBoolean, vboolean)
       WHERE id = nId;

    END IF;

  ELSE

    UPDATE register.value 
       SET vname = coalesce(pValueName, vname),
           vtype = coalesce(pData.vType, vtype), 
           vinteger = coalesce(pData.vInteger, vinteger), 
           vnumeric = coalesce(pData.vNumeric, vnumeric), 
           vdatetime = coalesce(pData.vDateTime, vdatetime), 
           vstring = coalesce(pData.vString, vstring), 
           vboolean = coalesce(pData.vBoolean, vboolean)
     WHERE id = nId;

  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegSetValueEx ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegSetValueEx (
  pKey		numeric,
  pValueName	text,
  pType		integer,
  pInteger	integer default null,
  pNumeric	numeric default null,
  pDateTime	timestamp default null,
  pString	text default null,
  pBoolean	boolean default null
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM register.value WHERE id = pKey;

  IF not found THEN

    SELECT id INTO nId FROM register.value WHERE key = pKey AND vname = coalesce(pValueName, 'default');

    IF not found THEN

      INSERT INTO register.value (key, vname, vtype, vinteger, vnumeric, vdatetime, vstring, vboolean)
      VALUES (pKey, pValueName, pType, pInteger, pNumeric, pDateTime, pString, pBoolean)
      RETURNING id INTO nId;

    ELSE

      UPDATE register.value 
         SET vtype = coalesce(pType, vtype), 
             vinteger = coalesce(pInteger, vinteger), 
             vnumeric = coalesce(pNumeric, vnumeric), 
             vdatetime = coalesce(pDateTime, vdatetime), 
             vstring = coalesce(pString, vstring), 
             vboolean = coalesce(pBoolean, vboolean)
       WHERE id = nId;

    END IF;

  ELSE

    UPDATE register.value 
       SET vname = coalesce(pValueName, vname),
           vtype = coalesce(pType, vtype), 
           vinteger = coalesce(pInteger, vinteger), 
           vnumeric = coalesce(pNumeric, vnumeric), 
           vdatetime = coalesce(pDateTime, vdatetime), 
           vstring = coalesce(pString, vstring), 
           vboolean = coalesce(pBoolean, vboolean)
     WHERE id = nId;

  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddRegKey ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddRegKey (
  pRoot		numeric,
  pParent	numeric,
  pKey		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
  nLevel	integer;
BEGIN
  nLevel := 0;
  pParent := coalesce(pParent, pRoot);

  IF pParent IS NOT NULL THEN
    SELECT level + 1 INTO nLevel FROM register.key WHERE id = pParent;
  END IF;
 
  INSERT INTO register.key (root, parent, key, level) 
  VALUES (pRoot, pParent, pKey, nLevel) 
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetRegRoot ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetRegRoot (
  pKey		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM register.key WHERE key = pKey AND level = 0;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetRegKey ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetRegKey (
  pParent	numeric,
  pKey		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM register.key WHERE parent = pParent AND key = pKey;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetRegKeyValue -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetRegKeyValue (
  pKey		numeric,
  pValueName	varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM register.value WHERE key = pKey AND vname = pValueName;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DelRegKey ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DelRegKey (
  pKey		numeric
) RETURNS	void
AS $$
BEGIN
  DELETE FROM register.value WHERE key = pKey;
  DELETE FROM register.key WHERE id = pKey;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DelRegKeyValue -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DelRegKeyValue (
  pId		numeric
) RETURNS	void
AS $$
BEGIN
  DELETE FROM register.value WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DelTreeRegKey ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DelTreeRegKey (
  pKey		numeric
) RETURNS	void
AS $$
DECLARE
  r		record;  
BEGIN
  FOR r IN SELECT id FROM register.key WHERE parent = pKey
  LOOP
    PERFORM DelTreeRegKey(r.id);
  END LOOP;

  PERFORM DelRegKey(pKey);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION RegCreateKey -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegCreateKey (
  pKey		text,
  pSubKey	text
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
  nRoot		numeric;
  nParent	numeric;

  arKey		text[];
  i		integer;
BEGIN
  arKey := ARRAY['CURRENT_CONFIG', 'CURRENT_USER'];

  IF array_position(arKey, pKey) IS NULL THEN
    PERFORM IncorrectRegisterKey(pKey, arKey);
  END IF;

  IF pKey = 'CURRENT_CONFIG' THEN
    pKey := 'kernel';
  ELSE
    pKey := current_username();
  END IF;

  nRoot := GetRegRoot(pKey);

  IF nRoot IS NULL THEN
    nRoot := AddRegKey(null, null, pKey);
  END IF;

  IF pSubKey IS NOT NULL THEN

    arKey := reg_key_to_array(pSubKey);

    FOR i IN 1..array_length(arKey, 1)
    LOOP
      nParent := coalesce(nId, nRoot);
      nId := GetRegKey(nParent, arKey[i]);
      IF nId IS NULL THEN
        nId := AddRegKey(nRoot, nParent, arKey[i]);
      END IF;
    END LOOP;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION RegOpenKey ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegOpenKey (
  pKey		text,
  pSubKey	text
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
  arKey		text[];
  i		integer;
BEGIN
  arKey := ARRAY['CURRENT_CONFIG', 'CURRENT_USER'];

  IF array_position(arKey, pKey) IS NULL THEN
    PERFORM IncorrectRegisterKey(pKey, arKey);
  END IF;

  IF pKey = 'CURRENT_CONFIG' THEN
    pKey := 'kernel';
  ELSE
    pKey := current_username();
  END IF;

  nId := GetRegRoot(pKey);

  IF (nId IS NOT NULL) AND (pSubKey IS NOT NULL) THEN

    arKey := reg_key_to_array(pSubKey);

    FOR i IN 1..array_length(arKey, 1)
    LOOP
      nId := GetRegKey(nId, arKey[i]);
    END LOOP;

  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION RegDeleteKey -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegDeleteKey (
  pKey		text,
  pSubKey	text
) RETURNS 	boolean
AS $$
DECLARE
  nKey		numeric;
BEGIN
  nKey := RegOpenKey(pKey, pSubKey);
  IF nKey IS NOT NULL THEN

    PERFORM DelRegKey(nKey);

    RETURN true;
  ELSE
    PERFORM SetErrorMessage('Указанный подключ не найден.');
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION RegDeleteKeyValue --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegDeleteKeyValue (
  pKey		text,
  pSubKey	text,
  pValueName	text
) RETURNS 	boolean
AS $$
DECLARE
  nId		numeric;
  nKey		numeric;
BEGIN
  nKey := RegOpenKey(pKey, pSubKey);
  IF nKey IS NOT NULL THEN

    nId := GetRegKeyValue(nKey, pValueName);
    IF nId IS NOT NULL THEN

      PERFORM DelRegKeyValue(nId);

      RETURN true;
    ELSE
      PERFORM SetErrorMessage('Указанное значение не найдено.');
    END IF;
  ELSE
    PERFORM SetErrorMessage('Указанный подключ не найден.');
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION RegDeleteTree  -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegDeleteTree (
  pKey		text,
  pSubKey	text
) RETURNS 	boolean
AS $$
DECLARE
  nKey		numeric;
BEGIN
  nKey := RegOpenKey(pKey, pSubKey);
  IF nKey IS NOT NULL THEN

    PERFORM DelTreeRegKey(nKey);

    RETURN true;
  ELSE
    PERFORM SetErrorMessage('Указанный подключ не найден.');
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- REGISTER --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW register (Id, Key, KeyName, Parnet, SubKey, SubKeyName, Level, 
  ValueName, Value
) 
AS
  SELECT coalesce(v.id, k.id), k.root, 
         CASE r.key WHEN 'kernel' THEN 'CURRENT_CONFIG' ELSE 'CURRENT_USER' END, 
         k.parent, k.id, k.key, k.level, 
         v.vname, get_reg_value(v.id)
    FROM register.key k  LEFT JOIN register.value v ON v.key = k.id
                        INNER JOIN (SELECT id, key FROM register.key) r ON r.id = k.root;

--------------------------------------------------------------------------------
-- REGISTER_EX -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW register_ex (Id, Key, KeyName, Parnet, SubKey, SubKeyName, Level, 
  ValueName, vType, vInteger, vNumeric, vDateTime, vString, vBoolean
) 
AS
  SELECT coalesce(v.id, k.id), k.root, 
         CASE r.key WHEN 'kernel' THEN 'CURRENT_CONFIG' ELSE 'CURRENT_USER' END, 
         k.parent, k.id, k.key, k.level, 
         v.vname, v.vtype, v.vinteger, v.vnumeric, v.vdatetime, v.vstring, v.vboolean
    FROM register.key k  LEFT JOIN register.value v ON v.key = k.id
                        INNER JOIN (SELECT id, key FROM register.key) r ON r.id = k.root;

--------------------------------------------------------------------------------
-- register --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION register (
  pKey		numeric
) RETURNS	SETOF register
AS $$
  SELECT * FROM register WHERE key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- register_ex -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION register_ex (
  pKey		numeric
) RETURNS	SETOF register_ex
AS $$
  SELECT * FROM register_ex WHERE key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Register --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Register
AS
  SELECT * FROM register(GetRegRoot('kernel'))
   UNION ALL
  SELECT * FROM register(GetRegRoot(current_username()));

GRANT ALL ON Register TO administrator;

--------------------------------------------------------------------------------
-- RegisterEx ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW RegisterEx
AS
  SELECT * FROM register_ex(GetRegRoot('kernel'))
   UNION ALL
  SELECT * FROM register_ex(GetRegRoot(current_username()));

GRANT ALL ON RegisterEx TO administrator;

--------------------------------------------------------------------------------
-- register_key ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW register_key
AS
  SELECT * FROM register.key;

--------------------------------------------------------------------------------
-- FUNCTION register_key -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION register_key (
  pKey		numeric
) RETURNS	SETOF register_key
AS $$
  SELECT * FROM register_key WHERE root = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegisterKey -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW RegisterKey
AS
  SELECT * FROM register_key(GetRegRoot('kernel'))
   UNION ALL
  SELECT * FROM register_key(GetRegRoot(current_username()));

GRANT ALL ON RegisterKey TO administrator;

--------------------------------------------------------------------------------
-- register_value --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW register_value (Id, Key, KeyName, SubKey, SubKeyName, 
  ValueName, Value
)
AS
  SELECT v.id, k.root, 
         CASE r.key WHEN 'kernel' THEN 'CURRENT_CONFIG' ELSE 'CURRENT_USER' END, 
         k.id, k.key, 
         v.vname, get_reg_value(v.id)
    FROM register.value v, LATERAL (SELECT * FROM register.key WHERE id = v.key) k, 
                           LATERAL (SELECT id, key FROM register.key WHERE id = k.root) r;

--------------------------------------------------------------------------------
-- register_value_ex -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW register_value_ex (Id, Key, KeyName, SubKey, SubKeyName, 
  ValueName, vType, vInteger, vNumeric, vDateTime, vString, vBoolean
)
AS
  SELECT v.id, k.root, 
         CASE r.key WHEN 'kernel' THEN 'CURRENT_CONFIG' ELSE 'CURRENT_USER' END, 
         k.id, k.key, 
         v.vname, v.vtype, v.vinteger, v.vnumeric, v.vdatetime, v.vstring, v.vboolean
    FROM register.value v, LATERAL (SELECT * FROM register.key WHERE id = v.key) k, 
                           LATERAL (SELECT id, key FROM register.key WHERE id = k.root) r;

--------------------------------------------------------------------------------
-- FUNCTION register_value -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION register_value (
  pKey		numeric
) RETURNS	SETOF register_value
AS $$
  SELECT * FROM register_value WHERE key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION register_value_ex --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION register_value_ex (
  pKey		numeric
) RETURNS	SETOF register_value_ex
AS $$
  SELECT * FROM register_value_ex WHERE key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegisterValue ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW RegisterValue
AS
  SELECT * FROM register_value(GetRegRoot('kernel'))
   UNION ALL
  SELECT * FROM register_value(GetRegRoot(current_username()));

GRANT ALL ON RegisterValue TO administrator;

--------------------------------------------------------------------------------
-- RegisterValueEx -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW RegisterValueEx
AS
  SELECT * FROM register_value_ex(GetRegRoot('kernel'))
   UNION ALL
  SELECT * FROM register_value_ex(GetRegRoot(current_username()));

GRANT ALL ON RegisterValueEx TO administrator;
