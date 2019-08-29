--------------------------------------------------------------------------------
-- db.log ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.log (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_EVENTLOG'),
    object		numeric(12),
    type		char DEFAULT 'M' NOT NULL,
    datetime		timestamp DEFAULT NOW() NOT NULL,
    username		varchar(50) DEFAULT current_username() NOT NULL,
    session		varchar(40),
    code		numeric(5) NOT NULL,
    text		text NOT NULL,
    CONSTRAINT fk_event_log_object FOREIGN KEY (object) REFERENCES db.object(id),
    CONSTRAINT ch_event_log_type CHECK (type IN ('M', 'W', 'E'))
);

COMMENT ON TABLE db.log IS 'Журнал событий.';

COMMENT ON COLUMN db.log.id IS 'Идентификатор';
COMMENT ON COLUMN db.log.object IS 'Объект';
COMMENT ON COLUMN db.log.type IS 'Тип события';
COMMENT ON COLUMN db.log.datetime IS 'Дата и время события';
COMMENT ON COLUMN db.log.username IS 'Имя пользователя';
COMMENT ON COLUMN db.log.session IS 'Сессия';
COMMENT ON COLUMN db.log.code IS 'Код события';
COMMENT ON COLUMN db.log.text IS 'Текст';

CREATE INDEX ON db.log (object);
CREATE INDEX ON db.log (type);
CREATE INDEX ON db.log (datetime);
CREATE INDEX ON db.log (username);
CREATE INDEX ON db.log (code);

CREATE OR REPLACE FUNCTION ft_event_log_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.SESSION IS NULL THEN
    NEW.SESSION := current_session();
  END IF;

  IF NEW.SESSION IS NOT NULL THEN
    NEW.SESSION := SubStr(NEW.SESSION, 1, 8) || '...' || SubStr(NEW.SESSION, 33);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_event_log_insert
  BEFORE INSERT ON db.log
  FOR EACH ROW
  EXECUTE PROCEDURE ft_event_log_insert();

--------------------------------------------------------------------------------
-- VIEW EventLog ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW EventLog (Id, Object, Type, TypeName, DateTime, UserName,
  Session, Code, Text
)
AS
  SELECT id, object, type,
         CASE
         WHEN type = 'M' THEN 'Информация'
         WHEN type = 'W' THEN 'Предупреждение'
         WHEN type = 'E' THEN 'Ошибка'
         END,
         datetime, username, session, code, text
    FROM db.log;

GRANT SELECT ON EventLog TO administrator;

--------------------------------------------------------------------------------
-- AddEventLog -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddEventLog (
  pObject	numeric,
  pType		text,
  pCode		numeric,
  pText		text
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  INSERT INTO db.log (object, type, code, text)
  VALUES (pObject, pType, pCode, pText)
  RETURNING id INTO nId;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewEventLog -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewEventLog (
  pObject	numeric,
  pType		text,
  pCode		numeric,
  pText		text
) RETURNS	void
AS $$
DECLARE
  nId		numeric;
BEGIN
  nId := AddEventLog(pObject, pType, pCode, pText);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- WriteToEventLog -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION WriteToEventLog (
  pObject	numeric,
  pType		text,
  pCode		numeric,
  pText		text
) RETURNS	void
AS $$
BEGIN
  IF pType IN ('M', 'W', 'E') THEN
    PERFORM NewEventLog(pObject, pType, pCode, pText);
  END IF;

  IF pType = 'D' THEN
    RAISE DEBUG '[%] [%] [%] %', pObject, pType, pCode, pText;
  END IF;

--  IF pType = 'N' THEN
--    RAISE NOTICE '[%] [%] [%] %', pObject, pType, pCode, pText;
--  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteEventLog --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteEventLog (
  pId		numeric
) RETURNS	void
AS $$
BEGIN
  DELETE FROM db.log WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;