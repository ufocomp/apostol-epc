--------------------------------------------------------------------------------
-- ORDER -----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.order --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.order (
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

COMMENT ON TABLE db.order IS 'Заказ.';

COMMENT ON COLUMN db.order.id IS 'Идентификатор';
COMMENT ON COLUMN db.order.document IS 'Документ';
COMMENT ON COLUMN db.order.code IS 'Код';
COMMENT ON COLUMN db.order.client IS 'Клиент';
COMMENT ON COLUMN db.order.transaction IS 'Транзакция';
COMMENT ON COLUMN db.order.tariff IS 'Тариф';
COMMENT ON COLUMN db.order.amount IS 'Сумма';

--------------------------------------------------------------------------------

CREATE INDEX ON db.order (document);

CREATE UNIQUE INDEX ON db.order (code);
CREATE UNIQUE INDEX ON db.order (transaction);

CREATE INDEX ON db.order (client);
CREATE INDEX ON db.order (tariff);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_order_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NEW.ID IS NULL OR NEW.ID = 0 THEN
    SELECT NEW.DOCUMENT INTO NEW.ID;
  END IF;

  IF NEW.CODE IS NULL OR NEW.CODE = '' THEN
    NEW.CODE := 'C:' || LPAD(TRIM(TO_CHAR(NEW.ID, '999999999999')), 10, '0');
  END IF;

  RAISE DEBUG 'Создан заказ Id: %', NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_order_insert
  BEFORE INSERT ON db.order
  FOR EACH ROW
  EXECUTE PROCEDURE ft_order_insert();

--------------------------------------------------------------------------------
-- CreateOrder -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт ордер
 * @param {numeric} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {numeric} pType - Тип: Type.Id
 * @param {varchar} pCode - Код
 * @param {numeric} pTransaction - Транзакция
 * @param {text} pDescription - Описание
 * @return {numeric} - Id
 */
CREATE OR REPLACE FUNCTION CreateOrder (
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
  nOrder	    numeric;
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

  IF nClass IS NULL OR GetClassCode(nClass) <> 'order' THEN
    PERFORM IncorrectClassType();
  END IF;

  SELECT id INTO nId FROM db.order WHERE code = pCode;

  IF found THEN
    PERFORM OrderCodeExists(pCode);
  END IF;

  SELECT id INTO nId FROM db.order WHERE transaction = pTransaction;

  IF found THEN
    PERFORM OrderTransactionExists();
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
    PERFORM InvalidOrderAmount();
  END IF;

  nDocument := CreateDocument(pParent, pType, pCode, pDescription);

  INSERT INTO db.order (id, document, code, client, transaction, tariff, amount)
  VALUES (nDocument, nDocument, pCode, nClient, pTransaction, nTariff, nAmount)
  RETURNING id INTO nOrder;

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nOrder, nMethod);

  RETURN nOrder;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditOrder ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет параметры заказа (но не сам заказ).
 * @param {numeric} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {numeric} pType - Тип: Type.Id
 * @param {varchar} pCode - Код
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditOrder (
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
  SELECT code INTO cCode FROM db.order WHERE id = pId;

  pParent := coalesce(pParent, cParent, 0);
  pType := coalesce(pType, cType);
  pCode := coalesce(pCode, cCode);
  pDescription := coalesce(pDescription, cDescription, '<null>');

  IF pCode <> cCode THEN
    SELECT id INTO nId FROM db.order WHERE code = pCode;
    IF found THEN
      PERFORM OrderCodeExists(pCode);
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

  UPDATE db.order
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
-- GetOrder -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetOrder (
  pCode		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.order WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetOrderAmount --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetOrderAmount (
  pOrder	numeric
) RETURNS	numeric
AS $$
DECLARE
  nAmount	numeric;
BEGIN
  SELECT amount INTO nAmount FROM db.order WHERE id = pOrder;
  RETURN nAmount;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Orders ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Orders
AS
  SELECT o.id, o.document, o.code, o.transaction, o.tariff,
         t.meterstop - t.meterstart as meter, f.cost, o.amount
    FROM db.order o INNER JOIN db.transaction t ON t.id = o.transaction
                    INNER JOIN db.tariff f ON f.id = o.tariff;

GRANT SELECT ON Orders TO administrator;

--------------------------------------------------------------------------------
-- ObjectOrders ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectOrder (Id, Object, Parent,
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
  SELECT o.id, d.object, d.parent,
         d.essence, d.essencecode, d.essencename,
         d.class, d.classcode, d.classlabel,
         d.type, d.typecode, d.typename, d.typedescription,
         o.code, o.transaction, o.tariff, o.meter, o.cost, o.amount,
         d.label, d.description,
         d.statetype, d.statetypecode, d.statetypename,
         d.state, d.statecode, d.statelabel, d.lastupdate,
         d.owner, d.ownercode, d.ownername, d.created,
         d.oper, d.opercode, d.opername, d.operdate,
         d.area, d.areacode, d.areaname
    FROM Orders o INNER JOIN ObjectDocument d ON d.id = o.document;

GRANT SELECT ON ObjectOrder TO administrator;
