--------------------------------------------------------------------------------
-- INVOICE ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.invoice ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.invoice (
    id			    numeric(12) PRIMARY KEY,
    document	    numeric(12) NOT NULL,
    code		    varchar(30) NOT NULL,
    client          numeric(12) NOT NULL,
    transaction     numeric(12) NOT NULL,
    tariff          numeric(12) NOT NULL,
    amount		    numeric(12,4) NOT NULL,
    CONSTRAINT fk_order_document FOREIGN KEY (document) REFERENCES db.document(id),
    CONSTRAINT fk_order_client FOREIGN KEY (client) REFERENCES db.client(id),
    CONSTRAINT fk_order_transaction FOREIGN KEY (transaction) REFERENCES db.transaction(id),
    CONSTRAINT fk_order_tariff FOREIGN KEY (tariff) REFERENCES db.tariff(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.invoice IS 'Счёт.';

COMMENT ON COLUMN db.invoice.id IS 'Идентификатор';
COMMENT ON COLUMN db.invoice.document IS 'Документ';
COMMENT ON COLUMN db.invoice.code IS 'Код';
COMMENT ON COLUMN db.invoice.client IS 'Клиент';
COMMENT ON COLUMN db.invoice.transaction IS 'Транзакция';
COMMENT ON COLUMN db.invoice.tariff IS 'Тариф';
COMMENT ON COLUMN db.invoice.amount IS 'Сумма';

--------------------------------------------------------------------------------

CREATE INDEX ON db.invoice (document);

CREATE UNIQUE INDEX ON db.invoice (code);
CREATE UNIQUE INDEX ON db.invoice (transaction);

CREATE INDEX ON db.invoice (client);
CREATE INDEX ON db.invoice (tariff);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_order_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NEW.ID IS NULL OR NEW.ID = 0 THEN
    SELECT NEW.DOCUMENT INTO NEW.ID;
  END IF;

  IF NULLIF(NEW.CODE, '') IS NULL THEN
    NEW.CODE := encode(gen_random_bytes(8), 'hex');
  END IF;

  RAISE DEBUG 'Создан счёт Id: %', NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_order_insert
  BEFORE INSERT ON db.invoice
  FOR EACH ROW
  EXECUTE PROCEDURE ft_order_insert();

--------------------------------------------------------------------------------
-- CreateInvoice ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт счёт на оплату
 * @param {numeric} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {numeric} pType - Тип: Type.Id
 * @param {varchar} pCode - Код
 * @param {numeric} pTransaction - Транзакция
 * @param {text} pDescription - Описание
 * @return {numeric} - Id
 */
CREATE OR REPLACE FUNCTION CreateInvoice (
  pParent	    numeric,
  pType		    numeric,
  pCode		    varchar,
  pTransaction  numeric,
  pDescription	text default null
) RETURNS 	    numeric
AS $$
DECLARE
  nId		    numeric;
  nCard         numeric;
  nInvoice	    numeric;
  nClient	    numeric;
  nTariff	    numeric;
  nDocument	    numeric;

  nAmount	    numeric;
  nCost         numeric;
  nMeter        integer;

  nClass	    numeric;
  nMethod	    numeric;
BEGIN
  SELECT class INTO nClass FROM type WHERE id = pType;

  IF nClass IS NULL OR GetClassCode(nClass) <> 'invoice' THEN
    PERFORM IncorrectClassType();
  END IF;

  SELECT id INTO nId FROM db.invoice WHERE code = pCode;

  IF found THEN
    PERFORM InvoiceCodeExists(pCode);
  END IF;

  SELECT id INTO nId FROM db.invoice WHERE transaction = pTransaction;

  IF found THEN
    PERFORM InvoiceTransactionExists();
  END IF;

  SELECT card, (meterstop - meterstart) INTO nCard, nMeter FROM db.transaction WHERE id = pTransaction;

  IF not found THEN
    PERFORM ObjectNotFound('транзакция', 'id', pTransaction);
  END IF;

  SELECT client INTO nClient FROM db.card WHERE id = nCard;

  IF nClient IS NULL THEN
    PERFORM CardNotAssociated(GetCardCode(nCard));
  END IF;

  SELECT linked INTO nTariff
    FROM db.object_link
   WHERE object = nClient
     AND validFromDate <= Now()
     AND validToDate > Now();

  IF not found THEN
    PERFORM ClientTariffNotFound(GetClientCode(nClient));
  END IF;

  SELECT cost INTO nCost FROM db.tariff WHERE id = nTariff;

  nAmount := nMeter * nCost;

  IF coalesce(nAmount, 0) = 0 THEN
    PERFORM InvalidInvoiceAmount();
  END IF;

  nDocument := CreateDocument(pParent, pType, pCode, pDescription);

  INSERT INTO db.invoice (id, document, code, client, transaction, tariff, amount)
  VALUES (nDocument, nDocument, pCode, nClient, pTransaction, nTariff, nAmount)
  RETURNING id INTO nInvoice;

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nInvoice, nMethod);

  RETURN nInvoice;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditInvoice -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет параметры счёта на оплату (но не сам счёт).
 * @param {numeric} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {numeric} pType - Тип: Type.Id
 * @param {varchar} pCode - Код
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditInvoice (
  pId		    numeric,
  pParent	    numeric default null,
  pType		    numeric default null,
  pCode		    varchar default null,
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
  cDescription	text;
BEGIN
  SELECT parent, type INTO cParent, cType FROM db.object WHERE id = pId;
  SELECT description INTO cDescription FROM db.document WHERE id = pId;
  SELECT code INTO cCode FROM db.invoice WHERE id = pId;

  pParent := coalesce(pParent, cParent, 0);
  pType := coalesce(pType, cType);
  pCode := coalesce(pCode, cCode);
  pDescription := coalesce(pDescription, cDescription, '<null>');

  IF pCode <> cCode THEN
    SELECT id INTO nId FROM db.invoice WHERE code = pCode;
    IF found THEN
      PERFORM InvoiceCodeExists(pCode);
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

  UPDATE db.invoice
     SET code = pCode
   WHERE id = pId;

  nClass := GetObjectClass(pId);
  nMethod := GetMethod(nClass, null, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetInvoice ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetInvoice (
  pCode		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.invoice WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetInvoiceAmount ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetInvoiceAmount (
  pInvoice	numeric
) RETURNS	numeric
AS $$
DECLARE
  nAmount	numeric;
BEGIN
  SELECT amount INTO nAmount FROM db.invoice WHERE id = pInvoice;
  RETURN nAmount;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Invoice ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Invoice
AS
  SELECT o.id, o.document, o.code, o.transaction, o.tariff,
         t.meterstop - t.meterstart as meter, f.cost, o.amount
    FROM db.invoice o INNER JOIN db.transaction t ON t.id = o.transaction
                    INNER JOIN db.tariff f ON f.id = o.tariff;

GRANT SELECT ON Invoice TO administrator;

--------------------------------------------------------------------------------
-- ObjectInvoice ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectInvoice (Id, Object, Parent,
  Essence, EssenceCode, EssenceName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Transaction, Tariff, Meter, Cost, Amount,
  Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName
)
AS
  SELECT i.id, d.object, d.parent,
         d.essence, d.essencecode, d.essencename,
         d.class, d.classcode, d.classlabel,
         d.type, d.typecode, d.typename, d.typedescription,
         i.code, i.transaction, i.tariff, i.meter, i.cost, i.amount,
         d.label, d.description,
         d.statetype, d.statetypecode, d.statetypename,
         d.state, d.statecode, d.statelabel, d.lastupdate,
         d.owner, d.ownercode, d.ownername, d.created,
         d.oper, d.opercode, d.opername, d.operdate,
         d.area, d.areacode, d.areaname
    FROM Invoice i INNER JOIN ObjectDocument d ON d.id = i.document;

GRANT SELECT ON ObjectInvoice TO administrator;
