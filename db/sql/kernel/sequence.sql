-- Последовательность для двенадцатизначных идентификаторов.
CREATE SEQUENCE IF NOT EXISTS SEQUENCE_REF
 START WITH 100000000000
 INCREMENT BY 1
 MINVALUE 100000000000
 MAXVALUE 999999999999;

-- Последовательность для идентификаторов объектов.
CREATE SEQUENCE IF NOT EXISTS SEQUENCE_ID
 START WITH 1
 INCREMENT BY 1
 MINVALUE 1;

-- Последовательность для идентификаторов пользователей и групп.
CREATE SEQUENCE IF NOT EXISTS SEQUENCE_USER
 START WITH 1000
 INCREMENT BY 1
 MINVALUE 1000;

-- Последовательность для идентификаторов реестра.
CREATE SEQUENCE IF NOT EXISTS SEQUENCE_REGISTER
 START WITH 1
 INCREMENT BY 1
 MINVALUE 1;

-- Последовательность для идентификаторов справочника адресов.
CREATE SEQUENCE IF NOT EXISTS SEQUENCE_ADDRESS
 START WITH 1
 INCREMENT BY 1
 MINVALUE 1;

-- Последовательность для идентификаторов журнала событий.
CREATE SEQUENCE IF NOT EXISTS SEQUENCE_LOG
 START WITH 1
 INCREMENT BY 1
 MINVALUE 1;

-- Последовательность для идентификаторов журнала API.
CREATE SEQUENCE IF NOT EXISTS SEQUENCE_API_LOG
 START WITH 1
 INCREMENT BY 1
 MINVALUE 1;

-- Последовательность для идентификаторов журнала событий OCPP.
CREATE SEQUENCE IF NOT EXISTS SEQUENCE_OCPP_LOG
 START WITH 1
 INCREMENT BY 1
 MINVALUE 1;

-- Последовательность для идентификаторов статусов OCPP.
CREATE SEQUENCE IF NOT EXISTS SEQUENCE_OCPP_STATUS
 START WITH 1
 INCREMENT BY 1
 MINVALUE 1;

-- Последовательность для идентификаторов транзакций OCPP.
CREATE SEQUENCE IF NOT EXISTS SEQUENCE_OCPP_TRANSACTION
 START WITH 1
 INCREMENT BY 1
 MINVALUE 1;
