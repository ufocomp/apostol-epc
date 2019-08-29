-- Последовательность для двенадцатизначных идентификаторов.
CREATE SEQUENCE IF NOT EXISTS SEQUENCE_REF
 START WITH 100000000000
 INCREMENT BY 1
 MINVALUE 100000000000
 MAXVALUE 999999999999;

-- Последовательность для идентификаторов.
CREATE SEQUENCE IF NOT EXISTS SEQUENCE_ID
 START WITH 1
 INCREMENT BY 1
 MINVALUE 1;

CREATE SEQUENCE IF NOT EXISTS SEQUENCE_LOG
 START WITH 1
 INCREMENT BY 1
 MINVALUE 1;

CREATE SEQUENCE IF NOT EXISTS SEQUENCE_EVENTLOG
 START WITH 1
 INCREMENT BY 1
 MINVALUE 1;

CREATE SEQUENCE IF NOT EXISTS SEQUENCE_APILOG
 START WITH 1
 INCREMENT BY 1
 MINVALUE 1;

CREATE SEQUENCE IF NOT EXISTS SEQUENCE_REGISTER
 START WITH 1
 INCREMENT BY 1
 MINVALUE 1;
