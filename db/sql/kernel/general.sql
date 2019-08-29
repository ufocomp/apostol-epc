--------------------------------------------------------------------------------
-- FUNCTION SetVar -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetVar (
  pType		TVarType,
  pName		text, 
  pValue	text
) RETURNS void
AS $$
BEGIN
  PERFORM set_config(pType || '.' || pName, pValue, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetVar (
  pType		TVarType,
  pName		text, 
  pValue	numeric
) RETURNS void
AS $$
BEGIN
  PERFORM set_config(pType || '.' || pName, IntToStr(pValue), false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetVar (
  pType		TVarType,
  pName		text, 
  pValue	timestamp
) RETURNS void
AS $$
BEGIN
  PERFORM set_config(pType || '.' || pName, DateToStr(pValue), false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetVar (
  pType		TVarType,
  pName		text, 
  pValue	timestamptz
) RETURNS void
AS $$
BEGIN
  PERFORM set_config(pType || '.' || pName, DateToStr(pValue), false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetVar (
  pType		TVarType,
  pName		text, 
  pValue	date
) RETURNS void
AS $$
BEGIN
  PERFORM set_config(pType || '.' || pName, DateToStr(pValue), false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetVar -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetVar (
  pType		TVarType,
  pName 	text
) RETURNS text
AS $$
DECLARE
  vValue text;
BEGIN
  SELECT INTO vValue current_setting(pType || '.' || pName);

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
-- FUNCTION SetErrorMessage ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetErrorMessage (
  pMessage 	text
) RETURNS 	void
AS $$
BEGIN
  PERFORM SetVar('kernel', 'error_message', pMessage);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetErrorMessage ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetErrorMessage (
) RETURNS 	text
AS $$
BEGIN
  RETURN GetVar('kernel', 'error_message');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION InitContex ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION InitContext (
  pObject	numeric,
  pClass	numeric,
  pMethod	numeric,
  pAction	numeric
)
RETURNS 	void
AS $$
BEGIN
  PERFORM SetVar('context', 'object', pObject);
  PERFORM SetVar('context', 'class',  pClass);
  PERFORM SetVar('context', 'method', pMethod);
  PERFORM SetVar('context', 'action', pAction);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION context_object -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION context_object()
RETURNS 	numeric
AS $$
DECLARE
  vValue	text;
BEGIN
  SELECT INTO vValue GetVar('context', 'object');

  IF vValue IS NOT NULL THEN
    RETURN StrToInt(vValue);
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION context_class ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION context_class()
RETURNS 	numeric
AS $$
DECLARE
  vValue	text;
BEGIN
  SELECT INTO vValue GetVar('context', 'class');

  IF vValue IS NOT NULL THEN
    RETURN StrToInt(vValue);
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION context_method -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION context_method()
RETURNS 	numeric
AS $$
DECLARE
  vValue	text;
BEGIN
  SELECT INTO vValue GetVar('context', 'method');

  IF vValue IS NOT NULL THEN
    RETURN StrToInt(vValue);
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION context_action -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION context_action()
RETURNS 	numeric
AS $$
DECLARE
  vValue	text;
BEGIN
  SELECT INTO vValue GetVar('context', 'action');

  IF vValue IS NOT NULL THEN
    RETURN StrToInt(vValue);
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
