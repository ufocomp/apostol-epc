--------------------------------------------------------------------------------
-- OBJECT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object (
    id			numeric(12) PRIMARY KEY,
    parent		numeric(12),
    type		numeric(12) NOT NULL,
    state		numeric(12),
    suid		numeric(12) NOT NULL,
    owner		numeric(12) NOT NULL,
    oper		numeric(12) NOT NULL,
    label		text,
    pdate		timestamp DEFAULT NOW() NOT NULL,
    ldate		timestamp DEFAULT NOW() NOT NULL,
    udate		timestamp DEFAULT NOW() NOT NULL,
    CONSTRAINT fk_object_parent FOREIGN KEY (parent) REFERENCES db.object(id),
    CONSTRAINT fk_object_type FOREIGN KEY (type) REFERENCES db.type(id),
    CONSTRAINT fk_object_state FOREIGN KEY (state) REFERENCES db.state_list(id),
    CONSTRAINT fk_object_suid FOREIGN KEY (suid) REFERENCES db.user(id),
    CONSTRAINT fk_object_owner FOREIGN KEY (owner) REFERENCES db.user(id),
    CONSTRAINT fk_object_oper FOREIGN KEY (oper) REFERENCES db.user(id)
);

COMMENT ON TABLE db.object IS 'Список объектов.';

COMMENT ON COLUMN db.object.id IS 'Идентификатор';
COMMENT ON COLUMN db.object.parent IS 'Родитель';
COMMENT ON COLUMN db.object.type IS 'Тип';
COMMENT ON COLUMN db.object.suid IS 'Системный пользователь';
COMMENT ON COLUMN db.object.owner IS 'Владелец (пользователь)';
COMMENT ON COLUMN db.object.oper IS 'Пользователь совершивший последнюю операцию';
COMMENT ON COLUMN db.object.label IS 'Метка';
COMMENT ON COLUMN db.object.pdate IS 'Физическая дата';
COMMENT ON COLUMN db.object.ldate IS 'Логическая дата';
COMMENT ON COLUMN db.object.udate IS 'Дата последнего изменения';

CREATE INDEX ON db.object (parent);
CREATE INDEX ON db.object (type);

CREATE INDEX ON db.object (suid);
CREATE INDEX ON db.object (owner);
CREATE INDEX ON db.object (oper);

CREATE INDEX ON db.object (label);
CREATE INDEX ON db.object (label text_pattern_ops);

CREATE INDEX ON db.object (pdate);
CREATE INDEX ON db.object (ldate);
CREATE INDEX ON db.object (udate);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_before_insert()
RETURNS trigger AS $$
DECLARE
  nClass        numeric;
  bAbstract	boolean;
BEGIN
  IF lower(session_user) = 'kernel' THEN
    PERFORM AccessDeniedForUser(session_user);
  END IF;

  SELECT class INTO nClass FROM db.type WHERE id = NEW.TYPE;
  SELECT abstract INTO bAbstract FROM db.class_tree WHERE id = nClass;

  IF bAbstract THEN
    PERFORM AbstractError();
  END IF;

  IF NEW.ID IS NULL OR NEW.ID = 0 THEN
    SELECT NEXTVAL('SEQUENCE_ID') INTO NEW.ID;
  END IF;

  NEW.SUID := session_userid();
  NEW.OWNER := current_userid();
  NEW.OPER := current_userid();

  NEW.PDATE := now();
  NEW.LDATE := now();
  NEW.UDATE := now();

  RAISE DEBUG 'Создан объект Id: %', NEW.ID;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_object_before_insert
  BEFORE INSERT ON db.object
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_object_before_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_after_insert()
RETURNS trigger AS $$
BEGIN
  INSERT INTO db.aom SELECT NEW.ID;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_object_after_insert
  AFTER INSERT ON db.object
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_object_after_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_before_update()
RETURNS trigger AS $$
DECLARE
  nStateType	numeric;
  nOldEssence	numeric;
  nNewEssence	numeric;
  nOldClass	numeric;
  nNewClass	numeric;
