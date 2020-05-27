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
  pUserName     text,
  pPassword     text,
  pHost         inet default null,
  OUT session	text,
  OUT result	boolean,
  OUT message	text
) RETURNS       record
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
  pSession      text,
  pHost         inet default null,
  OUT session	text,
  OUT result	boolean,
  OUT message	text
) RETURNS       record
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
  pSession	    text default current_session(),
  pLogoutAll	boolean default false,
  OUT result	boolean,
  OUT message	text
) RETURNS	    record
AS $$
BEGIN
  result := Logout(pSession, pLogoutAll);
  message := GetErrorMessage();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.join --------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт нового клиента и пользователя.
 * @param {varchar} pType - Tип клиента
 * @param {varchar} pUserName - Имя пользователя (login)
 * @param {text} pPassword - Пароль
 * @param {jsonb} pName - Полное наименование компании/Ф.И.О.
 * @param {text} pPhone - Телефон
 * @param {text} pEmail - Электронный адрес
 * @param {jsonb} pInfo - Дополнительная информация
 * @param {text} pDescription - Информация о клиенте
 * @out param {numeric} id - Идентификатор
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.join (
  pType         varchar,
  pUserName     varchar,
  pPassword     text,
  pName         jsonb,
  pPhone        text default null,
  pEmail        text default null,
  pInfo         jsonb default null,
  pDescription  text default null,
  OUT id        numeric,
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
DECLARE
  cn            record;
  nClient       numeric;
  nUserId       numeric;

  jPhone        jsonb;
  jEmail        jsonb;

  arTypes       text[];
  arKeys        text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  pType := lower(pType);
  arTypes := array_cat(arTypes, ARRAY['entity', 'physical', 'individual']);
  IF array_position(arTypes, pType::text) IS NULL THEN
    PERFORM IncorrectCode(pType, arTypes);
  END IF;

  arKeys := array_cat(arKeys, ARRAY['name', 'short', 'first', 'last', 'middle']);
  PERFORM CheckJsonbKeys('join', arKeys, pName);

  SELECT * INTO cn FROM jsonb_to_record(pName) AS x(name varchar, short varchar, first varchar, last varchar, middle varchar);

  nUserId := CreateUser(pUserName, pPassword, cn.short, pPhone, pEmail, cn.name);

  PERFORM AddMemberToGroup(nUserId, 1002);

  IF pPhone IS NOT NULL THEN
    jPhone := jsonb_build_object('mobile', pPhone);
  END IF;

  IF pEmail IS NOT NULL THEN
    jEmail := jsonb_build_array(pEmail);
  END IF;

  nClient := CreateClient(null, GetType(pType || '.client'), pUserName, nUserId, jPhone, jEmail, pInfo, pDescription);

  PERFORM NewClientName(nClient, cn.name, cn.short, cn.first, cn.last, cn.middle);

  id := nClient;

  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
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
  pUserName	    text,
  pPassword	    text,
  OUT result	boolean,
  OUT message	text
) RETURNS	    record
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
 * @out param {numeric} id - Идентификатор
 * @out param {numeric} userid - Идентификатор виртуального пользователя (учётной записи)
 * @out param {varchar} username - Имя виртуального пользователя (login)
 * @out param {text} fullname - Ф.И.О. виртуального пользователя
 * @out param {text} phone - Телефон виртуального пользователя
 * @out param {text} email - Электронный адрес виртуального пользователя
 * @out param {numeric} session_userid - Идентификатор учётной записи виртуального пользователя сессии
 * @out param {varchar} session_username - Имя виртуального пользователя сессии (login)
 * @out param {text} session_fullname - Ф.И.О. виртуального пользователя сессии
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.whoami (
  OUT id                numeric,
  OUT userid            numeric,
  OUT username          varchar,
  OUT fullname          text,
  OUT phone             text,
  OUT email             text,
  OUT session_userid	numeric,
  OUT session_username	varchar,
  OUT session_fullname  text,
  OUT area              numeric,
  OUT area_code         varchar,
  OUT area_name	        varchar,
  OUT interface         numeric,
  OUT interface_sid     varchar,
  OUT interface_name    varchar
) RETURNS SETOF record
AS $$
  WITH cs AS (
      SELECT current_session() AS session
  )
  SELECT p.id, s.userid, cu.username, cu.fullname, cu.phone, cu.email,
         s.suid, su.username, su.fullname,
         s.area, a.code, a.name,
         s.interface, i.sid, i.name
    FROM db.session s INNER JOIN cs ON cs.session = s.key
                      INNER JOIN users cu ON cu.id = s.userid
                      INNER JOIN users su ON su.id = s.suid
                      INNER JOIN db.area a ON a.id = s.area
                      INNER JOIN db.interface i ON i.id = s.interface
  		               LEFT JOIN db.client p ON p.userid = s.userid;
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
-- api.current_area ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает данные текущей зоны.
 * @return {area} - Зона
 */
