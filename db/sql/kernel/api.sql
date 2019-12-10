--------------------------------------------------------------------------------
-- API -------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- SESSION ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.login -------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Вход в систему по имени и паролю пользователя.
 * @param {text} pUserName - Пользователь (login)
 * @param {text} pPassword - Пароль
 * @param {inet} pHost - IP адрес
 * @out param {text} session - Ключ сессии
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.login (
  pUserName	text,
  pPassword	text,
  pHost		inet default null,
  OUT session	text,
  OUT result	boolean,
  OUT message	text
) RETURNS	record
AS $$
BEGIN
  session := Login(pUserName, pPassword, pHost);
  result := session IS NOT NULL;
  message := GetErrorMessage();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.slogin ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Вход в систему по ключу сессии.
 * @param {text} pSession - Ключ сессии
 * @param {inet} pHost - IP адрес
 * @out param {text} session - Ключ сессии
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.slogin (
  pSession	text,
  pHost		inet default null,
  OUT session	text,
  OUT result	boolean,
  OUT message	text
) RETURNS	record
AS $$
BEGIN
  session := pSession;
  result := SessionLogin(pSession, pHost);
  message := GetErrorMessage();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.logout ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выход из системы.
 * @param {text} pSession - Ключ сессии
 * @param {boolean} pLogoutAll - Закрыть все сессии
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.logout (
  pSession	text default current_session(),
  pLogoutAll	boolean default false,
  OUT result	boolean,
  OUT message	text
) RETURNS	record
AS $$
BEGIN
  result := Logout(pSession, pLogoutAll);
  message := GetErrorMessage();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.su ----------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Substitute user.
 * Меняет текущего пользователя в активном сеансе на указанного пользователя
 * @param {text} pUserName - Имя пользователь для подстановки
 * @param {text} pPassword - Пароль текущего пользователя
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.su (
  pUserName	text,
  pPassword	text,
  OUT result	boolean,
  OUT message	text
) RETURNS	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM SubstituteUser(pUserName, pPassword);
  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.whoami ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает информацию о виртуальном пользователе.
 * @out param {numeric} userid - Идентификатор виртуального пользователя
 * @out param {varchar} username - Имя виртуального пользователя (login)
 * @out param {text} fullname - Ф.И.О. виртуального пользователя
 * @out param {text} email - Электронный адрес виртуального пользователя
 * @out param {numeric} session_userid - Идентификатор учётной записи виртуального пользователя сессии
 * @out param {varchar} session_username - Имя виртуального пользователя сессии (login)
 * @out param {text} session_fullname - Ф.И.О. виртуального пользователя сессии
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.whoami (
  OUT userid		numeric,
  OUT username		varchar,
  OUT fullname		text,
  OUT email		text,
  OUT session_userid	numeric,
  OUT session_username	varchar,
  OUT session_fullname	text,
  OUT department	numeric,
  OUT department_code	varchar,
  OUT department_name	varchar,
  OUT workplace		numeric,
  OUT workplace_sid	varchar,
  OUT workplace_name	varchar
) RETURNS		SETOF record
AS $$
  WITH cs AS (
      SELECT current_session() AS session
  )
  SELECT s.userid, cu.username, cu.fullname, cu.email,
         s.suid, su.username, su.fullname,
         s.department, d.code, d.name,
         s.workplace, w.sid, w.name
    FROM db.session s INNER JOIN cs ON cs.session = s.key 
                      INNER JOIN users cu ON cu.id = s.userid
                      INNER JOIN users su ON su.id = s.suid
                      INNER JOIN department d ON d.id = s.department
                      INNER JOIN workplace w ON w.id = s.workplace
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.current_session ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает текущую сессии.
 * @return {session} - Сессия
 */
CREATE OR REPLACE FUNCTION api.current_session()
RETURNS	session
AS $$
  SELECT * FROM session WHERE key = current_session()
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.current_user ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает учётную запись текущего пользователя.
 * @return {users} - Учётная запись пользователя
 */
CREATE OR REPLACE FUNCTION api.current_user (
) RETURNS	users
AS $$
  SELECT * FROM users WHERE id = current_userid()
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.current_userid ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор авторизированного пользователя.
 * @return {numeric} - Идентификатор пользователя: users.id
 */
CREATE OR REPLACE FUNCTION api.current_userid()
RETURNS 	numeric
AS $$
BEGIN
  RETURN current_userid();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.current_username --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает имя авторизированного пользователя.
 * @return {text} - Имя (username) пользователя: users.username
 */
CREATE OR REPLACE FUNCTION api.current_username()
RETURNS 	text
AS $$
BEGIN
  RETURN current_username();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.current_department ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает данные текущего подразделения.
 * @return {department} - Подразделение
 */
