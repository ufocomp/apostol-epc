--------------------------------------------------------------------------------
-- db.document -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.document (
    id			numeric(12) PRIMARY KEY,
    object		numeric(12) NOT NULL,
    department		numeric(12) NOT NULL,
    description		text,
    CONSTRAINT fk_document_object FOREIGN KEY (object) REFERENCES db.object(id),
    CONSTRAINT fk_document_department FOREIGN KEY (department) REFERENCES db.department(id)
);

COMMENT ON TABLE db.document IS 'Документ.';

COMMENT ON COLUMN db.document.id IS 'Идентификатор';
COMMENT ON COLUMN db.document.object IS 'Объект';
COMMENT ON COLUMN db.document.department IS 'Подразделение';
COMMENT ON COLUMN db.document.description IS 'Описание';

CREATE INDEX ON db.document (object);
CREATE INDEX ON db.document (department);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_document_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NEW.ID IS NULL OR NEW.ID = 0 THEN
    SELECT NEW.OBJECT INTO NEW.ID;
  END IF;

  NEW.DEPARTMENT := current_department();

  IF NEW.DEPARTMENT = GetDepartment('root') THEN
    PERFORM RootDepartmentError();
  END IF;

  RAISE DEBUG 'Создан документ Id: %', NEW.ID;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_document_insert
  BEFORE INSERT ON db.document
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_document_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_document_update()
RETURNS trigger AS $$
BEGIN
  IF OLD.DEPARTMENT <> NEW.DEPARTMENT THEN
    SELECT ChangeDepartmentError();
  END IF;

  RAISE DEBUG 'Изменён документ Id: %', NEW.ID;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_document_update
  BEFORE UPDATE ON db.document
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_document_update();

--------------------------------------------------------------------------------
-- CreateDocument --------------------------------------------------------------
--------------------------------------------------------------------------------

create or replace function CreateDocument (
  pParent	numeric,
  pType		numeric,
  pLabel	text default null,
  pDesc		text default null
) returns 	numeric
as $$
declare
  nObject	numeric;
begin
  nObject := CreateObject(pParent, pType, pLabel);

  insert into db.document (object, description)
  values (nObject, pDesc)
  returning id into nObject;

  return nObject;
end;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Document --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Document (Id, Object, Department, Description,
  DepartmentCode, DepartmentName
) AS
  WITH RECURSIVE dep_tree(id) AS (
    SELECT id FROM department WHERE id = current_department()
     UNION ALL
    SELECT dp.id
      FROM db.department dp, dep_tree dtr
     WHERE dp.parent = dtr.id
  )
  SELECT d.id, d.object, d.department, d.description, p.code, p.name
    FROM db.document d INNER JOIN dep_tree dtr    ON d.department = dtr.id
                       INNER JOIN db.department p ON p.id = d.department;

GRANT SELECT ON Document TO administrator;

--------------------------------------------------------------------------------
-- ObjectDocument --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectDocument (Id, Object, Parent,
  Essence, EssenceCode, EssenceName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Department, DepartmentCode, DepartmentName
)
AS
  WITH cu AS (
    SELECT current_userid() AS owner
  )
  SELECT d.id, d.object, o.parent,
         o.essence, o.essencecode, o.essencename,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         o.label, d.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         d.department, d.departmentcode, d.departmentname
    FROM Document d INNER JOIN Object o        ON o.id = d.object
                    INNER JOIN cu              ON o.owner = cu.owner;

GRANT SELECT ON ObjectDocument TO administrator;