CREATE OR REPLACE FUNCTION api.current_area (
) RETURNS	area
AS $$
  SELECT * FROM area WHERE id = current_area();
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_area ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает зону.
 * @param {numeric} pArea - Идентификатор зоны
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_area (
  pArea	numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM SetArea(pArea);
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
-- api.current_interface -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает данные текущего интерфейса.
 * @return {interface} - Интерфейс
 */
CREATE OR REPLACE FUNCTION api.current_interface (
) RETURNS 	interface
AS $$
  SELECT * FROM interface WHERE id = current_interface();
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_interface -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает интерфейс.
 * @param {numeric} pInterface - Идентификатор интерфейса
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_interface (
  pInterface	numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM SetInterface(pInterface);
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
-- api.oper_date ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает дату операционного дня.
 * @return {timestamp} - Дата операционного дня
 */
CREATE OR REPLACE FUNCTION api.oper_date()
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_operdate (
  pOperDate 	timestamp,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM SetOperDate(pOperDate);
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
-- api.set_operdate ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает дату операционного дня.
 * @param {timestamptz} pOperDate - Дата операционного дня
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_operdate (
  pOperDate 	timestamptz,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM SetOperDate(pOperDate);
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_language (
  pLang		    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM SetLanguage(pLang);
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
-- api.set_language ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает по идентификатору текущий язык.
 * @param {text} pCode - Код языка
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_language (
  pCode 	    text default 'ru',
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM SetLanguage(pCode);
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
-- EVENT LOG -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.event_log
AS
  SELECT * FROM EventLog;

GRANT SELECT ON api.event_log TO daemon;

--------------------------------------------------------------------------------
-- api.event_log ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Журнал событий текущего пользователя.
 * @param {char} pType - Тип события: {M|W|E}
 * @param {integer} pCode - Код
 * @param {timestamp} pDateFrom - Дата начала периода
 * @param {timestamp} pDateTo - Дата окончания периода
 * @return {SETOF api.event_log} - Записи
 */
CREATE OR REPLACE FUNCTION api.event_log (
  pType		    char default null,
  pCode		    numeric default null,
  pDateFrom	    timestamp default null,
  pDateTo	    timestamp default null
) RETURNS	    SETOF api.event_log
AS $$
  SELECT *
    FROM api.event_log
   WHERE type = coalesce(pType, type)
     AND username = current_username()
     AND code = coalesce(pCode, code)
     AND datetime >= coalesce(pDateFrom, MINDATE())
     AND datetime < coalesce(pDateTo, MAXDATE())
   ORDER BY datetime DESC, id
   LIMIT 500
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.write_to_log ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.write_to_log (
  pType		    text,
  pCode		    numeric,
  pText		    text,
  OUT result	boolean,
  OUT message	text
) RETURNS	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM WriteToEventLog(pType, pCode, pText);

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
 * @out param {numeric} id - Id учётной записи
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_user (
  pUserName     varchar,
  pPassword     text,
  pFullName     text,
  pPhone        text default null,
  pEmail        text default null,
  pDescription  text default null,
  OUT id        numeric,
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := CreateUser(pUserName, pPassword, pFullName, pPhone, pEmail, pDescription);
  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_user -------------------------------------------------------------
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_user (
  pId			        numeric,
  pUserName		        varchar,
  pPassword		        text,
  pFullName		        text,
  pPhone		        text,
  pEmail		        text,
  pDescription		    text,
  pPasswordChange 	    boolean,
  pPasswordNotChange	boolean,
  OUT id		        numeric,
  OUT result		    boolean,
  OUT message		    text
) RETURNS 		        record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM UpdateUser(pId, pUserName, pPassword, pFullName, pPhone, pEmail, pDescription, pPasswordChange, pPasswordNotChange);

  id := pId;
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
-- api.del_user ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет учётную запись пользователя.
 * @param {numeric} pId - Идентификатор учётной записи пользователя
 * @out {numeric} id - Идентификатор учётной записи пользователя
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_user (
  pId		    numeric,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteUser(pId);

  id := pId;
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
  r		    users%rowtype;
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1000) THEN
      IF coalesce(pId, current_userid()) <> current_userid() THEN
        PERFORM AccessDenied();
      END IF;
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
-- api.list_user ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает учётные записи пользователей.
 * @return {SETOF users} - Учётные записи пользователей
 */
CREATE OR REPLACE FUNCTION api.list_user (
  pId		numeric default null
) RETURNS	SETOF users
AS $$
DECLARE
  r		    users%rowtype;
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1000) THEN
      IF coalesce(pId, current_userid()) <> current_userid() THEN
        PERFORM AccessDenied();
      END IF;
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.change_password (
  pId			numeric,
  pOldPass		text,
  pNewPass		text,
  OUT result	boolean,
  OUT message	text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  result := CheckPassword(GetUserName(pId), pOldPass);
  message := GetErrorMessage();

  IF result THEN
    PERFORM SetPassword(pId, pNewPass);
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
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
  pUserId		    numeric default current_userid(),
  OUT id		    numeric,
  OUT username		varchar,
  OUT fullname		text,
  OUT description   text
) RETURNS		    SETOF record
AS $$
  SELECT g.id, g.username, g.fullname, g.description
    FROM db.member_group m INNER JOIN groups g ON g.id = m.userid
   WHERE member = pUserId
     AND current_session() IS NOT NULL;
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
  pUserId           numeric default current_userid(),
  OUT id            numeric,
  OUT username      varchar,
  OUT fullname      text,
  OUT description   text
) RETURNS           SETOF record
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
 * @out param {text} message - Текст ошибки/результата
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.user_lock (
  pId           numeric,
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM UserLock(pId);

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
-- api.user_unlock -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Снимает блокировку с учётной записи пользователя.
 * @param {numeric} pId - Идентификатор учётной записи пользователя
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки/результата
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.user_unlock (
  pId			numeric,
  OUT result		boolean,
  OUT message		text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM UserUnlock(pId);

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
  OUT iptable	text
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
 * @out param {text} message - Текст ошибки/результата
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_user_iptable (
  pId			numeric,
  pType			char,
  pIpTable		text,
  OUT result		boolean,
  OUT message		text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM SetIPTableStr(pId, pType, pIpTable);

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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_group (
  pGroupName	varchar,
  pFullName     text,
  pDescription  text default null,
  OUT id        numeric,
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := CreateGroup(pGroupName, pFullName, pDescription);
  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_group ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет учётные данные группы.
 * @param {numeric} pId - Идентификатор группы
 * @param {varchar} pGroupName - Группа
 * @param {text} pFullName - Полное имя
 * @param {text} pDescription - Описание
 * @out {numeric} id - Идентификатор группы
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_group (
  pId           numeric,
  pGroupName    varchar,
  pFullName     text,
  pDescription  text,
  OUT id        numeric,
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM UpdateGroup(pId, pGroupName, pFullName, pDescription);

  id := pId;
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
-- api.del_group ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет группу.
 * @param {numeric} pId - Идентификатор группы
 * @out {numeric} id - Идентификатор группы
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_group (
  pId           numeric,
  OUT id        numeric,
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteGroup(pId);

  id := pId;
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
-- api.get_group ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает группу.
 * @return {record} - Группа
 */
CREATE OR REPLACE FUNCTION api.get_group (
  pId			numeric
) RETURNS		groups
AS $$
  SELECT * FROM groups WHERE id = pId AND current_session() IS NOT NULL;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_group --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список групп.
 * @return {record} - Группы
 */
CREATE OR REPLACE FUNCTION api.list_group (
) RETURNS		SETOF groups
AS $$
  SELECT * FROM groups WHERE current_session() IS NOT NULL;
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.member_group_add (
  pMember		numeric,
  pGroup		numeric,
  OUT result    boolean,
  OUT message   text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM AddMemberToGroup(pMember, pGroup);
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
-- api.member_group_del --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет группу для пользователя.
 * @param {numeric} pMember - Идентификатор пользователя
 * @param {numeric} pGroup - Идентификатор группы, при null удаляет все группы для указанного пользователя
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.member_group_del (
  pMember		numeric,
  pGroup		numeric,
  OUT result    boolean,
  OUT message   text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteGroupForMember(pMember, pGroup);
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
-- api.group_member_del --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет пользователя из группу.
 * @param {numeric} pGroup - Идентификатор группы
 * @param {numeric} pMember - Идентификатор пользователя, при null удаляет всех пользователей из указанной группы
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.group_member_del (
  pGroup		numeric,
  pMember		numeric default null,
  OUT result    boolean,
  OUT message   text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteMemberFromGroup(pGroup, pMember);
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
  pGroupId          numeric,
  OUT id            numeric,
  OUT username      varchar,
  OUT fullname      text,
  OUT email         text,
  OUT status        text,
  OUT description   text
) RETURNS		    SETOF record
AS $$
  SELECT u.id, u.username, u.fullname, u.email, u.status, u.description
    FROM db.member_group m INNER JOIN users u ON u.id = m.member
   WHERE m.userid = pGroupId
     AND current_session() IS NOT NULL;
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
  pUserId		    numeric default current_userid(),
  OUT id		    numeric,
  OUT username		varchar,
  OUT fullname		text,
  OUT description   text
) RETURNS		    SETOF record
AS $$
  SELECT * FROM api.member_user(pUserId)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_groups_json ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_groups_json (
  pMember	numeric
) RETURNS	json
AS $$
DECLARE
  arResult	json[];
  r		    record;
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
-- api.is_user_role ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.is_user_role (
  pRole         numeric,
  pUser         numeric default session_userid(),
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  message := 'Успешно.';
  result := IsUserRole(pRole, pUser);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.is_user_role ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.is_user_role (
  pRole         text,
  pUser         text default session_username(),
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  message := 'Успешно.';
  result := IsUserRole(pRole, pUser);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AREA ------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.area_type
AS
  SELECT * FROM AreaType;

GRANT SELECT ON api.area_type TO daemon;

--------------------------------------------------------------------------------
-- api.get_area_type -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Позвращает тип зоны.
 * @param {numeric} pId - Идентификатор типа зоны
 * @return {record} - Запись
 */
CREATE OR REPLACE FUNCTION api.get_area_type (
  pId		numeric
) RETURNS	api.area_type
AS $$
  SELECT * FROM api.area_type WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.area
AS
  SELECT * FROM Area;

GRANT SELECT ON api.area TO daemon;

--------------------------------------------------------------------------------
-- api.add_area ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт зону.
 * @param {numeric} pParent - Идентификатор "родителя"
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Id зоны
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_area (
  pParent       numeric,
  pType         numeric,
  pCode         varchar,
  pName         varchar,
  pDescription  text default null,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS       record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := CreateArea(pParent, pType, pCode, pName, pDescription);
  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_area -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет зону.
 * @param {numeric} pId - Идентификатор зоны
 * @param {numeric} pParent - Идентификатор "родителя"
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @param {timestamptz} pValidFromDate - Дата открытия
 * @param {timestamptz} pValidToDate - Дата закрытия
 * @out param {numeric} id - Id зоны
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_area (
  pId			    numeric,
  pParent		    numeric default null,
  pType			    numeric default null,
  pCode			    varchar default null,
  pName			    varchar default null,
  pDescription		text default null,
  pValidFromDate	timestamptz default null,
  pValidToDate		timestamptz default null,
  OUT id		    numeric,
  OUT result		boolean,
  OUT message		text
) RETURNS 		    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM EditArea(pId, pParent, pType, pCode, pName, pDescription, pValidFromDate, pValidToDate);

  id := pId;
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
-- api.del_area ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет зону.
 * @param {numeric} pId - Идентификатор зоны
 * @out {numeric} id - Идентификатор зоны
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_area (
  pId		    numeric,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteArea(pId);

  id := pId;
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
-- api.list_area ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список подразделений.
 * @return {record} - Группы
 */
CREATE OR REPLACE FUNCTION api.list_area (
) RETURNS		SETOF api.area
AS $$
  SELECT * FROM api.area;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_area ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает данные зоны.
 * @return {record} - Данные зоны
 */
CREATE OR REPLACE FUNCTION api.get_area (
  pId			numeric
) RETURNS		api.area
AS $$
  SELECT * FROM api.area WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_area_add ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет пользователя или группу в зону.
 * @param {numeric} pMember - Идентификатор пользователя/группы
 * @param {numeric} pArea - Идентификатор зоны
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.member_area_add (
  pMember		numeric,
  pArea		    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM AddMemberToArea(pMember, pArea);
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
-- api.member_area_del ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет зону для пользователя.
 * @param {numeric} pMember - Идентификатор пользователя
 * @param {numeric} pArea - Идентификатор зоны, при null удаляет все зоны для указанного пользователя
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.member_area_del (
  pMember		numeric,
  pArea			numeric,
  OUT result    boolean,
  OUT message   text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteAreaForMember(pMember, pArea);
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
-- api.area_member_del ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет пользователя из зоны.
 * @param {numeric} pArea - Идентификатор зоны
 * @param {numeric} pMember - Идентификатор пользователя, при null удаляет всех пользователей из указанного зоны
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.area_member_del (
  pArea		    numeric,
  pMember		numeric default null,
  OUT result    boolean,
  OUT message   text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteMemberFromArea(pArea, pMember);
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
-- VIEW api.member_area --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.member_area
AS
  SELECT * FROM MemberArea;

GRANT SELECT ON api.member_area TO daemon;

--------------------------------------------------------------------------------
-- api.area_member -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список участников зоны.
 * @return {SETOF record} - Запись
 */
CREATE OR REPLACE FUNCTION api.area_member (
  pAreaId		    numeric,
  OUT id		    numeric,
  OUT type		    char,
  OUT username		varchar,
  OUT fullname		text,
  OUT email		    text,
  OUT description   text,
  OUT status		text,
  OUT system		text
) RETURNS		    SETOF record
AS $$
  SELECT g.id, 'G' AS type, g.username, g.fullname, null AS email, g.description, null AS status, g.system
    FROM api.member_area m INNER JOIN groups g ON g.id = m.memberid
   WHERE m.area = pAreaId
     AND current_session() IS NOT NULL
  UNION ALL
  SELECT u.id, 'U' AS type, u.username, u.fullname, u.email, u.description, u.status, u.system
    FROM api.member_area m INNER JOIN users u ON u.id = m.memberid
   WHERE m.area = pAreaId
     AND current_session() IS NOT NULL;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_area -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает зоны доступные участнику.
 * @return {record} - Данные зоны
 */
CREATE OR REPLACE FUNCTION api.member_area (
  pUserId		numeric default current_userid()
) RETURNS		SETOF api.area
AS $$
  SELECT *
    FROM api.area
   WHERE id in (
     SELECT area FROM db.member_area WHERE member = (
       SELECT id FROM db.user WHERE id = pUserId
     )
   )
   UNION ALL
  SELECT *
    FROM api.area
   WHERE id in (
     SELECT area FROM db.member_area WHERE member IN (
       SELECT userid FROM db.member_group WHERE member = (
         SELECT id FROM db.user WHERE id = pUserId
       )
     )
   )
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- INTERFACE -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.interface
AS
  SELECT * FROM Interface;

GRANT SELECT ON api.interface TO daemon;

--------------------------------------------------------------------------------
-- api.add_interface -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт интерфейс.
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Идентификатор интерфейса
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_interface (
  pName		    varchar,
  pDescription	text default null,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := CreateInterface(pName, pDescription);
  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_interface --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет интерфейс.
 * @param {numeric} pId - Идентификатор интерфейса
 * @param {varchar} pName - Наименование
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Идентификатор интерфейса
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_interface (
  pId		    numeric,
  pName		    varchar,
  pDescription	text default null,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM UpdateInterface(pId, pName, pDescription);

  id := pId;
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
-- api.del_interface -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет интерфейс.
 * @param {numeric} pId - Идентификатор интерфейса
 * @out {numeric} id - Идентификатор интерфейса
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_interface (
  pId		    numeric,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteInterface(pId);

  id  := pId;
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
-- api.get_interface -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает данные интерфейса.
 * @return {record} - Данные интерфейса
 */
CREATE OR REPLACE FUNCTION api.get_interface (
  pId			numeric
) RETURNS		api.interface
AS $$
  SELECT * FROM api.interface WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_interface_add ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет пользователя или группу к рабочему месту.
 * @param {numeric} pMember - Идентификатор пользователя/группы
 * @param {numeric} pInterface - Идентификатор интерфейса
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.member_interface_add (
  pMember		numeric,
  pInterface	numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM AddMemberToInterface(pMember, pInterface);
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
-- api.member_interface_del ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет интерфейс для пользователя или группу.
 * @param {numeric} pMember - Идентификатор пользователя/группы
 * @param {numeric} pInterface - Идентификатор интерфейса, при null удаляет все рабочие места для указанного пользователя
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.member_interface_del (
  pMember		numeric,
  pInterface	numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteInterfaceForMember(pMember, pInterface);
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
-- api.interface_member_del ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет пользователя или группу из интерфейса.
 * @param {numeric} pInterface - Идентификатор интерфейса
 * @param {numeric} pMember - Идентификатор пользователя/группы, при null удаляет всех пользователей из указанного интерфейса
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.interface_member_del (
  pInterface	numeric,
  pMember		numeric default null,
  OUT result	boolean,
  OUT message	text
) RETURNS 		record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteMemberFromInterface(pInterface, pMember);
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
-- api.member_interface --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.member_interface
AS
  SELECT * FROM MemberInterface;

GRANT SELECT ON api.member_interface TO daemon;

--------------------------------------------------------------------------------
-- api.interface_member --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список участников интерфейса.
 * @return {SETOF record} - Запись
 */
CREATE OR REPLACE FUNCTION api.interface_member (
  pInterfaceId      numeric,
  OUT id            numeric,
  OUT type          char,
  OUT username      varchar,
  OUT fullname      text,
  OUT email         text,
  OUT description   text,
  OUT status        text,
  OUT system        text
) RETURNS           SETOF record
AS $$
  SELECT g.id, 'G' AS type, g.username, g.fullname, null AS email, g.description, null AS status, g.system
    FROM api.member_interface m INNER JOIN groups g ON g.id = m.memberid
   WHERE m.interface = pInterfaceId
     AND current_session() IS NOT NULL
  UNION ALL
  SELECT u.id, 'U' AS type, u.username, u.fullname, u.email, u.description, u.status, u.system
    FROM api.member_interface m INNER JOIN users u ON u.id = m.memberid
   WHERE m.interface = pInterfaceId
     AND current_session() IS NOT NULL;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.member_interface --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает рабочее места доступные участнику.
 * @return {record} - Данные интерфейса
 */
CREATE OR REPLACE FUNCTION api.member_interface (
  pUserId		numeric default current_userid()
) RETURNS		SETOF api.interface
AS $$
  SELECT *
    FROM api.interface
   WHERE id in (
     SELECT interface FROM db.member_interface WHERE member = (
       SELECT id FROM db.user WHERE id = pUserId
     )
   )
   UNION ALL
  SELECT *
    FROM api.interface
   WHERE id in (
     SELECT interface FROM db.member_interface WHERE member IN (
       SELECT userid FROM db.member_group WHERE member = (
         SELECT id FROM db.user WHERE id = pUserId
       )
     )
   )
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- REGISTRY --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.registry
AS
  SELECT * FROM Registry;

GRANT SELECT ON api.registry TO daemon;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.registry (
  pId		numeric,
  pKey		numeric,
  pSubKey	numeric
) RETURNS	SETOF api.registry
AS $$
  SELECT *
    FROM api.registry
   WHERE id = coalesce(pId, id)
     AND key = coalesce(pKey, key)
     AND subkey = coalesce(pSubKey, subkey)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.registry_ex
AS
  SELECT * FROM RegistryEx;

GRANT SELECT ON api.registry_ex TO daemon;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.registry_ex (
  pId		numeric,
  pKey		numeric,
  pSubKey	numeric
) RETURNS	SETOF api.registry_ex
AS $$
  SELECT *
    FROM api.registry_ex
   WHERE id = coalesce(pId, id)
     AND key = coalesce(pKey, key)
     AND subkey = coalesce(pSubKey, subkey)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.registry_key
AS
  SELECT * FROM RegistryKey;

GRANT SELECT ON api.registry_key TO daemon;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.registry_key (
  pId		numeric,
  pRoot		numeric,
  pParent	numeric,
  pKey		text
) RETURNS	SETOF api.registry_key
AS $$
  SELECT *
    FROM api.registry_key
   WHERE id = coalesce(pId, id)
     AND root = coalesce(pRoot, root)
     AND parent = coalesce(pParent, parent)
     AND key = coalesce(pKey, key)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.registry_value
AS
  SELECT * FROM RegistryValue;

GRANT SELECT ON api.registry_value TO daemon;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.registry_value_ex
AS
  SELECT * FROM RegistryValueEx;

GRANT SELECT ON api.registry_value_ex TO daemon;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.registry_value (
  pId		numeric,
  pKey		numeric
) RETURNS	SETOF api.registry_value
AS $$
  SELECT *
    FROM api.registry_value
   WHERE id = coalesce(pId, id)
     AND key = coalesce(pKey, key)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.registry_value_ex (
  pId		numeric,
  pKey		numeric
) RETURNS	SETOF api.registry_value_ex
AS $$
  SELECT *
    FROM api.registry_value_ex
   WHERE id = coalesce(pId, id)
     AND key = coalesce(pKey, key)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.registry_get_reg_key (
  pKey		    numeric,
  OUT key	    text,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  key := get_reg_key(pKey);

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
-- api.registry_enum_key -------------------------------------------------------
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
CREATE OR REPLACE FUNCTION api.registry_enum_key (
  pKey		    text,
  pSubKey	    text,
  OUT id	    numeric,
  OUT key	    text,
  OUT subkey	text
) RETURNS	    SETOF record
AS $$
  SELECT R.id, pKey, get_reg_key(R.id) FROM RegEnumKey(RegOpenKey(pKey, pSubKey)) AS R;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.registry_enum_value -----------------------------------------------------
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
CREATE OR REPLACE FUNCTION api.registry_enum_value (
  pKey		    text,
  pSubKey	    text,
  OUT id	    numeric,
  OUT key	    text,
  OUT subkey	text,
  OUT valuename	text,
  OUT value	    variant
) RETURNS	    SETOF record
AS $$
  SELECT R.id, pKey, pSubKey, R.vname, get_reg_value(R.id) FROM RegEnumValue(RegOpenKey(pKey, pSubKey)) AS R;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.registry_enum_value_ex --------------------------------------------------
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
CREATE OR REPLACE FUNCTION api.registry_enum_value_ex (
  pKey		    text,
  pSubKey	    text,
  OUT id	    numeric,
  OUT key	    text,
  OUT subkey	text,
  OUT valuename	text,
  OUT vtype	    integer,
  OUT vinteger	integer,
  OUT vnumeric	numeric,
  OUT vdatetime	timestamp,
  OUT vstring	text,
  OUT vboolean	boolean
) RETURNS	    SETOF record
AS $$
  SELECT R.id, pKey, pSubKey, R.vname, R.vtype, R.vinteger, R.vnumeric, R.vdatetime, R.vstring, R.vboolean FROM RegEnumValueEx(RegOpenKey(pKey, pSubKey)) AS R;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.registry_write ----------------------------------------------------------
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.registry_write (
  pId		    numeric,
  pKey		    text,
  pSubKey	    text,
  pValueName	text,
  pType		    integer,
  pData		    anynonarray,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS	    record
AS $$
DECLARE
  vData		    Variant;
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
    SELECT * INTO result, message FROM result_success();
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.registry_read -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Чтение из реестра.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey.
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @param {text} pValueName - Имя устанавливаемого значения. Если значение с таким именем не существует в ключе реестра, функция его создает.
 * @out param {Variant} data - Данные
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.registry_read (
  pKey		    text,
  pSubKey	    text,
  pValueName	text,
  OUT data	    Variant,
  OUT result	boolean,
  OUT message	text
) RETURNS	    record
AS $$
BEGIN
  result := false;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  data := RegGetValue(RegOpenKey(pKey, pSubKey), pValueName);

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
-- api.registry_delete_key -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет подключ и его значения.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey.
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.registry_delete_key (
  pKey		    text,
  pSubKey	    text,
  OUT result	boolean,
  OUT message	text
) RETURNS	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  IF RegDeleteKey(pKey, pSubKey) THEN
    SELECT * INTO result, message FROM result_success();
  ELSE
    result := false;
    message := GetErrorMessage();
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.registry_delete_value ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет указанное значение из указанного ключа реестра и подключа.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey.
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @param {text} pValueName - Имя удаляемого значения.
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.registry_delete_value (
  pId		    numeric,
  pKey		    text,
  pSubKey	    text,
  pValueName	text,
  OUT result	boolean,
  OUT message	text
) RETURNS	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  IF pId IS NOT NULL THEN
    PERFORM DelRegKeyValue(pId);
    SELECT * INTO result, message FROM result_success();
  ELSE
    IF RegDeleteKeyValue(pKey, pSubKey, pValueName) THEN
      SELECT * INTO result, message FROM result_success();
    ELSE
      result := false;
      message := GetErrorMessage();
    END IF;
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.registry_delete_tree ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет подключи и значения указанного ключа рекурсивно.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey.
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.registry_delete_tree (
  pKey		    text,
  pSubKey	    text,
  OUT result	boolean,
  OUT message	text
) RETURNS	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  IF RegDeleteTree(pKey, pSubKey) THEN
    SELECT * INTO result, message FROM result_success();
  ELSE
    result := false;
    message := GetErrorMessage();
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- KERNEL ----------------------------------------------------------------------
--------------------------------------------------------------------------------

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
  pScheme       text,
  pTable        text,
  pSearch       jsonb default null,
  pFilter       jsonb default null,
  pLimit        integer default null,
  pOffSet       integer default null,
  pOrderBy      jsonb default null
) RETURNS       text
AS $$
DECLARE
  r             record;

  vWith         text;
  vSelect       text;
  vWhere        text;
  vJoin         text;

  vCondition    text;
  vField        text;
  vCompare      text;
  vValue        text;
  vLStr         text;
  vRStr         text;

  arTables      text[];
  arValues      text[];
  arColumns     text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  arTables := array_cat(null, ARRAY['charge_point', 'card', 'client', 'invoice', 'order', 'calendar', 'tariff', 'client_tariff',
      'address', 'address_tree',
      'object_file', 'object_data', 'object_address', 'object_coordinates',
      'status_notification', 'transaction', 'meter_value']);

  IF array_position(arTables, pTable) IS NULL THEN
    PERFORM IncorrectValueInArray(pTable, 'sql/api/table', arTables);
  END IF;

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
-- LANGUAGE --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.language ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Язык
 */
CREATE OR REPLACE VIEW api.language
AS
  SELECT * FROM language;

GRANT SELECT ON api.language TO daemon;

--------------------------------------------------------------------------------
-- WORKFLOW --------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * Сущность
 */
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_class (
  pParent	    numeric,
  pType		    numeric,
  pCode		    varchar,
  pLabel	    text,
  pAbstract	    boolean default true,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := AddClass(pParent, pType, pCode, pLabel, pAbstract);
  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_class ------------------------------------------------------------
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_class (
  pId		    numeric,
  pParent	    numeric,
  pType		    numeric,
  pCode		    varchar,
  pLabel	    text,
  pAbstract	    boolean default true,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM EditClass(pId, pParent, pType, pCode, pLabel, pAbstract);

  id := pId;
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
-- api.del_class ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет класс.
 * @param {numeric} pId - Идентификатор класса
 * @out {numeric} id - Идентификатор класса
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_class (
  pId		    numeric,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteClass(pId);

  id := pId;
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
-- api.get_class ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает класс.
 * @return {record} - Запись
 */
CREATE OR REPLACE FUNCTION api.get_class (
  pId			numeric
) RETURNS		SETOF api.class
AS $$
  SELECT * FROM api.class WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_class --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список классов.
 * @return {SETOF record} - Записи
 */
CREATE OR REPLACE FUNCTION api.list_class (
) RETURNS		SETOF api.class
AS $$
  SELECT * FROM api.class
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
  pId		numeric
) RETURNS	api.state_type
AS $$
  SELECT * FROM api.state_type WHERE id = pId;
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_state (
  pClass	    numeric,
  pType		    numeric,
  pCode		    varchar,
  pLabel	    text,
  pSequence	    integer,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := AddState(pClass, pType, pCode, pLabel, pSequence);
  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_state ------------------------------------------------------------
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_state (
  pId		    numeric,
  pClass	    numeric default null,
  pType		    numeric default null,
  pCode		    varchar default null,
  pLabel	    text default null,
  pSequence	    integer default null,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM EditState(pId, pClass, pType, pCode, pLabel, pSequence);

  id := pId;
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
-- api.del_state ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет состояние.
 * @param {numeric} pId - Идентификатор состояния
 * @out param {numeric} id - Идентификатор состояния
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_state (
  pId		    numeric,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteState(pId);

  id := pId;
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
-- api.get_state ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает состояние.
 * @return {record} - Состояние
 */
CREATE OR REPLACE FUNCTION api.get_state (
  pId			numeric
) RETURNS		api.state
AS $$
  SELECT * FROM api.state WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_state --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список состояний.
 * @return {SETOF record} - Записи
 */
CREATE OR REPLACE FUNCTION api.list_state (
) RETURNS		SETOF api.state
AS $$
  SELECT * FROM api.state
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_method (
  pParent	    numeric,
  pClass	    numeric,
  pState	    numeric,
  pAction	    numeric,
  pCode		    varchar,
  pLabel	    text,
  pSequence	    integer,
  pVisible	    boolean,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := AddMethod(pParent, pClass, pState, pAction, pCode, pLabel, pSequence, pVisible);
  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_method -----------------------------------------------------------
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_method (
  pId		    numeric,
  pParent	    numeric default null,
  pClass	    numeric default null,
  pState	    numeric default null,
  pAction	    numeric default null,
  pCode		    varchar default null,
  pLabel	    text default null,
  pSequence	    integer default null,
  pVisible	    boolean default null,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM EditMethod(pId, pParent, pClass, pState, pAction, pCode, pLabel, pSequence, pVisible);

  id := pId;
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
-- api.del_method --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет метод (операцию).
 * @param {numeric} pId - Идентификатор метода
 * @out param {numeric} id - Идентификатор метода
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_method (
  pId		    numeric,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteMethod(pId);

  id := pId;
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
-- api.get_method --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает методы объекта.
 * @param {numeric} pClass - Идентификатор класса
 * @param {numeric} pState - Идентификатор состояния
 * @param {numeric} pAction - Идентификатор действия
 * @out param {numeric} id - Идентификатор метода
 * @out param {numeric} parent - Идентификатор метода родителя
 * @out param {numeric} action - Идентификатор действия
 * @out param {varchar} actioncode - Код действия
 * @out param {text} label - Описание метода
 * @out param {boolean} visible - Скрытый метод: Да/Нет
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.get_method (
  pClass		    numeric,
  pState		    numeric default null,
  pAction		    numeric default null,
  OUT id		    numeric,
  OUT parent		numeric,
  OUT action		numeric,
  OUT actioncode	varchar,
  OUT label		    text,
  OUT visible		boolean
) RETURNS		    SETOF record
AS $$
  SELECT m.id, m.parent, m.action, m.actioncode, m.label, m.visible
    FROM api.method m
   WHERE m.class = pClass
     AND m.state = coalesce(pState, m.state)
     AND m.action = coalesce(pAction, m.action)
   ORDER BY m.sequence
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_methods_json --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_methods_json (
  pClass	numeric,
  pState	numeric
) RETURNS	json
AS $$
DECLARE
  arResult	json[];
  r		    record;
BEGIN
  FOR r IN SELECT * FROM api.get_method(pClass, pState)
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_methods_jsonb -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_methods_jsonb (
  pClass	numeric,
  pState	numeric
) RETURNS	jsonb
AS $$
BEGIN
  RETURN api.get_methods_json(pClass, pState);
END;
$$ LANGUAGE plpgsql
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_transition (
  pState	    numeric,
  pMethod	    numeric,
  pNewState	    numeric,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := AddTransition(pState, pMethod, pNewState);
  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_transition -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет переход в новое состояние.
 * @param {numeric} pId - Идентификатор перехода
 * @param {numeric} pState - Идентификатор состояния
 * @param {numeric} pMethod - Идентификатор метода (операции)
 * @param {varchar} pNewState - Идентификатор нового состояния
 * @out param {numeric} id - Идентификатор перехода
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_transition (
  pId		    numeric,
  pState	    numeric default null,
  pMethod	    numeric default null,
  pNewState	    numeric default null,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM EditTransition(pId, pState, pMethod, pNewState);

  id := pId;
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
-- api.del_transition ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет переход в новое состояние.
 * @param {numeric} pId - Идентификатор перехода
 * @out param {numeric} id - Идентификатор перехода
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_transition (
  pId		    numeric,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteTransition(pId);

  id := pId;
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
-- api.get_transition ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает переход.
 * @return {record} - Запись
 */
CREATE OR REPLACE FUNCTION api.get_transition (
  pId		numeric
) RETURNS	api.transition
AS $$
  SELECT * FROM api.transition WHERE id = pId
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
  pId		numeric
) RETURNS	api.event_type
AS $$
  SELECT * FROM api.event_type WHERE id = pId;
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_event (
  pClass	    numeric,
  pType		    numeric,
  pAction	    numeric,
  pLabel	    text,
  pText		    text,
  pSequence	    integer,
  pEnabled	    boolean,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := AddEvent(pClass, pType, pAction, pLabel, pText, pSequence, pEnabled);
  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_event ------------------------------------------------------------
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_event (
  pId		    numeric,
  pClass	    numeric default null,
  pType		    numeric default null,
  pAction	    numeric default null,
  pLabel	    text default null,
  pText		    text default null,
  pSequence	    integer default null,
  pEnabled	    boolean default null,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM EditEvent(pId, pClass, pType, pAction, pLabel, pText, pSequence, pEnabled);

  id := pId;
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
-- api.del_event ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет событие.
 * @param {numeric} pId - Идентификатор события
 * @out param {numeric} id - Идентификатор события
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_state (
  pId		    numeric,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteEvent(pId);

  id := pId;
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
-- api.get_event ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает событыие.
 * @return {record} - Запись
 */
CREATE OR REPLACE FUNCTION api.get_event (
  pId		numeric
) RETURNS	api.event
AS $$
  SELECT * FROM api.event WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.run_action --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выполняет действие над объектом.
 * @param {numeric} pObject - Идентификатор объекта
 * @param {numeric} pAction - Идентификатор действия
 * @param {jsonb} pForm - Форма в формате JSON
 * @out param {numeric} id - Идентификатор объекта
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.run_action (
  pObject	    numeric,
  pAction	    numeric,
  pForm		    jsonb default null,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS	    record
AS $$
DECLARE
  nId		    numeric;
  nMethod	    numeric;
BEGIN
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

  PERFORM ExecuteObjectAction(pObject, pAction, pForm);

  id := pObject;
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
-- api.run_action --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выполняет действие над объектом по коду.
 * @param {numeric} pObject - Идентификатор объекта
 * @param {varchar} pCode - Код действия
 * @param {jsonb} pForm - Форма в формате JSON
 * @out param {numeric} id - Идентификатор объекта
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.run_action (
  pObject	    numeric,
  pCode		    varchar,
  pForm		    jsonb default null,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS	    record
AS $$
DECLARE
  arCodes	    text[];
  r		        record;
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  FOR r IN SELECT code FROM db.action
  LOOP
    arCodes := array_append(arCodes, r.code);
  END LOOP;

  IF array_position(arCodes, pCode::text) IS NULL THEN
    PERFORM IncorrectCode(pCode, arCodes);
  END IF;

  SELECT * INTO id, result, message FROM api.run_action(pObject, GetAction(pCode), pForm);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
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
 * @param {jsonb} pForm - Форма в формате JSON
 * @out param {numeric} id - Идентификатор объекта
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.run_method (
  pObject	    numeric,
  pMethod	    numeric,
  pForm		    jsonb default null,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS	    record
AS $$
DECLARE
  nId		    numeric;
  nAction	    numeric;
BEGIN
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

  SELECT * INTO id, result, message FROM api.run_action(pObject, nAction, pForm);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.object_force_del --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Принудительно "удаляет" документ (минуя события документооборота).
 * @param {numeric} pObject - Идентификатор объекта
 * @out param {numeric} id - Идентификатор
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.object_force_del (
  pObject	    numeric,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS	    record
AS $$
DECLARE
  nId		    numeric;
  nState	    numeric;
BEGIN
  result := false;

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  SELECT o.id INTO nId FROM db.object o WHERE o.id = pObject;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pObject);
  END IF;

  SELECT s.id INTO nState FROM db.state s WHERE s.class = GetObjectClass(pObject) AND s.code = 'deleted';

  IF found THEN
    PERFORM AddObjectState(pObject, nState);

    id := pObject;
    SELECT * INTO result, message FROM result_success();
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
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
-- api.type --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.type (
  pEssence	numeric
) RETURNS	SETOF api.type
AS $$
  SELECT * FROM api.type WHERE essence = pEssence;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_type (
  pClass	    numeric,
  pCode		    varchar,
  pName		    varchar,
  pDescription	text default null,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := AddType(pClass, pCode, pName, pDescription);
  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_type -------------------------------------------------------------
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_type (
  pId		    numeric,
  pClass	    numeric default null,
  pCode		    varchar default null,
  pName		    varchar default null,
  pDescription	text default null,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM EditType(pId, pClass, pCode, pName, pDescription);

  id := pId;
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
-- api.del_type ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет тип.
 * @param {numeric} pId - Идентификатор типа
 * @out param {numeric} id - Идентификатор типа
 * @out param {numeric} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_type (
  pId		    numeric,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM DeleteType(pId);

  id := pId;
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
-- api.get_type ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает тип.
 * @return {Type} - Тип
 */
CREATE OR REPLACE FUNCTION api.get_type (
  pId			numeric
) RETURNS		record
AS $$
  SELECT * FROM api.type WHERE id = pId
$$ LANGUAGE SQL
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
-- api.list_type ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает тип списоком.
 * @return {SETOF record} - Записи
 */
CREATE OR REPLACE FUNCTION api.list_type (
) RETURNS		SETOF api.type
AS $$
  SELECT * FROM api.type
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT FILE -----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.object_file -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object_file
AS
  SELECT * FROM ObjectFile;

GRANT SELECT ON api.object_file TO daemon;

--------------------------------------------------------------------------------
-- api.set_object_files_json ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_files_json (
  pObject	    numeric,
  pFiles	    json,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
DECLARE
  arKeys	    text[];
  nId		    numeric;
  r		        record;
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  SELECT o.id INTO nId FROM db.object o WHERE o.id = pObject;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pObject);
  END IF;

  IF pFiles IS NOT NULL THEN
    arKeys := array_cat(arKeys, ARRAY['id', 'hash', 'name', 'path', 'size', 'date', 'delete']);
    PERFORM CheckJsonKeys('/object/file/files', arKeys, pFiles);

    FOR r IN SELECT * FROM json_to_recordset(pFiles) AS files(id numeric, hash text, name text, path text, size int, date timestamp, delete boolean)
    LOOP
      IF r.id IS NOT NULL THEN

        SELECT o.id INTO nId FROM db.object_file o WHERE o.id = r.id AND object = pObject;

        IF NOT FOUND THEN
          PERFORM ObjectNotFound('файл', r.name, r.id);
        END IF;

        IF coalesce(r.delete, false) THEN
          PERFORM DeleteObjectFile(r.id);
        ELSE
          PERFORM EditObjectFile(r.id, r.hash, r.name, r.path, r.size, r.date);
        END IF;
      ELSE
        nId := AddObjectFile(pObject, r.hash, r.name, r.path, r.size, r.date);
      END IF;
    END LOOP;

    id := pObject;
    SELECT * INTO result, message FROM result_success();
  ELSE
    PERFORM JsonIsEmpty();
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_files_jsonb --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_files_jsonb (
  pObject	    numeric,
  pFiles	    jsonb,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
  SELECT * FROM api.set_object_files_json(pObject, pFiles::json);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_files_json ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_files_json (
  pObject	numeric
) RETURNS	json
AS $$
BEGIN
  RETURN GetObjectFilesJson(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_files_jsonb --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_files_jsonb (
  pObject	numeric
) RETURNS	jsonb
AS $$
BEGIN
  RETURN GetObjectFilesJsonb(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_file ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает файлы объекта
 * @param {numeric} pId - Идентификатор объекта
 * @return {api.object_file}
 */
CREATE OR REPLACE FUNCTION api.get_object_file (
  pId		numeric
) RETURNS	api.object_file
AS $$
  SELECT * FROM api.object_file WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_object_file --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список файлов объекта.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.object_file}
 */
CREATE OR REPLACE FUNCTION api.list_object_file (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.object_file
AS $$
BEGIN
  RETURN QUERY EXECUTE CreateApiSql('api', 'object_file', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT DATA -----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.object_data_type --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object_data_type
AS
  SELECT * FROM ObjectDataType;

GRANT SELECT ON api.object_data_type TO daemon;

--------------------------------------------------------------------------------
-- api.get_object_data_type_by_code --------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_data_type_by_code (
  pCode		varchar
) RETURNS	numeric
AS $$
BEGIN
  RETURN GetObjectDataType(pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.object_data -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object_data
AS
  SELECT * FROM ObjectData;

GRANT SELECT ON api.object_data TO daemon;

--------------------------------------------------------------------------------
-- api.set_object_data ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает данные объекта
 * @param {numeric} pObject - Идентификатор объекта
 * @param {varchar} pType - Код типа данных
 * @param {varchar} pCode - Код
 * @param {text} pData - Данные
 * @out param {numeric} id - Идентификатор
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_object_data (
  pObject	    numeric,
  pType		    varchar,
  pCode		    varchar,
  pData		    text,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS       record
AS $$
DECLARE
  nId           numeric;
  nType         numeric;
  arTypes       text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  pType := lower(pType);
  arTypes := array_cat(arTypes, ARRAY['text', 'json', 'xml']);
  IF array_position(arTypes, pType::text) IS NULL THEN
    PERFORM IncorrectCode(pType, arTypes);
  END IF;

  nType := GetObjectDataType(pType);

  nId := SetObjectData(pObject, nType, pCode, pData);

  id := nId;
  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_data_json ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_data_json (
  pObject	    numeric,
  pData	        json,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
DECLARE
  nId		    numeric;
  nType         numeric;

  arKeys	    text[];
  arTypes       text[];

  r		        record;
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  SELECT o.id INTO nId FROM db.object o WHERE o.id = pObject;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pObject);
  END IF;

  IF pData IS NOT NULL THEN
    arKeys := array_cat(arKeys, ARRAY['id', 'type', 'code', 'data']);
    PERFORM CheckJsonKeys('/object/data', arKeys, pData);

    FOR r IN SELECT * FROM json_to_recordset(pData) AS data(id numeric, type varchar, code varchar, data text)
    LOOP
      arTypes := array_cat(arTypes, ARRAY['text', 'json', 'xml']);
      IF array_position(arTypes, r.type::text) IS NULL THEN
        PERFORM IncorrectCode(r.type, arTypes);
      END IF;

      nType := GetObjectDataType(r.type);

      IF r.id IS NOT NULL THEN
        SELECT o.id INTO nId FROM db.object_data o WHERE o.id = r.id AND object = pObject;

        IF NOT FOUND THEN
          PERFORM ObjectNotFound('данные', r.code, r.id);
        END IF;

        IF NULLIF(r.data, '') IS NULL THEN
          PERFORM DeleteObjectData(r.id);
        ELSE
          PERFORM EditObjectData(r.id, pObject, nType, r.code, r.data);
        END IF;
      ELSE
        nId := AddObjectData(pObject, nType, r.code, r.data);
      END IF;
    END LOOP;

    id := nId;
    SELECT * INTO result, message FROM result_success();
  ELSE
    PERFORM JsonIsEmpty();
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_data_jsonb ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_data_jsonb (
  pObject	    numeric,
  pData	        jsonb,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
  SELECT * FROM api.set_object_data_json(pObject, pData::json);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_data_json ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_data_json (
  pObject	numeric
) RETURNS	json
AS $$
BEGIN
  RETURN GetObjectDataJson(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_data_jsonb ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_data_jsonb (
  pObject	numeric
) RETURNS	jsonb
AS $$
BEGIN
  RETURN GetObjectDataJsonb(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_data ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает данные объекта
 * @param {numeric} pId - Идентификатор объекта
 * @return {api.object_data}
 */
CREATE OR REPLACE FUNCTION api.get_object_data (
  pId		numeric
) RETURNS	api.object_data
AS $$
  SELECT * FROM api.object_data WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_object_data --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список данных объекта.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.object_data}
 */
CREATE OR REPLACE FUNCTION api.list_object_data (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.object_data
AS $$
BEGIN
  RETURN QUERY EXECUTE CreateApiSql('api', 'object_data', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT COORDINATES ----------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.object_coordinates ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object_coordinates
AS
  SELECT * FROM ObjectCoordinates;

GRANT SELECT ON api.object_coordinates TO daemon;

--------------------------------------------------------------------------------
-- api.set_object_coordinates --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает координаты объекта
 * @param {numeric} pObject - Идентификатор объекта
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {numeric} pLatitude - Широта
 * @param {numeric} pLongitude - Долгота
 * @param {numeric} pAccuracy - Точность (высота над уровнем моря)
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Идентификатор
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_object_coordinates (
  pObject	    numeric,
  pCode		    varchar,
  pName		    varchar,
  pLatitude     numeric,
  pLongitude    numeric,
  pAccuracy     numeric,
  pDescription  text,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS       record
AS $$
DECLARE
  nId           numeric;
  nDataId       numeric;
  nType         numeric;
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  pCode := coalesce(pCode, 'geo');

  SELECT d.id INTO nId FROM db.object_coordinates d WHERE d.object = pObject AND d.code = pCode;
  SELECT d.id INTO nDataId FROM db.object_data d WHERE d.object = pObject AND d.code = 'geo';

  IF pName IS NOT NULL THEN
    IF nId IS NULL THEN
      nId := AddObjectCoordinates(pObject, pCode, pName, pLatitude, pLongitude, pAccuracy, pDescription);
    ELSE
      PERFORM EditObjectCoordinates(nId, pObject, pCode, pName, pLatitude, pLongitude, pAccuracy, pDescription);
    END IF;

    nType := GetObjectDataType('json');
    IF nDataId IS NULL THEN
      nDataId := AddObjectData(pObject, nType, 'geo',GetObjectCoordinatesJson(pObject)::text);
    ELSE
      PERFORM EditObjectData(nDataId, pObject, nType, 'geo',GetObjectCoordinatesJson(pObject)::text);
    END IF;
  ELSE
    PERFORM DeleteObjectData(nDataId);
    PERFORM DeleteObjectCoordinates(nId);
  END IF;

  id := nId;
  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_coordinates_json ---------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_coordinates_json (
  pObject	    numeric,
  pCoordinates  json,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
DECLARE
  nId		    numeric;
  nDataId       numeric;
  nType		    numeric;
  arKeys	    text[];
  r		        record;
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  SELECT o.id INTO nId FROM db.object o WHERE o.id = pObject;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pObject);
  END IF;

  IF pCoordinates IS NOT NULL THEN
    arKeys := array_cat(arKeys, ARRAY['id', 'code', 'name', 'latitude', 'longitude', 'accuracy', 'description']);
    PERFORM CheckJsonKeys('/object/coordinates', arKeys, pCoordinates);

    nType := GetObjectDataType('json');

    FOR r IN SELECT * FROM json_to_recordset(pCoordinates) AS coordinates(id numeric, code varchar, name varchar, latitude numeric, longitude numeric, accuracy numeric, description text)
    LOOP
      IF r.id IS NOT NULL THEN

        r.code := coalesce(NULLIF(r.code, ''), 'geo');

        SELECT o.id INTO nId FROM db.object_coordinates o WHERE o.id = r.id AND o.object = pObject;

        IF NOT FOUND THEN
          PERFORM ObjectNotFound('координаты', r.code, r.id);
        END IF;

        SELECT o.id INTO nDataId FROM db.object_data o WHERE o.object = pObject AND o.code = 'geo';

        IF coalesce(r.name, true) THEN
          PERFORM DeleteObjectData(nDataId);
          PERFORM DeleteObjectCoordinates(r.id);
        ELSE
          PERFORM EditObjectCoordinates(r.id, pObject, r.code, r.name, r.latitude, r.longitude, r.accuracy, r.description);
          PERFORM EditObjectData(nDataId, pObject, nType, 'geo',pCoordinates::text);
        END IF;
      ELSE
        nId := AddObjectCoordinates(pObject, r.code, r.name, r.latitude, r.longitude, r.accuracy, r.description);
        nDataId := AddObjectData(pObject, nType, 'geo',pCoordinates::text);
      END IF;
    END LOOP;

    id := nId;
    SELECT * INTO result, message FROM result_success();
  ELSE
    PERFORM JsonIsEmpty();
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_coordinates_jsonb --------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_coordinates_jsonb (
  pObject	    numeric,
  pCoordinates  jsonb,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
  SELECT * FROM api.set_object_coordinates_json(pObject, pCoordinates::json);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_coordinates_json ---------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_coordinates_json (
  pObject	numeric
) RETURNS	json
AS $$
BEGIN
  RETURN GetObjectCoordinatesJson(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_coordinates_jsonb --------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_coordinates_jsonb (
  pObject	numeric
) RETURNS	jsonb
AS $$
BEGIN
  RETURN GetObjectCoordinatesJsonb(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_coordinates --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает данные объекта
 * @param {numeric} pId - Идентификатор объекта
 * @return {api.object_coordinates}
 */
CREATE OR REPLACE FUNCTION api.get_object_coordinates (
  pId		numeric
) RETURNS	api.object_coordinates
AS $$
  SELECT * FROM api.object_coordinates WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_object_coordinates -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список данных объекта.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.object_coordinates}
 */
CREATE OR REPLACE FUNCTION api.list_object_coordinates (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.object_coordinates
AS $$
BEGIN
  RETURN QUERY EXECUTE CreateApiSql('api', 'object_coordinates', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT ADDRESS --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.object_address ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object_address
AS
  SELECT * FROM ObjectAddresses;

GRANT SELECT ON api.object_address TO daemon;

--------------------------------------------------------------------------------
-- api.set_object_addresses_json -----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_addresses_json (
  pObject	    numeric,
  pAddresses    json,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
DECLARE
  nId		    numeric;
  nType         numeric;
  nAddress      numeric;

  arKeys	    text[];
  arTypes       text[];

  r		        record;
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  SELECT o.id INTO nId FROM db.object o WHERE o.id = pObject;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pObject);
  END IF;

  IF pAddresses IS NOT NULL THEN
    arKeys := array_cat(arKeys, ARRAY['id', 'parent', 'type', 'code', 'index', 'country', 'region', 'district', 'city', 'settlement', 'street', 'house', 'building', 'structure', 'apartment', 'address']);
    PERFORM CheckJsonKeys('/object/address/addresses', arKeys, pAddresses);

    FOR r IN SELECT * FROM json_to_recordset(pAddresses) AS addresses(id numeric, parent numeric, type varchar, code varchar, index varchar, country varchar, region varchar, district varchar, city varchar, settlement varchar, street varchar, house varchar, building varchar, structure varchar, apartment varchar, address text)
    LOOP
      arTypes := array_cat(arTypes, ARRAY['post', 'actual', 'legal']);
      IF array_position(arTypes, r.type::text) IS NULL THEN
        PERFORM IncorrectCode(r.type, arTypes);
      END IF;

      nType := GetType(r.type || '.address');

      IF r.id IS NOT NULL THEN
        SELECT o.id INTO nAddress FROM db.address o WHERE o.id = r.id;

        IF NOT FOUND THEN
          PERFORM ObjectNotFound('адрес', r.code, r.id);
        END IF;

        PERFORM EditAddress(r.id, r.parent, nType, r.code, r.index, r.country, r.region, r.district, r.city, r.settlement, r.street, r.house, r.building, r.structure, r.apartment, r.address);
      ELSE
        nAddress := CreateAddress(r.parent, nType, r.code, r.index, r.country, r.region, r.district, r.city, r.settlement, r.street, r.house, r.building, r.structure, r.apartment, r.address);
        nId := SetObjectLink(pObject, nAddress);
      END IF;
    END LOOP;

    id := nId;
    SELECT * INTO result, message FROM result_success();
  ELSE
    PERFORM JsonIsEmpty();
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_addresses_jsonb ----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_addresses_jsonb (
  pObject	    numeric,
  pAddresses	jsonb,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
  SELECT * FROM api.set_object_addresses_json(pObject, pAddresses::json);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_addresses_json -----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_addresses_json (
  pObject	numeric
) RETURNS	json
AS $$
BEGIN
  RETURN GetObjectAddressesJson(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_addresses_jsonb ----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_addresses_jsonb (
  pObject	numeric
) RETURNS	jsonb
AS $$
BEGIN
  RETURN GetObjectAddressesJsonb(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_address ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает адрес объекта
 * @param {numeric} pObject - Идентификатор объекта
 * @param {numeric} pAddress - Идентификатор адреса
 * @param {timestamp} pDateFrom - Дата операции
 * @out param {numeric} id - Идентификатор
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_object_address (
  pObject	    numeric,
  pAddress	    numeric,
  pDateFrom	    timestamp default oper_date(),
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS       record
AS $$
BEGIN
 IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := SetObjectLink(pObject, pAddress, pDateFrom);

  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_address ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает адрес объекта
 * @param {numeric} pId - Идентификатор адреса
 * @return {api.object_address}
 */
CREATE OR REPLACE FUNCTION api.get_object_address (
  pId		numeric
) RETURNS	api.object_address
AS $$
  SELECT * FROM api.object_address WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_object_address -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список адресов объекта.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.object_address}
 */
CREATE OR REPLACE FUNCTION api.list_object_address (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.object_address
AS $$
BEGIN
  RETURN QUERY EXECUTE CreateApiSql('api', 'object_address', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DOCUMENT --------------------------------------------------------------------
--------------------------------------------------------------------------------

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
-- ADDRESS ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.address_tree ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.address_tree
AS
  SELECT * FROM AddressTree;

GRANT SELECT ON api.address_tree TO daemon;

--------------------------------------------------------------------------------
-- api.get_address_tree --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает адрес из справачника адресов КЛАДР
 * @param {numeric} pId - Идентификатор
 * @return {api.address_tree}
 */
CREATE OR REPLACE FUNCTION api.get_address_tree (
  pId		numeric
) RETURNS	api.address_tree
AS $$
  SELECT * FROM api.address_tree WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_address_tree -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает справачник адресов КЛАДР.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.address_tree} - Дерево адресов
 */
CREATE OR REPLACE FUNCTION api.list_address_tree (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.address_tree
AS $$
BEGIN
  RETURN QUERY EXECUTE CreateApiSql('api', 'address_tree', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_address_tree_history ------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает историю из справочника адресов
 * @param {numeric} pId - Идентификатор
 * @return {SETOF api.address_tree}
 */
CREATE OR REPLACE FUNCTION api.get_address_tree_history (
  pId		numeric
) RETURNS	SETOF api.address_tree
AS $$
  WITH RECURSIVE addr_tree(id, parent, code, name, short, index, level) AS (
    SELECT id, parent, code, name, short, index, level FROM db.address_tree WHERE id = pId
     UNION ALL
    SELECT a.id, a.parent, a.code, a.name, a.short, a.index, a.level
      FROM db.address_tree a, addr_tree t
     WHERE a.id = t.parent
  )
  SELECT * FROM addr_tree
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_address_tree_string -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает адрес из справочника адресов по коду в виде строки
 * @param {varchar} pCode - Код из справочника адресов: ФФ СС РРР ГГГ ППП УУУУ. Где: ФФ - код страны; СС - код субъекта РФ; РРР - код района; ГГГ - код города; ППП - код населенного пункта; УУУУ - код улицы.
 * @param {integer} pShort - Сокращение: 0 - нет; 1 - слева; 2 - справа
 * @param {integer} pLevel - Ограничение уровня вложенности
 * @out param {text} address - Адрес в виде текста
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.get_address_tree_string (
  pCode		    varchar,
  pShort	    integer default 0,
  pLevel	    integer default 0,
  OUT address   text,
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
BEGIN
 IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  address := GetAddressTreeString(pCode, pShort, pLevel);

  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  address := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.address -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.address
AS
  SELECT * FROM ObjectAddress;

GRANT SELECT ON api.address TO daemon;

--------------------------------------------------------------------------------
-- api.add_address -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет новый адрес.
 * @param {numeric} pParent - Идентификатор родителя | null
 * @param {varchar} pType - Код типа адреса
 * @param {varchar} pCode - Код: ФФ СС РРР ГГГ ППП УУУУ. Где: ФФ - код страны; СС - код субъекта РФ; РРР - код района; ГГГ - код города; ППП - код населенного пункта; УУУУ - код улицы.
 * @param {varchar} pIndex - Почтовый индекс
 * @param {varchar} pCountry - Страна
 * @param {varchar} pRegion - Регион
 * @param {varchar} pDistrict - Район
 * @param {varchar} pCity - Город
 * @param {varchar} pSettlement - Населённый пункт
 * @param {varchar} pStreet - Улица
 * @param {varchar} pHouse - Дом
 * @param {varchar} pBuilding - Корпус
 * @param {varchar} pStructure - Строение
 * @param {varchar} pApartment - Квартира
 * @param {text} pAddress - Полный адрес
 * @out param {numeric} id - Идентификатор адреса
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_address (
  pParent       numeric,
  pType         varchar,
  pCode         varchar,
  pIndex        varchar,
  pCountry      varchar,
  pRegion       varchar,
  pDistrict     varchar,
  pCity         varchar,
  pSettlement   varchar,
  pStreet       varchar,
  pHouse        varchar,
  pBuilding     varchar,
  pStructure    varchar,
  pApartment    varchar,
  pAddress      text default null,
  OUT id        numeric,
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
DECLARE
  nAddress      numeric;
  arTypes       text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  pType := lower(pType);
  arTypes := array_cat(arTypes, ARRAY['post', 'actual', 'legal']);
  IF array_position(arTypes, pType::text) IS NULL THEN
    PERFORM IncorrectCode(pType, arTypes);
  END IF;

  nAddress := CreateAddress(pParent, GetType(pType || '.address'), pCode, pIndex, pCountry, pRegion, pDistrict, pCity, pSettlement, pStreet, pHouse, pBuilding, pStructure, pApartment, pAddress);

  id := nAddress;
  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_address ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет данные адреса.
 * @param {numeric} pId - Идентификатор адреса
 * @param {numeric} pParent - Идентификатор родителя | null
 * @param {varchar} pType - Код типа адреса
 * @param {varchar} pCode - Код: ФФ СС РРР ГГГ ППП УУУУ. Где: ФФ - код страны; СС - код субъекта РФ; РРР - код района; ГГГ - код города; ППП - код населенного пункта; УУУУ - код улицы.
 * @param {varchar} pIndex - Почтовый индекс
 * @param {varchar} pCountry - Страна
 * @param {varchar} pRegion - Регион
 * @param {varchar} pDistrict - Район
 * @param {varchar} pCity - Город
 * @param {varchar} pSettlement - Населённый пункт
 * @param {varchar} pStreet - Улица
 * @param {varchar} pHouse - Дом
 * @param {varchar} pBuilding - Корпус
 * @param {varchar} pStructure - Строение
 * @param {varchar} pApartment - Квартира
 * @param {text} pAddress - Полный адрес
 * @out param {numeric} id - Идентификатор адреса
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_address (
  pId           numeric,
  pParent       numeric default null,
  pType         varchar default null,
  pCode         varchar default null,
  pIndex        varchar default null,
  pCountry      varchar default null,
  pRegion       varchar default null,
  pDistrict     varchar default null,
  pCity         varchar default null,
  pSettlement   varchar default null,
  pStreet       varchar default null,
  pHouse        varchar default null,
  pBuilding     varchar default null,
  pStructure    varchar default null,
  pApartment    varchar default null,
  pAddress      text default null,
  OUT id        numeric,
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
DECLARE
  nAddress      numeric;
  nType         numeric;
  arTypes       text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  SELECT a.id INTO nAddress FROM db.address a WHERE a.id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('адрес', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    pType := lower(pType);
    arTypes := array_cat(arTypes, ARRAY['post', 'actual', 'legal']);
    IF array_position(arTypes, pType::text) IS NULL THEN
      PERFORM IncorrectCode(pType, arTypes);
    END IF;
    nType := GetType(pType || '.address');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditAddress(nAddress, pParent, nType, pCode, pIndex, pCountry, pRegion, pDistrict, pCity, pSettlement, pStreet, pHouse, pBuilding, pStructure, pApartment, pAddress);

  id := nAddress;
  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_address -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает адрес
 * @param {numeric} pId - Идентификатор адреса
 * @return {api.address} - Адрес
 */
CREATE OR REPLACE FUNCTION api.get_address (
  pId		numeric
) RETURNS	api.address
AS $$
  SELECT * FROM api.address WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_address ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список адресов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.address} - Адреса
 */
CREATE OR REPLACE FUNCTION api.list_address (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.address
AS $$
BEGIN
  RETURN QUERY EXECUTE CreateApiSql('api', 'address', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_address_string ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает адрес в виде строки
 * @param {varchar} pId - Идентификатор адреса
 * @out param {text} address - Адрес в виде строки
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.get_address_string (
  pId		    numeric,
  OUT address   text,
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
BEGIN
 IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  address := GetAddressString(pId);

  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  address := null;
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
 * @param {numeric} pParent - Идентификатор родителя | null
 * @param {varchar} pType - Tип клиента
 * @param {varchar} pCode - ИНН - для юридического лица | Имя пользователя (login) | null
 * @param {numeric} pUserId - Идентификатор пользователя системы | null
 * @param {jsonb} pName - Полное наименование компании/Ф.И.О.
 * @param {jsonb} pPhone - Телефоны
 * @param {jsonb} pEmail - Электронные адреса
 * @param {jsonb} pInfo - Дополнительная информация
 * @param {text} pDescription - Информация о клиенте
 * @out param {numeric} id - Идентификатор
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_client (
  pParent       numeric,
  pType         varchar,
  pCode         varchar,
  pUserId       numeric,
  pName         jsonb,
  pPhone        jsonb default null,
  pEmail        jsonb default null,
  pInfo         jsonb default null,
  pDescription  text default null,
  OUT id        numeric,
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
DECLARE
  cn            record;
  nClient       numeric;
  arTypes       text[];
  arKeys        text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  pType := lower(pType);
  arTypes := array_cat(arTypes, ARRAY['entity', 'physical', 'individual']);
  IF array_position(arTypes, pType::text) IS NULL THEN
    PERFORM IncorrectCode(pType, arTypes);
  END IF;

  arKeys := array_cat(arKeys, ARRAY['name', 'short', 'first', 'last', 'middle']);
  PERFORM CheckJsonbKeys('add_client', arKeys, pName);

  SELECT * INTO cn FROM jsonb_to_record(pName) AS x(name varchar, short varchar, first varchar, last varchar, middle varchar);

  IF pUserId = 0 THEN
    pUserId := CreateUser(pCode, pCode, cn.short, pPhone->>0, pEmail->>0, cn.name);
  END IF;

  nClient := CreateClient(pParent, GetType(pType || '.client'), pCode, pUserId, pPhone, pEmail, pInfo, pDescription);

  PERFORM NewClientName(nClient, cn.name, cn.short, cn.first, cn.last, cn.middle);

  id := nClient;

  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_client -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет данные клиента.
 * @param {numeric} pId - Идентификатор (api.get_client)
 * @param {numeric} pParent - Идентификатор родителя | null
 * @param {varchar} pType - Tип клиента
 * @param {varchar} pCode - ИНН - для юридического лица | Имя пользователя (login) | null
 * @param {numeric} pUserId - Идентификатор пользователя системы | null
 * @param {jsonb} pName - Полное наименование компании/Ф.И.О.
 * @param {jsonb} pPhone - Телефоны
 * @param {jsonb} pEmail - Электронные адреса
 * @param {jsonb} pInfo - Дополнительная информация
 * @param {text} pDescription - Информация о клиенте
 * @out param {numeric} id - Идентификатор
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_client (
  pId           numeric,
  pParent       numeric,
  pType         varchar,
  pCode         varchar,
  pUserId       numeric,
  pName         jsonb,
  pPhone        jsonb default null,
  pEmail        jsonb default null,
  pInfo         jsonb default null,
  pDescription  text default null,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS       record
AS $$
DECLARE
  r             record;
  nType         numeric;
  nClient       numeric;
  arTypes       text[];
  arKeys        text[];
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
    arTypes := array_cat(arTypes, ARRAY['entity', 'physical', 'individual']);
    IF array_position(arTypes, pType::text) IS NULL THEN
      PERFORM IncorrectCode(pType, arTypes);
    END IF;
    nType := GetType(pType || '.client');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  arKeys := array_cat(arKeys, ARRAY['name', 'short', 'first', 'last', 'middle']);
  PERFORM CheckJsonbKeys('update_client', arKeys, pName);

  PERFORM EditClient(nClient, pParent, nType, pCode, pUserId, pPhone, pEmail, pInfo, pDescription);

  FOR r IN SELECT * FROM jsonb_to_record(pName) AS x(name varchar, short varchar, first varchar, last varchar, middle varchar)
  LOOP
    PERFORM EditClientName(nClient, r.name, r.short, r.first, r.last, r.middle);
  END LOOP;

  id := nClient;

  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
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
 * @param {numeric} pId - Идентификатор
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
-- api.list_client -------------------------------------------------------------
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
CREATE OR REPLACE FUNCTION api.list_client (
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
-- CLIENT TARIFF ---------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.client_tariff -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.client_tariff
AS
  SELECT * FROM ClientTariffs;

GRANT SELECT ON api.client_tariff TO daemon;

--------------------------------------------------------------------------------
-- api.set_client_tariffs_json -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_client_tariffs_json (
  pClient	    numeric,
  pTariffs      json,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
DECLARE
  nId		    numeric;
  nType         numeric;
  nTariff       numeric;

  arKeys	    text[];
  arTypes       text[];

  r		        record;
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  SELECT o.id INTO nId FROM db.client o WHERE o.id = pClient;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('клиент', 'id', pClient);
  END IF;

  IF pTariffs IS NOT NULL THEN
    arKeys := array_cat(arKeys, ARRAY['id', 'parent', 'type', 'code', 'name', 'cost', 'description']);
    PERFORM CheckJsonKeys('/client/tariff/tariffs', arKeys, pTariffs);

    FOR r IN SELECT * FROM json_to_recordset(pTariffs) AS addresses(id numeric, parent numeric, type varchar, code varchar, name varchar, cost numeric, description text)
    LOOP
      arTypes := array_cat(arTypes, ARRAY['client']);
      IF array_position(arTypes, r.type::text) IS NULL THEN
        PERFORM IncorrectCode(r.type, arTypes);
      END IF;

      nType := GetType(r.type || '.tariff');

      IF r.id IS NOT NULL THEN
        SELECT o.id INTO nTariff FROM db.address o WHERE o.id = r.id;

        IF NOT FOUND THEN
          PERFORM ObjectNotFound('тариф', r.code, r.id);
        END IF;

        PERFORM EditTariff(r.id, r.parent, nType, r.code, r.name, r.cost, r.description);
      ELSE
        nTariff := CreateTariff(r.parent, nType, r.code, r.name, r.cost, r.description);
        nId := SetObjectLink(pClient, nTariff);
      END IF;
    END LOOP;

    id := nId;
    SELECT * INTO result, message FROM result_success();
  ELSE
    PERFORM JsonIsEmpty();
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_client_tariffs_jsonb ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_client_tariffs_jsonb (
  pClient	    numeric,
  pTariffs	    jsonb,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
  SELECT * FROM api.set_client_tariffs_json(pClient, pTariffs::json);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_client_tariffs_json -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_client_tariffs_json (
  pClient	numeric
) RETURNS	json
AS $$
BEGIN
  RETURN GetClientTariffsJson(pClient);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_client_tariffs_jsonb ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_client_tariffs_jsonb (
  pClient	numeric
) RETURNS	jsonb
AS $$
BEGIN
  RETURN GetClientTariffsJsonb(pClient);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_client_tariff -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает тариф клиенту
 * @param {numeric} pClient - Идентификатор клиента
 * @param {numeric} pTariff - Идентификатор тарифа
 * @param {timestamp} pDateFrom - Дата операции
 * @out param {numeric} id - Идентификатор
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_client_tariff (
  pClient	    numeric,
  pTariff	    numeric,
  pDateFrom	    timestamp default oper_date(),
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS       record
AS $$
BEGIN
 IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  id := SetObjectLink(pClient, pTariff, pDateFrom);

  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_client_tariff -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает тариф клиента
 * @param {numeric} pId - Идентификатор записи
 * @return {api.client_tariff}
 */
CREATE OR REPLACE FUNCTION api.get_client_tariff (
  pId		numeric
) RETURNS	api.client_tariff
AS $$
  SELECT * FROM api.client_tariff WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_client_tariff ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает тарифы клиента.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.client_tariff}
 */
CREATE OR REPLACE FUNCTION api.list_client_tariff (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.client_tariff
AS $$
BEGIN
  RETURN QUERY EXECUTE CreateApiSql('api', 'client_tariff', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CARD ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.card --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.card
AS
  SELECT * FROM ObjectCard;

GRANT SELECT ON api.card TO daemon;

--------------------------------------------------------------------------------
-- api.add_card ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет карту.
 * @param {numeric} pParent - Ссылка на родительский объект: api.document | null
 * @param {varchar} pType - Tип карты
 * @param {numeric} pClient - Идентификатор
 * @param {varchar} pCode - Код
 * @param {text} pName - Наименование
 * @param {date} pExpire - Дата окончания
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Идентификатор карты
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_card (
  pParent       numeric,
  pType         varchar,
  pClient       numeric,
  pCode         varchar,
  pName         text default null,
  pExpire       date default null,
  pDescription  text default null,
  OUT id        numeric,
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
DECLARE
  nCard         numeric;
  arTypes       text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  pType := lower(pType);
  arTypes := array_cat(arTypes, ARRAY['rfid', 'bank', 'plastic']);
  IF array_position(arTypes, pType::text) IS NULL THEN
    PERFORM IncorrectCode(pType, arTypes);
  END IF;

  nCard := CreateCard(pParent, GetType(pType || '.card'), pClient, pCode, pName, pExpire, pDescription);

  id := nCard;

  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_card -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет данные карты.
 * @param {numeric} pId - Идентификатор карты (api.get_card)
 * @param {numeric} pParent - Ссылка на родительский объект: api.document | null
 * @param {varchar} pType - Tип карты
 * @param {numeric} pClient - Идентификатор
 * @param {varchar} pCode - Код
 * @param {text} pName - Наименование
 * @param {date} pExpire - Дата окончания
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Идентификатор карты
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_card (
  pId           numeric,
  pParent       numeric,
  pType         varchar,
  pClient       numeric,
  pCode         varchar,
  pName         text default null,
  pExpire       date default null,
  pDescription  text default null,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS       record
AS $$
DECLARE
  nType         numeric;
  nCard         numeric;
  arTypes       text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  SELECT c.id INTO nCard FROM db.card c WHERE c.id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('карта', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    pType := lower(pType);
    arTypes := array_cat(arTypes, ARRAY['rfid', 'bank', 'plastic']);
    IF array_position(arTypes, pType::text) IS NULL THEN
      PERFORM IncorrectCode(pType, arTypes);
    END IF;
    nType := GetType(pType || '.card');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditCard(nCard, pParent, nType, pClient,pCode, pName, pExpire, pDescription);

  id := nCard;

  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_card ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает клиента
 * @param {numeric} pId - Идентификатор
 * @return {api.card} - Клиент
 */
CREATE OR REPLACE FUNCTION api.get_card (
  pId		numeric
) RETURNS	api.card
AS $$
  SELECT * FROM api.card WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_card ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список клиентов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.card} - Клиенты
 */
CREATE OR REPLACE FUNCTION api.list_card (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.card
AS $$
BEGIN
  RETURN QUERY EXECUTE CreateApiSql('api', 'card', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CHARGE POINT ----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- CONNECTORS ------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- VIEW api.connectors ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.connectors
AS
  SELECT * FROM Connectors;

GRANT SELECT ON api.connectors TO daemon;

--------------------------------------------------------------------------------
-- api.connectors --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает разъёмы зарядной станций
 * @param {numeric} pChargePoint - Идентификатор зарядной станции
 * @return {SETOF api.connectors}
 */
CREATE OR REPLACE FUNCTION api.connectors (
  pChargePoint  numeric
) RETURNS	    SETOF api.connectors
AS $$
  SELECT *
    FROM api.connectors
   WHERE chargepoint = pChargePoint
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW api.charge_point -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.charge_point
AS
--  SELECT o.*, GetJsonConnectors(id) as connectors, g.data AS geo
  SELECT o.*, c.data::json as connectors, g.data::json AS geo
    FROM ObjectChargePoint o LEFT JOIN db.object_data c ON c.object = o.object AND c.code = 'connectors'
                             LEFT JOIN db.object_data g ON g.object = o.object AND g.code = 'geo';

GRANT SELECT ON api.charge_point TO daemon;

--------------------------------------------------------------------------------
-- FUNCTION api.add_charge_point -----------------------------------------------
--------------------------------------------------------------------------------

/**
 * Обновляет данные зарядной станции.
 * @param {numeric} pId - Идентификатор зарядной станции (api.get_charge_point)
 * @param {numeric} pParent - Идентификатор родителя | null
 * @param {varchar} pType - Tип зарядной станции
 * @param {numeric} pClient - Идентификатор клиента | null
 * @param {varchar} pIdentity - Строковый идентификатор зарядной станции
 * @param {varchar} pName - Наименование
 * @param {varchar} pModel - Required. This contains a value that identifies the model of the ChargePoint.
 * @param {varchar} pVendor - Required. This contains a value that identifies the vendor of the ChargePoint.
 * @param {varchar} pVersion - Optional. This contains the firmware version of the Charge Point.
 * @param {varchar} pSerialNumber - Optional. This contains a value that identifies the serial number of the Charge Point.
 * @param {varchar} pBoxSerialNumber - Optional. This contains a value that identifies the serial number of the Charge Box inside the Charge Point. Deprecated, will be removed in future version.
 * @param {varchar} pMeterSerialNumber - Optional. This contains the serial number of the main electrical meter of the Charge Point.
 * @param {varchar} piccid - Optional. This contains the ICCID of the modem’s SIM card.
 * @param {varchar} pimsi - Optional. This contains the IMSI of the modem’s SIM card.
 * @param {varchar} pDescription - Описание
 * @out param {numeric} id - Идентификатор
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_charge_point (
  pParent               numeric,
  pType                 varchar,
  pClient               numeric,
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
  pDescription          text default null,
  OUT id                numeric,
  OUT result            boolean,
  OUT message           text
) RETURNS               record
AS $$
DECLARE
  nId                   numeric;
  arTypes               text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  pType := lower(pType);
  arTypes := array_cat(arTypes, ARRAY['public', 'private']);
  IF array_position(arTypes, pType::text) IS NULL THEN
    PERFORM IncorrectCode(pType, arTypes);
  END IF;

  nId := CreateChargePoint(pParent, GetType(pType || '.charge_point'), pClient, pIdentity, pName, pModel, pVendor, pVersion,
    pSerialNumber, pBoxSerialNumber, pMeterSerialNumber, piccid, pimsi, pDescription);

  id := nId;
  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.update_charge_point --------------------------------------------
--------------------------------------------------------------------------------

/**
 * Меняет данные зарядной станции.
 * @param {numeric} pId - Идентификатор зарядной станции
 * @param {numeric} pParent - Идентификатор родителя | null
 * @param {varchar} pType - Tип зарядной станции
 * @param {numeric} pClient - Идентификатор клиента | null
 * @param {varchar} pIdentity - Строковый идентификатор зарядной станции
 * @param {varchar} pName - Наименование
 * @param {varchar} pModel - Required. This contains a value that identifies the model of the ChargePoint.
 * @param {varchar} pVendor - Required. This contains a value that identifies the vendor of the ChargePoint.
 * @param {varchar} pVersion - Optional. This contains the firmware version of the Charge Point.
 * @param {varchar} pSerialNumber - Optional. This contains a value that identifies the serial number of the Charge Point.
 * @param {varchar} pBoxSerialNumber - Optional. This contains a value that identifies the serial number of the Charge Box inside the Charge Point. Deprecated, will be removed in future version.
 * @param {varchar} pMeterSerialNumber - Optional. This contains the serial number of the main electrical meter of the Charge Point.
 * @param {varchar} piccid - Optional. This contains the ICCID of the modem’s SIM card.
 * @param {varchar} pimsi - Optional. This contains the IMSI of the modem’s SIM card.
 * @param {varchar} pDescription - Описание
 * @out param {numeric} id - Идентификатор
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_charge_point (
  pId                   numeric,
  pParent               numeric default null,
  pType                 varchar default null,
  pClient               numeric default null,
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
  pDescription          text default null,
  OUT id                numeric,
  OUT result            boolean,
  OUT message           text
) RETURNS               record
AS $$
DECLARE
  nId                   numeric;
  nType                 numeric;
  arTypes               text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  SELECT c.id INTO nId FROM db.charge_point c WHERE c.id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('зарядная станция', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    pType := lower(pType);
    arTypes := array_cat(arTypes, ARRAY['public', 'private']);
    IF array_position(arTypes, pType::text) IS NULL THEN
      PERFORM IncorrectCode(pType, arTypes);
    END IF;

    nType := GetType(pType || '.charge_point');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = nId;
  END IF;

  PERFORM EditChargePoint(nId, pParent, nType, pClient, pIdentity, pName, pModel, pVendor, pVersion,
    pSerialNumber, pBoxSerialNumber, pMeterSerialNumber, piccid, pimsi, pDescription);

  id := nId;
  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
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
 * @return {api.charge_point} - Зарядная станция
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
 * @return {api.charge_point} - Зарядная станция
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
-- api.list_charge_point -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список зарядных станций.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.charge_point} - Зарядные станции
 */
CREATE OR REPLACE FUNCTION api.list_charge_point (
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

--------------------------------------------------------------------------------
-- STATUS NOTIFICATION ---------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- VIEW api.status_notification ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.status_notification
AS
  SELECT * FROM StatusNotification;

GRANT SELECT ON api.status_notification TO daemon;

--------------------------------------------------------------------------------
-- api.status_notification -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает уведомления о статусе зарядной станций
 * @param {numeric} pChargePoint - Идентификатор зарядной станции
 * @param {integer} pConnectorId - Идентификатор разъёма зарядной станции
 * @param {timestamptz} pDate - Дата и время
 * @return {SETOF api.status_notification}
 */
CREATE OR REPLACE FUNCTION api.status_notification (
  pChargePoint  numeric,
  pConnectorId  integer default null,
  pDate         timestamptz default current_timestamp at time zone 'utc'
) RETURNS	    SETOF api.status_notification
AS $$
  SELECT *
    FROM api.status_notification
   WHERE chargepoint = pChargePoint
     AND connectorid = coalesce(pConnectorId, connectorid)
     AND pDate BETWEEN validfromdate AND validtodate
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_status_notification -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает уведомление о статусе зарядной станции.
 * @param {numeric} pId - Идентификатор
 * @return {api.status_notification}
 */
CREATE OR REPLACE FUNCTION api.get_status_notification (
  pId		numeric
) RETURNS	api.status_notification
AS $$
  SELECT * FROM api.status_notification WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_status_notification ------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает уведомления о статусе зарядных станций.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.status_notification}
 */
CREATE OR REPLACE FUNCTION api.list_status_notification (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.status_notification
AS $$
BEGIN
  RETURN QUERY EXECUTE CreateApiSql('api', 'status_notification', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- TRANSACTION -----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- VIEW api.transaction --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.transaction
AS
  SELECT * FROM Transaction;

GRANT SELECT ON api.transaction TO daemon;

--------------------------------------------------------------------------------
-- api.get_transaction ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает транзакцию зарядной станции.
 * @param {numeric} pId - Идентификатор
 * @return {api.transaction}
 */
CREATE OR REPLACE FUNCTION api.get_transaction (
  pId		numeric
) RETURNS	api.transaction
AS $$
  SELECT * FROM api.transaction WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_transaction --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает транзакции зарядных станций.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.transaction} - уведомление о статусе
 */
CREATE OR REPLACE FUNCTION api.list_transaction (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.transaction
AS $$
BEGIN
  RETURN QUERY EXECUTE CreateApiSql('api', 'transaction', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- METER VALUE -----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- VIEW api.meter_value --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.meter_value
AS
  SELECT * FROM MeterValue;

GRANT SELECT ON api.meter_value TO daemon;

--------------------------------------------------------------------------------
-- api.get_meter_value ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает показания счётчика зарядной станции.
 * @param {numeric} pId - Идентификатор
 * @return {api.meter_value}
 */
CREATE OR REPLACE FUNCTION api.get_meter_value (
  pId		numeric
) RETURNS	api.meter_value
AS $$
  SELECT * FROM api.meter_value WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_meter_value --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает показания счётчика зарядных станций.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.meter_value}
 */
CREATE OR REPLACE FUNCTION api.list_meter_value (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.meter_value
AS $$
BEGIN
  RETURN QUERY EXECUTE CreateApiSql('api', 'meter_value', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- INVOICE ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.invoice -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.invoice
AS
  SELECT * FROM ObjectInvoice;

GRANT SELECT ON api.invoice TO daemon;

--------------------------------------------------------------------------------
-- api.add_invoice -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет счёт на оплату.
 * @param {numeric} pParent - Ссылка на родительский объект: api.document | null
 * @param {varchar} pType - Tип
 * @param {varchar} pCode - Код
 * @param {numeric} pTransaction - Транзакция
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Идентификатор счёта
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_invoice (
  pParent       numeric,
  pType         varchar,
  pCode         varchar,
  pTransaction  numeric,
  pDescription  text default null,
  OUT id        numeric,
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
DECLARE
  nInvoice      numeric;
  arTypes       text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  pType := lower(pType);
  arTypes := array_cat(arTypes, ARRAY['meter']);
  IF array_position(arTypes, pType::text) IS NULL THEN
    PERFORM IncorrectCode(pType, arTypes);
  END IF;

  nInvoice := CreateInvoice(pParent, GetType(pType || '.invoice'), pCode, pTransaction, pDescription);

  id := nInvoice;

  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_invoice ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет параметры счёта на оплату (но не сам счёт).
 * @param {numeric} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {varchar} pType - Тип
 * @param {varchar} pCode - Код
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Идентификатор счёта
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_invoice (
  pId		    numeric,
  pParent	    numeric default null,
  pType		    varchar default null,
  pCode		    varchar default null,
  pDescription	text default null,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS       record
AS $$
DECLARE
  nType         numeric;
  nInvoice      numeric;
  arTypes       text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  SELECT c.id INTO nInvoice FROM db.invoice c WHERE c.id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('заказ', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    pType := lower(pType);
    arTypes := array_cat(arTypes, ARRAY['meter']);
    IF array_position(arTypes, pType::text) IS NULL THEN
      PERFORM IncorrectCode(pType, arTypes);
    END IF;
    nType := GetType(pType || '.invoice');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditInvoice(nInvoice, pParent, nType,pCode, pDescription);

  id := nInvoice;

  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_invoice -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает счёт
 * @param {numeric} pId - Идентификатор
 * @return {api.invoice} - Счёт
 */
CREATE OR REPLACE FUNCTION api.get_invoice (
  pId		numeric
) RETURNS	api.invoice
AS $$
  SELECT * FROM api.invoice WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_invoice ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список счетов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.invoice} - Счета
 */
CREATE OR REPLACE FUNCTION api.list_invoice (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.invoice
AS $$
BEGIN
  RETURN QUERY EXECUTE CreateApiSql('api', 'invoice', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ORDER -----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.order -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.order
AS
  SELECT * FROM ObjectOrder;

GRANT SELECT ON api.order TO daemon;

--------------------------------------------------------------------------------
-- api.add_order ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет ордер.
 * @param {numeric} pParent - Ссылка на родительский объект: api.document | null
 * @param {varchar} pType - Tип
 * @param {varchar} pCode - Код
 * @param {numeric} pClient - Клиент
 * @param {numeric} pAmount - Сумма
 * @param {numeric} pUuid - Универсальный уникальный идентификатор
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Идентификатор ордера
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_order (
  pParent       numeric,
  pType         varchar,
  pCode         varchar,
  pClient       numeric,
  pAmount       numeric,
  pUuid         uuid,
  pDescription  text default null,
  OUT id        numeric,
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
DECLARE
  nOrder      numeric;
  arTypes       text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  pType := lower(pType);
  arTypes := array_cat(arTypes, ARRAY['payment']);
  IF array_position(arTypes, pType::text) IS NULL THEN
    PERFORM IncorrectCode(pType, arTypes);
  END IF;

  nOrder := CreateOrder(pParent, GetType(pType || '.order'), pCode, pClient, pAmount, pUuid, pDescription);

  id := nOrder;

  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_order ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет ордер.
 * @param {numeric} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {numeric} pType - Тип: Type.Id
 * @param {varchar} pCode - Код
 * @param {numeric} pClient - Клиент
 * @param {numeric} pAmount - Сумма
 * @param {numeric} pUuid - Универсальный уникальный идентификатор
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Идентификатор ордера
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_order (
  pId		    numeric,
  pParent	    numeric default null,
  pType		    varchar default null,
  pCode		    varchar default null,
  pClient       numeric default null,
  pAmount       numeric default null,
  pUuid         uuid default null,
  pDescription	text default null,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS       record
AS $$
DECLARE
  nType         numeric;
  nOrder        numeric;
  arTypes       text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  SELECT c.id INTO nOrder FROM db.order c WHERE c.id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('заказ', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    pType := lower(pType);
    arTypes := array_cat(arTypes, ARRAY['payment']);
    IF array_position(arTypes, pType::text) IS NULL THEN
      PERFORM IncorrectCode(pType, arTypes);
    END IF;
    nType := GetType(pType || '.order');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditOrder(nOrder, pParent, nType,pCode, pClient, pAmount, pUuid, pDescription);

  id := nOrder;

  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_order ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает ордер
 * @param {numeric} pId - Идентификатор
 * @return {api.order} - Ордер
 */
CREATE OR REPLACE FUNCTION api.get_order (
  pId		numeric
) RETURNS	api.order
AS $$
  SELECT * FROM api.order WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_order --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список ордеров.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.order} - Ордера
 */
CREATE OR REPLACE FUNCTION api.list_order (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.order
AS $$
BEGIN
  RETURN QUERY EXECUTE CreateApiSql('api', 'order', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- REFERENCE -------------------------------------------------------------------
--------------------------------------------------------------------------------

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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_calendar (
  pCode         varchar,
  pName         varchar,
  pWeek         numeric,
  pDayOff       jsonb,
  pHoliday      jsonb,
  pWorkStart    interval,
  pWorkCount    interval,
  pRestStart    interval,
  pRestCount    interval,
  pDescription  text default null,
  OUT id        numeric,
  OUT result    boolean,
  OUT message   text
) RETURNS       record
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

  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_calendar ---------------------------------------------------------
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_calendar (
  pId		    numeric,
  pCode		    varchar default null,
  pName		    varchar default null,
  pWeek		    numeric default null,
  pDayOff	    jsonb default null,
  pHoliday	    jsonb default null,
  pWorkStart	interval default null,
  pWorkCount    interval default null,
  pRestStart	interval default null,
  pRestCount    interval default null,
  pDescription	text default null,
  OUT id	    numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
DECLARE
  nId		    numeric;
  nCalendar	    numeric;
  aHoliday	    integer[][2];
  r		        record;
BEGIN
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

  id := pId;
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
-- api.list_calendar -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает календарь списком.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.calendar} - Календари
 */
CREATE OR REPLACE FUNCTION api.list_calendar (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.calendar
AS $$
BEGIN
  RETURN QUERY EXECUTE CreateApiSql('api', 'calendar', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.fill_calendar (
  pCalendar     numeric,
  pDateFrom     date,
  pDateTo       date,
  pUserId       numeric default null,
  OUT result	boolean,
  OUT message	text
) RETURNS 	    record
AS $$
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  PERFORM FillCalendar(pCalendar, pDateFrom, pDateTo, pUserId);

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
-- FUNCTION api.list_calendar_date ----------------------------------------------
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
CREATE OR REPLACE FUNCTION api.list_calendar_date (
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
-- FUNCTION api.list_calendar_user ----------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает только даты календаря заданного пользователя за указанный период.
 * @param {numeric} pCalendar - Идентификатор календаря
 * @param {date} pDateFrom - Дата начала периода
 * @param {date} pDateTo - Дата окончания периода
 * @param {numeric} pUserId - Идентификатор учётной записи пользователя
 * @return {SETOF api.calendar_date} - Даты календаря
 */
CREATE OR REPLACE FUNCTION api.list_calendar_user (
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.set_calendar_date (
  pCalendar     numeric,
  pDate         date,
  pFlag         bit default null,
  pWorkStart	interval default null,
  pWorkCount	interval default null,
  pRestStart	interval default null,
  pRestCount	interval default null,
  pUserId       numeric default null,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS       record
AS $$
DECLARE
  nId           numeric;
  r             record;
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
  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
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
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.del_calendar_date (
  pCalendar     numeric,
  pDate         date,
  pUserId       numeric default null,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS       record
AS $$
DECLARE
  nId           numeric;
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  result := false;

  nId := GetCalendarDate(pCalendar, pDate, pUserId);
  IF nId IS NOT NULL THEN
    PERFORM DeleteCalendarDate(nId);
    SELECT * INTO result, message FROM result_success();
  ELSE
    message := 'В календаре нет указанной даты для заданного пользователя.';
  END IF;

  id := nId;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- TARIFF ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.tariff ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.tariff
AS
  SELECT * FROM ObjectTariff;

GRANT SELECT ON api.tariff TO daemon;

--------------------------------------------------------------------------------
-- api.add_tariff --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет тариф.
 * @param {numeric} pParent - Ссылка на родительский объект: api.document | null
 * @param {varchar} pType - Тип
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {numeric} pCost - Стоимость
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Идентификатор тарифа
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.add_tariff (
  pParent       numeric,
  pType         varchar,
  pCode         varchar,
  pName         varchar,
  pCost         numeric,
  pDescription	text default null,
  OUT id        numeric,
  OUT result    boolean,
  OUT message   text
) RETURNS       record
AS $$
DECLARE
  nTariff       numeric;
  arTypes       text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  pType := lower(pType);
  arTypes := array_cat(arTypes, ARRAY['client']);
  IF array_position(arTypes, pType::text) IS NULL THEN
    PERFORM IncorrectCode(pType, arTypes);
  END IF;

  nTariff := CreateTariff(pParent, GetType(pType || '.tariff'), pCode, pName, pCost, pDescription);

  id := nTariff;

  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_tariff -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет тариф.
 * @param {numeric} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {varchar} pType - Тип
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {numeric} pCost - Стоимость
 * @param {text} pDescription - Описание
 * @out param {numeric} id - Идентификатор тарифа
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.update_tariff (
  pId		    numeric,
  pParent       numeric default null,
  pType         varchar default null,
  pCode         varchar default null,
  pName         varchar default null,
  pCost         numeric default null,
  pDescription	text default null,
  OUT id        numeric,
  OUT result	boolean,
  OUT message	text
) RETURNS       record
AS $$
DECLARE
  nType         numeric;
  nTariff       numeric;
  arTypes       text[];
BEGIN
  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  SELECT c.id INTO nTariff FROM db.tariff c WHERE c.id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('тариф', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    pType := lower(pType);
    arTypes := array_cat(arTypes, ARRAY['client']);
    IF array_position(arTypes, pType::text) IS NULL THEN
      PERFORM IncorrectCode(pType, arTypes);
    END IF;
    nType := GetType(pType || '.tariff');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditTariff(nTariff, pParent, nType,pCode, pName, pCost, pDescription);

  id := nTariff;

  SELECT * INTO result, message FROM result_success();
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
  id := null;
  result := false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_tariff --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает заказ
 * @param {numeric} pId - Идентификатор
 * @return {api.tariff} - Тариф
 */
CREATE OR REPLACE FUNCTION api.get_tariff (
  pId		numeric
) RETURNS	api.tariff
AS $$
  SELECT * FROM api.tariff WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_tariff -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список клиентов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.tariff} - Клиенты
 */
CREATE OR REPLACE FUNCTION api.list_tariff (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.tariff
AS $$
BEGIN
  RETURN QUERY EXECUTE CreateApiSql('api', 'tariff', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OCPP ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- OCPP LOG --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.ocpp_log
AS
  SELECT * FROM ocppLog;

GRANT SELECT ON api.ocpp_log TO daemon;

--------------------------------------------------------------------------------
-- api.ocpp_log ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Журнал событий.
 * @param {varchar} pIdentity - Идентификатор зарядной станции
 * @param {varchar} pAction - Действие
 * @param {timestamp} pDateFrom - Дата начала периода
 * @param {timestamp} pDateTo - Дата окончания периода
 * @return {SETOF api.ocpp_log} - Записи
 */
CREATE OR REPLACE FUNCTION api.ocpp_log (
  pIdentity	varchar default null,
  pAction	varchar default null,
  pDateFrom	timestamp default null,
  pDateTo	timestamp default null
) RETURNS	SETOF api.ocpp_log
AS $$
  SELECT *
    FROM api.ocpp_log
   WHERE identity = coalesce(pIdentity, identity)
     AND action = coalesce(pAction, action)
     AND datetime >= coalesce(pDateFrom, MINDATE())
     AND datetime < coalesce(pDateTo, MAXDATE())
   ORDER BY datetime DESC
   LIMIT 50
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
