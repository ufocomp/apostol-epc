--------------------------------------------------------------------------------
-- DAEMON API ------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- daemon.Authorize ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Авторизовать.
 * @param {text} pSession - Сессия
 * @out param {boolean} success - Успех
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION daemon.Authorize (
  pSession      text,
  OUT success   boolean,
  OUT message	text
) RETURNS       record
AS $$
BEGIN
  success := kernel.Authorize(pSession);
  message := GetErrorMessage();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.SignIn ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Вход в систему (Аутентификация).
 * @param {jsonb} pPayload - Данные
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION daemon.SignIn (
  pPayload      jsonb,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       SETOF json
AS $$
DECLARE
  vMessage      text;
BEGIN
  pPayload := pPayload - 'agent';
  pPayload := pPayload - 'host';
  pPayload := pPayload || jsonb_build_object('agent', pAgent, 'host', pHost);

  RETURN NEXT api.fetch('/sign/in', pPayload);

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT;

  PERFORM SetErrorMessage(vMessage);

  RETURN NEXT json_build_object('error', json_build_object('code', 9000, 'message', vMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.SignToken ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Вход в систему по текену JWT.
 * @param {jsonb} pPayload - Данные
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION daemon.SignToken (
  pPayload      jsonb,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       SETOF json
AS $$
DECLARE
  claim         record;
  google        record;
  vMessage      text;
BEGIN
  pPayload := pPayload - 'agent';
  pPayload := pPayload - 'host';
  pPayload := pPayload || jsonb_build_object('agent', pAgent, 'host', pHost);

  FOR claim IN SELECT * FROM jsonb_to_record(pPayload) AS x(iss text, sub text, aud text, exp double precision, nbf double precision, iat double precision, jti text)
  LOOP
    IF claim.iss = 'accounts.google.com' THEN
      FOR claim IN SELECT * FROM jsonb_to_record(pPayload) AS x(email text, email_verified bool, name text, given_name text, family_name text, locale text, picture text)
      LOOP

      END LOOP;
    END IF;

  END LOOP;

  RETURN NEXT api.fetch('/sign/in', pPayload);

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT;

  PERFORM SetErrorMessage(vMessage);

  RETURN NEXT json_build_object('error', json_build_object('code', 9000, 'message', vMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.SignUp ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Регистрация нового пользователя.
 * @param {text} pUsername - Пользователь для su
 * @param {text} pPassword - Пароль для su
 * @param {jsonb} pPayload - Данные
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION daemon.SignUp (
  pUsername     text,
  pPassword     text,
  pPayload      jsonb
) RETURNS       SETOF json
AS $$
DECLARE
  vSession      text;
  vMessage      text;
BEGIN
  vSession := Login(session_user, pPassword);

  PERFORM SubstituteUser(pUsername, pPassword);

  BEGIN
    RETURN NEXT api.fetch('/sign/up', pPayload);

    PERFORM SessionOut(vSession, false);

    RETURN;
  EXCEPTION
  WHEN others THEN
    GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT;
  END;

  PERFORM SetErrorMessage(vMessage);

  IF vSession IS NOT NULL THEN
    PERFORM SessionOut(vSession, false);
  END IF;

  RETURN NEXT json_build_object('error', json_build_object('code', 5000, 'message', vMessage));

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT;

  PERFORM SetErrorMessage(vMessage);

  RETURN NEXT json_build_object('error', json_build_object('code', 9000, 'message', vMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.Fetch ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API с аутентификацией по имени пользователя и паролю.
 * @param {text} pUsername - Пользователь
 * @param {text} pPassword - Пароль
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
* @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION daemon.Fetch (
  pUsername     text,
  pPassword     text,
  pPath	        text,
  pPayload      jsonb DEFAULT null,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       SETOF json
AS $$
DECLARE
  r             record;

  nApiId        numeric;
  dtBegin       timestamptz;

  vSession      text;
  vMessage      text;
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  pPath := lower(pPath);

  nApiId := AddApiLog(pPath, pPayload);

  vSession := Login(pUsername, pPassword, pAgent, pHost);

  BEGIN
    dtBegin := clock_timestamp();

	FOR r IN SELECT * FROM api.fetch(pPath, pPayload)
	LOOP
      RETURN NEXT r.fetch;
    END LOOP;

    UPDATE api.log SET runtime = age(clock_timestamp(), dtBegin) WHERE id = nApiId;

    PERFORM SessionOut(vSession, false);

    RETURN;
  EXCEPTION
  WHEN others THEN
    GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT;
  END;

  PERFORM SetErrorMessage(vMessage);

  IF current_session() IS NOT NULL THEN
    UPDATE api.log SET eventid = AddEventLog('E', 5000, vMessage) WHERE id = nApiId;
  END IF;

  IF vSession IS NOT NULL THEN
    PERFORM SessionOut(vSession, false);
  END IF;

  RETURN NEXT json_build_object('error', json_build_object('code', 5000, 'message', vMessage));

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT;

  PERFORM SetErrorMessage(vMessage);

  RETURN NEXT json_build_object('error', json_build_object('code', 9000, 'message', vMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.AuthFetch ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API с аутентификацией по сессии и одноразовому ключу.
 * @param {text} pSession - Сессия
 * @param {text} pPassword - Пароль
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION daemon.AuthFetch (
  pSession      text,
  pKey          text,
  pPath	        text,
  pPayload      jsonb DEFAULT null,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       SETOF json
AS $$
DECLARE
  r             record;

  nApiId        numeric;
  dtBegin       timestamptz;

  auth          record;
  vMessage      text;
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  pPath := lower(pPath);

  nApiId := AddApiLog(pPath, pPayload);

  BEGIN
    SELECT * INTO auth FROM api.authenticate(pSession, pKey, pAgent, pHost);

    RETURN NEXT row_to_json(auth);

    IF auth.result THEN
      dtBegin := clock_timestamp();

	  FOR r IN SELECT * FROM api.fetch(pPath, pPayload)
	  LOOP
        RETURN NEXT r.fetch;
      END LOOP;

      UPDATE api.log SET runtime = age(clock_timestamp(), dtBegin) WHERE id = nApiId;
    END IF;

    RETURN;
  EXCEPTION
  WHEN others THEN
    GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT;
  END;

  PERFORM SetErrorMessage(vMessage);

  IF current_session() IS NOT NULL THEN
    UPDATE api.log SET eventid = AddEventLog('E', 5000, vMessage) WHERE id = nApiId;
  END IF;

  RETURN NEXT json_build_object('error', json_build_object('code', 5000, 'message', vMessage));

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT;

  PERFORM SetErrorMessage(vMessage);

  RETURN NEXT json_build_object('error', json_build_object('code', 9000, 'message', vMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.TokenFetch -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API с проверкой JWT токена.
 * @param {text} pPassword - Пароль для su
 * @param {text} pToken - Токен JWT
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION daemon.TokenFetch (
  pPassword     text,
  pToken        text,
  pPath	        text,
  pPayload      jsonb DEFAULT null,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       SETOF json
AS $$
DECLARE
  r             record;

  nApiId        numeric;

  dtBegin       timestamptz;

  claim         record;
  clean         record;

  vSession      text;
  vMessage      text;
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  pPath := lower(pPath);

  nApiId := AddApiLog(pPath, pPayload);

  BEGIN
    SELECT * INTO clean FROM verify(pToken, SecretKey());

    IF coalesce(clean.valid, false) THEN


      --IF SessionIn(pSession, pAgent, pHost) IS NULL THEN
      --  PERFORM AuthenticateError(GetErrorMessage());
      --END IF;

      vSession := Login(session_user, pPassword, pAgent, pHost);

      PERFORM SubstituteUser(pUsername, pPassword);

      dtBegin := clock_timestamp();

	  FOR r IN SELECT * FROM api.fetch(pPath, pPayload)
	  LOOP
        RETURN NEXT r.fetch;
      END LOOP;

      PERFORM SessionOut(vSession, false);

      UPDATE api.log SET runtime = age(clock_timestamp(), dtBegin) WHERE id = nApiId;

      RETURN;
    END IF;

    PERFORM TokenError();
  EXCEPTION
  WHEN others THEN
    GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT;
  END;

  PERFORM SetErrorMessage(vMessage);

  IF current_session() IS NOT NULL THEN
    UPDATE api.log SET eventid = AddEventLog('E', 5000, vMessage) WHERE id = nApiId;
  END IF;

  IF vSession IS NOT NULL THEN
    PERFORM SessionOut(vSession, false);
  END IF;

  RETURN NEXT json_build_object('error', json_build_object('code', 5000, 'message', vMessage));

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT;

  PERFORM SetErrorMessage(vMessage);

  RETURN NEXT json_build_object('error', json_build_object('code', 9000, 'message', vMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- daemon.SignFetch ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API с проверкой подписи методом HMAC-SHA256.
 * @param {text} pPath - Путь
 * @param {json} pJson - Данные в JSON
 * @param {text} pSession - Сессия
 * @param {double precision} pNonce - Время в миллисекундах
 * @param {text} pSignature - Подпись
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @param {interval} pTimeWindow - Временное окно
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION daemon.SignFetch (
  pPath	        text,
  pJson         json DEFAULT null,
  pSession      text DEFAULT null,
  pNonce        double precision DEFAULT null,
  pSignature    text DEFAULT null,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null,
  pTimeWindow   INTERVAL DEFAULT '5 sec'
) RETURNS       SETOF json
AS $$
DECLARE
  r             record;

  Payload       jsonb;

  nApiId        numeric;

  dtBegin       timestamptz;
  dtTimeStamp   timestamptz;

  vMessage      text;

  passed        boolean;
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  pPath := lower(pPath);
  pJson := NULLIF(pJson::text, '{}');

  Payload := pJson::jsonb;

  IF pTimeWindow > INTERVAL '1 min' THEN
    pTimeWindow := INTERVAL '1 min';
  END IF;

  nApiId := AddApiLog(pPath, Payload);

  BEGIN
    dtTimeStamp := coalesce(to_timestamp(pNonce / 1000000), Now());

    IF (dtTimeStamp < (Now() + INTERVAL '1 sec') AND (Now() - dtTimeStamp) <= pTimeWindow) THEN

      SELECT (pSignature = GetSignature(pPath, pNonce, pJson, secret)) INTO passed
        FROM db.session
       WHERE key = pSession;

      IF NOT coalesce(passed, false) THEN
        PERFORM SignatureError();
      END IF;

      IF SessionIn(pSession, pAgent, pHost) IS NULL THEN
        PERFORM AuthenticateError(GetErrorMessage());
      END IF;

      dtBegin := clock_timestamp();

	  FOR r IN SELECT * FROM api.fetch(pPath, Payload)
	  LOOP
        RETURN NEXT r.fetch;
      END LOOP;

      UPDATE api.log SET runtime = age(clock_timestamp(), dtBegin) WHERE id = nApiId;

      RETURN;
    ELSE
	  PERFORM NonceExpired();
    END IF;
  EXCEPTION
  WHEN others THEN
    GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT;
  END;

  PERFORM SetErrorMessage(vMessage);

  IF current_session() IS NOT NULL THEN
    UPDATE api.log SET eventid = AddEventLog('E', 5000, vMessage) WHERE id = nApiId;
  END IF;

  RETURN NEXT json_build_object('error', json_build_object('code', 5000, 'message', vMessage));

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT;

  PERFORM SetErrorMessage(vMessage);

  RETURN NEXT json_build_object('error', json_build_object('code', 9000, 'message', vMessage));

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ParseToken ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ParseToken (
  pUserId	    numeric,
  pToken        jsonb
) RETURNS	    numeric
AS $$
DECLARE
  claim         record;
  nId           numeric;
  nProvider     numeric;
  nAudience     numeric;
  vCode         text;
BEGIN
  FOR claim IN SELECT * FROM json_to_record(pToken) AS x(iss text, aud text, sub text, exp double precision, nbf double precision, iat double precision, jti text)
  LOOP
    SELECT provider INTO nProvider FROM db.issuer WHERE code = claim.iss;

    IF NOT found THEN
      PERFORM IssuerNotFound(claim.iss);
    END IF;

    SELECT id INTO nAudience FROM db.audience WHERE provider = nProvider AND code = claim.aud;

    IF NOT found THEN
      PERFORM AudienceNotFound(claim.aud);
    END IF;

    SELECT id INTO nId FROM db.auth WHERE audience = nAudience AND code = claim.sub;

    IF found THEN
      RAISE EXCEPTION 'Учётная запись для внешнего пользователя "%" уже зарегистрирована.', claim.sub;
    END IF;

    PERFORM CreateAuth(pUserId, nAudience, claim.sub);

    SELECT code INTO vCode FROM db.provider WHERE id = nProvider;
    IF vCode = 'google' THEN
      FOR claim IN SELECT * FROM json_to_record(pToken) AS x(email text, email_verified bool, name text, given_name text, family_name text, locale text, picture text)
      LOOP
        UPDATE db.user SET email = coalesce(claim.email, email) WHERE Id = pUserId;
        UPDATE db.profile
           SET email_verified = coalesce(claim.email_verified, email_verified),
               picture = coalesce(claim.picture, picture)
         WHERE userid = pUserId;
      END LOOP;
    END IF;
  END LOOP;
    
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
