--------------------------------------------------------------------------------
-- ClientNameIsNull ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ClientNameIsNull() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Наименование клиента не должно быть пустым.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------
-- ClientCodeExists ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ClientCodeExists (
  pCode		varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Клиент с кодом "%" уже существует.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

