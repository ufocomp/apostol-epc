--------------------------------------------------------------------------------
-- api.log ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE api.log (
    id			    numeric PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_API_LOG'),
    datetime		timestamp DEFAULT clock_timestamp() NOT NULL,
    username		text NOT NULL DEFAULT session_user,
    api_session		char(40),
    api_username	varchar(50),
    route		    text NOT NULL,
    json		    jsonb,
    eventid		    numeric(12),
    runtime		    interval,
    CONSTRAINT fk_api_log_eventid FOREIGN KEY (eventid) REFERENCES db.log(id)
);

COMMENT ON TABLE api.log IS 'Лог API.';

COMMENT ON COLUMN api.log.id IS 'Идентификатор';
COMMENT ON COLUMN api.log.datetime IS 'Дата и время';
COMMENT ON COLUMN api.log.username IS 'Реальный пользователь';
COMMENT ON COLUMN api.log.api_session IS 'Сессия';
COMMENT ON COLUMN api.log.api_username IS 'Эффективный пользователь';
COMMENT ON COLUMN api.log.route IS 'Путь';
COMMENT ON COLUMN api.log.json IS 'JSON';
COMMENT ON COLUMN api.log.runtime IS 'Время выполнения запроса';

CREATE INDEX ON api.log (datetime);
--CREATE INDEX ON api.log (username);
--CREATE INDEX ON api.log (api_session);
CREATE INDEX ON api.log (api_username);
CREATE INDEX ON api.log (eventid);

--------------------------------------------------------------------------------
-- AddApiLog -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddApiLog (
  pRoute	text,
  pJson		jsonb
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
  nUserId	numeric;

  vKey		text;
  vUserName	text;
BEGIN
  SELECT key, userid INTO vKey, nUserId FROM db.session WHERE key = GetSessionKey();

  IF found THEN
    SELECT username INTO vUserName FROM db.user WHERE id = nUserId;
  END IF;

  IF lower(pRoute) = '/sign/in' THEN
    pJson := pJson - 'password';
  END IF;

  INSERT INTO api.log (api_session, api_username, route, json) 
  VALUES (vKey, vUserName, pRoute, pJson) 
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewApiLog -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewApiLog (
  pRoute	text,
  pJson		jsonb
) RETURNS	void
AS $$
DECLARE
  nId		numeric;
BEGIN
  nId := AddApiLog(pRoute, pJson);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- WriteToApiLog ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION WriteToApiLog (
  pRoute	text,
  pJson		jsonb
) RETURNS	void
AS $$
BEGIN
  PERFORM NewApiLog(pRoute, pJson);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteApiLog ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteApiLog (
  pId		numeric
) RETURNS	void
AS $$
BEGIN
  DELETE FROM api.log WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ClearApiLog -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ClearApiLog (
  pDateTime	timestamp
) RETURNS	void
AS $$
BEGIN
  DELETE FROM api.log WHERE datetime < pDateTime;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW ApiLog -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ApiLog (Id, DateTime, UserName, ApiSession, ApiUserName,
  Path, JSON, RunTime, EventId, Error)
AS
  SELECT al.id, al.datetime, al.username, al.api_session, al.api_username,
         al.route, al.json, round(extract(second from runtime)::numeric, 3), al.eventid, el.text
    FROM api.log al LEFT JOIN db.log el ON el.id = al.eventid;