BEGIN
  IF lower(session_user) = 'kernel' THEN
    SELECT AccessDeniedForUser(session_user);
  END IF;

  IF OLD.SUID <> NEW.SUID THEN
    PERFORM AccessDenied();
  END IF;

  IF NOT CheckObjectAccess(NEW.ID, B'010') THEN
    PERFORM AccessDenied();
  END IF;

  IF OLD.TYPE <> NEW.TYPE THEN
    SELECT class INTO nOldClass FROM db.type WHERE id = OLD.TYPE;
    SELECT class INTO nNewClass FROM db.type WHERE id = NEW.TYPE;

    SELECT essence INTO nOldEssence FROM db.class_tree WHERE id = nOldClass;
    SELECT essence INTO nNewEssence FROM db.class_tree WHERE id = nNewClass;

    IF nOldEssence <> nNewEssence THEN
      PERFORM IncorrectEssence();
    END IF;
  END IF;

  IF nOldClass <> nNewClass THEN

    SELECT type INTO nStateType FROM db.state_list WHERE id = OLD.STATE;
    NEW.STATE := GetState(nNewClass, nStateType);

    IF coalesce(OLD.STATE <> NEW.STATE, false) THEN
      UPDATE db.object_state SET state = NEW.STATE
       WHERE object = OLD.ID
         AND state = OLD.STATE;
    END IF;
  END IF;

  NEW.OPER := current_userid();

  NEW.LDATE := now();
  NEW.UDATE := now();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_object_before_update
  BEFORE UPDATE ON db.object
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_object_before_update();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_before_delete()
RETURNS trigger AS $$
BEGIN
  IF lower(session_user) = 'kernel' THEN
    SELECT AccessDeniedForUser(session_user);
  END IF;

  IF NOT CheckObjectAccess(OLD.ID, B'001') THEN
    PERFORM AccessDenied();
  END IF;

  DELETE FROM db.aom WHERE object = OLD.ID;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_object_before_delete
  BEFORE DELETE ON db.object
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_object_before_delete();

