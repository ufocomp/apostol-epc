--------------------------------------------------------------------------------
-- db.charge_point -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.charge_point (
    Id                  numeric(12) PRIMARY KEY,
    Reference           numeric(12) NOT NULL,
    Model               varchar(20) NOT NULL,
    Vendor              varchar(20) NOT NULL,
    Version             varchar(50),
    SerialNumber        varchar(25),
    BoxSerialNumber     varchar(25),
    MeterSerialNumber   varchar(25),
    iccid               varchar(20),
    imsi                varchar(20),
    CONSTRAINT fk_charge_point_reference FOREIGN KEY (reference) REFERENCES db.reference(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.charge_point IS 'Зарядная станция.';

COMMENT ON COLUMN db.charge_point.id IS 'Идентификатор.';
COMMENT ON COLUMN db.charge_point.reference IS 'Справочник.';
COMMENT ON COLUMN db.charge_point.Model IS 'Required. This contains a value that identifies the model of the ChargePoint.';
COMMENT ON COLUMN db.charge_point.Vendor IS 'Required. This contains a value that identifies the vendor of the ChargePoint.';
COMMENT ON COLUMN db.charge_point.Version IS 'Optional. This contains the firmware version of the Charge Point.';
COMMENT ON COLUMN db.charge_point.SerialNumber IS 'Optional. This contains a value that identifies the serial number of the Charge Point.';
COMMENT ON COLUMN db.charge_point.BoxSerialNumber IS 'Optional. This contains a value that identifies the serial number of the Charge Box inside the Charge Point. Deprecated, will be removed in future version.';
COMMENT ON COLUMN db.charge_point.MeterSerialNumber IS 'Optional. This contains the serial number of the main electrical meter of the Charge Point.';
COMMENT ON COLUMN db.charge_point.iccid IS 'Optional. This contains the ICCID of the modem’s SIM card.';
COMMENT ON COLUMN db.charge_point.imsi IS 'Optional. This contains the IMSI of the modem’s SIM card.';

--------------------------------------------------------------------------------

CREATE INDEX ON db.charge_point (reference);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_charge_point_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NEW.ID IS NULL OR NEW.ID = 0 THEN
    SELECT NEW.REFERENCE INTO NEW.ID;
  END IF;

  RAISE DEBUG 'Создана зарядная станция Id: %', NEW.ID;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_charge_point_insert
  BEFORE INSERT ON db.charge_point
  FOR EACH ROW
  EXECUTE PROCEDURE ft_charge_point_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_charge_point_update()
RETURNS trigger AS $$
DECLARE
BEGIN
  RAISE DEBUG 'Изменёна зарядная станция Id: %', NEW.ID;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_charge_point_update
  BEFORE UPDATE ON db.charge_point
  FOR EACH ROW
  EXECUTE PROCEDURE ft_charge_point_update();

--------------------------------------------------------------------------------
-- CreateChargePoint -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateChargePoint (
  pParent               numeric,
  pType                 numeric,
  pIdentity             varchar,
  pName                 varchar,
  pModel                varchar,
  pVendor               varchar,
  pVersion              varchar,
  pSerialNumber         varchar,
  pBoxSerialNumber      varchar,
  pMeterSerialNumber    varchar,
  piccid                varchar,
  pimsi                 varchar,
  pDescription          text default null
) RETURNS               numeric
AS $$
DECLARE
  nReference            numeric;
  nClass                numeric;
  nMethod               numeric;
BEGIN
  nReference := CreateReference(pParent, pType, pIdentity, pName, pDescription);

  INSERT INTO db.charge_point (id, reference, model, vendor, version, serialnumber, boxserialnumber, meterserialnumber, iccid, imsi)
  VALUES (nReference, nReference, pModel, pVendor, pVersion, pSerialNumber, pBoxSerialNumber, pMeterSerialNumber, piccid, pimsi);

  SELECT class INTO nClass FROM db.type WHERE id = pType;

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nReference, nMethod);

  RETURN nReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditChargePoint -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditChargePoint (
  pId                   numeric,
  pParent               numeric default null,
  pType                 numeric default null,
  pIdentity             varchar default null,
  pName                 varchar default null,
  pModel                varchar default null,
  pVendor               varchar default null,
  pVersion              varchar default null,
  pSerialNumber         varchar default null,
  pBoxSerialNumber      varchar default null,
  pMeterSerialNumber    varchar default null,
  piccid                varchar default null,
  pimsi                 varchar default null,
  pDescription          text default null
) RETURNS               void
AS $$
DECLARE
  nClass	numeric;
  nMethod	numeric;
BEGIN
  PERFORM EditReference(pId, pParent, pType, pIdentity, pName, pDescription);

  UPDATE db.charge_point
     SET Model = coalesce(pModel, Model),
         Vendor = coalesce(pVendor, Vendor),
         Version = coalesce(pVersion, Version),
         SerialNumber = coalesce(pSerialNumber, SerialNumber),
         BoxSerialNumber = coalesce(pBoxSerialNumber, BoxSerialNumber),
         MeterSerialNumber = coalesce(pMeterSerialNumber, MeterSerialNumber),
         iccid = coalesce(piccid, iccid),
         imsi = coalesce(pimsi, imsi)
   WHERE id = pId;

  SELECT class INTO nClass FROM db.type WHERE id = pType;

  nMethod := GetMethod(nClass, null, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetChargePoint --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetChargePoint (
  pCode		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT p.id INTO nId
    FROM db.charge_point p INNER JOIN db.reference r ON r.id = p.reference
   WHERE r.code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.status_notification ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.status_notification (
    Id              numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_OCPP_STATUS'),
    chargePoint     numeric(12) NOT NULL,
    connectorId     integer NOT NULL,
    status          varchar(50) NOT NULL,
    errorCode       varchar(30) NOT NULL,
    info            varchar(50),
    vendorId		varchar(255),
    vendorErrorCode	varchar(50),
    ValidFromDate	timestamp DEFAULT NOW() NOT NULL,
    ValidToDate		timestamp DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL,
    CONSTRAINT fk_status_notification_chargePoint FOREIGN KEY (chargePoint) REFERENCES db.charge_point(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.status_notification IS 'Уведомление о статусе.';

COMMENT ON COLUMN db.status_notification.Id IS 'Идентификатор.';
COMMENT ON COLUMN db.status_notification.chargePoint IS 'Зарядная станция.';
COMMENT ON COLUMN db.status_notification.connectorId IS 'Required. The id of the connector for which the status is reported. Id "0" (zero) is used if the status is for the Charge Point main controller.';
COMMENT ON COLUMN db.status_notification.status IS 'Required. This contains the current status of the Charge Point.';
COMMENT ON COLUMN db.status_notification.errorCode IS 'Required. This contains the error code reported by the Charge Point.';
COMMENT ON COLUMN db.status_notification.info IS 'Optional. Additional free format information related to the error.';
COMMENT ON COLUMN db.status_notification.vendorId IS 'Optional. This identifies the vendor-specific implementation.';
COMMENT ON COLUMN db.status_notification.vendorErrorCode IS 'Optional. This contains the vendor-specific error code.';
COMMENT ON COLUMN db.status_notification.ValidFromDate IS 'Дата начала периода действия';
COMMENT ON COLUMN db.status_notification.ValidToDate IS 'Дата окончания периода действия.';

--------------------------------------------------------------------------------

CREATE INDEX ON db.status_notification (chargePoint);
CREATE INDEX ON db.status_notification (connectorId);
CREATE INDEX ON db.status_notification (chargePoint, ValidFromDate, ValidToDate);

CREATE UNIQUE INDEX ON db.status_notification (chargePoint, connectorId, ValidFromDate, ValidToDate);

--------------------------------------------------------------------------------
-- FUNCTION AddStatusNotification ----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddStatusNotification (
  pChargePoint		numeric,
  pConnectorId		integer,
  pStatus		    varchar,
  pErrorCode		varchar,
  pInfo			    varchar,
  pVendorId		    varchar,
  pVendorErrorCode	varchar,
  pTimeStamp		timestamp
) RETURNS 		    numeric
AS $$
DECLARE
  nId			    numeric;

  dtDateFrom 		timestamp;
  dtDateTo 		    timestamp;
BEGIN
  -- получим дату значения в текущем диапозоне дат
  SELECT max(ValidFromDate), max(ValidToDate) INTO dtDateFrom, dtDateTo
    FROM db.status_notification
   WHERE chargePoint = pChargePoint
     AND connectorId = pConnectorId
     AND ValidFromDate <= pTimeStamp
     AND ValidToDate > pTimeStamp;

  IF dtDateFrom = pTimeStamp THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.status_notification
       SET status = pStatus,
           errorCode = pErrorCode,
           info = pInfo,
           vendorId = pVendorId,
           vendorErrorCode = pVendorErrorCode
     WHERE chargePoint = pChargePoint
       AND connectorId = pConnectorId
       AND ValidFromDate <= pTimeStamp
       AND ValidToDate > pTimeStamp;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.status_notification SET ValidToDate = pTimeStamp
     WHERE chargePoint = pChargePoint
       AND connectorId = pConnectorId
       AND ValidFromDate <= pTimeStamp
       AND ValidToDate > pTimeStamp;

    INSERT INTO db.status_notification (chargePoint, connectorId, status, errorCode, info, vendorId, vendorErrorCode, validfromdate, validtodate)
    VALUES (pChargePoint, pConnectorId, pStatus, pErrorCode, pInfo, pVendorId, pVendorErrorCode, pTimeStamp, coalesce(dtDateTo, MAXDATE()))
    RETURNING id INTO nId;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- StatusNotification ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW StatusNotification
AS
  SELECT * FROM db.status_notification;

GRANT SELECT ON StatusNotification TO administrator;

--------------------------------------------------------------------------------
-- GetJsonStatusNotification ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetJsonStatusNotification (
  pChargePoint  numeric,
  pConnectorId  integer default null,
  pDate         timestamptz default current_timestamp at time zone 'utc'
) RETURNS	    json
AS $$
DECLARE
  arResult	    json[];
  r		        record;
BEGIN
  FOR r IN
  SELECT *
    FROM StatusNotification
   WHERE chargepoint = pChargePoint
     AND connectorid = coalesce(pConnectorId, connectorid)
     AND pDate BETWEEN validfromdate AND validtodate
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.transaction --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.transaction (
    Id			    numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_OCPP_TRANSACTION'),
    Card		    numeric(12) NOT NULL,
    chargePoint		numeric(12) NOT NULL,
    connectorId		integer NOT NULL,
    meterStart		integer NOT NULL,
    meterStop		integer,
    reservationId	integer,
    reason		    text,
    Data		    json,
    dateStart		timestamp NOT NULL,
    dateStop		timestamp DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL,
    CONSTRAINT fk_transaction_Card FOREIGN KEY (Card) REFERENCES db.card(id),
    CONSTRAINT fk_transaction_chargePoint FOREIGN KEY (chargePoint) REFERENCES db.charge_point(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.transaction IS 'Уведомление о статусе.';

COMMENT ON COLUMN db.transaction.Id IS 'Идентификатор.';
COMMENT ON COLUMN db.transaction.Card IS 'Пластиковая карта.';
COMMENT ON COLUMN db.transaction.chargePoint IS 'Зарядная станция.';
COMMENT ON COLUMN db.transaction.connectorId IS 'Required. This identifies which connector of the Charge Point is used.';
COMMENT ON COLUMN db.transaction.meterStart IS 'Required. This contains the meter value in Wh for the connector at start of the transaction.';
COMMENT ON COLUMN db.transaction.meterStop IS 'Required. This contains the meter value in Wh for the connector at end of the transaction.';
COMMENT ON COLUMN db.transaction.reservationId IS 'Optional. This contains the id of the reservation that terminates as a result of this transaction.';
COMMENT ON COLUMN db.transaction.reason IS 'Optional. This contains the reason why the transaction was stopped. MAY only be omitted when the Reason is "Local".';
COMMENT ON COLUMN db.transaction.Data IS 'Optional. This contains transaction usage details relevant for billing purposes.';
COMMENT ON COLUMN db.transaction.dateStart IS 'Required. This contains the date and time on which the transaction is started.';
COMMENT ON COLUMN db.transaction.dateStop IS 'Required. This contains the date and time on which the transaction is stopped.';

--------------------------------------------------------------------------------

CREATE INDEX ON db.transaction (Card);
CREATE INDEX ON db.transaction (chargePoint);
CREATE INDEX ON db.transaction (connectorId);
CREATE INDEX ON db.transaction (Card, chargePoint, connectorId);

--------------------------------------------------------------------------------
-- FUNCTION StartTransaction ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StartTransaction (
  pCard			    numeric,
  pChargePoint		numeric,
  pConnectorId		integer,
  pMeterStart		integer,
  pReservationId	integer,
  pTimeStamp		timestamp
) RETURNS 		    numeric
AS $$
DECLARE
  nId			    numeric;
BEGIN
  INSERT INTO db.transaction (Card, chargePoint, connectorId, meterStart, reservationId, dateStart)
  VALUES (pCard, pChargePoint, pConnectorId, pMeterStart, pReservationId, pTimeStamp)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION StopTransaction ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StopTransaction (
  pId			numeric,
  pMeterStop	integer,
  pReason		text,
  pData			json,
  pTimeStamp	timestamp
) RETURNS 		integer
AS $$
DECLARE
  nMeterStart	integer;
BEGIN
  SELECT meterStart INTO nMeterStart FROM db.transaction WHERE Id = pId;

  IF NOT FOUND THEN
    PERFORM UnknownTransaction(pId);
  END IF;

  UPDATE db.transaction
     SET meterStop = pMeterStop,
         reason = pReason,
         Data = pData,
         dateStop = pTimeStamp
   WHERE Id = pId;

  RETURN pMeterStop - nMeterStart;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Transaction -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Transaction
AS
  SELECT * FROM db.transaction;

GRANT SELECT ON Transaction TO administrator;

--------------------------------------------------------------------------------
-- db.meter_value --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.meter_value (
    Id			    numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_OCPP_STATUS'),
    chargePoint		numeric(12) NOT NULL,
    connectorId		integer NOT NULL,
    transactionId	numeric(12),
    meterValue		json NOT NULL,
    ValidFromDate	timestamp DEFAULT NOW() NOT NULL,
    ValidToDate		timestamp DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL,
    CONSTRAINT fk_meter_value_chargePoint FOREIGN KEY (chargePoint) REFERENCES db.charge_point(id),
    CONSTRAINT fk_meter_value_transactionId FOREIGN KEY (transactionId) REFERENCES db.transaction(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.meter_value IS 'Meter values.';

COMMENT ON COLUMN db.meter_value.Id IS 'Идентификатор.';
COMMENT ON COLUMN db.meter_value.chargePoint IS 'Зарядная станция.';
COMMENT ON COLUMN db.meter_value.connectorId IS 'Required. The id of the connector for which the status is reported. Id "0" (zero) is used if the status is for the Charge Point main controller.';
COMMENT ON COLUMN db.meter_value.transactionId IS 'Optional. The transaction to which these meter samples are related.';
COMMENT ON COLUMN db.meter_value.meterValue IS 'Required. The sampled meter values with timestamps.';
COMMENT ON COLUMN db.meter_value.ValidFromDate IS 'Дата начала периода действия';
COMMENT ON COLUMN db.meter_value.ValidToDate IS 'Дата окончания периода действия.';

--------------------------------------------------------------------------------

CREATE INDEX ON db.meter_value (chargePoint);
CREATE INDEX ON db.meter_value (connectorId);
CREATE INDEX ON db.meter_value (transactionId);
CREATE INDEX ON db.meter_value (chargePoint, ValidFromDate, ValidToDate);

CREATE UNIQUE INDEX ON db.meter_value (chargePoint, connectorId, ValidFromDate, ValidToDate);

--------------------------------------------------------------------------------
-- FUNCTION AddMeterValue ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddMeterValue (
  pChargePoint		numeric,
  pConnectorId		integer,
  pTransactionId	numeric,
  pMeterValue		json,
  pTimeStamp		timestamp default now()
) RETURNS 		    numeric
AS $$
DECLARE
  nId			    numeric;

  dtDateFrom 		timestamp;
  dtDateTo 		    timestamp;
BEGIN
  -- получим дату значения в текущем диапозоне дат
  SELECT max(ValidFromDate), max(ValidToDate) INTO dtDateFrom, dtDateTo
    FROM db.meter_value
   WHERE chargePoint = pChargePoint
     AND connectorId = pConnectorId
     AND ValidFromDate <= pTimeStamp
     AND ValidToDate > pTimeStamp;

  IF dtDateFrom = pTimeStamp THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.meter_value
       SET transactionId = pTransactionId,
           meterValue = pMeterValue
     WHERE chargePoint = pChargePoint
       AND connectorId = pConnectorId
       AND ValidFromDate <= pTimeStamp
       AND ValidToDate > pTimeStamp;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.meter_value SET ValidToDate = pTimeStamp
     WHERE chargePoint = pChargePoint
       AND connectorId = pConnectorId
       AND ValidFromDate <= pTimeStamp
       AND ValidToDate > pTimeStamp;

    INSERT INTO db.meter_value (chargePoint, connectorId, transactionId, meterValue, validfromdate, validtodate)
    VALUES (pChargePoint, pConnectorId, pTransactionId, pMeterValue, pTimeStamp, coalesce(dtDateTo, MAXDATE()))
    RETURNING id INTO nId;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW MeterValue -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MeterValue
AS
  SELECT * FROM db.meter_value;

GRANT SELECT ON MeterValue TO administrator;

--------------------------------------------------------------------------------
-- ChargePoint -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ChargePoint (Id, Reference, Identity, Name, Description,
  Model, Vendor, Version, SerialNumber, BoxSerialNumber, MeterSerialNumber,
  iccid, imsi
)
AS
  SELECT p.id, p.reference, r.code, r.name, r.description,
         p.model, p.vendor, p.version, p.serialnumber, p.boxserialnumber, p.meterserialnumber,
         p.iccid, p.imsi
    FROM db.charge_point p INNER JOIN db.reference r ON r.id = p.reference;

GRANT SELECT ON ChargePoint TO administrator;

--------------------------------------------------------------------------------
-- ObjectChargePoint -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectChargePoint (Id, Object, Parent,
  Essence, EssenceCode, EssenceName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Identity, Name, Label, Description,
  Model, Vendor, Version, SerialNumber, BoxSerialNumber, MeterSerialNumber,
  iccid, imsi,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate
)
AS
  SELECT p.id, r.object, r.parent,
         r.essence, r.essencecode, r.essencename,
         r.class, r.classcode, r.classlabel,
         r.type, r.typecode, r.typename, r.typedescription,
         r.code, r.name, r.label, r.description,
         p.model, p.vendor, p.version, p.serialnumber, p.boxserialnumber, p.meterserialnumber,
         p.iccid, p.imsi,
         r.statetype, r.statetypecode, r.statetypename,
         r.state, r.statecode, r.statelabel, r.lastupdate,
         r.owner, r.ownercode, r.ownername, r.created,
         r.oper, r.opercode, r.opername, r.operdate
    FROM db.charge_point p INNER JOIN ObjectReference r ON r.id = p.reference;

GRANT SELECT ON ObjectChargePoint TO administrator;