CREATE OR REPLACE FUNCTION api.current_department (
) RETURNS	department
AS $$
  SELECT * FROM department WHERE id = current_department();
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_department ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает подразделение.
 * @param {numeric} pDepartment - Идентификатор подразделения
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_department (
  pDepartment	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM SetDepartment(pDepartment);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.current_workplace -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает данные текущего рабочего места.
 * @return {workplace} - Рабочее место
 */
CREATE OR REPLACE FUNCTION api.current_workplace (
) RETURNS 	workplace
AS $$
  SELECT * FROM workplace WHERE id = current_workplace();
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_workplace -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает рабочее место.
 * @param {numeric} pWorkPlace - Идентификатор рабочего места
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_workplace (
  pWorkPlace	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM SetWorkPlace(pWorkPlace);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.operdate ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает дату операционного дня.
 * @return {timestamp} - Дата операционного дня
 */
CREATE OR REPLACE FUNCTION api.operdate()
RETURNS 	timestamp
AS $$
BEGIN
  RETURN oper_date();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_operdate ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает дату операционного дня.
 * @param {timestamp} pOperDate - Дата операционного дня
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_operdate (
  pOperDate 	timestamp,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM SetOperDate(pOperDate);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_operdate ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает дату операционного дня.
 * @param {timestamptz} pOperDate - Дата операционного дня
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_operdate (
  pOperDate 	timestamptz,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM SetOperDate(pOperDate);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.current_language --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает данные текущего языка.
 * @return {language} - Язык
 */
CREATE OR REPLACE FUNCTION api.current_language (
) RETURNS 	language
AS $$
  SELECT * FROM language WHERE id = current_language();
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_language ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает по идентификатору текущий язык.
 * @param {numeric} pLang - Идентификатор языка
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_language (
  pLang		numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM SetLanguage(pLang);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_language ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает по идентификатору текущий язык.
 * @param {text} pCode - Код языка
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_language (
  pCode 	text default 'ru',
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM SetLanguage(pCode);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EVENTLOG --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.eventlog
AS
  SELECT e.*, coalesce(u.fullname, e.username) as fullname, u.email, u.description
    FROM EventLog e LEFT JOIN users u ON u.username = e.username;

GRANT SELECT ON api.eventlog TO daemon;

--------------------------------------------------------------------------------
-- api.eventlog ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Журнал событий.
 * @param {numeric} pObject - Идентификатор объекта
 * @param {char} pType - Тип события: {M|W|E}
 * @param {varchar} pUserName - Имя пользователя (логин)
 * @param {integer} pCode - Код
 * @param {timestamp} pDateFrom - Дата начала периода
 * @param {timestamp} pDateTo - Дата окончания периода
 * @return {SETOF VEventLog} - Записи
 */
CREATE OR REPLACE FUNCTION api.eventlog (
  pObject	numeric default null,
  pType		char default null,
  pUserName	varchar default null,
  pCode		numeric default null,
  pDateFrom	timestamp default null,
  pDateTo	timestamp default null
) RETURNS	SETOF api.eventlog
AS $$
  SELECT *
    FROM api.eventlog
   WHERE coalesce(object, 0) = coalesce(pObject, object, 0)
     AND type = coalesce(pType, type)
     AND username = coalesce(pUserName, username)
     AND code = coalesce(pCode, code)
     AND datetime >= coalesce(pDateFrom, MINDATE())
     AND datetime < coalesce(pDateTo, MAXDATE())
   ORDER BY datetime DESC, id
   LIMIT 500
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.write_to_event_log ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.write_to_event_log (
  pObject	numeric,
  pType		text,
  pCode		numeric,
  pText		text,
  OUT result	boolean,
  OUT error	text
) RETURNS	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM WriteToEventLog(pObject, pType, pCode, pText);

  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- USER ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.add_user ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт учётную запись пользователя.
 * @param {varchar} pUserName - Пользователь
 * @param {text} pPassword - Пароль
 * @param {text} pFullName - Полное имя
 * @param {text} pPhone - Телефон
 * @param {text} pEmail - Электронный адрес
 * @param {text} pDescription - Описание
 * @param {text[]} pGroups - Группа: ARRAY['Строковый идентификатор группы', ...]
 * @out param {numeric} id - Id учётной записи
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_user (
  pUserName	varchar,
  pPassword	text,
  pFullName	text,
  pPhone	text default null,
  pEmail	text default null,
  pDescription	text default null,
  pGroups	text[] default null,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := CreateUser(pUserName, pPassword, pFullName, pPhone, pEmail, pDescription, pGroups);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.upd_user ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет учётную запись пользователя.
 * @param {numeric} pId - Идентификатор учетной записи
 * @param {varchar} pUserName - Пользователь
 * @param {text} pPassword - Пароль
 * @param {text} pFullName - Полное имя
 * @param {text} pPhone - Телефон
 * @param {text} pEmail - Электронный адрес
 * @param {text} pDescription - Описание
 * @param {boolean} pPasswordChange - Сменить пароль при следующем входе в систему
 * @param {boolean} pPasswordNotChange - Установить запрет на смену пароля самим пользователем
 * @out {numeric} id - Идентификатор учетной записи
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.upd_user (
  pId			numeric,
  pUserName		varchar,
  pPassword		text,
  pFullName		text,
  pPhone		text,
  pEmail		text,
  pDescription		text,
  pPasswordChange 	boolean,
  pPasswordNotChange	boolean,
  OUT id		numeric,
  OUT result		boolean,
  OUT error		text
) RETURNS 		record
AS $$
BEGIN
  id := pId;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM UpdateUser(pId, pUserName, pPassword, pFullName, pPhone, pEmail, pDescription, pPasswordChange, pPasswordNotChange);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.del_user ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет учётную запись пользователя.
 * @param {numeric} pId - Идентификатор учётной записи пользователя
 * @out {numeric} id - Идентификатор учётной записи пользователя
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_user (
  pId		numeric,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  id := pId;
 
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteUser(pId);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_user ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает учётную запись пользователя.
 * @return {SETOF users} - Учётная запись пользователя
 */
CREATE OR REPLACE FUNCTION api.get_user (
  pId		numeric default current_userid()
) RETURNS	SETOF users
AS $$
DECLARE
  r		users%rowtype;
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  FOR r IN SELECT * FROM users WHERE id = pId
  LOOP
    RETURN NEXT r;
  END LOOP;

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.lst_user ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает учётные записи пользователей.
 * @return {SETOF users} - Учётные записи пользователей
 */
CREATE OR REPLACE FUNCTION api.lst_user (
  pId		numeric default null
) RETURNS	SETOF users
AS $$
DECLARE
  r		users%rowtype;
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole('administrator') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  FOR r IN SELECT * FROM users WHERE id = coalesce(pId, id)
  LOOP
    RETURN NEXT r;
  END LOOP;

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.change_password ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает пароль пользователя.
 * @param {numeric} pId - Идентификатор учетной записи
 * @param {text} pOldPass - Старый пароль
 * @param {text} pNewPass - Новый пароль
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.change_password (
  pId			numeric,
  pOldPass		text,
  pNewPass		text,
  OUT result		boolean,
  OUT error		text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  result := CheckPassword(GetUserName(pId), pOldPass);
  error := GetErrorMessage();

  IF result THEN
    PERFORM SetPassword(pId, pNewPass);
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.user_member -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список групп пользователя.
 * @return {record} - Группы
 */
CREATE OR REPLACE FUNCTION api.user_member (
  pUserId		numeric default current_userid(),
  OUT id		numeric,
  OUT username		varchar,
  OUT fullname		text,
  OUT description       text
) RETURNS		SETOF record
AS $$
  SELECT g.id, g.username, g.fullname, g.description
    FROM db.member_group m INNER JOIN groups g ON g.id = m.userid
   WHERE member = pUserId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_user -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список групп пользователя.
 * @return {record} - Группы
 */
CREATE OR REPLACE FUNCTION api.member_user (
  pUserId		numeric default current_userid(),
  OUT id		numeric,
  OUT username		varchar,
  OUT fullname		text,
  OUT description       text
) RETURNS		SETOF record
AS $$
  SELECT * FROM api.user_member(pUserId);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.user_lock ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Блокирует учётную запись пользователя.
 * @param {numeric} pId - Идентификатор учётной записи пользователя
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки/результата
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.user_lock (
  pId		numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
DECLARE
  nId		numeric;
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM UserLock(pId);

  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.user_unlock -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Снимает блокировку с учётной записи пользователя.
 * @param {numeric} pId - Идентификатор учётной записи пользователя
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки/результата
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.user_unlock (
  pId			numeric,
  OUT result		boolean,
  OUT error		text
) RETURNS 		record
AS $$
DECLARE
  nId		numeric;
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM UserUnlock(pId);

  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_user_iptable --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает таблицу IP-адресов в виде одной строки.
 * @param {numeric} pId - Идентификатор учётной записи пользователя
 * @param {char} pType - Тип: A - allow; D - denied'
 * @out param {numeric} id - Идентификатор учётной записи пользователя
 * @out param {char} type - Тип: A - allow; D - denied'
 * @out param {text} iptable - IP-адреса в виде одной строки
 * @return {text}
 */
CREATE OR REPLACE FUNCTION api.get_user_iptable (
  pId			numeric,
  pType			char,
  OUT id		numeric,
  OUT type		char,
  OUT iptable		text
) RETURNS 		record
AS $$
  SELECT pId, pType, GetIPTableStr(pId, pType) WHERE current_session() IS NOT NULL;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_user_iptable --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает таблицу IP-адресов из строки.
 * @param {numeric} pId - Идентификатор учётной записи пользователя
 * @param {char} pType - Тип: A - allow; D - denied'
 * @param {text} pIpTable - IP-адреса в виде одной строки
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки/результата
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_user_iptable (
  pId			numeric,
  pType			char,
  pIpTable		text,
  OUT result		boolean,
  OUT error		text
) RETURNS 		record
AS $$
DECLARE
  nId		numeric;
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM SetIPTableStr(pId, pType, pIpTable);

  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GROUP -----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.add_group ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт группу учётных записей пользователя.
 * @param {varchar} pGroupName - Группа
 * @param {text} pFullName - Полное имя
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Id учётной записи
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_group (
  pGroupName	varchar,
  pFullName	text,
  pDescription	text default null,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := CreateGroup(pGroupName, pFullName, pDescription);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.upd_group ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет учётные данные группы.
 * @param {numeric} pId - Идентификатор группы
 * @param {varchar} pGroupName - Группа
 * @param {text} pFullName - Полное имя
 * @param {text} pDescription - Описание
 * @out {numeric} id - Идентификатор группы
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.upd_group (
  pId			numeric,
  pGroupName		varchar,
  pFullName		text,
  pDescription		text,
  OUT id		numeric,
  OUT result		boolean,
  OUT error		text
) RETURNS 		record
AS $$
BEGIN
  id := pId;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM UpdateGroup(pId, pGroupName, pFullName, pDescription);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.del_group ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет группу.
 * @param {numeric} pId - Идентификатор группы
 * @out {numeric} id - Идентификатор группы
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_group (
  pId		numeric,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  id := pId;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteGroup(pId);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_group ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает группу.
 * @return {record} - Группа
 */
CREATE OR REPLACE FUNCTION api.get_group (
  pId			numeric,
  OUT id		numeric,
  OUT username		varchar,
  OUT fullname		text,
  OUT description       text
) RETURNS		record
AS $$
  SELECT id, username, fullname, description 
    FROM groups 
   WHERE id = pId
     AND current_session() IS NOT NULL;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.lst_group ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список групп.
 * @return {record} - Группы
 */
CREATE OR REPLACE FUNCTION api.lst_group (
  OUT id		numeric,
  OUT username		varchar,
  OUT fullname		text,
  OUT description       text
) RETURNS		SETOF record
AS $$
  SELECT id, username, fullname, description 
    FROM groups
   WHERE current_session() IS NOT NULL;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_group_add --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет пользователя в группу.
 * @param {numeric} pMember - Идентификатор пользователя
 * @param {numeric} pGroup - Идентификатор группы
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.member_group_add (
  pMember		numeric,
  pGroup		numeric,
  OUT result		boolean,
  OUT error		text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM AddMemberToGroup(pMember, pGroup);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_group_del --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет группу для пользователя.
 * @param {numeric} pMember - Идентификатор пользователя
 * @param {numeric} pGroup - Идентификатор группы, при null удаляет все группы для указанного пользователя
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.member_group_del (
  pMember		numeric,
  pGroup		numeric,
  OUT result		boolean,
  OUT error		text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteGroupForMember(pMember, pGroup);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.group_member_del --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет пользователя из группу.
 * @param {numeric} pGroup - Идентификатор группы
 * @param {numeric} pMember - Идентификатор пользователя, при null удаляет всех пользователей из указанной группы
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.group_member_del (
  pGroup		numeric,
  pMember		numeric default null,
  OUT result		boolean,
  OUT error		text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteMemberFromGroup(pGroup, pMember);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_group ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.member_group
AS
  SELECT * FROM MemberGroup;

GRANT SELECT ON api.member_group TO daemon;

--------------------------------------------------------------------------------
-- api.group_member ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список пользователей группы.
 * @return {SETOF record} - Группы
 */
CREATE OR REPLACE FUNCTION api.group_member (
  pGroupId		numeric,
  OUT id		numeric,
  OUT username		varchar,
  OUT fullname		text,
  OUT email		text,
  OUT status		text,
  OUT description       text
) RETURNS		SETOF record
AS $$
  SELECT u.id, u.username, u.fullname, u.email, u.status, u.description
    FROM db.member_group m INNER JOIN users u ON u.id = m.member
   WHERE m.userid = pGroupId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_group ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список групп пользователя.
 * @return {record} - Группы
 */
CREATE OR REPLACE FUNCTION api.member_group (
  pUserId		numeric default current_userid(),
  OUT id		numeric,
  OUT username		varchar,
  OUT fullname		text,
  OUT description       text
) RETURNS		SETOF record
AS $$
  SELECT * FROM api.member_user(pUserId)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.is_user_role ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.is_user_role (
  pRole			numeric,
  pUser			numeric default current_userid(),
  OUT result		boolean,
  OUT error		text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  error := 'Успешно.';
  result := IsUserRole(pRole, pUser);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.is_user_role ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.is_user_role (
  pRole			text,
  pUser			text default session_username(),
  OUT result		boolean,
  OUT error		text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  error := 'Успешно.';
  result := IsUserRole(pRole, pUser);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DEPARTMENT ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.department_type
AS
  SELECT * FROM DepartmentType;

GRANT SELECT ON api.department_type TO daemon;

--------------------------------------------------------------------------------
-- api.get_department_type -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Позвращает тип подразделения.
 * @param {numeric} pId - Идентификатор типа подразделения
 * @return {record} - Запись
 */
CREATE OR REPLACE FUNCTION api.get_department_type (
  pId		numeric,
  OUT id	numeric,
  OUT code	varchar,
  OUT name	varchar
) RETURNS	record
AS $$
  SELECT id, code, name
    FROM api.department_type
   WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.department
AS
  SELECT * FROM Department;

GRANT SELECT ON api.department TO daemon;

--------------------------------------------------------------------------------
-- api.add_department ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт подразделение.
 * @param {numeric} pParent - Идентификатор "родителя"
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Id подразделения
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_department (
  pParent	numeric,
  pType		numeric,
  pCode		varchar,
  pName		varchar,
  pDescription	text default null,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := CreateDepartment(pParent, pType, pCode, pName, pDescription);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.upd_department ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет подразделение.
 * @param {numeric} pId - Идентификатор подразделения
 * @param {numeric} pParent - Идентификатор "родителя"
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @param {timestamptz} pValidFromDate - Дата открытия
 * @param {timestamptz} pValidToDate - Дата закрытия
 * @out param {numeric} id - Id подразделения
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.upd_department (
  pId			numeric,
  pParent		numeric default null,
  pType			numeric default null,
  pCode			varchar default null,
  pName			varchar default null,
  pDescription		text default null,
  pValidFromDate	timestamptz default null,
  pValidToDate		timestamptz default null,
  OUT id		numeric,
  OUT result		boolean,
  OUT error		text
) RETURNS 		record
AS $$
BEGIN
  id := pId;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM EditDepartment(pId, pParent, pType, pCode, pName, pDescription, pValidFromDate, pValidToDate);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.del_department ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет подразделение.
 * @param {numeric} pId - Идентификатор подразделения
 * @out {numeric} id - Идентификатор подразделения
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_department (
  pId		numeric,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  id := pId;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteDepartment(pId);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.lst_department ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список подразделений.
 * @return {record} - Группы
 */
CREATE OR REPLACE FUNCTION api.lst_department (
  OUT id		numeric,
  OUT type		numeric,
  OUT typecode		varchar,
  OUT typename		varchar,
  OUT code		varchar,
  OUT name		varchar,
  OUT description       text,
  OUT validfromdate	timestamp,
  OUT validtodate	timestamp
) RETURNS		SETOF record
AS $$
  SELECT id, type, typecode, typename, code, name, description, validfromdate, validtodate 
    FROM api.department;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_department ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает данные подразделения.
 * @return {record} - Данные подразделения
 */
CREATE OR REPLACE FUNCTION api.get_department (
  pId			numeric,
  OUT id		numeric,
  OUT type		numeric,
  OUT typecode		varchar,
  OUT typename		varchar,
  OUT code		varchar,
  OUT name		varchar,
  OUT description       text,
  OUT validfromdate	timestamp,
  OUT validtodate	timestamp
) RETURNS		record
AS $$
  SELECT id, type, typecode, typename, code, name, description, validfromdate, validtodate 
    FROM api.department
   WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_department_add ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет пользователя или группу в подразделение.
 * @param {numeric} pMember - Идентификатор пользователя/группы
 * @param {numeric} pDepartment - Идентификатор подразделения
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.member_department_add (
  pMember		numeric,
  pDepartment		numeric,
  OUT result		boolean,
  OUT error		text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM AddMemberToDepartment(pMember, pDepartment);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_department_del ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет подразделение для пользователя.
 * @param {numeric} pMember - Идентификатор пользователя
 * @param {numeric} pDepartment - Идентификатор подразделения, при null удаляет все подразделения для указанного пользователя
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.member_department_del (
  pMember		numeric,
  pDepartment		numeric,
  OUT result		boolean,
  OUT error		text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteDepartmentForMember(pMember, pDepartment);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.department_member_del ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет пользователя из подразделения.
 * @param {numeric} pDepartment - Идентификатор подразделения
 * @param {numeric} pMember - Идентификатор пользователя, при null удаляет всех пользователей из указанного подразделения
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.department_member_del (
  pDepartment		numeric,
  pMember		numeric default null,
  OUT result		boolean,
  OUT error		text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteMemberFromDepartment(pDepartment, pMember);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW api.member_department --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.member_department
AS
  SELECT * FROM MemberDepartment;

GRANT SELECT ON api.member_department TO daemon;

--------------------------------------------------------------------------------
-- api.department_member -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список участников подразделения.
 * @return {SETOF record} - Запись
 */
CREATE OR REPLACE FUNCTION api.department_member (
  pDepartmentId		numeric,
  OUT id		numeric,
  OUT type		char,
  OUT username		varchar,
  OUT fullname		text,
  OUT email		text,
  OUT description       text,
  OUT status		text,
  OUT system		text
) RETURNS		SETOF record
AS $$
  SELECT g.id, 'G' AS type, g.username, g.fullname, null AS email, g.description, null AS status, g.system
    FROM api.member_department m INNER JOIN groups g ON g.id = m.memberid
   WHERE m.department = pDepartmentId
     AND current_session() IS NOT NULL
  UNION ALL
  SELECT u.id, 'U' AS type, u.username, u.fullname, u.email, u.description, u.status, u.system
    FROM api.member_department m INNER JOIN users u ON u.id = m.memberid
   WHERE m.department = pDepartmentId
     AND current_session() IS NOT NULL;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_department -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает подразделения доступные участнику.
 * @return {record} - Данные подразделения
 */
CREATE OR REPLACE FUNCTION api.member_department (
  pUserId		numeric default current_userid(),
  OUT id		numeric,
  OUT code		varchar,
  OUT name		varchar,
  OUT description       text
) RETURNS		SETOF record
AS $$
  SELECT id, code, name, description
    FROM api.department
   WHERE id in (
     SELECT department FROM db.member_department WHERE member = (
       SELECT id FROM db.user WHERE id = pUserId
     )
   )
   UNION ALL
  SELECT id, code, name, description
    FROM api.department
   WHERE id in (
     SELECT department FROM db.member_department WHERE member IN (
       SELECT userid FROM db.member_group WHERE member = (
         SELECT id FROM db.user WHERE id = pUserId
       )
     )
   )
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- WORKPLACE -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.workplace
AS
  SELECT * FROM WorkPlace;

GRANT SELECT ON api.workplace TO daemon;

--------------------------------------------------------------------------------
-- api.add_workplace -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт рабочее место.
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Идентификатор рабочего места
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_workplace (
  pName		varchar,
  pDescription	text default null,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := CreateWorkPlace(pName, pDescription);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.upd_workplace -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет рабочее место.
 * @param {numeric} pId - Идентификатор рабочего места
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Идентификатор рабочего места
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.upd_workplace (
  pId		numeric,
  pName		varchar,
  pDescription	text default null,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  id := pId;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM UpdateWorkPlace(pId, pName, pDescription);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.del_workplace -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет рабочее место.
 * @param {numeric} pId - Идентификатор рабочего места
 * @out {numeric} id - Идентификатор рабочего места
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_workplace (
  pId		numeric,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  id  := pId;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteWorkPlace(pId);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_workplace -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает данные рабочего места.
 * @return {record} - Данные рабочего места
 */
CREATE OR REPLACE FUNCTION api.get_workplace (
  pId			numeric,
  OUT id		numeric,
  OUT sid		varchar,
  OUT name		varchar,
  OUT description       text
) RETURNS		record
AS $$
  SELECT id, sid, name, description
    FROM api.workplace
   WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_workplace_add ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет пользователя или группу к рабочему месту.
 * @param {numeric} pMember - Идентификатор пользователя/группы
 * @param {numeric} pWorkPlace - Идентификатор рабочего места
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.member_workplace_add (
  pMember		numeric,
  pWorkPlace		numeric,
  OUT result		boolean,
  OUT error		text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM AddMemberToWorkPlace(pMember, pWorkPlace);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_workplace_del ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет рабочее место для пользователя или группу.
 * @param {numeric} pMember - Идентификатор пользователя/группы
 * @param {numeric} pWorkPlace - Идентификатор рабочего места, при null удаляет все рабочие места для указанного пользователя
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.member_workplace_del (
  pMember		numeric,
  pWorkPlace		numeric,
  OUT result		boolean,
  OUT error		text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteWorkPlaceForMember(pMember, pWorkPlace);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.workplace_member_del ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет пользователя или группу из рабочего места.
 * @param {numeric} pWorkPlace - Идентификатор рабочего места
 * @param {numeric} pMember - Идентификатор пользователя/группы, при null удаляет всех пользователей из указанного рабочего места
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.workplace_member_del (
  pWorkPlace		numeric,
  pMember		numeric default null,
  OUT result		boolean,
  OUT error		text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteMemberFromWorkPlace(pWorkPlace, pMember);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_workplace --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.member_workplace
AS
  SELECT * FROM MemberWorkPlace;

GRANT SELECT ON api.member_workplace TO daemon;

--------------------------------------------------------------------------------
-- api.workplace_member --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список участников рабочего места.
 * @return {SETOF record} - Запись
 */
CREATE OR REPLACE FUNCTION api.workplace_member (
  pWorkPlaceId		numeric,
  OUT id		numeric,
  OUT type		char,
  OUT username		varchar,
  OUT fullname		text,
  OUT email		text,
  OUT description       text,
  OUT status		text,
  OUT system		text
) RETURNS		SETOF record
AS $$
  SELECT g.id, 'G' AS type, g.username, g.fullname, null AS email, g.description, null AS status, g.system
    FROM api.member_workplace m INNER JOIN groups g ON g.id = m.memberid
   WHERE m.workplace = pWorkPlaceId
     AND current_session() IS NOT NULL
  UNION ALL
  SELECT u.id, 'U' AS type, u.username, u.fullname, u.email, u.description, u.status, u.system
    FROM api.member_workplace m INNER JOIN users u ON u.id = m.memberid
   WHERE m.workplace = pWorkPlaceId
     AND current_session() IS NOT NULL;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_workplace --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает рабочее места доступные участнику.
 * @return {record} - Данные рабочего места
 */
CREATE OR REPLACE FUNCTION api.member_workplace (
  pUserId		numeric default current_userid(),
  OUT id		numeric,
  OUT sid		varchar,
  OUT name		varchar,
  OUT description       text
) RETURNS		SETOF record
AS $$
  SELECT id, sid, name, description
    FROM api.workplace
   WHERE id in (
     SELECT workplace FROM db.member_workplace WHERE member = (
       SELECT id FROM db.user WHERE id = pUserId
     )
   )
   UNION ALL
  SELECT id, sid, name, description
    FROM api.workplace
   WHERE id in (
     SELECT workplace FROM db.member_workplace WHERE member IN (
       SELECT userid FROM db.member_group WHERE member = (
         SELECT id FROM db.user WHERE id = pUserId
       )
     )
   )
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- API -------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- quote_literal_json ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION quote_literal_json (
  pStr		text
) RETURNS	text
AS $$
DECLARE
  l		integer;
  c		integer;
BEGIN
  l := position('->>' in pStr);
  IF l > 0 THEN
    c := position(')' in SubStr(pStr, l + 3));
    IF position(E'\'' in pStr) = 0 THEN
      IF c > 0 THEN
        pStr := SubStr(pStr, 1, l + 2) || quote_literal(SubStr(pStr, l + 3, c - 1)) || ')';
      ELSE
        pStr := SubStr(pStr, 1, l + 2) || quote_literal(SubStr(pStr, l + 3));
      END IF;
    END IF;
  END IF;
  RETURN pStr;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- array_quote_literal_json ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION array_quote_literal_json (
  pArray	anyarray
) RETURNS	anyarray
AS $$
DECLARE
  i		integer;
  l		integer;
  vStr		text;
BEGIN
  FOR i IN 1..array_length(pArray, 1)
  LOOP
    vStr := pArray[i];
    l := position('->>' in vStr);
    IF l > 0 THEN
      IF position(E'\'' in vStr) = 0 THEN
        pArray[i] := SubString(vStr from 1 for l + 2) || quote_literal(SubString(vStr from l + 3));
      END IF;
    END IF;
  END LOOP;

  RETURN pArray;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateApiSql ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает динамический SQL запрос.
 * @param {text} pScheme - Схема
 * @param {text} pTable - Таблица
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {text} - SQL запрос

 Где сравнение (compare):
   EQL - равно
   NEQ - не равно
   LSS - меньше
   LEQ - меньше или равно
   GTR - больше
   GEQ - больше или равно
   GIN - для поиска вхождений JSON

   LKE - LIKE - Значение ключа (value) должно передаваться вместе со знаком '%' в нужном вам месте
   ISN - IS NULL - Ключ (value) должен быть опушен
   INN - IS NOT NULL - Ключ (value) должен быть опушен
 */
CREATE OR REPLACE FUNCTION CreateApiSql (
  pScheme	text,
  pTable	text,
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	text
AS $$
DECLARE
  r		record;

  nUserId	numeric;

  vMethod	text;
  vWith		text;
  vSelect	text;
  vWhere	text;
  vJoin		text;

  vCondition	text;
  vField	text;
  vCompare	text;
  vValue	text;
  vLStr		text;
  vRStr		text;

  IsSecurity	boolean;
  IsExternal	boolean;

  arTables	text[];
  arValues	text[];
  arColumns	text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  arTables := array_cat(null, ARRAY['client', 'charge_point']);

  IF array_position(arTables, pTable) IS NULL THEN
    PERFORM IncorrectValueInArray(pTable, 'sql/api/table', arTables);
  END IF;

  IsSecurity := false;
  nUserId := current_userid();

  IsExternal := false;

  vSelect := coalesce(vWith, '') || 'SELECT ' || coalesce(array_to_string(arColumns, ', '), 't.*') || E'\n  FROM ' || pScheme || '.' || pTable || ' t ' || coalesce(vJoin, '');

  IF pFilter IS NOT NULL THEN
    PERFORM CheckJsonbKeys(pTable || '/filter', arColumns, pFilter);

    FOR r IN SELECT * FROM jsonb_each(pFilter)
    LOOP
      pSearch := coalesce(pSearch, '[]'::jsonb) || jsonb_build_object('field', r.key, 'value', r.value);
    END LOOP;
  END IF;

  IF pSearch IS NOT NULL THEN

    IF jsonb_typeof(pSearch) = 'array' THEN

      PERFORM CheckJsonbKeys(pTable || '/search', ARRAY['condition', 'field', 'compare', 'value', 'valarr', 'lstr', 'rstr'], pSearch);

      FOR r IN SELECT * FROM jsonb_to_recordset(pSearch) AS x(condition text, field text, compare text, value text, valarr jsonb, lstr text, rstr text)
      LOOP
        vCondition := coalesce(upper(r.condition), 'AND');
        vField     := coalesce(lower(r.field), '<null>');
        vCompare   := coalesce(upper(r.compare), 'EQL');
        vLStr	   := coalesce(r.lstr, '');
        vRStr	   := coalesce(r.rstr, '');

        vField := quote_literal_json(vField);

        arValues := array_cat(null, ARRAY['AND', 'OR']);
        IF array_position(arValues, vCondition) IS NULL THEN
          PERFORM IncorrectValueInArray(coalesce(r.condition, '<null>'), 'condition', arValues);
        END IF;
/*
        IF array_position(arColumns, vField) IS NULL THEN
          PERFORM IncorrectValueInArray(coalesce(r.field, '<null>'), 'field', arColumns);
        END IF;
*/
        IF r.valarr IS NOT NULL THEN
          vValue := jsonb_array_to_string(r.valarr, ',');

          IF vWhere IS NULL THEN
            vWhere := E'\n WHERE ' || vField || ' IN (' || vValue || ')';
          ELSE
            vWhere := vWhere || E'\n  ' || vCondition || ' ' || vField || ' IN (' || vValue  || ')';
          END IF;

        ELSE
          vValue := quote_nullable(r.value);

          arValues := array_cat(null, ARRAY['EQL', 'NEQ', 'LSS', 'LEQ', 'GTR', 'GEQ', 'GIN', 'LKE', 'ISN', 'INN']);
          IF array_position(arValues, vCompare) IS NULL THEN
            PERFORM IncorrectValueInArray(coalesce(r.compare, '<null>'), 'compare', arValues);
          END IF;

          IF vWhere IS NULL THEN
            vWhere := E'\n WHERE ' || vLStr || vField || GetCompare(vCompare) || vValue || vRStr;
          ELSE
            vWhere := vWhere || E'\n  ' || vCondition || ' ' || vLStr || vField || GetCompare(vCompare) || vValue || vRStr;
          END IF;
        END IF;

      END LOOP;

    ELSE
      PERFORM IncorrectJsonType(jsonb_typeof(pSearch), 'array');
    END IF;

  END IF;

  vSelect := vSelect || coalesce(vWhere, '');

  IF pOrderBy IS NOT NULL THEN
--    PERFORM CheckJsonbValues('orderby', array_cat(arColumns, array_add_text(arColumns, ' desc')), pOrderBy);
    vSelect := vSelect || E'\n ORDER BY ' || array_to_string(array_quote_literal_json(JsonbToStrArray(pOrderBy)), ',');
  ELSE
    vSelect := vSelect || E'\n ORDER BY id';
  END IF;

  IF pLimit IS NOT NULL THEN
    vSelect := vSelect || E'\n LIMIT ' || pLimit;
  END IF;

  IF pOffSet IS NOT NULL THEN
    vSelect := vSelect || E'\nOFFSET ' || pOffSet;
  END IF;

  RAISE NOTICE '%', vSelect;

  RETURN vSelect;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- KERNEL ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.essence
AS
  SELECT * FROM Essence;

GRANT SELECT ON api.essence TO daemon;

--------------------------------------------------------------------------------
-- api.get_essence -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает сущность.
 * @return {record} - Запись
 */
CREATE OR REPLACE FUNCTION api.get_essence (
  pId		numeric,
  OUT id	numeric,
  OUT code	varchar,
  OUT name	varchar
) RETURNS	record
AS $$
  SELECT e.id, e.code, e.name
    FROM api.essence e
   WHERE e.id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CLASS -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.class
AS
  SELECT * FROM ClassTree;

GRANT SELECT ON api.class TO daemon;

--------------------------------------------------------------------------------
-- api.add_class ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт класс.
 * @param {numeric} pParent - Идентификатор "родителя"
 * @param {numeric} pType - Идентификатор типа класса
 * @param {varchar} pCode - Код
 * @param {text} pLabel - Наименование
 * @param {boolean} pAbstract - Абстрактный (Да/Нет)
 * @out param {numeric} id - Id класса
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_class (
  pParent	numeric,
  pType		numeric,
  pCode		varchar,
  pLabel	text,
  pAbstract	boolean default true,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := AddClass(pParent, pType, pCode, pLabel, pAbstract);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.upd_class ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет класс.
 * @param {numeric} pId - Идентификатор класса
 * @param {numeric} pParent - Идентификатор "родителя"
 * @param {numeric} pType - Идентификатор типа класса
 * @param {varchar} pCode - Код
 * @param {text} pLabel - Наименование
 * @param {boolean} pAbstract - Абстрактный (Да/Нет)
 * @out {numeric} id - Идентификатор класса
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.upd_class (
  pId		numeric,
  pParent	numeric,
  pType		numeric,
  pCode		varchar,
  pLabel	text,
  pAbstract	boolean default true,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  id := pId;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM EditClass(pId, pParent, pType, pCode, pLabel, pAbstract);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.del_class ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет класс.
 * @param {numeric} pId - Идентификатор класса
 * @out {numeric} id - Идентификатор класса
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_class (
  pId		numeric,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  id := pId;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteClass(pId);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_class ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает класс.
 * @return {record} - Запись
 */
CREATE OR REPLACE FUNCTION api.get_class (
  pId			numeric,
  OUT id		numeric,
  OUT parent		numeric,
  OUT essence		numeric,
  OUT essencecode	varchar,
  OUT essenceename	text,
  OUT level		integer,
  OUT code		varchar,
  OUT label		text,
  OUT abstract		boolean
) RETURNS		SETOF record
AS $$
  SELECT id, parent, essence, essencecode, essencename, level, code, label, abstract
    FROM api.class
   WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.lst_class ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список классов.
 * @return {SETOF record} - Записи
 */
CREATE OR REPLACE FUNCTION api.lst_class (
  OUT id		numeric,
  OUT parent		numeric,
  OUT essence		numeric,
  OUT essencecode	varchar,
  OUT essenceename	text,
  OUT level		integer,
  OUT code		varchar,
  OUT label		text,
  OUT abstract		boolean
) RETURNS		SETOF record
AS $$
  SELECT id, parent, essence, essencecode, essencename, level, code, label, abstract
    FROM api.class
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- STATE -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.state_type
AS
  SELECT * FROM StateType;

GRANT SELECT ON api.state_type TO daemon;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.state
AS
  SELECT * FROM State;

GRANT SELECT ON api.state TO daemon;

--------------------------------------------------------------------------------
-- api.get_state_type ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает тип состояния.
 * @return {record} - Запись
 */
CREATE OR REPLACE FUNCTION api.get_state_type (
  pId		numeric,
  OUT id	numeric,
  OUT code	varchar,
  OUT name	varchar
) RETURNS	record
AS $$
  SELECT id, code, name
    FROM api.state_type
   WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.state (
  pClass	numeric
) RETURNS	SETOF api.state
AS $$
  SELECT * FROM api.state WHERE class = pClass
  UNION ALL
  SELECT *
    FROM api.state
   WHERE id = GetState(pClass, code)
     AND id NOT IN (SELECT id FROM api.state WHERE class = pClass)
   ORDER BY sequence
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_state ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт состояние.
 * @param {numeric} pClass - Идентификатор класса
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {text} pLabel - Наименование
 * @param {integer} pSequence - Очередность
 * @out param {numeric} id - Идентификатор состояния
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_state (
  pClass	numeric,
  pType		numeric,
  pCode		varchar,
  pLabel	text,
  pSequence	integer,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := AddState(pClass, pType, pCode, pLabel, pSequence);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.upd_state ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет состояние.
 * @param {numeric} pId - Идентификатор состояния
 * @param {numeric} pClass - Идентификатор класса
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {text} pLabel - Наименование
 * @param {integer} pSequence - Очередность
 * @out param {numeric} id - Идентификатор состояния
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.upd_state (
  pId		numeric,
  pClass	numeric default null,
  pType		numeric default null,
  pCode		varchar default null,
  pLabel	text default null,
  pSequence	integer default null,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  id := pId;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM EditState(pId, pClass, pType, pCode, pLabel, pSequence);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.del_state ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет состояние.
 * @param {numeric} pId - Идентификатор состояния
 * @out param {numeric} id - Идентификатор состояния
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_state (
  pId		numeric,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  id := pId;
 
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteState(pId);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_state ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает состояние.
 * @return {record} - Состояние
 */
CREATE OR REPLACE FUNCTION api.get_state (
  pId			numeric,
  OUT id		numeric,
  OUT type		numeric,
  OUT typecode		varchar,
  OUT typename		text,
  OUT code		varchar,
  OUT label		text
) RETURNS		record
AS $$
  SELECT id, type, typecode, typename, code, label
    FROM api.state 
   WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ACTION ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.action
AS
  SELECT * FROM Action;

GRANT SELECT ON api.action TO daemon;

--------------------------------------------------------------------------------
-- METHOD ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.method
AS
  SELECT * FROM Method;

GRANT SELECT ON api.method TO daemon;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.method (
  pClass	numeric,
  pState	numeric
) RETURNS	SETOF api.method
AS $$
  SELECT * FROM api.method WHERE class = pClass AND coalesce(state, 0) = coalesce(pState, state, 0)
   UNION ALL
  SELECT *
    FROM api.method
   WHERE id = GetMethod(pClass, pState, action)
     AND id NOT IN (SELECT id FROM api.method WHERE class = pClass AND coalesce(state, 0) = coalesce(pState, state, 0))
   ORDER BY statecode, sequence
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_method --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт метод (операцию).
 * @param {numeric} pParent - Идентификатор родителя (для создания вложенных методов, для построения меню)
 * @param {numeric} pClass - Идентификатор класса: api.class
 * @param {numeric} pState - Идентификатор состояния: api.state
 * @param {numeric} pAction - Идентификатор действия: api.action
 * @param {varchar} pCode - Код
 * @param {text} pLabel - Наименование
 * @param {integer} pSequence - Очередность
 * @param {boolean} pVisible - Видимый: Да/Нет
 * @out param {numeric} id - Идентификатор метода
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_method (
  pParent	numeric,
  pClass	numeric,
  pState	numeric,
  pAction	numeric,
  pCode		varchar,
  pLabel	text,
  pSequence	integer,
  pVisible	boolean,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := AddMethod(pParent, pClass, pState, pAction, pCode, pLabel, pSequence, pVisible);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.upd_method --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет метод (операцию).
 * @param {numeric} pId - Идентификатор метода
 * @param {numeric} pParent - Идентификатор родителя (для создания вложенных методов, для построения меню)
 * @param {numeric} pClass - Идентификатор класса: api.class
 * @param {numeric} pState - Идентификатор состояния: api.state
 * @param {numeric} pAction - Идентификатор действия: api.action
 * @param {varchar} pCode - Код
 * @param {text} pLabel - Наименование
 * @param {integer} pSequence - Очередность
 * @param {boolean} pVisible - Видимый: Да/Нет
 * @out param {numeric} id - Идентификатор метода
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.upd_method (
  pId		numeric,
  pParent	numeric default null,
  pClass	numeric default null,
  pState	numeric default null,
  pAction	numeric default null,
  pCode		varchar default null,
  pLabel	text default null,
  pSequence	integer default null,
  pVisible	boolean default null,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  id := pId;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM EditMethod(pId, pParent, pClass, pState, pAction, pCode, pLabel, pSequence, pVisible);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.del_method --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет метод (операцию).
 * @param {numeric} pId - Идентификатор метода
 * @out param {numeric} id - Идентификатор метода
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_method (
  pId		numeric,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  id := pId;
 
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteMethod(pId);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_method --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает методы объекта.
 * @param {numeric} pState - Идентификатор состояния
 * @param {numeric} pClass - Идентификатор класса 
 * @param {numeric} pParent - Идентификатор метода родителя
 * @out param {numeric} id - Идентификатор метода
 * @out param {numeric} parent - Идентификатор метода родителя
 * @out param {numeric} action - Идентификатор действия
 * @out param {varchar} actioncode - Код действия
 * @out param {text} label - Описание метода
 * @out param {boolean} hidden - Скрытый метод: Да/Нет
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.get_method (
  pState		numeric,
  pClass		numeric,
  pUserId		numeric default current_userid(),
  OUT id		numeric,
  OUT parent		numeric,
  OUT action		numeric,
  OUT actioncode	varchar,
  OUT label		text,
  OUT visible		boolean
) RETURNS		SETOF record
AS $$
  SELECT m.id, m.parent, m.action, m.actioncode, m.label, m.visible
    FROM api.method m
   WHERE m.class = pClass
     AND m.state = pState
   ORDER BY m.sequence
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- TRANSITION ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.transition
AS
  SELECT * FROM Transition;

GRANT SELECT ON api.transition TO daemon;

--------------------------------------------------------------------------------
-- api.add_transition ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт переход в новое состояние.
 * @param {numeric} pState - Идентификатор состояния
 * @param {numeric} pMethod - Идентификатор метода (операции)
 * @param {varchar} pNewState - Идентификатор нового состояния
 * @out param {numeric} id - Идентификатор перехода
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_transition (
  pState	numeric,
  pMethod	numeric,
  pNewState	numeric,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := AddTransition(pState, pMethod, pNewState);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.upd_transition ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет переход в новое состояние.
 * @param {numeric} pId - Идентификатор перехода
 * @param {numeric} pState - Идентификатор состояния
 * @param {numeric} pMethod - Идентификатор метода (операции)
 * @param {varchar} pNewState - Идентификатор нового состояния
 * @out param {numeric} id - Идентификатор перехода
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.upd_transition (
  pId		numeric,
  pState	numeric default null,
  pMethod	numeric default null,
  pNewState	numeric default null,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  id := pId;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM EditTransition(pId, pState, pMethod, pNewState);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.del_transition ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет переход в новое состояние.
 * @param {numeric} pId - Идентификатор перехода
 * @out param {numeric} id - Идентификатор перехода
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_transition (
  pId		numeric,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  id := pId;
 
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteTransition(pId);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_transition ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает переход.
 * @return {record} - Запись
 */
CREATE OR REPLACE FUNCTION api.get_transition (
  pId			numeric,
  OUT id		numeric,
  OUT state		numeric,
  OUT statetypecode	varchar,
  OUT statetypename	varchar,
  OUT statecode		varchar,
  OUT statelabel	text,
  OUT method		numeric,
  OUT methodcode	varchar,
  OUT methodlabel	text,
  OUT newstate		numeric,
  OUT newstatetypecode	varchar,
  OUT newstatetypename	varchar,
  OUT newstatecode	varchar,
  OUT newstatelabel	text
) RETURNS		record
AS $$
  SELECT id, state, statetypecode, statetypename, statecode, statelabel, 
         method, methodcode, methodlabel,
         newstate, newstatetypecode, newstatetypename, newstatecode, newstatelabel
    FROM api.transition
   WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EVENT -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.event_type
AS
  SELECT * FROM EventType;

GRANT SELECT ON api.event_type TO daemon;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.event
AS
  SELECT * FROM Event;

GRANT SELECT ON api.event TO daemon;

--------------------------------------------------------------------------------
-- api.get_event_type ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает тип события.
 * @return {record} - Запись
 */
CREATE OR REPLACE FUNCTION api.get_event_type (
  pId		numeric,
  OUT id	numeric,
  OUT code	varchar,
  OUT name	varchar
) RETURNS	record
AS $$
  SELECT id, code, name
    FROM api.event_type
   WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_event ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт событие.
 * @param {numeric} pClass - Идентификатор класса
 * @param {numeric} pType - Идентификатор типа
 * @param {numeric} pAction - Идентификатор действия
 * @param {text} pLabel - Наименование
 * @param {text} pText - PL/pgSQL Код
 * @param {integer} pSequence - Очередность
 * @param {boolean} pEnabled - Включен: Да/Нет
 * @out param {numeric} id - Идентификатор события
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_event (
  pClass	numeric,
  pType		numeric,
  pAction	numeric,
  pLabel	text,
  pText		text,
  pSequence	integer,
  pEnabled	boolean,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := AddEvent(pClass, pType, pAction, pLabel, pText, pSequence, pEnabled);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.upd_event ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет событие.
 * @param {numeric} pId - Идентификатор события
 * @param {numeric} pClass - Идентификатор класса
 * @param {numeric} pType - Идентификатор типа
 * @param {numeric} pAction - Идентификатор действия
 * @param {text} pLabel - Наименование
 * @param {text} pText - PL/pgSQL Код
 * @param {integer} pSequence - Очередность
 * @param {boolean} pEnabled - Включен: Да/Нет
 * @out param {numeric} id - Идентификатор события
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.upd_event (
  pId		numeric,
  pClass	numeric default null,
  pType		numeric default null,
  pAction	numeric default null,
  pLabel	text default null,
  pText		text default null,
  pSequence	integer default null,
  pEnabled	boolean default null,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  id := pId;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM EditEvent(pId, pClass, pType, pAction, pLabel, pText, pSequence, pEnabled);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.del_event ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет событие.
 * @param {numeric} pId - Идентификатор события
 * @out param {numeric} id - Идентификатор события
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_state (
  pId		numeric,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  id := pId;
 
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteEvent(pId);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_event ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает событыие.
 * @return {record} - Запись
 */
CREATE OR REPLACE FUNCTION api.get_event (
  pId			numeric,
  OUT id		numeric,
  OUT class		numeric,
  OUT type		numeric,
  OUT typecode		varchar,
  OUT typename		varchar,
  OUT action		numeric,
  OUT actioncode	varchar,
  OUT actionname	varchar,
  OUT label		text,
  OUT text		text,
  OUT sequence		integer,
  OUT enabled		boolean
) RETURNS		record
AS $$
  SELECT id, class, type, typecode, typename, action, actioncode, actionname, label, text, sequence, enabled
    FROM api.event 
   WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- TYPE ------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.type
AS
  SELECT * FROM Type;

GRANT SELECT ON api.type TO daemon;

--------------------------------------------------------------------------------
-- api.add_type ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт тип.
 * @param {numeric} pClass - Идентификатор класса
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Идентификатор типа
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_type (
  pClass	numeric,
  pCode		varchar,
  pName		varchar,
  pDescription	text default null,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := AddType(pClass, pCode, pName, pDescription);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.upd_type ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет тип.
 * @param {numeric} pId - Идентификатор типа
 * @param {numeric} pClass - Идентификатор класса
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Идентификатор типа
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.upd_type (
  pId		numeric,
  pClass	numeric default null,
  pCode		varchar default null,
  pName		varchar default null,
  pDescription	text default null,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  id := pId;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM EditType(pId, pClass, pCode, pName, pDescription);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.del_type ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет тип.
 * @param {numeric} pId - Идентификатор типа
 * @out param {numeric} id - Идентификатор типа
 * @out param {numeric} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_type (
  pId		numeric,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  id := pId;
 
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteType(pId);
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_type ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает тип.
 * @return {Type} - Тип
 */
CREATE OR REPLACE FUNCTION api.get_type (
  pId			numeric,
  OUT id		numeric,
  OUT code		varchar,
  OUT name		text,
  OUT description	text
) RETURNS		record
AS $$
  SELECT id, code, name, description
    FROM api.type
   WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.lst_type ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает тип списоком.
 * @return {SETOF record} - Записи
 */
CREATE OR REPLACE FUNCTION api.lst_type (
  OUT id		numeric,
  OUT code		varchar,
  OUT name		text,
  OUT description	text
) RETURNS		SETOF record
AS $$
  SELECT id, code, name, description
    FROM api.type 
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DIRECTORY -------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.language ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Языки.
 */
CREATE OR REPLACE VIEW api.language
AS
  SELECT * FROM language;

GRANT SELECT ON api.language TO daemon;

--------------------------------------------------------------------------------
-- JSON ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- JsonToIntArray --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION JsonToIntArray (
  pJson		json
) RETURNS	integer[]
AS $$
DECLARE
  r		record;
  result	integer[];
BEGIN
  IF json_typeof(pJson) = 'array' THEN
    
    FOR r IN SELECT * FROM json_array_elements_text(pJson)
    LOOP
      result := array_append(result, r.value::integer);
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM json_each_text(pJson)
    LOOP
      result := array_append(result, r.value::integer);
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonbToIntArray -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION JsonbToIntArray (
  pJson		jsonb
) RETURNS	integer[]
AS $$
DECLARE
  r		record;
  result	integer[];
BEGIN
  IF jsonb_typeof(pJson) = 'array' THEN
    
    FOR r IN SELECT * FROM jsonb_array_elements_text(pJson)
    LOOP
      result := array_append(result, r.value::integer);
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM jsonb_each_text(pJson)
    LOOP
      result := array_append(result, r.value::integer);
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonToNumArray --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION JsonToNumArray (
  pJson		json
) RETURNS	numeric[]
AS $$
DECLARE
  r		record;
  result	numeric[];
BEGIN
  IF json_typeof(pJson) = 'array' THEN
    
    FOR r IN SELECT * FROM json_array_elements_text(pJson)
    LOOP
      result := array_append(result, r.value::numeric);
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM json_each_text(pJson)
    LOOP
      result := array_append(result, r.value::numeric);
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonbToNumArray -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION JsonbToNumArray (
  pJson		jsonb
) RETURNS	numeric[]
AS $$
DECLARE
  r		record;
  result	numeric[];
BEGIN
  IF jsonb_typeof(pJson) = 'array' THEN
    
    FOR r IN SELECT * FROM jsonb_array_elements_text(pJson)
    LOOP
      result := array_append(result, r.value::numeric);
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM jsonb_each_text(pJson)
    LOOP
      result := array_append(result, r.value::numeric);
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonToStrArray --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION JsonToStrArray (
  pJson		json
) RETURNS	text[]
AS $$
DECLARE
  r		record;
  result	text[];
BEGIN
  IF json_typeof(pJson) = 'array' THEN
    
    FOR r IN SELECT * FROM json_array_elements_text(pJson)
    LOOP
      result := array_append(result, r.value);
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM json_each_text(pJson)
    LOOP
      result := array_append(result, r.value);
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonbToStrArray -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION JsonbToStrArray (
  pJson		jsonb
) RETURNS	text[]
AS $$
DECLARE
  r		record;
  result	text[];
BEGIN
  IF jsonb_typeof(pJson) = 'array' THEN
    
    FOR r IN SELECT * FROM jsonb_array_elements_text(pJson)
    LOOP
      result := array_append(result, r.value);
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM jsonb_each_text(pJson)
    LOOP
      result := array_append(result, r.value);
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonToBoolArray -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION JsonToBoolArray (
  pJson		json
) RETURNS	boolean[]
AS $$
DECLARE
  r		record;
  result	boolean[];
BEGIN
  IF json_typeof(pJson) = 'array' THEN
    
    FOR r IN SELECT * FROM json_array_elements_text(pJson)
    LOOP
      result := array_append(result, r.value::boolean);
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM json_each_text(pJson)
    LOOP
      result := array_append(result, r.value::boolean);
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonbToBoolArray ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION JsonbToBoolArray (
  pJson		jsonb
) RETURNS	boolean[]
AS $$
DECLARE
  r		record;
  result	boolean[];
BEGIN
  IF jsonb_typeof(pJson) = 'array' THEN
    
    FOR r IN SELECT * FROM jsonb_array_elements_text(pJson)
    LOOP
      result := array_append(result, r.value::boolean);
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM jsonb_each_text(pJson)
    LOOP
      result := array_append(result, r.value::boolean);
    END LOOP;

  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- jsonb_array_to_string -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION jsonb_array_to_string (
  pJson		jsonb,
  pSep		text
) RETURNS	text
AS $$
DECLARE
  r		record;
  arStr		text[];
BEGIN
  IF jsonb_typeof(pJson) = 'array' THEN
    
    FOR r IN SELECT * FROM jsonb_array_elements_text(pJson)
    LOOP
      arStr := array_append(arStr, quote_nullable(r.value));
    END LOOP;

  ELSE
    PERFORM IncorrectJsonType(jsonb_typeof(pJson), 'array');
  END IF;

  RETURN array_to_string(arStr, pSep, '*');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckJsonKeys ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckJsonKeys (
  pRoute	text,
  pKeys		text[],
  pJson		json
) RETURNS	void
AS $$
DECLARE
  e		record;
  r		record;
BEGIN
  IF json_typeof(pJson) = 'array' THEN
    
    FOR e IN SELECT * FROM json_array_elements(pJson)
    LOOP
      FOR r IN SELECT * FROM json_each_text(e.value)
      LOOP
        IF array_position(pKeys, r.key) IS NULL THEN
          PERFORM IncorrectJsonKey(pRoute, r.key, pKeys);
        END IF;
      END LOOP;
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM json_each_text(pJson)
    LOOP
      IF array_position(pKeys, r.key) IS NULL THEN
        PERFORM IncorrectJsonKey(pRoute, r.key, pKeys);
      END IF;
    END LOOP;

  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckJsonbKeys --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckJsonbKeys (
  pRoute	text,
  pKeys		text[],
  pJson		jsonb
) RETURNS	void
AS $$
DECLARE
  e		record;
  r		record;
BEGIN
  IF jsonb_typeof(pJson) = 'array' THEN
    
    FOR e IN SELECT * FROM jsonb_array_elements(pJson)
    LOOP
      FOR r IN SELECT * FROM jsonb_each_text(e.value)
      LOOP
        IF array_position(pKeys, r.key) IS NULL THEN
          PERFORM IncorrectJsonKey(pRoute, r.key, pKeys);
        END IF;
      END LOOP;
    END LOOP;

  ELSE

    FOR r IN SELECT * FROM jsonb_each_text(pJson)
    LOOP
      IF array_position(pKeys, r.key) IS NULL THEN
        PERFORM IncorrectJsonKey(pRoute, r.key, pKeys);
      END IF;
    END LOOP;

  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckJsonValues -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckJsonValues (
  pArrayName	text,
  pArray	anyarray,
  pJson		json
) RETURNS	void
AS $$
DECLARE
  r		record;
BEGIN
  IF json_typeof(pJson) = 'array' THEN
    
    FOR r IN SELECT * FROM json_array_elements_text(pJson)
    LOOP
      IF array_position(pArray, coalesce(r.value, '<null>')) IS NULL THEN
        PERFORM IncorrectValueInArray(coalesce(r.value, '<null>'), pArrayName, pArray);
      END IF;
    END LOOP;

  ELSE
    PERFORM IncorrectJsonType(json_typeof(pJson), 'array');
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckJsonbValues ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckJsonbValues (
  pArrayName	text,
  pArray	anyarray,
  pJson		jsonb
) RETURNS	void
AS $$
DECLARE
  r		record;
BEGIN
  IF jsonb_typeof(pJson) = 'array' THEN
    
    FOR r IN SELECT * FROM jsonb_array_elements_text(pJson)
    LOOP
      IF array_position(pArray, coalesce(r.value, '<null>')) IS NULL THEN
        PERFORM IncorrectValueInArray(coalesce(r.value, '<null>'), pArrayName, pArray);
      END IF;
    END LOOP;

  ELSE
    PERFORM IncorrectJsonType(jsonb_typeof(pJson), 'array');
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonToFields ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION JsonToFields (
  pJson		json,
  pFields	text[]
) RETURNS	text
AS $$
DECLARE
  vFields	text;
BEGIN
  IF pJson IS NOT NULL THEN
    PERFORM CheckJsonValues('fields', pFields, pJson);

    RETURN array_to_string(array_quote_literal_json(JsonToStrArray(pJson)), ',');
  END IF;

  RETURN '*';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- JsonbToFields ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION JsonbToFields (
  pJson		jsonb,
  pFields	text[]
) RETURNS	text
AS $$
DECLARE
  vFields	text;
BEGIN
  IF pJson IS NOT NULL THEN
--    PERFORM CheckJsonbValues('fields', pFields, pJson);

    RETURN array_to_string(array_quote_literal_json(JsonbToStrArray(pJson)), ',');
  END IF;

  RETURN '*';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.get_object_json_files ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_json_files (
  pObject	numeric
) RETURNS	json
AS $$
DECLARE
  arResult	json[]; 
  r		record;
BEGIN
  FOR r IN
    SELECT id, file_hash AS hash, file_name AS name, file_path AS path, file_size AS size, file_date AS date
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
-- api.get_object_jsonb_files --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_jsonb_files (
  pObject	numeric
) RETURNS	jsonb
AS $$
BEGIN
  RETURN api.get_object_json_files(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_json_files ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_json_files (
  pObject	numeric,
  pFiles	jsonb,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
DECLARE
  arKeys	text[];
  nId		numeric;
  r		record;
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  SELECT id INTO nId FROM Document WHERE object = pObject;
  IF not found THEN
    PERFORM ObjectNotFound('документ', 'id', pObject);
  END IF;

  IF pFiles IS NOT NULL THEN
    arKeys := array_cat(arKeys, ARRAY['id', 'hash', 'name', 'path', 'size', 'date', 'delete']);
    PERFORM CheckJsonbKeys('/object/file/files', arKeys, pFiles);

    FOR r IN SELECT * FROM jsonb_to_recordset(pFiles) AS files(id numeric, hash text, name text, path text, size int, date timestamp, delete boolean)
    LOOP
      IF r.id IS NOT NULL THEN

        SELECT id INTO nId FROM db.object_file WHERE id = r.id AND object = pObject;

        IF NOT FOUND THEN
          PERFORM ObjectNotFound('файл', r.name, r.id);
        END IF;

        IF coalesce(r.delete, false) THEN
          PERFORM DeleteObjectFile(r.id);
        ELSE
          PERFORM EditObjectFile(r.id, r.hash, r.name, r.path, r.size, r.date);
        END IF;
      ELSE
        PERFORM NewObjectFile(pObject, r.hash, r.name, r.path, r.size, r.date);
      END IF;
    END LOOP;

    SELECT * INTO result, error FROM result_success();
  ELSE
    PERFORM JsonIsEmpty();
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_type ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает тип объекта по коду.
 * @param {varchar} pCode - Код типа объекта
 * @return {numeric} - Тип объекта
 */
CREATE OR REPLACE FUNCTION api.get_type (
  pCode		varchar
) RETURNS	numeric
AS $$
BEGIN
  IF current_session() IS NOT NULL THEN
    RETURN GetType(pCode);
  END IF;

  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetJsonMethods --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetJsonMethods (
  pState	numeric,
  pClass	numeric,
  pUserId	numeric default current_userid(),
  pUseCache	boolean default null
) RETURNS	json
AS $$
DECLARE
  arResult	json[];
  r		record;
BEGIN
  IF coalesce(pUseCache, true) THEN
/*
    FOR r IN 
      SELECT id, parent, action, actioncode, label, visible, enable
        FROM cache.method 
       WHERE class = pClass 
         AND state = pState 
         AND userid = pUserId
    LOOP
      arResult := array_append(arResult, row_to_json(r));
    END LOOP;
*/
  ELSE

    FOR r IN SELECT * FROM api.get_method(pState, pClass, pUserId)
    LOOP
      arResult := array_append(arResult, row_to_json(r));
    END LOOP;

  END IF;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetJsonbMethods -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetJsonbMethods (
  pState	numeric,
  pClass	numeric,
  pUserId	numeric default current_userid(),
  pUseCache	boolean default null
) RETURNS	jsonb
AS $$
BEGIN
  RETURN GetJsonMethods(pState, pClass, pUserId, pUseCache);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetJsonGroups ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetJsonGroups (
  pMember	numeric
) RETURNS	json
AS $$
DECLARE
  arResult	json[];
  r		record;
BEGIN
  FOR r IN SELECT * FROM api.member_user(pMember)
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.run_action --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выполняет действие над объектом.
 * @param {numeric} pObject - Идентификатор объекта
 * @param {numeric} pAction - Идентификатор действия
 * @out param {numeric} id - Идентификатор объекта
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.run_action (
  pObject	numeric,
  pAction	numeric,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS	record
AS $$
DECLARE
  nId		numeric;
  nMethod	numeric;
BEGIN
  id := pObject;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  SELECT o.id INTO nId FROM db.object o WHERE o.id = pObject;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pObject);
  END IF;

  IF pAction IS NULL THEN
    PERFORM ActionIsEmpty();
  END IF;

  nMethod := GetObjectMethod(pObject, pAction);

  IF nMethod IS NULL THEN
    PERFORM MethodActionNotFound(pObject, pAction);
  END IF;

  PERFORM ExecuteObjectAction(pObject, pAction);

  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.run_action --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выполняет действие над объектом по коду.
 * @param {numeric} pObject - Идентификатор объекта
 * @param {varchar} pCode - Код действия
 * @out param {numeric} id - Идентификатор объекта
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.run_action (
  pObject	numeric,
  pCode		varchar,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS	record
AS $$
DECLARE
  vCode		varchar;
  arCodes	text[];
  r		record;
BEGIN
  id := pObject;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  FOR r IN SELECT code FROM db.action_list
  LOOP
    arCodes := array_append(arCodes, r.code);
  END LOOP;

  IF array_position(arCodes, pCode) IS NULL THEN
    PERFORM IncorrectCode(pCode, arCodes);
  END IF;

  SELECT * INTO id, result, error FROM api.run_action(pObject, GetAction(pCode));
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.run_method --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выполняет метод.
 * @param {numeric} pObject - Идентификатор объекта
 * @param {numeric} pMethod - Идентификатор метода
 * @out param {numeric} id - Идентификатор объекта
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.run_method (
  pObject	numeric,
  pMethod	numeric,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS	record
AS $$
DECLARE
  nId		numeric;
  nAction	numeric;
BEGIN
  id := pObject;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  IF pMethod IS NULL THEN
    PERFORM MethodIsEmpty();
  END IF;

  SELECT o.id INTO nId FROM db.object o WHERE o.id = pObject;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pObject);
  END IF;

  SELECT action INTO nAction FROM method m WHERE m.id = pMethod;

  IF NOT FOUND THEN
    PERFORM MethodNotFound(pObject, pMethod);
  END IF;

  SELECT * INTO id, result, error FROM api.run_action(pObject, nAction);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_document ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает документ.
 * @param {numeric} pId - Идентификатор документа
 * @return {VDocument} - Документ
 */
CREATE OR REPLACE FUNCTION api.get_document (
  pId		numeric
) RETURNS	Document
AS $$
  SELECT * FROM Document WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.object_forcedel ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Принудительно "удалят" документ (минуя события документооборота).
 * @param {numeric} pObject - Идентификатор объекта (api.get_document)
 * @out param {numeric} id - Идентификатор заявки
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.object_forcedel (
  pObject	numeric,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS	record
AS $$
DECLARE
  nId		numeric;
  nState	numeric;
BEGIN
  id := pObject;
  result := false;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  SELECT o.id INTO nId FROM db.object o WHERE o.id = pObject;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pObject);
  END IF;

  SELECT s.id INTO nState FROM db.state_list s WHERE s.class = GetObjectClass(pObject) AND s.code = 'deleted';

  IF found THEN

    PERFORM AddObjectState(pObject, nState);

    SELECT * INTO result, error FROM result_success();
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- REGISTER --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.register
AS
  SELECT * FROM Register;

GRANT SELECT ON api.register TO daemon;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.register (
  pId		numeric,
  pKey		numeric,
  pSubKey	numeric
) RETURNS	SETOF api.register
AS $$
  SELECT * 
    FROM api.register 
   WHERE id = coalesce(pId, id)
     AND key = coalesce(pKey, key)
     AND subkey = coalesce(pSubKey, subkey)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.register_ex
AS
  SELECT * FROM RegisterEx;

GRANT SELECT ON api.register_ex TO daemon;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.register_ex (
  pId		numeric,
  pKey		numeric,
  pSubKey	numeric
) RETURNS	SETOF api.register_ex
AS $$
  SELECT * 
    FROM api.register_ex
   WHERE id = coalesce(pId, id)
     AND key = coalesce(pKey, key)
     AND subkey = coalesce(pSubKey, subkey)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.register_key
AS
  SELECT * FROM RegisterKey;

GRANT SELECT ON api.register_key TO daemon;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.register_key (
  pId		numeric,
  pRoot		numeric,
  pParent	numeric,
  pKey		text
) RETURNS	SETOF api.register_key
AS $$
  SELECT * 
    FROM api.register_key
   WHERE id = coalesce(pId, id)
     AND root = coalesce(pRoot, root)
     AND parent = coalesce(pParent, parent)
     AND key = coalesce(pKey, key)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.register_value
AS
  SELECT * FROM RegisterValue;

GRANT SELECT ON api.register_value TO daemon;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.register_value_ex
AS
  SELECT * FROM RegisterValueEx;

GRANT SELECT ON api.register_value_ex TO daemon;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.register_value (
  pId		numeric,
  pKey		numeric
) RETURNS	SETOF api.register_value
AS $$
  SELECT * 
    FROM api.register_value
   WHERE id = coalesce(pId, id)
     AND key = coalesce(pKey, key)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.register_value_ex (
  pId		numeric,
  pKey		numeric
) RETURNS	SETOF api.register_value_ex
AS $$
  SELECT * 
    FROM api.register_value_ex
   WHERE id = coalesce(pId, id)
     AND key = coalesce(pKey, key)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.register_get_reg_key (
  pKey		numeric,
  OUT key	text,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  key := get_reg_key(pKey);

  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.register_enum_key -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Перечисляет подключи указанной пары ключ/подключ реестра.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey. 
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @out param {numeric} id - Идентификатор подключа
 * @out param {text} key - Ключ
 * @out param {text} subkey - Подключ
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.register_enum_key (
  pKey		text,
  pSubKey	text,
  OUT id	numeric,
  OUT key	text,
  OUT subkey	text
) RETURNS	SETOF record
AS $$
  SELECT id, pKey, get_reg_key(id) FROM RegEnumKey(RegOpenKey(pKey, pSubKey));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.register_enum_value -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Перечисляет значения для указанной пары ключ/подключ реестра.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey. 
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @out param {numeric} id - Идентификатор значения
 * @out param {text} key - Ключ
 * @out param {text} subkey - Подключ
 * @out param {text} valuename - Имя значения
 * @out param {variant} data - Данные
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.register_enum_value (
  pKey		text,
  pSubKey	text,
  OUT id	numeric,
  OUT key	text,
  OUT subkey	text,
  OUT valuename	text,
  OUT value	variant
) RETURNS	SETOF record
AS $$
  SELECT id, pKey, pSubKey, vname, get_reg_value(id) FROM RegEnumValue(RegOpenKey(pKey, pSubKey));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.register_enum_value_ex --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Перечисляет значения для указанной пары ключ/подключ реестра.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey. 
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @out param {numeric} id - Идентификатор значения
 * @out param {text} key - Ключ
 * @out param {text} subkey - Подключ
 * @out param {text} valuename - Имя значения
 * @out param {integer} vtype - Тип данных: 0..4
 * @out param {integer} vinteger - Целое число
 * @out param {numeric} vnumeric - Число с произвольной точностью
 * @out param {timestamp} vdatetime - Дата и время
 * @out param {text} vstring - Строка
 * @out param {boolean} vboolean - Логический
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.register_enum_value_ex (
  pKey		text,
  pSubKey	text,
  OUT id	numeric,
  OUT key	text,
  OUT subkey	text,
  OUT valuename	text,
  OUT vtype	integer,
  OUT vinteger	integer,
  OUT vnumeric	numeric,
  OUT vdatetime	timestamp,
  OUT vstring	text,
  OUT vboolean	boolean
) RETURNS	SETOF record
AS $$
  SELECT id, pKey, pSubKey, vname, vtype, vinteger, vnumeric, vdatetime, vstring, vboolean FROM RegEnumValueEx(RegOpenKey(pKey, pSubKey));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.register_write ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запись в реестр.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey. 
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @param {text} pValueName - Имя устанавливаемого значения. Если значение с таким именем не существует в ключе реестра, функция его создает.
 * @param {integer} pType - Определяет тип сохраняемых данных значения. Где: 0 - Целое число; 
                                                                             1 - Число с произвольной точностью; 
                                                                             2 - Дата и время; 
                                                                             3 - Строка; 
                                                                             4 - Логический.
 * @param {anynonarray} pData - Данные для установки их по указанному имени значения.
 * @out param {numeric} id - Идентификатор заявки
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.register_write (
  pId		numeric,
  pKey		text,
  pSubKey	text,
  pValueName	text,
  pType		integer,
  pData		anynonarray,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS	record
AS $$
DECLARE
  vData		Variant;
BEGIN
  id := null;
  result := false;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  vData.vType := pType;

  CASE pType 
  WHEN 0 THEN vData.vInteger := pData;
  WHEN 1 THEN vData.vNumeric := pData;
  WHEN 2 THEN vData.vDateTime := pData;
  WHEN 3 THEN vData.vString := pData;
  WHEN 4 THEN vData.vBoolean := pData;
  END CASE;

  id := RegSetValue(coalesce(pId, RegCreateKey(pKey, pSubKey)), pValueName, vData);

  IF id IS NOT NULL THEN
    SELECT * INTO result, error FROM result_success();
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.register_read -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Чтение из реестра.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey. 
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @param {text} pValueName - Имя устанавливаемого значения. Если значение с таким именем не существует в ключе реестра, функция его создает.
 * @out param {Variant} data - Данные
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.register_read (
  pId		numeric,
  pKey		text,
  pSubKey	text,
  pValueName	text,
  OUT data	Variant,
  OUT result	boolean,
  OUT error	text
) RETURNS	record
AS $$
BEGIN
  result := false;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  data := RegGetValue(RegOpenKey(pKey, pSubKey), pValueName);

  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.register_delete_key -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет подключ и его значения.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey. 
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.register_delete_key (
  pKey		text,
  pSubKey	text,
  OUT result	boolean,
  OUT error	text
) RETURNS	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  IF RegDeleteKey(pKey, pSubKey) THEN
    SELECT * INTO result, error FROM result_success();
  ELSE
    result := false;
    error := GetErrorMessage();
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.register_delete_value ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет указанное значение из указанного ключа реестра и подключа.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey. 
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @param {text} pValueName - Имя удаляемого значения.
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.register_delete_value (
  pId		numeric,
  pKey		text,
  pSubKey	text,
  pValueName	text,
  OUT result	boolean,
  OUT error	text
) RETURNS	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  IF pId IS NOT NULL THEN
    PERFORM DelRegKeyValue(pId);
    SELECT * INTO result, error FROM result_success();
  ELSE
    IF RegDeleteKeyValue(pKey, pSubKey, pValueName) THEN
      SELECT * INTO result, error FROM result_success();
    ELSE
      result := false;
      error := GetErrorMessage();
    END IF;
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.register_delete_tree ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет подключи и значения указанного ключа рекурсивно.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey. 
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.register_delete_tree (
  pKey		text,
  pSubKey	text,
  OUT result	boolean,
  OUT error	text
) RETURNS	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  IF RegDeleteTree(pKey, pSubKey) THEN
    SELECT * INTO result, error FROM result_success();
  ELSE
    result := false;
    error := GetErrorMessage();
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CALENDAR --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.calendar ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Календарь
 * @field {numeric} id - Идентификатор
 * @field {numeric} object - Идентификатор справочника
 * @field {numeric} parent - Идентификатор объекта родителя
 * @field {numeric} class - Идентификатор класса
 * @field {varchar} code - Код
 * @field {varchar} name - Наименование
 * @field {text} description - Описание
 * @field {numeric} week - Количество используемых (рабочих) дней в неделе
 * @field {integer[]} dayoff - Массив выходных дней в неделе. Допустимые значения [1..7, ...]
 * @field {integer[][]} holiday - Массив праздничных дней в году. Допустимые значения [[1..12,1..31], ...]
 * @field {interval} workstart - Начало рабочего дня
 * @field {interval} workcount - Количество рабочих часов
 * @field {interval} reststart - Начало перерыва
 * @field {interval} restcount - Количество часов перерыва
 * @field {numeric} state - Идентификатор состояния
 * @field {timestamp} lastupdate - Дата последнего обновления
 * @field {numeric} owner - Идентификатор учётной записи владельца
 * @field {timestamp} created - Дата создания
 * @field {numeric} oper - Идентификатор учётной записи оператора
 * @field {timestamp} operdate - Дата операции
 */
CREATE OR REPLACE VIEW api.calendar
AS
  SELECT *
    FROM ObjectCalendar;

GRANT SELECT ON api.calendar TO daemon;

--------------------------------------------------------------------------------
-- api.add_calendar ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создает календарь.
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {numeric} pWeek - Количество используемых (рабочих) дней в неделе
 * @param {jsonb} pDayOff - Массив выходных дней в неделе. Допустимые значения [1..7, ...]
 * @param {jsonb} pHoliday - Двухмерный массив праздничных дней в году в формате [[MM,DD], ...]. Допустимые значения [[1..12,1..31], ...]
 * @param {interval} pWorkStart - Начало рабочего дня
 * @param {interval} pWorkCount - Количество рабочих часов
 * @param {interval} pRestStart - Начало перерыва
 * @param {interval} pRestCount - Количество часов перерыва
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Идентификатор календаря
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_calendar (
  pCode		varchar,
  pName		varchar,
  pWeek		numeric,
  pDayOff	jsonb,
  pHoliday	jsonb,
  pWorkStart	interval,
  pWorkCount    interval,
  pRestStart	interval,
  pRestCount    interval,
  pDescription	text default null,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
DECLARE
  nCalendar	numeric;
  aHoliday	integer[][2];
  r		record;
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  IF pHoliday IS NOT NULL THEN

    aHoliday := ARRAY[[0,0]];

    IF jsonb_typeof(pHoliday) = 'array' THEN
      FOR r IN SELECT * FROM jsonb_array_elements(pHoliday)
      LOOP
        IF jsonb_typeof(r.value) = 'array' THEN
          aHoliday := array_cat(aHoliday, JsonbToIntArray(r.value));
        ELSE
          PERFORM IncorrectJsonType(jsonb_typeof(r.value), 'array');
        END IF;
      END LOOP;
    ELSE
      PERFORM IncorrectJsonType(jsonb_typeof(pHoliday), 'array');
    END IF;
  END IF;

  nCalendar := CreateCalendar(null, GetType('workday.calendar'), pCode, pName, pWeek, JsonbToIntArray(pDayOff), aHoliday[2:], pWorkStart, pWorkCount, pRestStart, pRestCount, pDescription);

  id := nCalendar;

  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.upd_calendar ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет календарь.
 * @param {numeric} pId - Идентификатор календаря (api.get_calendar)
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {numeric} pWeek - Количество используемых (рабочих) дней в неделе
 * @param {jsonb} pDayOff - Массив выходных дней в неделе. Допустимые значения [1..7, ...]
 * @param {jsonb} pHoliday - Двухмерный массив праздничных дней в году в формате [[MM,DD], ...]. Допустимые значения [[1..12,1..31], ...]
 * @param {interval} pWorkStart - Начало рабочего дня
 * @param {interval} pWorkCount - Количество рабочих часов
 * @param {interval} pRestStart - Начало перерыва
 * @param {interval} pRestCount - Количество часов перерыва
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Идентификатор календаря
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.upd_calendar (
  pId		numeric,
  pCode		varchar default null,
  pName		varchar default null,
  pWeek		numeric default null,
  pDayOff	jsonb default null,
  pHoliday	jsonb default null,
  pWorkStart	interval default null,
  pWorkCount    interval default null,
  pRestStart	interval default null,
  pRestCount    interval default null,
  pDescription	text default null,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
DECLARE
  nId		numeric;
  nCalendar	numeric;
  aHoliday	integer[][2];
  r		record;
BEGIN
  id := pId;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  SELECT c.id INTO nId FROM calendar c WHERE c.id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('календарь', 'id', pId);
  END IF;

  nCalendar := pId;

  IF pHoliday IS NOT NULL THEN

    aHoliday := ARRAY[[0,0]];

    IF jsonb_typeof(pHoliday) = 'array' THEN
      FOR r IN SELECT * FROM jsonb_array_elements(pHoliday)
      LOOP
        IF jsonb_typeof(r.value) = 'array' THEN
          aHoliday := array_cat(aHoliday, JsonbToIntArray(r.value));
        ELSE
          PERFORM IncorrectJsonType(jsonb_typeof(r.value), 'array');
        END IF;
      END LOOP;
    ELSE
      PERFORM IncorrectJsonType(jsonb_typeof(pHoliday), 'array');
    END IF;
  END IF;

  PERFORM EditCalendar(nCalendar, null, null, pCode, pName, pWeek, JsonbToIntArray(pDayOff), aHoliday[2:], pWorkStart, pWorkCount, pRestStart, pRestCount, pDescription);

  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_calendar ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает календарь.
 * @param {numeric} pId - Идентификатор календаря
 * @return {api.calendar} - Календарь
 */
CREATE OR REPLACE FUNCTION api.get_calendar (
  pId		numeric
) RETURNS	api.calendar
AS $$
  SELECT * FROM api.calendar WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.lst_calendar ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает календарь списком.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Cортировать по указанным в массиве полям
 * @param {boolean} pUseCache - Использовать кеш
 * @return {SETOF api.calendar} - Календари
 */
CREATE OR REPLACE FUNCTION api.lst_calendar (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null,
  pUseCache	boolean default null
) RETURNS	SETOF api.calendar
AS $$
BEGIN
  RETURN QUERY EXECUTE CreateApiSql('api', 'calendar', pSearch, pFilter, pLimit, pOffSet, pOrderBy, pUseCache);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.fill_calendar --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Заполняет календарь датами.
 * @param {numeric} pCalendar - Идентификатор календаря
 * @param {date} pDateFrom - Дата начала периода
 * @param {date} pDateTo - Дата окончания периода
 * @param {numeric} pUserId - Идентификатор учётной записи пользователя
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.fill_calendar (
  pCalendar	numeric,
  pDateFrom	date,
  pDateTo	date,
  pUserId	numeric default null,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM FillCalendar(pCalendar, pDateFrom, pDateTo, pUserId);

  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW api.calendar_date ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.calendar_date
AS
  SELECT * FROM calendar_date;

GRANT SELECT ON api.calendar_date TO daemon;

--------------------------------------------------------------------------------
-- VIEW api.calendardate -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.calendardate
AS
  SELECT * FROM CalendarDate;

GRANT SELECT ON api.calendardate TO daemon;

--------------------------------------------------------------------------------
-- FUNCTION api.lst_calendar_date ----------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает даты календаря за указанный период и для заданного пользователя.
 * Даты календаря пользовоталя переопределяют даты календаря для всех пользователей (общие даты)
 * @param {numeric} pCalendar - Идентификатор календаря
 * @param {date} pDateFrom - Дата начала периода
 * @param {date} pDateTo - Дата окончания периода
 * @param {numeric} pUserId - Идентификатор учётной записи пользователя
 * @return {SETOF api.calendar_date} - Даты календаря
 */
CREATE OR REPLACE FUNCTION api.lst_calendar_date (
  pCalendar	numeric,
  pDateFrom	date,
  pDateTo	date,
  pUserId	numeric default null
) RETURNS	SETOF api.calendar_date
AS $$
  SELECT * FROM calendar_date(pCalendar, coalesce(pDateFrom, date_trunc('year', now())::date), coalesce(pDateTo, (date_trunc('year', now()) + INTERVAL '1 year' - INTERVAL '1 day')::date), pUserId) ORDER BY date;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.lst_calendar_user ----------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает только даты календаря заданного пользователя за указанный период.
 * @param {numeric} pCalendar - Идентификатор календаря
 * @param {date} pDateFrom - Дата начала периода
 * @param {date} pDateTo - Дата окончания периода
 * @param {numeric} pUserId - Идентификатор учётной записи пользователя
 * @return {SETOF api.calendar_date} - Даты календаря
 */
CREATE OR REPLACE FUNCTION api.lst_calendar_user (
  pCalendar	numeric,
  pDateFrom	date,
  pDateTo	date,
  pUserId	numeric default null
) RETURNS	SETOF api.calendar_date
AS $$
  SELECT * 
    FROM calendar_date 
   WHERE calendar = pCalendar 
     AND (date >= coalesce(pDateFrom, date_trunc('year', now())::date) AND 
          date <= coalesce(pDateTo, (date_trunc('year', now()) + INTERVAL '1 year' - INTERVAL '1 day')::date)) 
     AND userid = coalesce(pUserId, userid)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.get_calendar_date ----------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает дату календаря для заданного пользователя.
 * @param {numeric} pCalendar - Идентификатор календаря
 * @param {date} pDate - Дата
 * @param {numeric} pUserId - Идентификатор учётной записи пользователя
 * @return {api.calendardate} - Дата календаря
 */
CREATE OR REPLACE FUNCTION api.get_calendar_date (
  pCalendar	numeric,
  pDate		date,
  pUserId	numeric default null
) RETURNS	api.calendar_date
AS $$
  SELECT * FROM calendar_date(pCalendar, pDate, pDate, pUserId);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.set_calendar_date ----------------------------------------------
--------------------------------------------------------------------------------
/**
 * Заполняет календарь датами.
 * @param {numeric} pCalendar - Идентификатор календаря
 * @param {date} pDate - Дата
 * @param {bit} pFlag - Флаг: 1000 - Предпраздничный; 0100 - Праздничный; 0010 - Выходной; 0001 - Нерабочий; 0000 - Рабочий.
 * @param {interval} pWorkStart - Начало рабочего дня
 * @param {interval} pWorkCount - Количество рабочих часов
 * @param {interval} pRestStart - Начало перерыва
 * @param {interval} pRestCount - Количество часов перерыва
 * @param {numeric} pUserId - Идентификатор учётной записи пользователя
 * @out param {numeric} id - Идентификатор даты календаря
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_calendar_date (
  pCalendar	numeric,
  pDate		date,
  pFlag		bit default null,
  pWorkStart	interval default null,
  pWorkCount	interval default null,
  pRestStart	interval default null,
  pRestCount	interval default null,
  pUserId	numeric default null,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
DECLARE
  nId		numeric;
  r		record;
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  nId := GetCalendarDate(pCalendar, pDate, pUserId);
  IF nId IS NOT NULL THEN
    SELECT * INTO r FROM db.cdate WHERE calendar = pCalendar AND date = pDate AND userid IS NULL;
    IF r.flag = coalesce(pFlag, r.flag) AND
       r.work_start = coalesce(pWorkStart, r.work_start) AND
       r.work_count = coalesce(pWorkCount, r.work_count) AND
       r.rest_start = coalesce(pRestStart, r.rest_start) AND
       r.rest_count = coalesce(pRestCount, r.rest_count) THEN
      PERFORM DeleteCalendarDate(nId);
    ELSE
      PERFORM EditCalendarDate(nId, pCalendar, pDate, pFlag, pWorkStart, pWorkCount, pRestStart, pRestCount, pUserId);
    END IF;
  ELSE
    nId := AddCalendarDate(pCalendar, pDate, pFlag, pWorkStart, pWorkCount, pRestStart, pRestCount, pUserId);
  END IF;

  id := nId;
  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.del_calendar_date ----------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет дату календаря.
 * @param {numeric} pCalendar - Идентификатор календаря
 * @param {date} pDate - Дата
 * @param {numeric} pUserId - Идентификатор учётной записи пользователя
 * @out param {numeric} id - Идентификатор даты календаря
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_calendar_date (
  pCalendar	numeric,
  pDate		date,
  pUserId	numeric default null,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
DECLARE
  nId		numeric;
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  result := false;

  nId := GetCalendarDate(pCalendar, pDate, pUserId);
  IF nId IS NOT NULL THEN
    PERFORM DeleteCalendarDate(nId);
    SELECT * INTO result, error FROM result_success();
  ELSE
    error := 'В календаре нет указанной даты для заданного пользователя.';
  END IF;

  id := nId;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CLIENT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.client ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.client
AS
  SELECT * FROM ObjectClient;

GRANT SELECT ON api.client TO daemon;

--------------------------------------------------------------------------------
-- api.add_client --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет нового клиента.
 * @param {varchar} pType - Tип клиента
 * @param {varchar} pCode - ИНН - для юридического лица | Имя пользователя (login) | null
 * @param {numeric} pUserId - Идентификатор пользователя системы | null
 * @param {jsonb} pName - Полное наименование компании/Ф.И.О.
 * @param {jsonb} pPhone - Телефоны
 * @param {jsonb} pEmail - Электронные адреса
 * @param {jsonb} pAddress - Почтовые адреса
 * @param {jsonb} pInfo - Дополнительная информация
 * @param {text} pDescription - Информация о клиенте
 * @out param {numeric} id - Идентификатор клиента
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_client (
  pType		varchar,
  pCode		varchar,
  pUserId	numeric,
  pName		jsonb,
  pPhone	jsonb default null,
  pEmail	jsonb default null,
  pAddress	jsonb default null,
  pInfo 	jsonb default null,
  pDescription	text default null,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
DECLARE
  r		record;
  nClient	numeric;
  arTypes	text[];
  arKeys	text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  pType := lower(pType);
  arTypes := array_cat(arTypes, ARRAY['entity', 'natural', 'sole']);
  IF array_position(arTypes, pType) IS NULL THEN
    PERFORM IncorrectCode(pType, arTypes);
  END IF;

  arKeys := array_cat(arKeys, ARRAY['name', 'short', 'first', 'last', 'middle']);
  PERFORM CheckJsonbKeys('add_client', arKeys, pName);

  nClient := CreateClient(null, GetType(pType || '.client'), pCode, pUserId, pPhone, pEmail, pAddress, pInfo, pDescription);

  FOR r IN SELECT * FROM jsonb_to_record(pName) AS x(name varchar, short varchar, first varchar, last varchar, middle varchar)
  LOOP
    PERFORM NewClientName(nClient, r.name, r.short, r.first, r.last, r.middle);
  END LOOP;

  id := nClient;

  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.upd_client --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет данные клиента.
 * @param {numeric} pId - Идентификатор клиента (api.get_client)
 * @param {varchar} pType - Tип клиента
 * @param {varchar} pCode - ИНН - для юридического лица | Имя пользователя (login) | null
 * @param {numeric} pUserId - Идентификатор пользователя системы | null
 * @param {jsonb} pName - Полное наименование компании/Ф.И.О.
 * @param {jsonb} pPhone - Телефоны
 * @param {jsonb} pEmail - Электронные адреса
 * @param {jsonb} pAddress - Почтовые адреса
 * @param {jsonb} pInfo - Дополнительная информация
 * @param {text} pDescription - Информация о клиенте
 * @out param {numeric} id - Идентификатор клиента
 * @out param {boolean} result - Результат
 * @out param {text} error - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.upd_client (
  pId		numeric,
  pType		varchar,
  pCode		varchar,
  pUserId	numeric,
  pName		jsonb,
  pPhone	jsonb default null,
  pEmail	jsonb default null,
  pAddress	jsonb default null,
  pInfo 	jsonb default null,
  pDescription	text default null,
  OUT id	numeric,
  OUT result	boolean,
  OUT error	text
) RETURNS 	record
AS $$
DECLARE
  r		record;
  nType         numeric;
  nClient	numeric;
  arTypes	text[];
  arKeys	text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  SELECT c.id INTO nClient FROM db.client c WHERE c.id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('клиент', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    pType := lower(pType);
    arTypes := array_cat(arTypes, ARRAY['entity', 'natural', 'sole']);
    IF array_position(arTypes, pType) IS NULL THEN
      PERFORM IncorrectCode(pType, arTypes);
    END IF;
    nType := GetType(pType || '.client');
  ELSE
    SELECT type INTO nType FROM db.object WHERE id = pId;
  END IF;

  arKeys := array_cat(arKeys, ARRAY['name', 'short', 'first', 'last', 'middle']);
  PERFORM CheckJsonbKeys('upd_client', arKeys, pName);

  PERFORM EditClient(nClient, null, nType, pCode, pUserId, pPhone, pEmail, pAddress, pInfo, pDescription);

  FOR r IN SELECT * FROM jsonb_to_record(pName) AS x(name varchar, short varchar, first varchar, last varchar, middle varchar)
  LOOP
    PERFORM EditClientName(nClient, r.name, r.short, r.first, r.last, r.middle);
  END LOOP;

  id := nClient;

  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_client --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает клиента
 * @param {numeric} pId - Идентификатор клиента
 * @return {api.client} - Клиент
 */
CREATE OR REPLACE FUNCTION api.get_client (
  pId		numeric
) RETURNS	api.client
AS $$
  SELECT * FROM api.client WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.lst_client --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список клиентов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.client} - Клиенты
 */
CREATE OR REPLACE FUNCTION api.lst_client (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.client
AS $$
BEGIN
  RETURN QUERY EXECUTE CreateApiSql('api', 'client', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OCPP ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- VIEW api.charge_point -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.charge_point
AS
  SELECT * FROM ObjectChargePoint;

GRANT SELECT ON api.charge_point TO daemon;

--------------------------------------------------------------------------------
-- FUNCTION api.add_charge_point -----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.add_charge_point (
  pProtocol	      varchar,
  pIdentity	      varchar,
  pName		      varchar,
  pModel	      varchar,
  pVendor	      varchar,
  pVersion	      varchar,
  pSerialNumber	      varchar,
  pBoxSerialNumber    varchar,
  pMeterSerialNumber  varchar,
  piccid	      varchar,
  pimsi	              varchar,
  pDescription	      text default null,
  OUT id	      numeric,
  OUT result	      boolean,
  OUT error	      text
) RETURNS 	      record
AS $$
DECLARE
  arProtocols         text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  pProtocol := lower(pProtocol);
  arProtocols := array_cat(arProtocols, ARRAY['soap', 'json']);
  IF array_position(arProtocols, pProtocol) IS NULL THEN
    PERFORM IncorrectCode(pProtocol, arProtocols);
  END IF;

  id := CreateChargePoint(null, GetType(pProtocol || '.charge_point'), pIdentity, pName, pModel, pVendor, pVersion,
    pSerialNumber, pBoxSerialNumber, pMeterSerialNumber, piccid, pimsi, pDescription);

  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.upd_charge_point -----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.upd_charge_point (
  pId	              numeric,
  pProtocol	      varchar default null,
  pIdentity	      varchar default null,
  pName		      varchar default null,
  pModel	      varchar default null,
  pVendor	      varchar default null,
  pVersion	      varchar default null,
  pSerialNumber	      varchar default null,
  pBoxSerialNumber    varchar default null,
  pMeterSerialNumber  varchar default null,
  piccid	      varchar default null,
  pimsi	              varchar default null,
  pDescription	      text default null,
  OUT id	      numeric,
  OUT result	      boolean,
  OUT error	      text
) RETURNS 	      record
AS $$
DECLARE
  nId                 numeric;
  nType               numeric;
  arProtocols         text[];
BEGIN
  id := pId;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  SELECT c.id INTO nId FROM db.charge_point c WHERE c.id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('зарядная станция', 'id', pId);
  END IF;

  IF pProtocol IS NOT NULL THEN
    pProtocol := lower(pProtocol);
    arProtocols := array_cat(arProtocols, ARRAY['soap', 'json']);
    IF array_position(arProtocols, pProtocol) IS NULL THEN
      PERFORM IncorrectCode(pProtocol, arProtocols);
    END IF;
    nType := GetType(pProtocol || '.charge_point');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  id := EditChargePoint(pId, null, nType, pIdentity, pName, pModel, pVendor, pVersion,
    pSerialNumber, pBoxSerialNumber, pMeterSerialNumber, piccid, pimsi, pDescription);

  SELECT * INTO result, error FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS error = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_charge_point --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает зарядную станцию по идентификатору
 * @param {numeric} pId - Идентификатор зарядной станции
 * @return {api.client} - Зарядная станция
 */
CREATE OR REPLACE FUNCTION api.get_charge_point (
  pId		numeric
) RETURNS	api.charge_point
AS $$
  SELECT * FROM api.charge_point WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_charge_point --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает зарядную станцию по строковому идентификатору
 * @param {numeric} pId - Идентификатор зарядной станции
 * @return {api.client} - Зарядная станция
 */
CREATE OR REPLACE FUNCTION api.get_charge_point (
  pIdentity	varchar
) RETURNS	api.charge_point
AS $$
  SELECT * FROM api.charge_point WHERE identity = pIdentity
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.lst_charge_point --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список зарядных станций.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.client} - Зарядные станции
 */
CREATE OR REPLACE FUNCTION api.lst_charge_point (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.charge_point
AS $$
BEGIN
  RETURN QUERY EXECUTE CreateApiSql('api', 'charge_point', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
