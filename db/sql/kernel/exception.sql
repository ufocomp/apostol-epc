CREATE OR REPLACE FUNCTION LoginFailed() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Не выполнен вход в систему.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION LoginError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Вход в систему невозможен. Проверьте правильность имени пользователя и повторите ввод пароля.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION UserLockError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Вход в систему невозможен. Учетная запись заблокирована.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION PasswordExpiryError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Вход в систему невозможен. Истек срок действия пароля.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION SessionLoginError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Вход в систему по ключу сессии невозможен. Ключ не прошёл проверку.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION AccessDenied() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Недостаточно прав для выполнения данной операции.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION AccessDenied (
  pMessage	text
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Недостаточно прав для выполнения %.', pMessage;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION AccessDeniedForUser (
  pUserName	text
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Для пользователя "%" данное действие запрещено.', pUserName;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION UserObjectError (
  pUserName	text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Запрещены операции с документами, для пользователя "%".', pUserName;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION AbstractError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'У абстрактного класса не может быть объектов.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION ChangeClassError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Недопустимо изменение класса объекта.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION ChangeAreaError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Недопустимо изменение подразделения документа.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectEssence() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Неверно задана сущность объекта.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectClassType() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Неверно задан тип объекта.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectDocumentType() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Неверно задан тип документа.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION ClientNameIsNull() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Наименование клиента не должно быть пустым.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectLanguageCode (
  pCode		varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Не найден идентификатор языка по коду: %.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION RootAreaError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Запрещены операции с документами в корневом подразделении.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION AreaError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Не найдено подразделение с указанным идентификатором.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectAreaCode (
  pCode		varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Не найдено подразделение с кодом: %.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION UserNotMemberArea (
  pUser		varchar,
  pArea	    varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Пользователь "%" не является членом подразделения "%".', pUser, pArea;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION InterfaceError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Не найдено рабочее место с указанным идентификатором.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION UserNotMemberInterface (
  pUser		    varchar,
  pInterface	varchar
) RETURNS	    void
AS $$
BEGIN
  RAISE EXCEPTION 'Пользователь "%" не является членом рабочего места "%".', pUser, pInterface;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION UnknownRoleName (
  pRoleName	varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Группа "%" не существует.', pRoleName;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION RoleExists (
  pRoleName	varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Роль "%" уже существует.', pRoleName;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION UserNotFound (
  pUserName	varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Пользователь "%" не существует.', pUserName;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION UserNotFound (
  pId		numeric
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Пользователь с идентификатором "%" не существует.', pId;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION DeleteUserError() RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Нельзя удалить самого себя.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION ClientCodeExists (
  pCode		varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Клиент с кодом "%" уже существует.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION CardCodeExists (
  pCode		varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Карта с кодом "%" уже существует.', pCode;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION AlreadyExists (
  pWho		varchar
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '% уже существует.', pWho;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectKeyInArray (
  pKey		varchar,
  pArrayName	varchar,
  pArray	anyarray
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Недопустимый ключ "%" в массиве "%". Допустимые ключи: %.', pKey, pArrayName, pArray;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectValueInArray (
  pValue	varchar,
  pArrayName	varchar,
  pArray	anyarray
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Недопустимое значение "%" в массиве "%". Допустимые значения: %.', pValue, pArrayName, pArray;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectCode (
  pCode		varchar,
  pArray	anyarray
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Недопустимый код "%". Допустимые коды: %.', pCode, pArray;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION ObjectNotFound (
  pWho		varchar,
  pParam	varchar,
  pId		numeric
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Не найден(а) % с идентификатором: % (%).', pWho, pId, pParam;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION MethodActionNotFound (
  pObject	numeric,
  pAction	numeric
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Не найден метод объекта "%", для действия: "%" (%).', pObject, pAction, GetActionCode(pAction);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION MethodNotFound (
  pObject	numeric,
  pMethod	numeric
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Не найден метод % объекта "%".', pMethod, pObject;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION ChangeObjectStateError (
  pObject	numeric
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Не удалось изменить состояние объекта: %.', pObject;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION RouteIsEmpty (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Путь не должен быть пустым.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION RouteNotFound (
  pRoute	text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Не найден путь: "%".', pRoute;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION JsonIsEmpty (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'JSON не должен быть пустым';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectJsonKey (
  pRoute	text,
  pKey		text,
  pArray	anyarray
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '[%] Недопустимый ключ "%" в JSON. Допустимые ключи: %.', pRoute, pKey, pArray;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION JsonKeyNotFound (
  pRoute	text,
  pKey		text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION '[%] Не найден обязательный ключ "%" в JSON.', pRoute, pKey;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectJsonType (
  pType		text,
  pExpected	text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Неверный тип JSON "%", ожидается "%".', pType, pExpected;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION MethodIsEmpty (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Идентификатор метода не должен быть пустым';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION ActionIsEmpty (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Идентификатор действия не должен быть пустым';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION ExecutorIsEmpty (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Исполнитель не должен быть пустым';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectDateInterval (
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Дата окончания периода не может быть меньше даты начала периода.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION UserPasswordChange (
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Не удалось изменить пароль, установлен запрет на изменение пароля.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION SystemRoleError (
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Операции изменения, удаления для системных ролей запрещены.';
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION CacheTableNotFound (
  pTable	text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION ' найдена таблица %.', pTable;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION LoginIpTableError (
  pHost		inet
) RETURNS void
AS $$
BEGIN
  RAISE EXCEPTION 'Вход в систему невозможен. Ограничен доступ по IP-адресу: %', host(pHost);
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION IncorrectRegisterKey (
  pKey		text,
  pArray	anyarray
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'РЕЕСТР: Недопустимый ключ "%". Допустимые ключи: %.', pKey, pArray;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION ActionNotFound -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ActionNotFound (
  pAction	text
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'OCPP: Неопределенное действие: "%".', pAction;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION UnknownTransaction -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION UnknownTransaction (
  pId		numeric
) RETURNS	void
AS $$
BEGIN
  RAISE EXCEPTION 'Неизвестная транзакия: "%".', pId;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;
