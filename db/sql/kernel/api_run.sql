--------------------------------------------------------------------------------
-- api.run ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выполнить команду APIs/API в формате JSON.
 * @param {text} pRoute - Путь
 * @param {jsonb} pJson - JSON
 * @param {text} pSession - Ключ сессии
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION api.run (
  pRoute	text,
  pJson		jsonb default null,
  pSession	text default null
) RETURNS	SETOF json
AS $$
DECLARE
  nApiId	numeric;
  nEventId	numeric;

  r		record;
  e		record;

  nKey		integer;
  Search	jsonb; 

  arJson	json[]; 

  tsBegin	timestamp;

  arKeys	text[];
  vError	text;
BEGIN
  IF pRoute IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  nKey := 0;
  nApiId := AddApiLog(pRoute, pJson);
  pSession := NULLIF(pSession, '');

  IF lower(pRoute) <> '/login' AND pSession IS NOT NULL THEN
    IF NOT SessionLogin(pSession) THEN
      RETURN NEXT json_build_object('session', pSession, 'result', false, 'error', GetErrorMessage());
      RETURN;
    END IF;
  END IF;

  BEGIN
    tsBegin := clock_timestamp();

    CASE lower(pRoute)
    WHEN '/login' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['username', 'password', 'host', 'session']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF pJson ? 'session' THEN
        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(session text, host inet)
        LOOP
          RETURN NEXT row_to_json(api.slogin(r.session, r.host));
        END LOOP;
      ELSE
        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(username text, password text, host inet)
        LOOP
          RETURN NEXT row_to_json(api.login(r.username, r.password, r.host));
        END LOOP;
      END IF;

    WHEN '/logout' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['session', 'logoutall']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(session text, logoutall boolean)
      LOOP
        RETURN NEXT row_to_json(api.logout(coalesce(r.session, current_session()), r.logoutall));
      END LOOP;

    WHEN '/su' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['username', 'password']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(username varchar, password text)
      LOOP
        RETURN NEXT row_to_json(api.su(coalesce(r.username, r.password)));
      END LOOP;

    WHEN '/whoami' THEN

      FOR r IN SELECT * FROM api.whoami()
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/current/session' THEN

      FOR r IN SELECT * FROM api.current_session()
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/current/user' THEN

      FOR r IN SELECT * FROM api.current_user()
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/current/userid' THEN

      FOR r IN SELECT * FROM api.current_userid()
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/current/username' THEN

      FOR r IN SELECT * FROM api.current_username()
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/current/department' THEN

      FOR r IN SELECT * FROM api.current_department()
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/current/workplace' THEN

      FOR r IN SELECT * FROM api.current_workplace()
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/current/language' THEN

      FOR r IN SELECT * FROM api.current_language()
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/current/operdate' THEN

      FOR r IN SELECT * FROM api.operdate()
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/department/set' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric)
      LOOP
        RETURN NEXT row_to_json(api.set_department(r.id));
      END LOOP;

    WHEN '/workplace/set' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric)
      LOOP
        RETURN NEXT row_to_json(api.set_workplace(r.id));
      END LOOP;

    WHEN '/operdate/set' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['operdate']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(operdate timestamp)
      LOOP
        RETURN NEXT row_to_json(api.set_operdate(r.operdate));
      END LOOP;

    WHEN '/language/set' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['language']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(language  text)
      LOOP
        RETURN NEXT row_to_json(api.set_language(r.language));
      END LOOP;

    WHEN '/eventlog' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['object', 'type', 'username', 'code', 'datefrom', 'dateto']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(object numeric, type char, username varchar, code numeric, datefrom timestamp, dateto timestamp)
      LOOP
        FOR e IN SELECT * FROM api.eventlog(r.object, r.type, r.username, r.code, r.datefrom, r.dateto)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/eventlog/add' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['object', 'type', 'code', 'text']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(object numeric, type char, code integer, text text)
      LOOP
        RETURN NEXT row_to_json(api.write_to_event_log(r.object, coalesce(r.type, 'M'), coalesce(r.code, 9999), r.text));
      END LOOP;

    WHEN '/user/add' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['username', 'password', 'fullname', 'phone', 'email', 'description', 'groups']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(username varchar, password text, fullname text, phone text, email text, description text, groups jsonb)
        LOOP
          RETURN NEXT row_to_json(api.add_user(r.username, r.password, r.fullname, r.phone, r.email, r.description, JsonbToStrArray(r.groups)));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(username varchar, password text, fullname text, phone text, email text, description text, groups jsonb)
        LOOP
          RETURN NEXT row_to_json(api.add_user(r.username, r.password, r.fullname, r.phone, r.email, r.description, JsonbToStrArray(r.groups)));
        END LOOP;

      END IF;

    WHEN '/user/upd' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'username', 'password', 'fullname', 'phone', 'email', 'description', 'passwordchange', 'passwordnotchange']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, username varchar, password text, fullname text, phone text, email text, description text, passwordchange boolean, passwordnotchange boolean)
        LOOP
          RETURN NEXT row_to_json(api.upd_user(r.id, r.username, r.password, r.fullname, r.phone, r.email, r.description, r.passwordchange, r.passwordnotchange));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, username varchar, password text, fullname text, phone text, email text, description text, passwordchange boolean, passwordnotchange boolean)
        LOOP
          RETURN NEXT row_to_json(api.upd_user(r.id, r.username, r.password, r.fullname, r.phone, r.email, r.description, r.passwordchange, r.passwordnotchange));
        END LOOP;

      END IF;

    WHEN '/user/password' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'username', 'oldpass', 'newpass']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, username varchar, oldpass text, newpass text)
        LOOP
          RETURN NEXT row_to_json(api.change_password(coalesce(r.id, GetUser(r.username)), r.oldpass, r.newpass));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, username varchar, oldpass text, newpass text)
        LOOP
          RETURN NEXT row_to_json(api.change_password(coalesce(r.id, GetUser(r.username)), r.oldpass, r.newpass));
        END LOOP;

      END IF;

    WHEN '/user/get' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT * FROM api.get_user(r.id)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT * FROM api.get_user(r.id)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/user/lst' THEN

      FOR r IN SELECT * FROM api.lst_user()
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/user/member' THEN

      FOR r IN SELECT * FROM api.user_member()
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/user/lock' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['id', 'username']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, username varchar)
        LOOP
          RETURN NEXT row_to_json(api.user_lock(coalesce(r.id, GetUser(r.username))));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, username varchar)
        LOOP
          RETURN NEXT row_to_json(api.user_lock(coalesce(r.id, GetUser(r.username))));
        END LOOP;

      END IF;

    WHEN '/user/unlock' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['id', 'username']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, username varchar)
        LOOP
          RETURN NEXT row_to_json(api.user_unlock(coalesce(r.id, GetUser(r.username))));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, username varchar)
        LOOP
          RETURN NEXT row_to_json(api.user_unlock(coalesce(r.id, GetUser(r.username))));
        END LOOP;

      END IF;

    WHEN '/user/iptable/get' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'username', 'type']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, username varchar, type char)
        LOOP
          RETURN NEXT row_to_json(api.get_user_iptable(coalesce(r.id, GetUser(r.username)), r.type));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, username varchar, type char)
        LOOP
          RETURN NEXT row_to_json(api.get_user_iptable(coalesce(r.id, GetUser(r.username)), r.type));
        END LOOP;

      END IF;

    WHEN '/user/iptable/set' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'username', 'type', 'iptable']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, username varchar, type char, iptable text)
        LOOP
          RETURN NEXT row_to_json(api.set_user_iptable(coalesce(r.id, GetUser(r.username)), r.type, r.iptable));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, username varchar, type char, iptable text)
        LOOP
          RETURN NEXT row_to_json(api.set_user_iptable(coalesce(r.id, GetUser(r.username)), r.type, r.iptable));
        END LOOP;

      END IF;

    WHEN '/group/get' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT * FROM api.get_group(r.id)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT * FROM api.get_group(r.id)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/group/lst' THEN

      FOR r IN SELECT * FROM api.lst_group()
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/group/member' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'groupname']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, groupname varchar)
      LOOP
        FOR e IN SELECT * FROM api.group_member(coalesce(r.id, GetGroup(r.groupname)))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/department/lst' THEN

      FOR r IN SELECT * FROM api.lst_department()
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/department/get' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN SELECT * FROM api.get_department(r.id)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN SELECT * FROM api.get_department(r.id)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/department/member' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'code']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, code varchar)
      LOOP
        FOR e IN SELECT * FROM api.department_member(coalesce(r.id, GetDepartment(r.code)))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/workplace/member' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'sid']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, sid varchar)
      LOOP
        FOR e IN SELECT * FROM api.workplace_member(coalesce(r.id, GetWorkPlace(r.sid)))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/member/user' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'username']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, username varchar)
      LOOP
        FOR e IN SELECT * FROM api.member_user(coalesce(r.id, GetUser(r.username)))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/member/group' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'username']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, username varchar)
      LOOP
        FOR e IN SELECT * FROM api.member_group(coalesce(r.id, GetUser(r.username)))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/member/department' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'username']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, username varchar)
      LOOP
        FOR e IN SELECT * FROM api.member_department(coalesce(r.id, GetUser(r.username)))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/member/workplace' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'username']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, username varchar)
      LOOP
        FOR e IN SELECT * FROM api.member_workplace(coalesce(r.id, GetUser(r.username)))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/language' THEN

      FOR r IN SELECT * FROM api.language
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/essence' THEN

      FOR r IN SELECT * FROM api.essence
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/class' THEN

      FOR r IN SELECT * FROM api.class
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/action' THEN

      FOR r IN SELECT * FROM api.action
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/state/type' THEN

      FOR r IN SELECT * FROM api.state_type
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/state' THEN

      FOR r IN SELECT * FROM api.state
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/type' THEN

      FOR r IN SELECT * FROM api.type
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/action/run' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'action']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, action numeric)
        LOOP
          FOR e IN SELECT * FROM api.run_action(r.id, r.action)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, action numeric)
        LOOP
          FOR e IN SELECT * FROM api.run_action(r.id, r.action)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/method/get' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'state', 'class', 'classcode']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, state numeric, class numeric, classcode varchar)
      LOOP
        FOR e IN SELECT * FROM api.get_method(coalesce(r.state, GetObjectState(r.id)), coalesce(r.class, GetClass(r.classcode), GetObjectClass(r.id)))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/method/run' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'method']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, method numeric)
        LOOP
          FOR e IN SELECT * FROM api.run_method(r.id, r.method)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, method numeric)
        LOOP
          FOR e IN SELECT * FROM api.run_method(r.id, r.method)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/object/class' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT * FROM Class WHERE id = GetObjectClass(r.id)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT * FROM Class WHERE id = GetObjectClass(r.id)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/object/type' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT * FROM Type WHERE id = GetObjectType(r.id)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT * FROM Type WHERE id = GetObjectType(r.id)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/object/state' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;
      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT * FROM State WHERE id = GetObjectState(r.id)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT * FROM State WHERE id = GetObjectState(r.id)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/object/file' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'files']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, files jsonb)
        LOOP
          IF r.files IS NOT NULL THEN
            RETURN NEXT row_to_json(api.set_object_json_files(r.id, r.files));
          ELSE
            RETURN NEXT api.get_object_json_files(r.id);
          END IF;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, files jsonb)
        LOOP
          IF r.files IS NOT NULL THEN
            RETURN NEXT row_to_json(api.set_object_json_files(r.id, r.files));
          ELSE
            RETURN NEXT api.get_object_json_files(r.id);
          END IF;
        END LOOP;

      END IF;

    WHEN '/object/file/get' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, hash text, name text, path text, size int, date timestamp, delete boolean)
        LOOP
          RETURN NEXT api.get_object_json_files(r.id);
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, hash text, name text, path text, size int, date timestamp, delete boolean)
        LOOP
          RETURN NEXT api.get_object_json_files(r.id);
        END LOOP;

      END IF;

    WHEN '/object/file/set' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'files']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, files jsonb)
        LOOP
          RETURN NEXT row_to_json(api.set_object_json_files(r.id, r.files));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, files jsonb)
        LOOP
          RETURN NEXT row_to_json(api.set_object_json_files(r.id, r.files));
        END LOOP;

      END IF;

    WHEN '/object/forcedel' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric)
        LOOP
          RETURN NEXT row_to_json(api.object_forcedel(r.id));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric)
        LOOP
          RETURN NEXT row_to_json(api.object_forcedel(r.id));
        END LOOP;
      END IF;

    WHEN '/register' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'extended']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, key numeric, subkey numeric, extended boolean)
        LOOP
          IF coalesce(r.extended, false) THEN
            FOR e IN SELECT * FROM api.register_ex(r.id, r.key, r.subkey)
            LOOP
              RETURN NEXT row_to_json(e);
            END LOOP;
          ELSE
            FOR e IN SELECT * FROM api.register(r.id, r.key, r.subkey)
            LOOP
              RETURN NEXT row_to_json(e);
            END LOOP;
          END IF;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key numeric, subkey numeric, extended boolean)
        LOOP
          IF coalesce(r.extended, false) THEN
            FOR e IN SELECT * FROM api.register_ex(r.id, r.key, r.subkey)
            LOOP
              RETURN NEXT row_to_json(e);
            END LOOP;
          ELSE
            FOR e IN SELECT * FROM api.register(r.id, r.key, r.subkey)
            LOOP
              RETURN NEXT row_to_json(e);
            END LOOP;
          END IF;
        END LOOP;

      END IF;

    WHEN '/register/key' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['id', 'root', 'parent', 'key']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, root numeric, parent numeric, key text)
        LOOP
          FOR e IN SELECT * FROM api.register_key(r.id, r.root, r.parent, r.key)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, root numeric, parent numeric, key text)
        LOOP
          FOR e IN SELECT * FROM api.register_key(r.id, r.root, r.parent, r.key)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/register/value' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['id', 'key', 'extended']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, key numeric, extended boolean)
        LOOP
          IF coalesce(r.extended, false) THEN
            FOR e IN SELECT * FROM api.register_value_ex(r.id, r.key)
            LOOP
              RETURN NEXT row_to_json(e);
            END LOOP;
          ELSE
            FOR e IN SELECT * FROM api.register_value(r.id, r.key)
            LOOP
              RETURN NEXT row_to_json(e);
            END LOOP;
          END IF;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key numeric, extended boolean)
        LOOP
          IF coalesce(r.extended, false) THEN
            FOR e IN SELECT * FROM api.register_value_ex(r.id, r.key)
            LOOP
              RETURN NEXT row_to_json(e);
            END LOOP;
          ELSE
            FOR e IN SELECT * FROM api.register_value(r.id, r.key)
            LOOP
              RETURN NEXT row_to_json(e);
            END LOOP;
          END IF;
        END LOOP;

      END IF;

    WHEN '/register/get/key' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['id']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric)
        LOOP
          RETURN NEXT row_to_json(api.register_get_reg_key(r.id));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric)
        LOOP
          RETURN NEXT row_to_json(api.register_get_reg_key(r.id));
        END LOOP;

      END IF;

    WHEN '/register/enum/key' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['key', 'subkey']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(key text, subkey text)
        LOOP
          FOR e IN SELECT * FROM api.register_enum_key(r.key, r.subkey)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(key text, subkey text)
        LOOP
          FOR e IN SELECT * FROM api.register_enum_key(r.key, r.subkey)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/register/enum/value' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['key', 'subkey', 'extended']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(key text, subkey text, extended boolean)
        LOOP
          IF coalesce(r.extended, false) THEN
            FOR e IN SELECT * FROM api.register_enum_value_ex(r.key, r.subkey)
            LOOP
              RETURN NEXT row_to_json(e);
            END LOOP;
          ELSE
            FOR e IN SELECT * FROM api.register_enum_value(r.key, r.subkey)
            LOOP
              RETURN NEXT row_to_json(e);
            END LOOP;
          END IF;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(key text, subkey text, extended boolean)
        LOOP
          IF coalesce(r.extended, false) THEN
            FOR e IN SELECT * FROM api.register_enum_value_ex(r.key, r.subkey)
            LOOP
              RETURN NEXT row_to_json(e);
            END LOOP;
          ELSE
            FOR e IN SELECT * FROM api.register_enum_value(r.key, r.subkey)
            LOOP
              RETURN NEXT row_to_json(e);
            END LOOP;
          END IF;
        END LOOP;

      END IF;

    WHEN '/register/write' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name', 'type', 'data']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, key text, subkey text, name text, type integer, data anynonarray)
        LOOP
          RETURN NEXT row_to_json(api.register_write(r.id, r.key, r.subkey, r.name, r.type, r.data));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key text, subkey text, name text, type integer, data anynonarray)
        LOOP
          RETURN NEXT row_to_json(api.register_write(r.id, r.key, r.subkey, r.name, r.type, r.data));
        END LOOP;

      END IF;

    WHEN '/register/write/integer' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name', 'value']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, key text, subkey text, name text, value integer)
        LOOP
          RETURN NEXT row_to_json(api.register_write(r.id, r.key, r.subkey, r.name, 0, r.value));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key text, subkey text, name text, value integer)
        LOOP
          RETURN NEXT row_to_json(api.register_write(r.id, r.key, r.subkey, r.name, 0, r.value));
        END LOOP;

      END IF;

    WHEN '/register/write/numeric' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name', 'value']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, key text, subkey text, name text, value numeric)
        LOOP
          RETURN NEXT row_to_json(api.register_write(r.id, r.key, r.subkey, r.name, 1, r.value));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key text, subkey text, name text, value numeric)
        LOOP
          RETURN NEXT row_to_json(api.register_write(r.id, r.key, r.subkey, r.name, 1, r.value));
        END LOOP;

      END IF;

    WHEN '/register/write/datetime' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name', 'value']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, key text, subkey text, name text, value timestamp)
        LOOP
          RETURN NEXT row_to_json(api.register_write(r.id, r.key, r.subkey, r.name, 2, r.value));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key text, subkey text, name text, value timestamp)
        LOOP
          RETURN NEXT row_to_json(api.register_write(r.id, r.key, r.subkey, r.name, 2, r.value));
        END LOOP;

      END IF;

    WHEN '/register/write/string' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name', 'value']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, key text, subkey text, name text, value text)
        LOOP
          RETURN NEXT row_to_json(api.register_write(r.id, r.key, r.subkey, r.name, 3, r.value));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key text, subkey text, name text, value text)
        LOOP
          RETURN NEXT row_to_json(api.register_write(r.id, r.key, r.subkey, r.name, 3, r.value));
        END LOOP;

      END IF;

    WHEN '/register/write/boolean' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name', 'value']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, key text, subkey text, name text, value boolean)
        LOOP
          RETURN NEXT row_to_json(api.register_write(r.id, r.key, r.subkey, r.name, 4, r.value));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key text, subkey text, name text, value boolean)
        LOOP
          RETURN NEXT row_to_json(api.register_write(r.id, r.key, r.subkey, r.name, 4, r.value));
        END LOOP;

      END IF;

    WHEN '/register/read' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, key text, subkey text, name text)
        LOOP
          RETURN NEXT row_to_json(api.register_read(r.key, r.subkey, r.name));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key text, subkey text, name text)
        LOOP
          RETURN NEXT row_to_json(api.register_read(r.key, r.subkey, r.name));
        END LOOP;

      END IF;

    WHEN '/register/read/integer' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, key text, subkey text, name text)
        LOOP
          FOR e IN SELECT (data::variant).vinteger as value, result, error FROM api.register_read(r.key, r.subkey, r.name)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;

          RETURN NEXT row_to_json();
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key text, subkey text, name text)
        LOOP
          FOR e IN SELECT (data::variant).vinteger as value, result, error FROM api.register_read(r.key, r.subkey, r.name)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/register/read/numeric' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, key text, subkey text, name text)
        LOOP
          FOR e IN SELECT (data::variant).vnumeric as value, result, error FROM api.register_read(r.key, r.subkey, r.name)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;

          RETURN NEXT row_to_json();
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key text, subkey text, name text)
        LOOP
          FOR e IN SELECT (data::variant).vnumeric as value, result, error FROM api.register_read(r.key, r.subkey, r.name)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/register/read/datetime' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, key text, subkey text, name text)
        LOOP
          FOR e IN SELECT (data::variant).vdatetime as value, result, error FROM api.register_read(r.key, r.subkey, r.name)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;

          RETURN NEXT row_to_json();
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key text, subkey text, name text)
        LOOP
          FOR e IN SELECT (data::variant).vdatetime as value, result, error FROM api.register_read(r.key, r.subkey, r.name)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/register/read/string' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, key text, subkey text, name text)
        LOOP
          FOR e IN SELECT (data::variant).vstring as value, result, error FROM api.register_read(r.key, r.subkey, r.name)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;

          RETURN NEXT row_to_json();
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key text, subkey text, name text)
        LOOP
          FOR e IN SELECT (data::variant).vstring as value, result, error FROM api.register_read(r.key, r.subkey, r.name)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/register/read/boolean' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, key text, subkey text, name text)
        LOOP
          FOR e IN SELECT (data::variant).vboolean as value, result, error FROM api.register_read(r.key, r.subkey, r.name)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;

          RETURN NEXT row_to_json();
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key text, subkey text, name text)
        LOOP
          FOR e IN SELECT (data::variant).vboolean as value, result, error FROM api.register_read(r.key, r.subkey, r.name)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/register/delete/key' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['key', 'subkey']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(key text, subkey text)
        LOOP
          RETURN NEXT row_to_json(api.register_delete_key(r.key, r.subkey));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(key text, subkey text)
        LOOP
          RETURN NEXT row_to_json(api.register_delete_key(r.key, r.subkey));
        END LOOP;

      END IF;

    WHEN '/register/delete/value' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, key text, subkey text, name text)
        LOOP
          RETURN NEXT row_to_json(api.register_delete_value(r.id, r.key, r.subkey, r.name));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key text, subkey text, name text)
        LOOP
          RETURN NEXT row_to_json(api.register_delete_value(r.id, r.key, r.subkey, r.name));
        END LOOP;

      END IF;

    WHEN '/register/delete/tree' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['key', 'subkey']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(key text, subkey text)
        LOOP
          RETURN NEXT row_to_json(api.register_delete_tree(r.key, r.subkey));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(key text, subkey text)
        LOOP
          RETURN NEXT row_to_json(api.register_delete_tree(r.key, r.subkey));
        END LOOP;

      END IF;

    WHEN '/calendar/method' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT id, api.get_method(GetObjectState(id), GetObjectClass(id)) as method FROM api.get_calendar(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT id, api.get_method(GetObjectState(id), GetObjectClass(id)) as method FROM api.get_calendar(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/calendar/count' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby', 'usecache']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb, usecache boolean)
        LOOP
          FOR e IN SELECT count(*) FROM api.lst_calendar(r.search, r.filter, r.reclimit, r.recoffset, r.orderby, r.usecache)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb, usecache boolean)
        LOOP
          FOR e IN SELECT count(*) FROM api.lst_calendar(r.search, r.filter, r.reclimit, r.recoffset, r.orderby, r.usecache)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/calendar/add' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['code', 'name', 'week', 'dayoff', 'holiday', 'workstart', 'workcount', 'reststart', 'restcount', 'description']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(code varchar, name varchar, week numeric, dayoff jsonb, holiday jsonb, workstart interval, workcount interval, reststart interval, restcount interval, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_calendar(r.code, r.name, r.week, r.dayoff, r.holiday, r.workstart, r.workcount, r.reststart, r.restcount, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(code varchar, name varchar, week numeric, dayoff jsonb, holiday jsonb, workstart interval, workcount interval, reststart interval, restcount interval, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_calendar(r.code, r.name, r.week, r.dayoff, r.holiday, r.workstart, r.workcount, r.reststart, r.restcount, r.description));
        END LOOP;

      END IF;

    WHEN '/calendar/upd' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'code', 'name', 'week', 'dayoff', 'holiday', 'workstart', 'workcount', 'reststart', 'restcount', 'description']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, code varchar, name varchar, week numeric, dayoff jsonb, holiday jsonb, workstart interval, workcount interval, reststart interval, restcount interval, description text)
        LOOP
          RETURN NEXT row_to_json(api.upd_calendar(r.id, r.code, r.name, r.week, r.dayoff, r.holiday, r.workstart, r.workcount, r.reststart, r.restcount, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, code varchar, name varchar, week numeric, dayoff jsonb, holiday jsonb, workstart interval, workcount interval, reststart interval, restcount interval, description text)
        LOOP
          RETURN NEXT row_to_json(api.upd_calendar(r.id, r.code, r.name, r.week, r.dayoff, r.holiday, r.workstart, r.workcount, r.reststart, r.restcount, r.description));
        END LOOP;

      END IF;

    WHEN '/calendar/get' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_calendar($1)', JsonbToFields(r.fields, GetColumns('calendar', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_calendar($1)', JsonbToFields(r.fields, GetColumns('calendar', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/calendar/lst' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'compact', 'search', 'filter', 'reclimit', 'recoffset', 'orderby', 'usecache']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(fields jsonb, compact boolean, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb, usecache boolean)
      LOOP
        IF coalesce(r.compact, false) THEN
          FOR e IN EXECUTE format('SELECT %s FROM api.lst_calendar_compact($1, $2, $3, $4, $5, $6)', JsonbToFields(r.fields, GetColumns('calendar_compact', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby, r.usecache
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        ELSE
          FOR e IN EXECUTE format('SELECT %s FROM api.lst_calendar($1, $2, $3, $4, $5, $6)', JsonbToFields(r.fields, GetColumns('calendar', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby, r.usecache
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END IF;
      END LOOP;

    WHEN '/calendar/fill' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['calendar', 'calendarcode', 'datefrom', 'dateto', 'userid']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(calendar numeric, calendarcode varchar, datefrom date, dateto date, userid numeric)
        LOOP
          RETURN NEXT row_to_json(api.fill_calendar(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.datefrom, r.dateto, r.userid));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(calendar numeric, calendarcode varchar, datefrom date, dateto date, userid numeric)
        LOOP
          RETURN NEXT row_to_json(api.fill_calendar(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.datefrom, r.dateto, r.userid));
        END LOOP;

      END IF;

    WHEN '/calendar/date/lst' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['calendar', 'calendarcode', 'datefrom', 'dateto', 'userid']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(calendar numeric, calendarcode varchar, datefrom date, dateto date, userid numeric)
        LOOP
          FOR e IN SELECT * FROM api.lst_calendar_date(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.datefrom, r.dateto, r.userid)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(calendar numeric, calendarcode varchar, datefrom date, dateto date, userid numeric)
        LOOP
          FOR e IN SELECT * FROM api.lst_calendar_date(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.datefrom, r.dateto, r.userid)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/calendar/user/lst' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['calendar', 'calendarcode', 'datefrom', 'dateto', 'userid']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(calendar numeric, calendarcode varchar, datefrom date, dateto date, userid numeric)
        LOOP
          FOR e IN SELECT * FROM api.lst_calendar_user(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.datefrom, r.dateto, r.userid)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(calendar numeric, calendarcode varchar, datefrom date, dateto date, userid numeric)
        LOOP
          FOR e IN SELECT * FROM api.lst_calendar_user(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.datefrom, r.dateto, r.userid)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/calendar/date/get' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['calendar', 'calendarcode', 'date', 'userid']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(calendar numeric, calendarcode varchar, date date, userid numeric)
        LOOP
          RETURN NEXT row_to_json(api.get_calendar_date(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.date, r.userid));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(calendar numeric, calendarcode varchar, date date, userid numeric)
        LOOP
          RETURN NEXT row_to_json(api.get_calendar_date(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.date, r.userid));
        END LOOP;

      END IF;

    WHEN '/calendar/date/set' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['calendar', 'calendarcode', 'date', 'flag', 'workstart', 'workcount', 'reststart', 'restcount', 'userid']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(calendar numeric, calendarcode varchar, date date, flag bit(4), workstart interval, workcount interval, reststart interval, restcount interval, userid numeric)
        LOOP
          RETURN NEXT row_to_json(api.set_calendar_date(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.date, r.flag, r.workstart, r.workcount, r.reststart, r.restcount, r.userid));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(calendar numeric, calendarcode varchar, date date, flag bit(4), workstart interval, workcount interval, reststart interval, restcount interval, userid numeric)
        LOOP
          RETURN NEXT row_to_json(api.set_calendar_date(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.date, r.flag, r.workstart, r.workcount, r.reststart, r.restcount, r.userid));
        END LOOP;

      END IF;

    WHEN '/calendar/date/del' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['calendar', 'calendarcode', 'date', 'userid']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(calendar numeric, calendarcode varchar, date date, userid numeric)
        LOOP
          RETURN NEXT row_to_json(api.del_calendar_date(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.date, r.userid));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(calendar numeric, calendarcode varchar, date date, userid numeric)
        LOOP
          RETURN NEXT row_to_json(api.del_calendar_date(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.date, r.userid));
        END LOOP;

      END IF;

    ELSE
      PERFORM RouteNotFound(pRoute);
    END CASE;

    UPDATE api.log SET runtime = age(clock_timestamp(), tsBegin) WHERE id = nApiId;

    RETURN;
  EXCEPTION
  WHEN others THEN
    GET STACKED DIAGNOSTICS vError = MESSAGE_TEXT;
  END;

  PERFORM SetErrorMessage(vError);

  IF current_session() IS NOT NULL THEN
    nEventId := AddEventLog(null, 'E', 5000, vError);
    UPDATE api.log SET eventid = nEventId WHERE id = nApiId;
  END IF;

  RETURN NEXT json_build_object('result', false, 'error', vError);

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vError = MESSAGE_TEXT;

  PERFORM SetErrorMessage(vError);

  RETURN NEXT json_build_object('result', false, 'error', vError);

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;