--------------------------------------------------------------------------------
-- CheckObjectAccess -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckObjectAccess (
  pObject	numeric,
  pMask		bit,
  pUserId	numeric default current_userid()
) RETURNS	boolean
AS $$
BEGIN
  RETURN coalesce(GetObjectMask(pObject, pUserId) & pMask = pMask, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW object -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW object (Id, Parent,
  Essence, EssenceCode, EssenceName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Label,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate
) AS
  WITH cu AS (
    SELECT current_userid() AS owner
  )
  SELECT o.id, o.parent,
         e.id, e.code, e.name,
         c.id, c.code, c.label,
         t.id, t.code, t.name, t.description,
         o.label,
         y.id, y.code, y.name,
         o.state, s.code, s.label, o.udate,
         o.owner, w.username, w.fullname, o.pdate,
         o.oper, u.username, u.fullname, o.ldate
    FROM db.object o INNER JOIN db.type t       ON t.id = o.type
                     INNER JOIN db.class_tree c ON c.id = t.class
                     INNER JOIN db.essence e    ON e.id = c.essence
                     INNER JOIN db.state_list s ON s.id = o.state
                     INNER JOIN db.state_type y ON y.id = s.type
                     INNER JOIN db.user w       ON w.id = o.owner AND w.type = 'U'
                     INNER JOIN db.user u       ON u.id = o.oper AND u.type = 'U'
   WHERE o.owner = (SELECT owner FROM cu);

GRANT SELECT ON object TO administrator;

--------------------------------------------------------------------------------
-- CreateObject ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateObject (
  pParent	numeric,
  pType         numeric,
  pLabel	text default null
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  INSERT INTO db.object (parent, type, label)
  VALUES (pParent, pType, pLabel)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetObjectParent -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetObjectParent (
  nObject	numeric,
  pParent	numeric
) RETURNS	void
AS $$
BEGIN
  UPDATE db.object SET parent = pParent WHERE id = nObject;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectParent -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectParent (
  nObject	numeric
) RETURNS	numeric
AS $$
DECLARE
  nParent	numeric;
BEGIN
  SELECT parent INTO nParent FROM db.object WHERE id = nObject;
  RETURN nParent;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectLabel -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectLabel (
  pObject	numeric
) RETURNS	text
AS $$
DECLARE
  vLabel	text;
BEGIN
  SELECT label INTO vLabel FROM db.object WHERE id = pObject;

  RETURN vLabel;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectClass -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectClass (
  pId		numeric
) RETURNS	numeric
AS $$
DECLARE
  nClass	numeric;
BEGIN
  SELECT class INTO nClass FROM db.type WHERE id = (
    SELECT type FROM db.object WHERE id = pId
  );

  RETURN nClass;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectType ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectType (
  pId		numeric
) RETURNS	numeric
AS $$
DECLARE
  nType         numeric;
BEGIN
  SELECT type INTO nType FROM db.object WHERE id = pId;

  RETURN nType;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectState -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectState (
  pId		numeric
) RETURNS	numeric
AS $$
DECLARE
  nState	numeric;
BEGIN
  SELECT state INTO nState FROM db.object WHERE id = pId;

  RETURN nState;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectOwner -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectOwner (
  pId		numeric
) RETURNS 	numeric
AS $$
DECLARE
  nOwner	numeric;
BEGIN
  SELECT owner INTO nOwner FROM db.object WHERE id = pId;

  RETURN nOwner;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectOper ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectOper (
  pId		numeric
) RETURNS 	numeric
AS $$
DECLARE
  nOper	numeric;
BEGIN
  SELECT oper INTO nOper FROM db.object WHERE id = pId;

  RETURN nOper;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- TABLE db.aom ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.aom (
    object		NUMERIC(12) NOT NULL,
    mask		BIT(9) DEFAULT B'111100000' NOT NULL,
    CONSTRAINT fk_aom_object FOREIGN KEY (object) REFERENCES db.object(id)
);

COMMENT ON TABLE db.aom IS 'Маска доступа к объекту.';

COMMENT ON COLUMN db.aom.object IS 'Объект';
COMMENT ON COLUMN db.aom.mask IS 'Маска доступа. Девять бит (a:{u:sud}{g:sud}{o:sud}), по три бита на действие s - select, u - update, d - delete, для: a - all (все) = u - user (владелец) g - group (группа) o - other (остальные)';

CREATE UNIQUE INDEX ON db.aom (object);

--------------------------------------------------------------------------------
-- GetObjectMask ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectMask (
  pObject	numeric,
  pUserId	numeric default current_userid()
) RETURNS	bit
AS $$
  SELECT CASE
         WHEN pUserId = o.owner THEN SubString(mask FROM 1 FOR 3)
         WHEN EXISTS (SELECT id FROM db.user WHERE id = pUserId AND type = 'G') THEN SubString(mask FROM 4 FOR 3)
         ELSE SubString(mask FROM 7 FOR 3)
         END
    FROM db.aom a INNER JOIN db.object o ON o.id = a.object
   WHERE object = pObject
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT_STATE ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_state (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_ID'),
    object		numeric(12) NOT NULL,
    state		numeric(12) NOT NULL,
    validfromdate	timestamp DEFAULT NOW() NOT NULL,
    validtodate		timestamp DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL,
    CONSTRAINT fk_object_state_object FOREIGN KEY (object) REFERENCES db.object(id),
    CONSTRAINT fk_object_state_state FOREIGN KEY (state) REFERENCES db.state_list(id)
);

COMMENT ON TABLE db.object_state IS 'Состояние объекта.';

COMMENT ON COLUMN db.object_state.id IS 'Идентификатор';
COMMENT ON COLUMN db.object_state.object IS 'Объект';
COMMENT ON COLUMN db.object_state.state IS 'Ссылка на состояние объекта';
COMMENT ON COLUMN db.object_state.validfromdate IS 'Дата начала периода действия';
COMMENT ON COLUMN db.object_state.validtodate IS 'Дата окончания периода действия';

CREATE INDEX ON db.object_state (object);
CREATE INDEX ON db.object_state (state);
CREATE INDEX ON db.object_state (object, validfromdate, validtodate);

CREATE UNIQUE INDEX ON db.object_state (object, state, validfromdate, validtodate);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_state_change()
RETURNS TRIGGER AS
$$
BEGIN
  IF (TG_OP = 'INSERT') OR (TG_OP = 'UPDATE') THEN
    IF NEW.VALIDFROMDATE IS NULL THEN
      NEW.VALIDFROMDATE := now();
    END IF;

    IF NEW.VALIDFROMDATE > NEW.VALIDTODATE THEN
      RAISE EXCEPTION 'Дата начала периода действия не должна превышать дату окончания периода действия.';
    END IF;

    RETURN NEW;
  ELSE
    IF OLD.VALIDTODATE = MAXDATE() THEN
      UPDATE db.object SET state = NULL WHERE id = OLD.OBJECT;
    END IF;

    RETURN OLD;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_object_state_change
  AFTER INSERT OR UPDATE OR DELETE ON db.object_state
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_object_state_change();

--------------------------------------------------------------------------------
-- VIEW ObjectState ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectState (Id, Object, Class,
  State, StateTypeCode, StateTypeName, StateCode, StateLabel,
  ValidFromDate, ValidToDate
)
AS
  SELECT o.id, o.object, s.class, o.state, s.typecode, s.typename, s.code, s.label,
         o.validfromdate, o.validtodate
    FROM db.object_state o INNER JOIN State s ON s.id = o.state;

GRANT SELECT ON ObjectState TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION AddObjectState -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddObjectState (
  pObject	numeric,
  pState	numeric,
  pDateFrom	timestamp default oper_date()
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;

  dtDateFrom 	timestamp;
  dtDateTo 	timestamp;
BEGIN
  -- получим дату значения в текущем диапозоне дат
  SELECT max(ValidFromDate), max(ValidToDate) INTO dtDateFrom, dtDateTo
    FROM db.object_state
   WHERE object = pObject
     AND ValidFromDate <= pDateFrom
     AND ValidToDate > pDateFrom;

  IF dtDateFrom = pDateFrom THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.object_state SET State = pState
     WHERE object = pObject
       AND ValidFromDate <= pDateFrom
       AND ValidToDate > pDateFrom;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.object_state SET ValidToDate = pDateFrom
     WHERE object = pObject
       AND ValidFromDate <= pDateFrom
       AND ValidToDate > pDateFrom;

    INSERT INTO db.object_state (object, state, validfromdate, validtodate)
    VALUES (pObject, pState, pDateFrom, coalesce(dtDateTo, MAXDATE()))
    RETURNING id INTO nId;
  END IF;

  UPDATE db.object SET state = pState WHERE id = pObject;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectState -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectState (
  pObject	numeric,
  pDate		timestamp
) RETURNS	numeric
AS $$
DECLARE
  nState	numeric;
BEGIN
  SELECT state INTO nState
    FROM db.object_state
   WHERE object = pObject
     AND ValidFromDate <= pDate
     AND ValidToDate > pDate;

  RETURN nState;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectStateCode -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectStateCode (
  pObject	numeric,
  pDate		timestamp default oper_date()
) RETURNS 	varchar
AS $$
DECLARE
  nState	numeric;
  vCode		varchar;
BEGIN
  vCode := null;

  nState := GetObjectState(pObject, pDate);
  IF nState IS NOT NULL THEN
    SELECT code INTO vCode FROM db.state_list WHERE id = nState;
  END IF;

  RETURN vCode;
exception
  when NO_DATA_FOUND THEN
    RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetNewState --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetNewState (
  pMethod	numeric
) RETURNS 	numeric
AS $$
DECLARE
  nNewState	numeric;
BEGIN
  SELECT newstate INTO nNewState FROM db.transition WHERE method = pMethod;

  RETURN nNewState;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ChangeObjectState -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ChangeObjectState (
  pObject	numeric default context_object(),
  pMethod	numeric default context_method()
) RETURNS 	void
AS $$
DECLARE
  nNewState	numeric;
BEGIN
  nNewState := GetNewState(pMethod);
  IF nNewState IS NOT NULL THEN
    PERFORM AddObjectState(pObject, nNewState);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectMethod ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectMethod (
  pObject	numeric,
  pAction	numeric
) RETURNS	numeric
AS $$
DECLARE
  nType         numeric;
  nClass	numeric;
  nState	numeric;
  nMethod	numeric;
BEGIN
  SELECT type, state INTO nType, nState FROM db.object WHERE id = pObject;
  SELECT class INTO nClass FROM db.type WHERE id = nType;

  nMethod := GetMethod(nClass, nState, pAction);

  RETURN nMethod;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ExecuteAction -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ExecuteAction (
  pClass	numeric default context_class(),
  pAction	numeric default context_action()
) RETURNS	void
AS $$
DECLARE
  nClass	numeric;
  Rec		record;
BEGIN
  FOR Rec IN
    SELECT typecode, text
      FROM Event
     WHERE class = pClass
       AND action = pAction
       AND enabled
     ORDER BY sequence
  LOOP
    IF Rec.typecode = 'parent' THEN
      SELECT parent INTO nClass FROM db.class_tree WHERE id = pClass;
      IF nClass IS NOT NULL THEN
        PERFORM ExecuteAction(nClass, pAction);
      END IF;
    ELSIF Rec.typecode = 'event' THEN
      EXECUTE 'SELECT ' || Rec.Text;
    ELSIF Rec.typecode = 'plpgsql' THEN
      EXECUTE Rec.Text;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ExecuteMethod -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ExecuteMethod (
  pObject	numeric,
  pMethod	numeric
) RETURNS	void
AS $$
DECLARE
  nSaveObject	numeric;
  nSaveClass	numeric;
  nSaveMethod	numeric;
  nSaveAction	numeric;

  nClass	numeric;
  nAction	numeric;
BEGIN
  nSaveObject := context_object();
  nSaveClass  := context_class();
  nSaveMethod := context_method();
  nSaveAction := context_action();

  nClass := GetObjectClass(pObject);

  SELECT action INTO nAction FROM db.method WHERE id = pMethod;

  PERFORM InitContext(pObject, nClass, pMethod, nAction);
  PERFORM ExecuteAction(nClass, nAction);
  PERFORM InitContext(nSaveObject, nSaveClass, nSaveMethod, nSaveAction);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ExecuteMethodForAllChild ------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ExecuteMethodForAllChild (
  pObject	numeric default context_object(),
  pClass	numeric default context_class(),
  pMethod	numeric default context_method(),
  pAction	numeric default context_action()
) RETURNS	void
AS $$
DECLARE
  nMethod	numeric;
  rec		RECORD;
BEGIN
  FOR rec IN
    SELECT o.id, t.class, o.state FROM db.object o INNER JOIN db.type t ON o.type = t.id
     WHERE o.parent = pObject AND t.class = pClass
  LOOP
    nMethod := GetMethod(rec.class, rec.state, pAction);
    IF nMethod IS NOT NULL THEN
      PERFORM ExecuteMethod(rec.id, nMethod);
    END IF;
  END LOOP;

  PERFORM InitContext(pObject, pClass, pMethod, pAction);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ExecuteObjectAction -----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ExecuteObjectAction (
  pObject	numeric,
  pAction	numeric
) RETURNS void
AS $$
DECLARE
  nMethod	numeric;
BEGIN
  nMethod := GetObjectMethod(pObject, pAction);
  IF nMethod IS NOT NULL THEN
    PERFORM ExecuteMethod(pObject, nMethod);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.object_group -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_group (
    id                  numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_ID'),
    owner		numeric(12) NOT NULL,
    code                varchar(30) NOT NULL,
    name                varchar(50) NOT NULL,
    description         text,
    CONSTRAINT fk_object_group_owner FOREIGN KEY (owner) REFERENCES db.user(id)
);

COMMENT ON TABLE db.object_group IS 'Группа объектов.';

COMMENT ON COLUMN db.object_group.id IS 'Идентификатор';
COMMENT ON COLUMN db.object_group.owner IS 'Владелец';
COMMENT ON COLUMN db.object_group.code IS 'Код';
COMMENT ON COLUMN db.object_group.name IS 'Наименование';
COMMENT ON COLUMN db.object_group.description IS 'Описание';

CREATE INDEX ON db.object_group (owner);

CREATE UNIQUE INDEX ON db.object_group (code);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_group_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.OWNER IS NULL THEN
    NEW.OWNER := current_userid();
  END IF;

  IF NEW.CODE IS NULL THEN
    NEW.CODE := 'G:' || TRIM(TO_CHAR(NEW.ID, '999999999999'));
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_object_group
  BEFORE INSERT ON db.object_group
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_object_group_insert();

--------------------------------------------------------------------------------
-- CreateObjectGroup -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateObjectGroup (
  pCode		varchar,
  pName		varchar,
  pDescription	varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  INSERT INTO db.object_group (code, name, description)
  VALUES (pCode, pName, pDescription)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditObjectGroup -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditObjectGroup (
  pId		numeric,
  pCode		varchar,
  pName		varchar,
  pDescription	varchar
) RETURNS	void
AS $$
BEGIN
  UPDATE db.object_group
     SET code = pCode,
         name = pName,
         description = pDescription
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectGroup --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectGroup (
  pCode		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO strict nId FROM db.object_group WHERE code = pCode;

  RETURN nId;
exception
  when NO_DATA_FOUND THEN
    RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ObjectGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectGroup (Id, Code, Name, Description)
AS
  SELECT id, code, name, description
    FROM db.object_group
   WHERE coalesce(owner, coalesce(current_userid(), 0)) = coalesce(current_userid(), 0);

GRANT SELECT ON ObjectGroup TO administrator;

--------------------------------------------------------------------------------
-- db.object_group_member ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_group_member (
    id                  numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_ID'),
    gid                 numeric(12) NOT NULL,
    object              numeric(12) NOT NULL,
    CONSTRAINT fk_object_group_member_gid FOREIGN KEY (gid) REFERENCES db.object_group(id),
    CONSTRAINT fk_object_group_member_object FOREIGN KEY (object) REFERENCES db.object(id)
);

COMMENT ON TABLE db.object_group_member IS 'Члены группы объектов.';

COMMENT ON COLUMN db.object_group_member.id IS 'Идентификатор';
COMMENT ON COLUMN db.object_group_member.gid IS 'Группа';
COMMENT ON COLUMN db.object_group_member.object IS 'Объект';

CREATE INDEX ON db.object_group_member (gid);
CREATE INDEX ON db.object_group_member (object);

--------------------------------------------------------------------------------
-- AddObjectToGroup ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddObjectToGroup (
  pGroup	numeric,
  pObject	numeric
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.object_group_member WHERE gid = pGroup AND object = pObject;
  IF not found THEN
    INSERT INTO db.object_group_member (gid, object) 
    VALUES (pGroup, pObject)
    RETURNING id INTO nId;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteObjectOfGroup ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteObjectOfGroup (
  pGroup	numeric,
  pObject	numeric
) RETURNS	void
AS $$
DECLARE
  nCount	integer;
BEGIN
  DELETE FROM db.object_group_member
   WHERE gid = pGroup
     AND object = pObject;

  SELECT count(object) INTO nCount 
    FROM db.object_group_member
   WHERE gid = pGroup;

  IF nCount = 0 THEN
    DELETE FROM db.object_group WHERE id = pGroup;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ObjectGroupMember -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectGroupMember (Id, GId, Object, Code, Name, Description)
AS
  SELECT m.id, m.gid, m.object, g.code, g.name, g.description
    FROM db.object_group_member m INNER JOIN ObjectGroup g ON g.id = m.gid;

GRANT SELECT ON ObjectGroupMember TO administrator;

--------------------------------------------------------------------------------
-- db.object_file --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_file (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_ID'),
    object		numeric(12) NOT NULL,
    load_date		timestamp DEFAULT NOW() NOT NULL,
    file_hash		text NOT NULL,
    file_name		text NOT NULL,
    file_path		text DEFAULT NULL,
    file_size		numeric DEFAULT 0,
    file_date		timestamp DEFAULT NULL,
    file_body		bytea DEFAULT NULL,
    CONSTRAINT fk_object_file_object FOREIGN KEY (object) REFERENCES db.object(id)
);

COMMENT ON TABLE db.object_file IS 'Файлы объекта.';

COMMENT ON COLUMN db.object_file.object IS 'Объект';
COMMENT ON COLUMN db.object_file.load_date IS 'Дата загрузки';
COMMENT ON COLUMN db.object_file.file_hash IS 'Хеш файла';
COMMENT ON COLUMN db.object_file.file_name IS 'Наименование файла';
COMMENT ON COLUMN db.object_file.file_path IS 'Путь к файлу на сервере';
COMMENT ON COLUMN db.object_file.file_size IS 'Размер файла';
COMMENT ON COLUMN db.object_file.file_date IS 'Дата и время файла';
COMMENT ON COLUMN db.object_file.file_body IS 'Содержимое файла (если нужно)';

CREATE INDEX ON db.object_file (object);

CREATE INDEX ON db.object_file (file_hash);
CREATE INDEX ON db.object_file (file_name);
CREATE INDEX ON db.object_file (file_path);
CREATE INDEX ON db.object_file (file_date);

--------------------------------------------------------------------------------
-- VIEW ObjectFile -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectFile (Id, Object, LoadDate, FileHash, FileName, FilePath,
  FileSize, FileDate, FileBody
) 
AS
  SELECT id, object, load_date, file_hash, file_name, file_path, file_size, file_date, file_body
    FROM db.object_file;

GRANT SELECT ON ObjectFile TO administrator;

--------------------------------------------------------------------------------
-- AddObjectFile ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddObjectFile (
  pObject	numeric,
  pHash		text,
  pName		text,
  pPath		text,
  pSize		numeric,
  pDate		timestamp,
  pBody		bytea default null
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  INSERT INTO db.object_file (object, file_hash, file_name, file_path, file_size, file_date, file_body) 
  VALUES (pObject, pHash, pName, pPath, pSize, pDate, pBody) 
  RETURNING id INTO nId;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewObjectFile ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewObjectFile (
  pObject	numeric,
  pHash		text,
  pName		text,
  pPath		text,
  pSize		numeric,
  pDate		timestamp,
  pBody		bytea default null
) RETURNS	void
AS $$
DECLARE
  nId		numeric;
BEGIN
  nId := AddObjectFile(pObject, pHash, pName, pPath, pSize, pDate, pBody);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditObjectFile --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditObjectFile (
  pId		numeric,
  pHash		text,
  pName		text,
  pPath		text,
  pSize		numeric,
  pDate		timestamp,
  pBody		bytea default null,
  pLoad		timestamp default now()
) RETURNS	void
AS $$
BEGIN
  UPDATE db.object_file 
     SET load_date = pLoad,
         file_hash = pHash,
         file_name = pName,
         file_path = pPath, 
         file_size = pSize,
         file_date = pDate,
         file_body = pBody
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteObjectFile ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteObjectFile (
  pId		numeric
) RETURNS	void
AS $$
BEGIN
  DELETE FROM db.object_file WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectFiles --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectFiles (
  pObject	numeric
) RETURNS	text[][]
AS $$
DECLARE
  arResult	text[][]; 
  i		integer default 1;
  r		db.object_file%rowtype;
BEGIN
  FOR r IN
    SELECT *
      FROM db.object_file
     WHERE object = pObject
     ORDER BY load_date desc, file_path, file_name
  LOOP
    arResult[i] := ARRAY[r.id, r.file_hash, r.file_name, r.file_path, r.file_size, r.file_date];
    i := i + 1;
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectFiles --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectFiles (
  pObject	numeric
) RETURNS	text[]
AS $$
DECLARE
  arResult	text[]; 
  r		db.object_file%rowtype;
BEGIN
  FOR r IN
    SELECT *
      FROM db.object_file
     WHERE object = pObject
     ORDER BY load_date desc, file_path, file_name
  LOOP
    arResult := array_cat(arResult, ARRAY[r.id, r.file_hash, r.file_name, r.file_path, r.file_size, r.file_date]);
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectFilesJson ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectFilesJson (
  pObject	numeric
) RETURNS	json
AS $$
DECLARE
  arResult	json[]; 
  r		record;
BEGIN
  FOR r IN
    SELECT id, file_hash AS hash, file_name AS name, file_path AS path, file_size AS size, file_date AS date, encode(file_body, 'base64') AS body
      FROM db.object_file
     WHERE object = pObject
     ORDER BY load_date desc, file_path, file_name
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectFilesJsonb ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectFilesJsonb (
  pObject	numeric
) RETURNS	jsonb
AS $$
BEGIN
  RETURN GetObjectFilesJson(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.object_data_type ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_data_type (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_ID'),
    code        	varchar(30) NOT NULL,
    name 		varchar(50) NOT NULL,
    description		text
);

COMMENT ON TABLE db.object_data_type IS 'Тип произвольных данных объекта.';

COMMENT ON COLUMN db.object_data_type.id IS 'Идентификатор';
COMMENT ON COLUMN db.object_data_type.code IS 'Код';
COMMENT ON COLUMN db.object_data_type.name IS 'Наименование';
COMMENT ON COLUMN db.object_data_type.description IS 'Описание';

CREATE INDEX ON db.object_data_type (code);

INSERT INTO db.object_data_type (code, name, description) VALUES ('text', 'Текст', 'Произвольная строка');
INSERT INTO db.object_data_type (code, name, description) VALUES ('json', 'JSON', 'JavaScript Object Notation');
INSERT INTO db.object_data_type (code, name, description) VALUES ('xml', 'XML', 'eXtensible Markup Language');

--------------------------------------------------------------------------------
-- GetObjectDataType -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectDataType (
  pCode		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.object_data_type WHERE code = pCode;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ObjectDataType --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectDataType (Id, Code, Name, Description)
AS
  SELECT id, code, name, description
    FROM db.object_data_type;

GRANT SELECT ON ObjectDataType TO administrator;

--------------------------------------------------------------------------------
-- db.object_data --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_data (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_ID'),
    object		numeric(12) NOT NULL,
    type		numeric(12) NOT NULL,
    code        	varchar(30) NOT NULL,
    data		text,
    CONSTRAINT fk_object_data_object FOREIGN KEY (object) REFERENCES db.object(id),
    CONSTRAINT fk_object_data_type FOREIGN KEY (type) REFERENCES db.object_data_type(id)
);

COMMENT ON TABLE db.object_data IS 'Произвольные данные объекта.';

COMMENT ON COLUMN db.object_data.object IS 'Объект';
COMMENT ON COLUMN db.object_data.type IS 'Тип произвольных данных объекта';
COMMENT ON COLUMN db.object_data.code IS 'Код';
COMMENT ON COLUMN db.object_data.data IS 'Данные';

CREATE INDEX ON db.object_data (object);
CREATE INDEX ON db.object_data (type);
CREATE INDEX ON db.object_data (code);

CREATE UNIQUE INDEX ON db.object_data (object, type, code);

--------------------------------------------------------------------------------
-- VIEW ObjectData -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectData (Id, Object, Type, TypeCode, TypeName, TypeDesc, Code, Data)
AS
  SELECT d.id, d.object, d.type, t.code, t.name, t.description, d.code, d.data
    FROM db.object_data d INNER JOIN db.object_data_type t ON t.id = d.type;

GRANT SELECT ON ObjectData TO administrator;

--------------------------------------------------------------------------------
-- AddObjectData ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddObjectData (
  pObject	numeric,
  pType		numeric,
  pCode		text,
  pData		text
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  INSERT INTO db.object_data (object, type, code, data) 
  VALUES (pObject, pType, pCode, pData) 
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetObjectData ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetObjectData (
  pObject	numeric,
  pType		numeric,
  pCode		text,
  pData		text
) RETURNS	void
AS $$
DECLARE
  nId		numeric;
BEGIN
  nId := AddObjectData(pObject, pType, pCode, pData);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectData ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectData (
  pObject	numeric,
  pType		numeric,
  pCode		text
) RETURNS	text
AS $$
DECLARE
  vData		text;
BEGIN
  SELECT data INTO vData FROM db.object_data WHERE object = pObject AND type = pType AND code = pCode;
  RETURN vData;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteObjectData ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteObjectData (
  pId		numeric
) RETURNS	void
AS $$
BEGIN
  DELETE FROM db.object_data WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteObjectData ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteObjectData (
  pObject	numeric,
  pType		numeric,
  pCode		text
) RETURNS	void
AS $$
BEGIN
  DELETE FROM db.object_data WHERE object = pObject AND type = pType AND code = pCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
