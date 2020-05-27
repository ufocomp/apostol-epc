CREATE OR REPLACE FUNCTION ClientCodeExists (
  pCode		varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Клиент с кодом "%" уже существует.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION CardCodeExists (
  pCode		varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Карта с кодом "%" уже существует.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION InvoiceCodeExists (
  pCode		varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Счёт с кодом "%" уже существует.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION OrderCodeExists (
  pCode		varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Заказ с кодом "%" уже существует.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION InvoiceTransactionExists()
RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Заказ по этой транзакции уже создан.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION ChargePointExists (
  pCode		varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Зарядная станция с идентификатором "%" уже существует.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION ActionNotFound -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ActionNotFound (
  pAction	text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'OCPP: Неопределенное действие: "%".', pAction;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION UnknownTransaction -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION UnknownTransaction (
  pId		numeric
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Неизвестная транзакия: "%".', pId;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION InvalidInvoiceAmount -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION InvalidInvoiceAmount() RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Неверная сумма заказа.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION InvalidInvoiceAmount -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CardNotAssociated (
  pCode     varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Карта "%" не связана с клиентом.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION ClientTariffNotFound  ----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ClientTariffNotFound (
  pCode     varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'У клиента "%" нет действующего тарифа.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;
