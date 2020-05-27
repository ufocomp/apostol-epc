--------------------------------------------------------------------------------
-- CUSTOMER SECURITY -----------------------------------------------------------
--------------------------------------------------------------------------------

INSERT INTO db.interface (sid, name, description) VALUES ('I:1:0:0', 'Все', 'Интерфейс для всех');
INSERT INTO db.interface (sid, name, description) VALUES ('I:1:0:1', 'Администраторы', 'Интерфейс для администраторов');
INSERT INTO db.interface (sid, name, description) VALUES ('I:1:0:2', 'Операторы', 'Интерфейс для операторов системы');
INSERT INTO db.interface (sid, name, description) VALUES ('I:1:0:3', 'Пользователи', 'Интерфейс для пользователей');

SELECT CreateArea(null, GetAreaType('all'), 'all', 'Все');
SELECT CreateArea(GetArea('all'), GetAreaType('default'), 'default', 'По умолчанию');

SELECT AddMemberToInterface(CreateGroup('administrator', 'Администраторы', 'Группа для администраторов системы'), GetInterface('I:1:0:1'));
SELECT AddMemberToInterface(CreateGroup('operator', 'Операторы', 'Группа для операторов системы'), GetInterface('I:1:0:2'));
SELECT AddMemberToInterface(CreateGroup('user', 'Пользователи', 'Группа для пользователей системы'), GetInterface('I:1:0:3'));

SELECT AddMemberToGroup(CreateUser('admin', 'admin', 'Администратор', null,null, 'Администратор системы', true, false, GetArea('all')), GetGroup('administrator'));

SELECT CreateUser('daemon', 'daemon', 'Демон', null, null, 'Пользователь для API');
SELECT CreateUser('apibot', 'apibot', 'Системная служба API', null, null, 'API клиент');
SELECT CreateUser('mailbot', 'mailbot', 'Почтовый клиент', null, null, 'Почтовый клиент');
SELECT CreateUser('ocpp', 'ocpp', 'Системная служба OCPP', null, null, 'OCPP клиент');

SELECT AddMemberToArea(GetUser('admin'), GetArea('default'));
SELECT AddMemberToArea(GetUser('apibot'), GetArea('default'));
SELECT AddMemberToArea(GetUser('mailbot'), GetArea('default'));
SELECT AddMemberToArea(GetUser('ocpp'), GetArea('default'));
