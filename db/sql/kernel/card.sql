--------------------------------------------------------------------------------
-- db.card ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.card (
    Id			numeric(12) PRIMARY KEY,
    Document		numeric(12) NOT NULL,
    Code		varchar(30) NOT NULL,
    Client		numeric(12),
    CONSTRAINT fk_card_document FOREIGN KEY (document) REFERENCES db.document(id),
    CONSTRAINT fk_card_client FOREIGN KEY (client) REFERENCES db.client(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.card IS 'Пластиковая карта для зарядной станции.';

COMMENT ON COLUMN db.card.id IS 'Идентификатор';
COMMENT ON COLUMN db.card.document IS 'Документ';
COMMENT ON COLUMN db.card.code IS 'Код';
COMMENT ON COLUMN db.card.client IS 'Клиент';

--------------------------------------------------------------------------------

CREATE UNIQUE INDEX ON db.card (code);

CREATE INDEX ON db.card (document);
CREATE INDEX ON db.card (client);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_card_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NEW.id IS NULL OR NEW.id = 0 THEN
    SELECT NEW.DOCUMENT INTO NEW.id;
  END IF;

  RAISE DEBUG '[%] Добавлена карта: %', NEW.Id, NEW.Code;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_card_insert
  BEFORE INSERT ON db.card
  FOR EACH ROW
  EXECUTE PROCEDURE ft_card_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_card_update()
RETURNS trigger AS $$
DECLARE
  nParent	numeric;
  nUserId	numeric;
BEGIN
  IF OLD.Client IS NULL AND NEW.Client IS NOT NULL THEN
    nUserId := GetClientUserId(NEW.Client);
    PERFORM CheckObjectAccess(NEW.id, B'010', nUserId);
    SELECT parent INTO nParent FROM db.object WHERE id = NEW.DOCUMENT;
    IF nParent IS NOT NULL THEN
      PERFORM CheckObjectAccess(nParent, B'010', nUserId);
    END IF;
  END IF;

  RAISE DEBUG '[%] Обнавлёна карта: %', NEW.Id, NEW.Code;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_card_update
  BEFORE UPDATE ON db.card
  FOR EACH ROW
  EXECUTE PROCEDURE ft_card_update();

--------------------------------------------------------------------------------
-- CreateCard ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт новую карту
 * @param {numeric} pParent - Ссылка на родительский объект: VObject.Parent | null
 * @param {numeric} pType - Тип
 * @param {varchar} pCode - Код
 * @param {numeric} pClient - Клиент
 * @param {text} pDescription - Описание
 * @return {numeric} - Id карты
 */
CREATE OR REPLACE FUNCTION CreateCard (
  pParent	numeric,
  pType		numeric,
  pCode		varchar,
  pClient	numeric default null,
  pDescription	text default null
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
  nCard		numeric;
  nDocument	numeric;

  nClass	numeric;
  nMethod	numeric;
BEGIN
  SELECT class INTO nClass FROM type WHERE id = pType;

  IF nClass IS NULL OR GetClassCode(nClass) <> 'card' THEN
    PERFORM IncorrectClassType();
  END IF;

  SELECT id INTO nId FROM db.card WHERE code = pCode;

  IF found THEN
    PERFORM CardCodeExists(pCode);
  END IF;

  nDocument := CreateDocument(pParent, pType, null, pDescription);

  INSERT INTO db.card (id, document, code, client)
  VALUES (nDocument, nDocument, pCode, pClient)
  RETURNING id INTO nCard;

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nCard, nMethod);

  RETURN nCard;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditCard --------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет основные параметры клиента.
 * @param {numeric} pId - Идентификатор клиента
 * @param {numeric} pParent - Ссылка на родительский объект: VObject.Parent | null
 * @param {numeric} pType - Тип
 * @param {varchar} pCode - Код
 * @param {numeric} pClient - Клиент
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditCard (
  pId		numeric,
  pParent	numeric default null,
  pType		numeric default null,
  pCode		varchar default null,
  pClient	numeric default null,
  pDescription	text default null
) RETURNS 	void
AS $$
DECLARE
  nId		numeric;
  nClass	numeric;
  nMethod	numeric;

  -- current
  cParent	numeric;
  cType		numeric;
  cCode		varchar;
  cClient	numeric;
  cDescription	text;
BEGIN
  SELECT parent, type INTO cParent, cType FROM db.object WHERE id = pId;
  SELECT description INTO cDescription FROM db.document WHERE id = pId;
  SELECT code, client INTO cCode, cClient FROM db.card WHERE id = pId;

  pParent := coalesce(pParent, cParent, 0);
  pType := coalesce(pType, cType);
  pCode := coalesce(pCode, cCode);
  pClient := coalesce(pClient, cClient);
  pDescription := coalesce(pDescription, cDescription, '<null>');

  IF pCode <> cCode THEN
    SELECT id INTO nId FROM db.card WHERE code = pCode;
    IF found THEN
      PERFORM CardCodeExists(pCode);
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

  UPDATE db.card
     SET Code = pCode,
         Client = pClient
   WHERE Id = pId;

  nClass := GetObjectClass(pId);
  nMethod := GetMethod(nClass, null, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetCard ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetCard (
  pCode		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.card WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetCardClient ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetCardClient (
  pCard		numeric
) RETURNS	numeric
AS $$
DECLARE
  nClient	numeric;
BEGIN
  SELECT Client INTO nClient FROM db.card WHERE id = pCard;
  RETURN nClient;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Card ------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Card
AS
  SELECT * FROM db.card;

GRANT SELECT ON Card TO administrator;

--------------------------------------------------------------------------------
-- ObjectCard ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectCard (Id, Object, Parent,
  Essence, EssenceCode, EssenceName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Client,
  Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Department, DepartmentCode, DepartmentName
)
AS
  SELECT c.id, d.object, d.parent,
         d.essence, d.essencecode, d.essencename,
         d.class, d.classcode, d.classlabel,
         d.type, d.typecode, d.typename, d.typedescription,
         c.code, c.client,
         d.label, d.description,
         d.statetype, d.statetypecode, d.statetypename,
         d.state, d.statecode, d.statelabel, d.lastupdate,
         d.owner, d.ownercode, d.ownername, d.created,
         d.oper, d.opercode, d.opername, d.operdate,
         d.department, d.departmentcode, d.departmentname
    FROM Card c INNER JOIN ObjectDocument d ON d.id = c.document;

GRANT SELECT ON ObjectCard TO administrator;
