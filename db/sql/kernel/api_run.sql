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
  nId	    numeric;
  nApiId	numeric;
  nEventId	numeric;

  r		    record;
  e		    record;

  nKey		integer;
  arJson	json[];

  tsBegin	timestamp;

  arKeys	text[];
  vMessage	text;
BEGIN
  IF pRoute IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  nKey := 0;
  nApiId := AddApiLog(pRoute, pJson);
  pSession := NULLIF(pSession, '');

  IF lower(pRoute) <> '/login' AND pSession IS NOT NULL THEN
    IF NOT SessionLogin(pSession) THEN
      RETURN NEXT json_build_object('session', pSession, 'result', false, 'message', GetErrorMessage());
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

    WHEN '/run' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['key', 'route', 'json']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN
        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(key text, route text, json jsonb)
        LOOP
          FOR e IN SELECT * FROM api.run(r.route, r.json)
          LOOP
            arJson := array_append(arJson, (row_to_json(e)->>'run')::json);
          END LOOP;

          RETURN NEXT jsonb_build_object('key', coalesce(r.key, IntToStr(nKey)), 'route', r.route, 'json', array_to_json(arJson)::jsonb);

          arJson := null;
          nKey := nKey + 1;
        END LOOP;

      ELSE

        PERFORM IncorrectJsonType(jsonb_typeof(pJson), 'array');

      END IF;

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

    WHEN '/current/area' THEN

      FOR r IN SELECT * FROM api.current_area()
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/current/interface' THEN

      FOR r IN SELECT * FROM api.current_interface()
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/current/language' THEN

      FOR r IN SELECT * FROM api.current_language()
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/current/operdate' THEN

      FOR r IN SELECT * FROM api.oper_date()
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/area/set' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric)
      LOOP
        RETURN NEXT row_to_json(api.set_area(r.id));
      END LOOP;

    WHEN '/interface/set' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric)
      LOOP
        RETURN NEXT row_to_json(api.set_interface(r.id));
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

    WHEN '/event/log' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['type', 'username', 'code', 'datefrom', 'dateto']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(type char, username varchar, code numeric, datefrom timestamp, dateto timestamp)
      LOOP
        FOR e IN SELECT * FROM api.event_log(r.type, r.username, r.code, r.datefrom, r.dateto)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/event/add' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['type', 'code', 'text']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(type char, code integer, text text)
      LOOP
        RETURN NEXT row_to_json(api.write_to_log(coalesce(r.type, 'M'), coalesce(r.code, 9999), r.text));
      END LOOP;

    WHEN '/user/add' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['username', 'password', 'fullname', 'phone', 'email', 'description']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(username varchar, password text, fullname text, phone text, email text, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_user(r.username, r.password, r.fullname, r.phone, r.email, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(username varchar, password text, fullname text, phone text, email text, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_user(r.username, r.password, r.fullname, r.phone, r.email, r.description));
        END LOOP;

      END IF;

    WHEN '/user/update' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'username', 'password', 'fullname', 'phone', 'email', 'description', 'passwordchange', 'passwordnotchange']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, username varchar, password text, fullname text, phone text, email text, description text, passwordchange boolean, passwordnotchange boolean)
        LOOP
          RETURN NEXT row_to_json(api.update_user(r.id, r.username, r.password, r.fullname, r.phone, r.email, r.description, r.passwordchange, r.passwordnotchange));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, username varchar, password text, fullname text, phone text, email text, description text, passwordchange boolean, passwordnotchange boolean)
        LOOP
          RETURN NEXT row_to_json(api.update_user(r.id, r.username, r.password, r.fullname, r.phone, r.email, r.description, r.passwordchange, r.passwordnotchange));
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

    WHEN '/user/list' THEN

      FOR r IN SELECT * FROM api.list_user()
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

    WHEN '/group/list' THEN

      FOR r IN SELECT * FROM api.list_group()
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/group/add' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['code', 'name', 'description']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(code varchar, name text, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_group(r.code, r.name, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(code varchar, name text, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_group(r.code, r.name, r.description));
        END LOOP;

      END IF;

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

    WHEN '/area/list' THEN

      FOR r IN SELECT * FROM api.list_area()
      LOOP
        RETURN NEXT row_to_json(r);
      END LOOP;

    WHEN '/area/get' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN SELECT * FROM api.get_area(r.id)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN SELECT * FROM api.get_area(r.id)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/area/member' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'code']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, code varchar)
      LOOP
        FOR e IN SELECT * FROM api.area_member(coalesce(r.id, GetArea(r.code)))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/interface/member' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'sid']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, sid varchar)
      LOOP
        FOR e IN SELECT * FROM api.interface_member(coalesce(r.id, GetInterface(r.sid)))
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

    WHEN '/member/area' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'username']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, username varchar)
      LOOP
        FOR e IN SELECT * FROM api.member_area(coalesce(r.id, GetUser(r.username)))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/member/interface' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'username']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, username varchar)
      LOOP
        FOR e IN SELECT * FROM api.member_interface(coalesce(r.id, GetUser(r.username)))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

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
          FOR e IN SELECT (data::variant).vinteger as value, result, message FROM api.register_read(r.key, r.subkey, r.name)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;

          RETURN NEXT row_to_json();
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key text, subkey text, name text)
        LOOP
          FOR e IN SELECT (data::variant).vinteger as value, result, message FROM api.register_read(r.key, r.subkey, r.name)
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
          FOR e IN SELECT (data::variant).vnumeric as value, result, message FROM api.register_read(r.key, r.subkey, r.name)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;

          RETURN NEXT row_to_json();
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key text, subkey text, name text)
        LOOP
          FOR e IN SELECT (data::variant).vnumeric as value, result, message FROM api.register_read(r.key, r.subkey, r.name)
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
          FOR e IN SELECT (data::variant).vdatetime as value, result, message FROM api.register_read(r.key, r.subkey, r.name)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;

          RETURN NEXT row_to_json();
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key text, subkey text, name text)
        LOOP
          FOR e IN SELECT (data::variant).vdatetime as value, result, message FROM api.register_read(r.key, r.subkey, r.name)
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
          FOR e IN SELECT (data::variant).vstring as value, result, message FROM api.register_read(r.key, r.subkey, r.name)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;

          RETURN NEXT row_to_json();
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key text, subkey text, name text)
        LOOP
          FOR e IN SELECT (data::variant).vstring as value, result, message FROM api.register_read(r.key, r.subkey, r.name)
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
          FOR e IN SELECT (data::variant).vboolean as value, result, message FROM api.register_read(r.key, r.subkey, r.name)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;

          RETURN NEXT row_to_json();
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, key text, subkey text, name text)
        LOOP
          FOR e IN SELECT (data::variant).vboolean as value, result, message FROM api.register_read(r.key, r.subkey, r.name)
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

      arKeys := array_cat(arKeys, ARRAY['id', 'action', 'form']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, action numeric, form jsonb)
        LOOP
          FOR e IN SELECT * FROM api.run_action(r.id, r.action, r.form)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, action numeric, form jsonb)
        LOOP
          FOR e IN SELECT * FROM api.run_action(r.id, r.action, r.form)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/method/get' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['object', 'class', 'classcode', 'state', 'statecode', 'action', 'actioncode']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(object numeric, class numeric, classcode varchar, state numeric, statecode varchar, action numeric, actioncode varchar)
      LOOP
        nId := coalesce(r.class, GetClass(r.classcode), GetObjectClass(r.object));
        FOR e IN SELECT * FROM api.get_method(nId, coalesce(r.state, GetState(nId, r.statecode), GetObjectState(r.object)), coalesce(r.action, GetAction(r.actioncode)))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/method/run' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'method', 'form']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, method numeric, form jsonb)
        LOOP
          FOR e IN SELECT * FROM api.run_method(r.id, r.method, r.form)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, method numeric, form jsonb)
        LOOP
          FOR e IN SELECT * FROM api.run_method(r.id, r.method, r.form)
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

    WHEN '/object/force/del' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric)
        LOOP
          RETURN NEXT row_to_json(api.object_force_del(r.id));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric)
        LOOP
          RETURN NEXT row_to_json(api.object_force_del(r.id));
        END LOOP;
      END IF;

    WHEN '/object/file' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'files']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, files json)
        LOOP
          IF r.files IS NOT NULL THEN
            RETURN NEXT row_to_json(api.set_object_files_json(r.id, r.files));
          ELSE
            RETURN NEXT api.get_object_files_json(r.id);
          END IF;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, files json)
        LOOP
          IF r.files IS NOT NULL THEN
            RETURN NEXT row_to_json(api.set_object_files_json(r.id, r.files));
          ELSE
            RETURN NEXT api.get_object_files_json(r.id);
          END IF;
        END LOOP;

      END IF;

    WHEN '/object/file/set' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'files']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, files json)
        LOOP
          RETURN NEXT row_to_json(api.set_object_files_json(r.id, r.files));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, files json)
        LOOP
          RETURN NEXT row_to_json(api.set_object_files_json(r.id, r.files));
        END LOOP;

      END IF;

    WHEN '/object/file/get' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_object_file($1)', JsonbToFields(r.fields, GetColumns('object_file', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_object_file($1)', JsonbToFields(r.fields, GetColumns('object_file', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/object/file/list' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.list_object_file($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('object_file', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/object/data' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'data']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, data json)
        LOOP
          IF r.data IS NOT NULL THEN
            RETURN NEXT row_to_json(api.set_object_data_json(r.id, r.data));
          ELSE
            RETURN NEXT api.get_object_data_json(r.id);
          END IF;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, data json)
        LOOP
          IF r.data IS NOT NULL THEN
            RETURN NEXT row_to_json(api.set_object_data_json(r.id, r.data));
          ELSE
            RETURN NEXT api.get_object_data_json(r.id);
          END IF;
        END LOOP;

      END IF;

    WHEN '/object/data/set' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'data']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, data json)
        LOOP
          RETURN NEXT row_to_json(api.set_object_data_json(r.id, r.data));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, data json)
        LOOP
          RETURN NEXT row_to_json(api.set_object_data_json(r.id, r.data));
        END LOOP;

      END IF;


    WHEN '/object/data/get' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_object_data($1)', JsonbToFields(r.fields, GetColumns('object_data', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_object_data($1)', JsonbToFields(r.fields, GetColumns('object_data', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/object/data/list' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.list_object_data($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('object_data', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/object/address/set' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'address', 'datefrom']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, address numeric, datefrom timestamp)
        LOOP
          RETURN NEXT row_to_json(api.set_object_address(r.id, r.address, coalesce(r.datefrom, oper_date())));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, address numeric, datefrom timestamp)
        LOOP
          RETURN NEXT row_to_json(api.set_object_address(r.id, r.address, coalesce(r.datefrom, oper_date())));
        END LOOP;

      END IF;

    WHEN '/object/address/get' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_object_address($1)', JsonbToFields(r.fields, GetColumns('object_address', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_object_address($1)', JsonbToFields(r.fields, GetColumns('object_address', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/object/address/list' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.list_object_address($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('object_address', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/calendar/method' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_calendar(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_calendar(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/calendar/count' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_calendar(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_calendar(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
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
          RETURN NEXT row_to_json(api.update_calendar(r.id, r.code, r.name, r.week, r.dayoff, r.holiday, r.workstart, r.workcount, r.reststart, r.restcount, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, code varchar, name varchar, week numeric, dayoff jsonb, holiday jsonb, workstart interval, workcount interval, reststart interval, restcount interval, description text)
        LOOP
          RETURN NEXT row_to_json(api.update_calendar(r.id, r.code, r.name, r.week, r.dayoff, r.holiday, r.workstart, r.workcount, r.reststart, r.restcount, r.description));
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

    WHEN '/calendar/list' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'compact', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(fields jsonb, compact boolean, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.list_calendar($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('calendar', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
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

    WHEN '/calendar/date/list' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['calendar', 'calendarcode', 'datefrom', 'dateto', 'userid']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(calendar numeric, calendarcode varchar, datefrom date, dateto date, userid numeric)
        LOOP
          FOR e IN SELECT * FROM api.list_calendar_date(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.datefrom, r.dateto, r.userid)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(calendar numeric, calendarcode varchar, datefrom date, dateto date, userid numeric)
        LOOP
          FOR e IN SELECT * FROM api.list_calendar_date(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.datefrom, r.dateto, r.userid)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/calendar/user/list' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['calendar', 'calendarcode', 'datefrom', 'dateto', 'userid']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(calendar numeric, calendarcode varchar, datefrom date, dateto date, userid numeric)
        LOOP
          FOR e IN SELECT * FROM api.list_calendar_user(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.datefrom, r.dateto, r.userid)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(calendar numeric, calendarcode varchar, datefrom date, dateto date, userid numeric)
        LOOP
          FOR e IN SELECT * FROM api.list_calendar_user(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.datefrom, r.dateto, r.userid)
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

    WHEN '/address/tree/get' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_address_tree($1)', JsonbToFields(r.fields, GetColumns('address_tree', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_address_tree($1)', JsonbToFields(r.fields, GetColumns('address_tree', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/address/tree/list' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.list_address_tree($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('address_tree', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/address/tree/history' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['id', 'code']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, code varchar)
      LOOP
        FOR e IN SELECT api.get_address_tree_history(coalesce(r.id, GetAddressTreeId(r.code))) AS history
        LOOP
          RETURN NEXT row_to_json(e)->>'history';
        END LOOP;
      END LOOP;

    WHEN '/address/tree/string' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['code', 'short', 'level']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(code varchar, short integer, level integer)
        LOOP
          RETURN NEXT row_to_json(api.get_address_tree_string(r.code, coalesce(r.short, 0), coalesce(r.level, 0)));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(code varchar, short integer, level integer)
        LOOP
          RETURN NEXT row_to_json(api.get_address_tree_string(r.code, coalesce(r.short, 0), coalesce(r.level, 0)));
        END LOOP;

      END IF;

    WHEN '/address/type' THEN

      FOR e IN SELECT * FROM api.type(GetEssence('address'))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;

    WHEN '/address/method' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_address(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_address(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/address/count' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_address(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_address(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/address/add' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['parent', 'type', 'code', 'index', 'country', 'region', 'district', 'city', 'settlement', 'street', 'house', 'building', 'structure', 'apartment', 'address']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(parent numeric, type varchar, code varchar, index varchar, country varchar, region varchar, district varchar, city varchar, settlement varchar, street varchar, house varchar, building varchar, structure varchar, apartment varchar, address text)
        LOOP
          RETURN NEXT row_to_json(api.add_address(r.parent, r.type, r.code, r.index, r.country, r.region, r.district, r.city, r.settlement, r.street, r.house, r.building, r.structure, r.apartment, r.address));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(parent numeric, type varchar, code varchar, index varchar, country varchar, region varchar, district varchar, city varchar, settlement varchar, street varchar, house varchar, building varchar, structure varchar, apartment varchar, address text)
        LOOP
          RETURN NEXT row_to_json(api.add_address(r.parent, r.type, r.code, r.index, r.country, r.region, r.district, r.city, r.settlement, r.street, r.house, r.building, r.structure, r.apartment, r.address));
        END LOOP;

      END IF;

    WHEN '/address/update' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'parent', 'type', 'code', 'index', 'country', 'region', 'district', 'city', 'settlement', 'street', 'house', 'building', 'structure', 'apartment', 'address']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, parent numeric, type varchar, code varchar, index varchar, country varchar, region varchar, district varchar, city varchar, settlement varchar, street varchar, house varchar, building varchar, structure varchar, apartment varchar, address text)
        LOOP
          RETURN NEXT row_to_json(api.update_address(r.id, r.parent, r.type, r.code, r.index, r.country, r.region, r.district, r.city, r.settlement, r.street, r.house, r.building, r.structure, r.apartment, r.address));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, parent numeric, type varchar, code varchar, index varchar, country varchar, region varchar, district varchar, city varchar, settlement varchar, street varchar, house varchar, building varchar, structure varchar, apartment varchar, address text)
        LOOP
          RETURN NEXT row_to_json(api.update_address(r.id, r.parent, r.type, r.code, r.index, r.country, r.region, r.district, r.city, r.settlement, r.street, r.house, r.building, r.structure, r.apartment, r.address));
        END LOOP;

      END IF;

    WHEN '/address/get' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_address($1)', JsonbToFields(r.fields, GetColumns('address', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_address($1)', JsonbToFields(r.fields, GetColumns('address', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/address/list' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.list_address($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('address', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/address/string' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric)
        LOOP
          RETURN NEXT row_to_json(api.get_address_string(r.id));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric)
        LOOP
          RETURN NEXT row_to_json(api.get_address_string(r.id));
        END LOOP;

      END IF;

    WHEN '/client/type' THEN

      FOR e IN SELECT * FROM api.type(GetEssence('client'))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;

    WHEN '/client/method' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_client(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_client(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/client/count' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_client(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_client(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/client/add' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['parent', 'type', 'code', 'userid', 'name', 'phone', 'email', 'info', 'description']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(parent numeric, type varchar, code varchar, userid numeric, name jsonb, phone jsonb, email jsonb, info jsonb, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_client(r.parent, r.type, r.code, r.userid, r.name, r.phone, r.email, r.info, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(parent numeric, type varchar, code varchar, userid numeric, name jsonb, phone jsonb, email jsonb, info jsonb, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_client(r.parent, r.type, r.code, r.userid, r.name, r.phone, r.email, r.info, r.description));
        END LOOP;

      END IF;

    WHEN '/client/update' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'parent', 'type', 'code', 'userid', 'name', 'phone', 'email', 'info', 'description']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, parent numeric, type varchar, code varchar, userid numeric, name jsonb, phone jsonb, email jsonb, info jsonb, description text)
        LOOP
          RETURN NEXT row_to_json(api.update_client(r.id, r.parent, r.type, r.code, r.userid, r.name, r.phone, r.email, r.info, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, parent numeric, type varchar, code varchar, userid numeric, name jsonb, phone jsonb, email jsonb, info jsonb, description text)
        LOOP
          RETURN NEXT row_to_json(api.update_client(r.id, r.parent, r.type, r.code, r.userid, r.name, r.phone, r.email, r.info, r.description));
        END LOOP;

      END IF;

    WHEN '/client/get' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_client($1)', JsonbToFields(r.fields, GetColumns('client', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_client($1)', JsonbToFields(r.fields, GetColumns('client', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/client/list' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.list_client($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('client', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/card/type' THEN

      FOR e IN SELECT * FROM api.type(GetEssence('card'))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;

    WHEN '/card/method' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_card(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_card(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/card/count' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_card(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_card(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/card/add' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['type', 'code', 'client', 'description']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(type varchar, code varchar, client numeric, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_card(r.type, r.code, r.client, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(type varchar, code varchar, client numeric, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_card(r.type, r.code, r.client, r.description));
        END LOOP;

      END IF;

    WHEN '/card/update' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'type', 'code', 'client', 'description']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, type varchar, code varchar, client numeric, description text)
        LOOP
          RETURN NEXT row_to_json(api.update_card(r.id, r.type, r.code, r.client, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, type varchar, code varchar, client numeric, description text)
        LOOP
          RETURN NEXT row_to_json(api.update_card(r.id, r.type, r.code, r.client, r.description));
        END LOOP;

      END IF;

    WHEN '/card/get' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_card($1)', JsonbToFields(r.fields, GetColumns('card', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_card($1)', JsonbToFields(r.fields, GetColumns('card', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/card/list' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.list_card($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('card', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/charge_point/type' THEN

      FOR e IN SELECT * FROM api.type(GetEssence('charge_point'))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;

    WHEN '/charge_point/method' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_charge_point(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_charge_point(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/charge_point/count' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_charge_point(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_charge_point(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/charge_point/add' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['protocol', 'identity', 'name', 'model', 'vendor', 'version', 'serialnumber', 'boxserialnumber', 'meterserialnumber', 'iccid', 'imsi', 'description']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(protocol varchar, identity varchar, name varchar, model varchar, vendor varchar, version varchar, serialnumber varchar, boxserialnumber varchar, meterserialnumber varchar, iccid varchar, imsi varchar, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_charge_point(r.protocol, r.identity, r.name, r.model, r.vendor, r.version, r.serialnumber, r.boxserialnumber, r.meterserialnumber, r.iccid, r.imsi, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(protocol varchar, identity varchar, name varchar, model varchar, vendor varchar, version varchar, serialnumber varchar, boxserialnumber varchar, meterserialnumber varchar, iccid varchar, imsi varchar, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_charge_point(r.protocol, r.identity, r.name, r.model, r.vendor, r.version, r.serialnumber, r.boxserialnumber, r.meterserialnumber, r.iccid, r.imsi, r.description));
        END LOOP;

      END IF;

    WHEN '/charge_point/update' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'protocol', 'identity', 'name', 'model', 'vendor', 'version', 'serialnumber', 'boxserialnumber', 'meterserialnumber', 'iccid', 'imsi', 'description']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, protocol varchar, identity varchar, name varchar, model varchar, vendor varchar, version varchar, serialnumber varchar, boxserialnumber varchar, meterserialnumber varchar, iccid varchar, imsi varchar, description text)
        LOOP
          RETURN NEXT row_to_json(api.update_charge_point(r.id, r.protocol, r.identity, r.name, r.name, r.model, r.vendor, r.version, r.serialnumber, r.boxserialnumber, r.meterserialnumber, r.iccid, r.imsi, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, protocol varchar, identity varchar, name varchar, model varchar, vendor varchar, version varchar, serialnumber varchar, boxserialnumber varchar, meterserialnumber varchar, iccid varchar, imsi varchar, description text)
        LOOP
          RETURN NEXT row_to_json(api.update_charge_point(r.id, r.protocol, r.identity, r.name, r.name, r.model, r.vendor, r.version, r.serialnumber, r.boxserialnumber, r.meterserialnumber, r.iccid, r.imsi, r.description));
        END LOOP;

      END IF;

    WHEN '/charge_point/get' THEN

      IF pJson IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);

      IF jsonb_typeof(pJson) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_charge_point($1)', JsonbToFields(r.fields, GetColumns('charge_point', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_charge_point($1)', JsonbToFields(r.fields, GetColumns('charge_point', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/charge_point/list' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.list_charge_point($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('charge_point', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/charge_point/status' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.status_charge_point($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('status_notification', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/ocpp/log' THEN

      IF pJson IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['identity', 'action', 'datefrom', 'dateto']);
        PERFORM CheckJsonbKeys(pRoute, arKeys, pJson);
      ELSE
        pJson := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pJson) AS x(identity varchar, action varchar, datefrom timestamp, dateto timestamp)
      LOOP
        FOR e IN SELECT * FROM api.ocpp_log(r.identity, r.action, r.datefrom, r.dateto)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE
      PERFORM RouteNotFound(pRoute);
    END CASE;

    UPDATE api.log SET runtime = age(clock_timestamp(), tsBegin) WHERE id = nApiId;

    RETURN;
  EXCEPTION
  WHEN others THEN
    GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT;
  END;

  PERFORM SetErrorMessage(vMessage);

  IF current_session() IS NOT NULL THEN
    nEventId := AddEventLog('E', 5000, vMessage);
    UPDATE api.log SET eventid = nEventId WHERE id = nApiId;
  END IF;

  RETURN NEXT json_build_object('result', false, 'message', vMessage);

  RETURN;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT;

  PERFORM SetErrorMessage(vMessage);

  RETURN NEXT json_build_object('result', false, 'message', vMessage);

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
