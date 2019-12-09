--------------------------------------------------------------------------------
-- ALL_TAB_COLUMNS -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW all_tab_columns(table_name, column_id, column_name, data_type, udt_name)
AS
  SELECT table_name, ordinal_position as column_id, column_name, data_type, udt_name
    FROM information_schema.columns
   WHERE table_schema = 'kernel';

GRANT SELECT ON all_tab_columns TO PUBLIC;

--------------------------------------------------------------------------------
-- ALL_COL_COMMENTS ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW all_col_comments(table_name, table_description, column_name, column_description)
AS
  SELECT table_name, 
         obj_description(format('%s.%s', isc.table_schema, isc.table_name)::regclass::oid, 'pg_class') as table_description,
         column_name,
         pg_catalog.col_description(format('%s.%s', isc.table_schema, isc.table_name)::regclass::oid, isc.ordinal_position) as column_description
    FROM information_schema.columns isc
   WHERE table_schema = 'kernel';

GRANT SELECT ON all_col_comments TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION array_pos ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION array_pos (
  anyarray	text[],
  anyelement 	text
) RETURNS	int
AS $$
DECLARE
  i		int;
  l		int;
BEGIN
  i := 1;
  l := array_length(anyarray, 1);
  WHILE (i <= l) AND (anyarray[i] <> anyelement) LOOP
    i := i + 1;
  END LOOP;

  IF i > l THEN
    i := 0;
  END IF;

  RETURN i;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- FUNCTION array_pos ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION array_pos (
  anyarray	numeric[],
  anyelement 	numeric
) RETURNS	int
AS $$
DECLARE
  i		int;
  l		int;
BEGIN
  i := 1;
  l := array_length(anyarray, 1);
  WHILE (i <= l) AND (anyarray[i] <> anyelement) LOOP
    i := i + 1;
  END LOOP;

  IF i > l THEN
    i := 0;
  END IF;

  RETURN i;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- FUNCTION string_to_array_trim -----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION string_to_array_trim (
  str		text,
  sep	 	text
) RETURNS	text[]
AS $$
DECLARE
  i		int;
  pos		int;
  arr		text[];
BEGIN
  pos := StrPos(str, sep);
  i := 1;

  WHILE pos > 0
  LOOP
    arr[i] := trim(SubStr(str, 1, pos - 1));
    str := trim(SubStr(str, pos + 1));
    pos := StrPos(str, sep);
    i := i + 1;
  END LOOP;

  arr[i] := str;

  RETURN arr;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- FUNCTION str_to_inet --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION str_to_inet (
  str		text,
  OUT host	inet,
  OUT range     integer
) RETURNS	record
AS $$
DECLARE
  vHost		text;
  vStr		text;

  pos		int;
  nMask		int;
BEGIN
  range := null;
  nMask := 32;

  vStr := str;
  pos := StrPos(vStr, '-');

  IF pos > 0 THEN
    vHost := SubStr(vStr, 1, pos - 1);
    vStr := SubStr(vStr, pos + 1);
    range := (vStr::inet - vHost::inet) + 1;
  ELSE
    vHost := vStr;
  END IF;

  vStr := vHost;
  pos := StrPos(vStr, '*');

  WHILE pos > 0
  LOOP
    nMask := nMask - 8;
    vStr := SubStr(vStr, pos + 1);
    pos := StrPos(vStr, '*');
  END LOOP;

  host := replace(vHost, '*', '0') || '/' || nMask;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- FUNCTION IntToStr -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION IntToStr (
  pValue	numeric,
  pFormat	text default '999999999999'
) RETURNS	text
AS $$
DECLARE
  sStr		text;
