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
    amount		    numeric(12,4) NOT NULL,
    uuid            uuid,
    CONSTRAINT fk_order_document FOREIGN KEY (document) REFERENCES db.document(id),
    CONSTRAINT fk_order_client FOREIGN KEY (client) REFERENCES db.client(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.order IS 'Заказ.';

COMMENT ON COLUMN db.order.id IS 'Идентификатор';
COMMENT ON COLUMN db.order.document IS 'Документ';
COMMENT ON COLUMN db.order.code IS 'Код';
COMMENT ON COLUMN db.order.client IS 'Клиент';
COMMENT ON COLUMN db.order.amount IS 'Сумма';
COMMENT ON COLUMN db.order.uuid IS 'Универсальный уникальный идентификатор';

--------------------------------------------------------------------------------

CREATE INDEX ON db.order (document);
CREATE INDEX ON db.order (client);

CREATE UNIQUE INDEX ON db.order (code);
CREATE UNIQUE INDEX ON db.order (uuid);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_order_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NEW.ID IS NULL OR NEW.ID = 0 THEN
    SELECT NEW.DOCUMENT INTO NEW.ID;
  END IF;

  IF NULLIF(NEW.CODE, '') IS NULL THEN
    NEW.CODE := encode(gen_random_bytes(12), 'hex');
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
 * Создаёт счёт на оплату
 * @param {numeric} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {numeric} pType - Тип: Type.Id
 * @param {varchar} pCode - Код
 * @param {numeric} pClient - Клиент
 * @param {numeric} pAmount - Сумма
 * @param {numeric} pUuid - Универсальный уникальный идентификатор
 * @param {text} pDescription - Описание
 * @return {numeric} - Id
 */
CREATE OR REPLACE FUNCTION CreateOrder (
  pParent	    numeric,
  pType		    numeric,
  pCode		    varchar,
  pClient       numeric,
  pAmount	    numeric,
  pUuid         uuid default null,
  pDescription	text default null
) RETURNS 	    numeric
AS $$
DECLARE
  nId		    numeric;
  nOrder	    numeric;
  nDocument	    numeric;

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

  SELECT id INTO nId FROM db.client WHERE id = pClient;

  IF not found THEN
    PERFORM ObjectNotFound('клиент', 'id', pClient);
  END IF;

  nDocument := CreateDocument(pParent, pType, pCode, pDescription);

  INSERT INTO db.order (id, document, code, client, amount, uuid)
  VALUES (nDocument, nDocument, pCode, pClient, pAmount, pUuid)
  RETURNING id INTO nOrder;

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nOrder, nMethod);

  RETURN nOrder;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditOrder -------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет параметры счёта на оплату (но не сам счёт).
 * @param {numeric} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {numeric} pType - Тип: Type.Id
 * @param {varchar} pCode - Код
 * @param {numeric} pClient - Клиент
 * @param {numeric} pAmount - Сумма
 * @param {numeric} pUuid - Универсальный уникальный идентификатор
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditOrder (
  pId		    numeric,
  pParent	    numeric default null,
  pType		    numeric default null,
  pCode		    varchar default null,
  pClient       numeric default null,
  pAmount	    numeric default null,
  pUuid         uuid default null,
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

  SELECT id INTO nId FROM db.client WHERE id = pClient;

  IF not found THEN
    PERFORM ObjectNotFound('клиент', 'id', pClient);
  END IF;

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
     SET code = coalesce(pCode, code),
         client = coalesce(pClient, client),
         amount = coalesce(pAmount, amount),
         uuid = coalesce(pUuid, uuid)
   WHERE id = pId;

  nClass := GetObjectClass(pId);
  nMethod := GetMethod(nClass, null, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetOrder --------------------------------------------------------------------
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
  SELECT o.id, o.document, o.code, o.client, c.code AS ClientCode, o.amount, o.uuid
    FROM db.order o INNER JOIN db.client c ON c.id = o.client;

GRANT SELECT ON Orders TO administrator;

--------------------------------------------------------------------------------
-- ObjectOrder -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectOrder (Id, Object, Parent,
  Essence, EssenceCode, EssenceName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Client, ClientCode, Amount, Uuid,
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
         o.code, o.client, o.clientcode, o.amount, o.uuid,
         d.label, d.description,
         d.statetype, d.statetypecode, d.statetypename,
         d.state, d.statecode, d.statelabel, d.lastupdate,
         d.owner, d.ownercode, d.ownername, d.created,
         d.oper, d.opercode, d.opername, d.operdate,
         d.area, d.areacode, d.areaname
    FROM Orders o INNER JOIN ObjectDocument d ON d.id = o.document;

GRANT SELECT ON ObjectOrder TO administrator;
