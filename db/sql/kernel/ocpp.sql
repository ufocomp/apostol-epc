--------------------------------------------------------------------------------
-- ocpp.log --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE ocpp.log (
    id			numeric PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_OCPP_LOG'),
    datetime	timestamp DEFAULT clock_timestamp() NOT NULL,
    username	text NOT NULL DEFAULT session_user,
    identity	text NOT NULL,
    action		text NOT NULL,
    request		jsonb,
    response	jsonb,
    runtime		interval
);

COMMENT ON TABLE ocpp.log IS 'Лог OCPP.';

COMMENT ON COLUMN ocpp.log.id IS 'Идентификатор';
COMMENT ON COLUMN ocpp.log.datetime IS 'Дата и время';
COMMENT ON COLUMN ocpp.log.username IS 'Пользователь СУБД';
COMMENT ON COLUMN ocpp.log.identity IS 'Идентификатор зарядной станции';
COMMENT ON COLUMN ocpp.log.action IS 'Действие';
COMMENT ON COLUMN ocpp.log.request IS 'Запрос';
COMMENT ON COLUMN ocpp.log.response IS 'Ответ';
COMMENT ON COLUMN ocpp.log.runtime IS 'Время выполнения запроса';

CREATE INDEX ON ocpp.log (identity);
CREATE INDEX ON ocpp.log (action);
CREATE INDEX ON ocpp.log (datetime);