BEGIN
  RETURN trim(to_char(pValue, pFormat));
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION IntToStr(numeric, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToInt -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StrToInt (
  pValue	text,
  pFormat	text default '999999999999'
) RETURNS	numeric
AS $$
DECLARE
  sStr		text;
BEGIN
  return to_number(pValue, pFormat);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION IntToStr(numeric, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION DateToStr ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DateToStr (
  pValue	timestamptz,
  pFormat	text default 'DD.MM.YYYY HH24:MI:SS'
) RETURNS	text
AS $$
DECLARE
  sStr		text;
BEGIN
  return to_char(pValue, pFormat);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION DateToStr(timestamptz, text) TO PUBLIC;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DateToStr (
  pValue	timestamp,
  pFormat	text default 'DD.MM.YYYY HH24:MI:SS'
) RETURNS	text
AS $$
DECLARE
  sStr		text;
BEGIN
  return to_char(pValue, pFormat);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION DateToStr(timestamp, text) TO PUBLIC;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DateToStr (
  pValue	date,
  pFormat	text default 'DD.MM.YYYY'
) RETURNS	text
AS $$
DECLARE
  sStr		text;
BEGIN
  return to_char(pValue, pFormat);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION DateToStr(date, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToDate ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StrToDate (
  pValue	text,
  pFormat	text default 'DD.MM.YYYY'
) RETURNS	date
AS $$
BEGIN
  return to_date(pValue, pFormat);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION StrToDate(text, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToTimeStamp -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StrToTimeStamp (
  pValue	text,
  pFormat	text default 'DD.MM.YYYY HH24:MI:SS'
) RETURNS	timestamp
AS $$
BEGIN
  return to_timestamp(pValue, pFormat);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION StrToTimeStamp(text, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToTimeStamptz ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StrToTimeStamptz (
  pValue	text,
  pFormat	text default 'DD.MM.YYYY HH24:MI:SS'
) RETURNS	timestamptz
AS $$
BEGIN
  return to_timestamp(pValue, pFormat);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION StrToTimeStamptz(text, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION MINDATE ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION MINDATE() RETURNS DATE
AS $$
BEGIN
  RETURN TO_DATE('2000-01-01', 'YYYY-MM-DD');
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION MINDATE() TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION MAXDATE ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION MAXDATE() RETURNS DATE
AS $$
BEGIN
  RETURN TO_DATE('4433-12-31', 'YYYY-MM-DD');
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION MAXDATE() TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckNull (
  pValue	text
) RETURNS	text
AS $$
BEGIN
  RETURN NULLIF(pValue, '<null>');
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION CheckNull(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckNull (
  pValue	json
) RETURNS	json
AS $$
BEGIN
  RETURN NULLIF(pValue, '{}'::json);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION CheckNull(json) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckNull (
  pValue	jsonb
) RETURNS	jsonb
AS $$
BEGIN
  RETURN NULLIF(pValue, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION CheckNull(jsonb) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckNull (
  pValue	numeric
) RETURNS	numeric
AS $$
BEGIN
  RETURN NULLIF(pValue, 0);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION CheckNull(numeric) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION GetCompare ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetCompare (
  pCompare	text
) RETURNS	text
AS $$
BEGIN
  CASE pCompare
  WHEN 'EQL' THEN
    RETURN ' = ';
  WHEN 'NEQ' THEN
    RETURN ' <> ';
  WHEN 'LSS' THEN
    RETURN ' < ';
  WHEN 'LEQ' THEN
    RETURN ' <= ';
  WHEN 'GTR' THEN
    RETURN ' > ';
  WHEN 'GEQ' THEN
    RETURN ' >= ';
  WHEN 'GIN' THEN
    RETURN ' @> ';
  WHEN 'LKE' THEN
    RETURN ' LIKE ';
  WHEN 'ISN' THEN
    RETURN ' IS ';
  WHEN 'INN' THEN
    RETURN ' IS NOT ';
  ELSE
    NULL;
  END CASE;

  RETURN ' = ';
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION GetCompare(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- GetColumns ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetColumns (
  pTable	text,
  pSchema	text default current_schema(),
  pAlias	text default null
) RETURNS	text[]
AS $$
DECLARE
  arResult	text[];
  r		record;
BEGIN
  FOR r IN
    SELECT column_name
      FROM information_schema.columns
     WHERE table_schema = lower(pSchema)
       AND table_name = lower(pTable)
     ORDER BY ordinal_position
  LOOP
    arResult := array_append(arResult, coalesce(pAlias || '.', '') || r.column_name::text);
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

GRANT EXECUTE ON FUNCTION GetColumns(text, text, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- array_add_text --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION array_add_text (
  pArray	text[],
  pText		text
) RETURNS	text[]
AS $$
DECLARE
  i		integer;
  arResult	text[];
BEGIN
  FOR i IN 1..array_length(pArray, 1)
  LOOP
    arResult := array_append(arResult, pArray[i] || pText);
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

GRANT EXECUTE ON FUNCTION array_add_text(text[], text) TO PUBLIC;

--------------------------------------------------------------------------------
-- min -------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE FUNCTION min(integer, integer) RETURNS integer AS $$
  SELECT CASE WHEN $1 < $2 THEN $1 ELSE $2 END
$$ LANGUAGE SQL STRICT;

GRANT EXECUTE ON FUNCTION min(integer, integer) TO PUBLIC;

--------------------------------------------------------------------------------
-- max -------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE FUNCTION max(integer, integer) RETURNS integer AS $$
  SELECT CASE WHEN $1 > $2 THEN $1 ELSE $2 END
$$ LANGUAGE SQL STRICT;

GRANT EXECUTE ON FUNCTION max(integer, integer) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION min_array ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION min_array (
  parray	anyarray,
  pelement 	anyelement default null
) RETURNS	anyelement
AS $$
DECLARE
  i		integer;
  r		integer;
BEGIN
  i := 1;
  r := null;
  FOR i IN 1..array_length(parray, 1) 
  LOOP
    IF pelement IS NOT NULL THEN
      IF coalesce(r, pelement) = pelement THEN
        r = parray[i];
      ELSE
        IF parray[i] <> pelement THEN
          r = min(coalesce(r, parray[i]), parray[i]);
        END IF;
      END IF;
    ELSE
      r = min(coalesce(r, parray[i]), parray[i]);
    END IF;
  END LOOP;

  RETURN r;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION min_array(anyarray, anyelement) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION max_array ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION max_array (
  parray	anyarray,
  pelement 	anyelement default null
) RETURNS	anyelement
AS $$
DECLARE
  i		integer;
  r		integer;
BEGIN
  i := 1;
  r := null;
  FOR i IN 1..array_length(parray, 1) 
  LOOP
    IF pelement IS NOT NULL THEN
      IF coalesce(r, pelement) = pelement THEN
        r = parray[i];
      ELSE
        IF parray[i] <> pelement THEN
          r = max(coalesce(r, parray[i]), parray[i]);
        END IF;
      END IF;
    ELSE
      r = max(coalesce(r, parray[i]), parray[i]);
    END IF;
  END LOOP;

  RETURN r;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION max_array(anyarray, anyelement) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION inet_to_array ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION inet_to_array (
  ip		inet
) RETURNS	text[]
AS $$
DECLARE
  r		text[];
  i		integer;
  p		integer;
  v		text;
BEGIN
  v := host(ip);
  p := position('.' in v);
  i := 0;

  WHILE p > 0
  LOOP
    r[i] := SubString(v from 1 for p - 1);
    v := SubString(v from p + 1);
    p := position('.' in v);
    i := i + 1;
  END LOOP;

  r[i] := v;

  RETURN r;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION inet_to_array(inet) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION result_success -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION result_success (
  result	out boolean,
  message		out text
)
RETURNS 	record
AS $$
BEGIN
  result := true;
  message := 'Success';
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION result_success() TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION GetISOTime ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetISOTime (
  pTime		timestamp default current_timestamp at time zone 'utc'
)
RETURNS 	text
AS $$
BEGIN
  RETURN replace(to_char(pTime, 'YYYY-MM-DD#HH24:MI:SS.MSZ'), '#', 'T');
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION GetISOTime(timestamp) TO PUBLIC;