--------------------------------------------------------------------------------
-- ocpp.WriteToLog -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ocpp.WriteToLog (
  pIdentity	text,
  pAction	text,
  pRequest	jsonb default null,
  pResponse	jsonb default null,
  pRunTime	interval default null
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  INSERT INTO ocpp.log (identity, action, request, response, runtime)
  VALUES (pIdentity, pAction, pRequest, pResponse, pRunTime)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ocpp.ClearLog ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ocpp.ClearLog (
  pDateTime	timestamp
) RETURNS	void
AS $$
BEGIN
  DELETE FROM ocpp.log WHERE datetime < pDateTime;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW ocppLog ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ocppLog (Id, DateTime, UserName,
  Identity, Action, Request, Response, RunTime)
AS
  SELECT id, datetime, username, identity, action, request, response,
         round(extract(second from runtime)::numeric, 3)
    FROM ocpp.log;

--------------------------------------------------------------------------------
-- ocpp.SetSession -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ocpp.SetSession (
) RETURNS	    text
AS $$
DECLARE
  nUserId	    numeric;
  nArea         numeric;
  nInterface	numeric;

  vSession	    text;
BEGIN
  IF session_user <> 'ocpp' THEN
    PERFORM AccessDeniedForUser(session_user);
  END IF;

  nUserId := GetUser('ocpp');

  IF nUserId IS NOT NULL THEN
    SELECT key INTO vSession FROM db.session WHERE userid = nUserId;

    IF NOT FOUND THEN
      nArea := GetDefaultArea(nUserId);
      nInterface := GetDefaultInterface(nUserId);

      INSERT INTO db.session (userid, area, interface, host)
      VALUES (nUserId, nArea, nInterface, null)
      RETURNING key INTO vSession;
    END IF;

    PERFORM SetSessionKey(vSession);
    PERFORM SetUserId(nUserId);
  END IF;

  RETURN vSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ocpp.GetIdTagStatus ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ocpp.GetIdTagStatus (
  pChargePoint	numeric,
  pIdTag        text
) RETURNS       text
AS $$
DECLARE
  nId           numeric;
  nCard         numeric;

  vStateCode    varchar;

  Status        text;
BEGIN
  Status := 'Invalid';

  IF pChargePoint IS NOT NULL AND pIdTag IS NOT NULL THEN

    nCard := GetCard(pIdTag);

    IF nCard IS NULL THEN
      nCard := CreateCard(null, GetType('plastic.card'), pIdTag);
    END IF;

    vStateCode := GetObjectStateTypeCode(nCard);

    IF vStateCode IS NOT NULL THEN
      IF vStateCode = 'enabled' THEN
        SELECT id INTO nId FROM db.transaction WHERE Card = nCard AND now() BETWEEN DateStart AND DateStop;
        IF FOUND THEN
          Status := 'ConcurrentTx';
        ELSE
      	  Status := 'Accepted';
        END IF;
      ELSEIF vStateCode = 'deleted' THEN
        Status := 'Expired';
      ELSE
        Status := 'Blocked';
      END IF;
    END IF;
  END IF;

  RETURN Status;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ocpp.Heartbeat --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ocpp.Heartbeat (
  pIdentity	    text,
  pRequest	    jsonb default null
) RETURNS	    json
AS $$
DECLARE
  nChargePoint	numeric;
BEGIN
  nChargePoint := GetChargePoint(pIdentity);

  IF nChargePoint IS NOT NULL THEN
    PERFORM ExecuteObjectAction(nChargePoint, GetAction('heartbeat'), pRequest);
  END IF;

  RETURN json_build_object('currentTime', GetISOTime());
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ocpp.Authorize --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ocpp.Authorize (
  pIdentity	text,
  pRequest	jsonb
) RETURNS	json
AS $$
DECLARE
  nChargePoint	numeric;

  arKeys	text[];
  vStatus	text;

  idTag		text;
BEGIN
  IF pRequest IS NULL THEN
    PERFORM JsonIsEmpty();
  END IF;

  arKeys := array_cat(arKeys, ARRAY['idTag']);
  PERFORM CheckJsonbKeys(pIdentity || '/Authorize', arKeys, pRequest);

  idTag := pRequest->>'idTag';

  nChargePoint := GetChargePoint(pIdentity);

  vStatus := ocpp.GetIdTagStatus(nChargePoint, idTag);

  RETURN json_build_object('idTagInfo', json_build_object('expiryDate', GetISOTime(current_timestamp at time zone 'utc' + interval '1 day') , 'status', vStatus));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ocpp.BootNotification -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ocpp.BootNotification (
  pIdentity         text,
  pRequest          jsonb
) RETURNS           json
AS $$
DECLARE
  nChargePoint      numeric;
  nType             numeric;

  arKeys            text[];
  vStatus           text;

  vSerialNumber     text;
  vStateCode        text;

  chargeBoxSerialNumber		text;
  chargePointModel		    text;
  chargePointSerialNumber	text;
  chargePointVendor		    text;
  firmwareVersion		    text;
  meterSerialNumber		    text;
  iccid				        text;
  imsi				        text;
BEGIN
  IF pRequest IS NULL THEN
    PERFORM JsonIsEmpty();
  END IF;

  arKeys := array_cat(arKeys, ARRAY['chargeBoxSerialNumber', 'chargePointModel', 'chargePointSerialNumber', 'chargePointVendor', 'firmwareVersion', 'meterSerialNumber', 'iccid', 'imsi']);
  PERFORM CheckJsonbKeys(pIdentity || '/BootNotification', arKeys, pRequest);

  chargeBoxSerialNumber := pRequest->>'chargeBoxSerialNumber';
  chargePointModel := pRequest->>'chargePointModel';
  chargePointSerialNumber := pRequest->>'chargePointSerialNumber';
  chargePointVendor := pRequest->>'chargePointVendor';
  firmwareVersion := pRequest->>'firmwareVersion';
  meterSerialNumber := pRequest->>'meterSerialNumber';
  iccid := pRequest->>'iccid';
  imsi := pRequest->>'imsi';

  nChargePoint := GetChargePoint(pIdentity);

  IF nChargePoint IS NULL THEN
    IF chargePointModel IN ('PROD') THEN
      nType := GetType('soap.charge_point');
    ELSE
      nType := GetType('json.charge_point');
    END IF;

    nChargePoint := CreateChargePoint(null, nType, pIdentity, 'Charge Point', chargePointModel, chargePointVendor, firmwareVersion, chargePointSerialNumber, chargeBoxSerialNumber, meterSerialNumber, iccid, imsi);
  END IF;

  SELECT SerialNumber INTO vSerialNumber FROM db.charge_point WHERE id = nChargePoint;

  vStatus := 'Rejected';
  IF vSerialNumber = chargePointSerialNumber THEN
    vStateCode := GetObjectStateTypeCode(nChargePoint);
    IF coalesce(vStateCode, 'null') = 'enabled' THEN
      vStatus := 'Accepted';
    ELSE
      vStatus := 'Pending';
    END IF;
  END IF;

  RETURN json_build_object('currentTime', GetISOTime(), 'interval', 600, 'status', vStatus);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ocpp.StatusNotification -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ocpp.StatusNotification (
  pIdentity	        text,
  pRequest	        jsonb
) RETURNS	        json
AS $$
DECLARE
  nId			    numeric;
  nChargePoint      numeric;

  arKeys            text[];

  connectorId       integer;
  status		    text;
  errorCode		    text;
  info			    text;
  timestamp		    timestamp;
  vendorId		    text;
  vendorErrorCode	text;
BEGIN
  IF pRequest IS NULL THEN
    PERFORM JsonIsEmpty();
  END IF;

  arKeys := array_cat(arKeys, ARRAY['connectorId', 'status', 'errorCode', 'info', 'timestamp', 'vendorId', 'vendorErrorCode']);
  PERFORM CheckJsonbKeys(pIdentity || '/StatusNotification', arKeys, pRequest);

  connectorId := pRequest->>'connectorId';
  status := pRequest->>'status';
  errorCode := pRequest->>'errorCode';
  info := pRequest->>'info';
  timestamp := pRequest->>'timestamp';
  vendorId := pRequest->>'vendorId';
  vendorErrorCode := pRequest->>'vendorErrorCode';

  nChargePoint := GetChargePoint(pIdentity);

  IF nChargePoint IS NOT NULL THEN
    nId := AddStatusNotification(nChargePoint, connectorId, status, errorCode, info, vendorId, vendorErrorCode, timestamp);
  END IF;

  RETURN '{}'::json;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ocpp.StartTransaction -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ocpp.StartTransaction (
  pIdentity     text,
  pRequest      jsonb
) RETURNS       json
AS $$
DECLARE
  nId           numeric;
  nChargePoint	numeric;
  nCard         numeric;

  arKeys        text[];
  vStatus       text;

  idTag         text;
  connectorId	integer;
  meterStart	integer;
  reservationId	integer;
  dateStart     timestamp;
BEGIN
  IF pRequest IS NULL THEN
    PERFORM JsonIsEmpty();
  END IF;

  arKeys := array_cat(arKeys, ARRAY['idTag', 'connectorId', 'meterStart', 'reservationId', 'timestamp']);
  PERFORM CheckJsonbKeys(pIdentity || '/StartTransaction', arKeys, pRequest);

  idTag := pRequest->>'idTag';
  connectorId := pRequest->>'connectorId';
  meterStart := pRequest->>'meterStart';
  reservationId := pRequest->>'reservationId';
  dateStart := pRequest->>'timestamp';

  nChargePoint := GetChargePoint(pIdentity);

  vStatus := ocpp.GetIdTagStatus(nChargePoint, idTag);

  IF vStatus = 'Accepted' AND nChargePoint IS NOT NULL THEN
    nCard := GetCard(idTag);

    nId := kernel.StartTransaction(nCard, nChargePoint, connectorId, meterStart, reservationId, dateStart);

    PERFORM ExecuteObjectAction(nChargePoint, GetAction('start'), pRequest);
  END IF;

  RETURN json_build_object('transactionId', nId, 'idTagInfo', json_build_object('expiryDate', GetISOTime(current_timestamp at time zone 'utc' + interval '1 day') , 'status', vStatus));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ocpp.StopTransaction --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ocpp.StopTransaction (
  pIdentity     text,
  pRequest      jsonb
) RETURNS       json
AS $$
DECLARE
  nChargePoint	numeric;

  arKeys        text[];
  vStatus       text;

  Balance       integer default 0;

  idTag         text;
  transactionId integer;
  meterStop     integer;
  reason        text;
  Data          json;
  dateStop      timestamp;
BEGIN
  IF pRequest IS NULL THEN
    PERFORM JsonIsEmpty();
  END IF;

  arKeys := array_cat(arKeys, ARRAY['idTag', 'transactionId', 'meterStop', 'reason', 'transactionData', 'timestamp']);
  PERFORM CheckJsonbKeys(pIdentity || '/StopTransaction', arKeys, pRequest);

  idTag := pRequest->>'idTag';
  transactionId := pRequest->>'transactionId';
  meterStop := pRequest->>'meterStop';
  reason := pRequest->>'reason';
  Data := pRequest->>'transactionData';
  dateStop := pRequest->>'timestamp';

  IF (transactionId > 0) THEN
    Balance := kernel.StopTransaction(transactionId, meterStop, reason, Data, dateStop);
  END IF;

  nChargePoint := GetChargePoint(pIdentity);

  IF nChargePoint IS NOT NULL THEN
    PERFORM ExecuteObjectAction(nChargePoint, GetAction('stop'), pRequest);
  END IF;

  IF idTag IS NOT NULL THEN
    vStatus := ocpp.GetIdTagStatus(nChargePoint, idTag);
    RETURN json_build_object('idTagInfo', json_build_object('expiryDate', GetISOTime(current_timestamp at time zone 'utc' + interval '1 day') , 'status', vStatus));
  END IF;

  RETURN '{}'::json;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ocpp.MeterValues ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ocpp.MeterValues (
  pIdentity     text,
  pRequest      jsonb default null
) RETURNS       json
AS $$
DECLARE
  nId           numeric;
  nChargePoint  numeric;

  arKeys        text[];

  connectorId	integer;
  transactionId	integer;
  meterValue	json;
BEGIN
  IF pRequest IS NULL THEN
    PERFORM JsonIsEmpty();
  END IF;

  arKeys := array_cat(arKeys, ARRAY['connectorId', 'transactionId', 'meterValue']);
  PERFORM CheckJsonbKeys(pIdentity || '/MeterValues', arKeys, pRequest);

  nChargePoint := GetChargePoint(pIdentity);

  IF nChargePoint IS NOT NULL THEN
    connectorId := pRequest->>'connectorId';
    transactionId := pRequest->>'transactionId';
    meterValue := pRequest->>'meterValue';

    nId := AddMeterValue(nChargePoint, connectorId, transactionId, meterValue);
  END IF;

  RETURN '{}'::json;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ocpp.DataTransfer -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ocpp.DataTransfer (
  pIdentity	    text,
  pRequest	    jsonb
) RETURNS	    json
AS $$
DECLARE
  nChargePoint	numeric;

  vVendor		varchar;

  arKeys	    text[];
  vStatus	    text;

  vendorId 	    text;
  messageId	    text;
  data		    text;
BEGIN
  vStatus := 'Rejected';

  IF pRequest IS NULL THEN
    PERFORM JsonIsEmpty();
  END IF;

  arKeys := array_cat(arKeys, ARRAY['vendorId', 'messageId', 'data']);
  PERFORM CheckJsonbKeys(pIdentity || '/DataTransfer', arKeys, pRequest);

  vendorId := pRequest->>'vendorId';
  messageId := pRequest->>'messageId';
  data := pRequest->>'data';

  nChargePoint := GetChargePoint(pIdentity);

  IF nChargePoint IS NOT NULL THEN

    SELECT Vendor INTO vVendor FROM db.charge_point WHERE id = nChargePoint;

    IF vVendor = vendorId THEN
      vStatus := 'Accepted';
    ELSE
      vStatus := 'UnknownVendorId';
    END IF;
  END IF;

  RETURN json_build_object('status', vStatus);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ocpp.Parse ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Разбор OCPP пакета полученного от зарядной станции.
 * @param {text} pIdentity - Идентификатор зарядной станции
 * @param {text} pAction - Действие
 * @param {jsonb} pRequest - JSON запрос
 * @return {json} - JSON ответ
 */
CREATE OR REPLACE FUNCTION ocpp.Parse (
  pIdentity	text,
  pAction	text,
  pRequest	jsonb
) RETURNS	json
AS $$
DECLARE
  nLogId	numeric;

  tsBegin	timestamp;

  vError	text;
  vSession	text;

  jResponse	json;
BEGIN
  vSession := ocpp.SetSession();

  nLogId := ocpp.WriteTolog(pIdentity, pAction, pRequest);

  BEGIN
    tsBegin := clock_timestamp();

    CASE pAction
    WHEN 'Heartbeat' THEN

      jResponse := ocpp.Heartbeat(pIdentity, pRequest);

    WHEN 'Authorize' THEN

      jResponse := ocpp.Authorize(pIdentity, pRequest);

    WHEN 'BootNotification' THEN

      jResponse := ocpp.BootNotification(pIdentity, pRequest);

    WHEN 'StatusNotification' THEN

      jResponse := ocpp.StatusNotification(pIdentity, pRequest);

    WHEN 'StartTransaction' THEN

      jResponse := ocpp.StartTransaction(pIdentity, pRequest);

    WHEN 'StopTransaction' THEN

      jResponse := ocpp.StopTransaction(pIdentity, pRequest);

    WHEN 'MeterValues' THEN

      jResponse := ocpp.MeterValues(pIdentity, pRequest);

    WHEN 'DataTransfer' THEN

      jResponse := ocpp.DataTransfer(pIdentity, pRequest);

    ELSE
      PERFORM ActionNotFound(pAction);
    END CASE;

    UPDATE ocpp.log SET response = jResponse, runtime = age(clock_timestamp(), tsBegin) WHERE id = nLogId;

    RETURN json_build_object('result', true, 'response', jResponse);
  EXCEPTION
  WHEN others THEN
    GET STACKED DIAGNOSTICS vError = MESSAGE_TEXT;
  END;

  PERFORM SetErrorMessage(vError);

  jResponse := json_build_object('error', vError);

  UPDATE ocpp.log SET response = jResponse, runtime = age(clock_timestamp(), tsBegin) WHERE id = nLogId;

  RETURN json_build_object('result', false, 'response', jResponse);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vError = MESSAGE_TEXT;

  PERFORM SetErrorMessage(vError);

  RETURN json_build_object('result', false, 'response', json_build_object('error', vError));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
