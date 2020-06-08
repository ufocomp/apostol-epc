--------------------------------------------------------------------------------
-- api.fetch -------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API.
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION api.fetch (
  pPath     text,
  pPayload  jsonb DEFAULT null
) RETURNS   SETOF json
AS $$
DECLARE
  nId       numeric;

  r         record;
  e         record;

  nKey      integer;
  arJson    json[];

  arKeys    text[];
  vUserName varchar;
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
  	PERFORM RouteIsEmpty();
  END IF;

  IF SubStr(pPath, 1, 9) = '/registry' THEN
    FOR r IN SELECT * FROM registry.fetch(pPath, pPayload)
    LOOP
      RETURN NEXT r.fetch;
    END LOOP;
    RETURN;
  END IF;

  CASE lower(pPath)
  WHEN '/sign/in' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['username', 'phone', 'email', 'password', 'agent', 'host']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF pPayload ? 'phone' THEN
	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(phone text, password text, agent text, host inet)
	  LOOP
		SELECT username INTO vUserName FROM db.user WHERE type = 'U' AND phone = r.phone;
		RETURN NEXT row_to_json(api.signin(coalesce(vUserName, ''), r.password, r.agent, r.host));
	  END LOOP;
	ELSIF pPayload ? 'email' THEN
	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(email text, password text, agent text, host inet)
	  LOOP
		SELECT username INTO vUserName FROM db.user WHERE type = 'U' AND email = r.email;
		RETURN NEXT row_to_json(api.signin(coalesce(vUserName, ''), r.password, r.agent, r.host));
	  END LOOP;
	ELSE
	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(username text, password text, agent text, host inet)
	  LOOP
		RETURN NEXT row_to_json(api.signin(coalesce(r.username, ''), r.password, r.agent, r.host));
	  END LOOP;
	END IF;

  WHEN '/sign/up' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

    arKeys := array_cat(arKeys, ARRAY['type', 'username', 'password', 'name', 'phone', 'email', 'info', 'description', 'audience', 'code']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(type varchar, username varchar, password text, name jsonb, phone text, email text, info jsonb, description text, audience text, code text)
    LOOP
      RETURN NEXT row_to_json(api.signup(NULLIF(r.type, ''), NULLIF(r.username, ''), NULLIF(r.password, ''), r.name, NULLIF(r.phone, ''), NULLIF(r.email, ''), r.info, NULLIF(r.description, ''), NULLIF(r.audience, ''), NULLIF(r.code, '')));
    END LOOP;

  WHEN '/sign/out' THEN

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['session', 'closeall']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(session text, logoutall boolean)
	LOOP
	  RETURN NEXT row_to_json(api.signout(coalesce(r.session, current_session()), r.logoutall));
	END LOOP;

  WHEN '/authenticate' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['session', 'key', 'agent', 'host']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(session text, key text, agent text, host inet)
	LOOP
	  RETURN NEXT row_to_json(api.authenticate(r.session, r.key, r.agent, r.host));
	END LOOP;

  WHEN '/authorize' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['session']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(session text)
	LOOP
	  RETURN NEXT row_to_json(api.authorize(r.session));
	END LOOP;

  WHEN '/su' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['username', 'password']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(username varchar, password text)
	LOOP
	  RETURN NEXT row_to_json(api.su(r.username, r.password));
	END LOOP;

  WHEN '/whoami' THEN

	FOR r IN SELECT * FROM api.whoami()
	LOOP
	  RETURN NEXT row_to_json(r);
	END LOOP;

  WHEN '/fetch' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['key', 'path', 'payload']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN
	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(key text, path text, payload jsonb)
	  LOOP
		FOR e IN SELECT * FROM api.fetch(r.path, r.payload)
		LOOP
		  arJson := array_append(arJson, (row_to_json(e)->>'fetch')::json);
		END LOOP;

		RETURN NEXT jsonb_build_object('key', coalesce(r.key, IntToStr(nKey)), 'path', r.path, 'payload', array_to_json(arJson)::jsonb);

		arJson := null;
		nKey := nKey + 1;
	  END LOOP;

	ELSE

	  PERFORM IncorrectJsonType(jsonb_typeof(pPayload), 'array');

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

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
	LOOP
	  RETURN NEXT row_to_json(api.set_area(r.id));
	END LOOP;

  WHEN '/interface/set' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
	LOOP
	  RETURN NEXT row_to_json(api.set_interface(r.id));
	END LOOP;

  WHEN '/operdate/set' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['operdate']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(operdate timestamp)
	LOOP
	  RETURN NEXT row_to_json(api.set_operdate(r.operdate));
	END LOOP;

  WHEN '/language/set' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'code']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, code text)
	LOOP
	  RETURN NEXT row_to_json(api.set_language(coalesce(r.id, GetLanguage(r.code))));
	END LOOP;

  WHEN '/event/log' THEN

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['type', 'code', 'datefrom', 'dateto']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(type char, code numeric, datefrom timestamp, dateto timestamp)
	LOOP
	  FOR e IN SELECT * FROM api.event_log(r.type, r.code, r.datefrom, r.dateto)
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

  WHEN '/event/add' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['type', 'code', 'text']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(type char, code integer, text text)
	LOOP
	  RETURN NEXT row_to_json(api.write_to_log(coalesce(r.type, 'M'), coalesce(r.code, 9999), r.text));
	END LOOP;

  WHEN '/user/add' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['username', 'password', 'fullname', 'phone', 'email', 'description']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(username varchar, password text, fullname text, phone text, email text, description text)
	  LOOP
		RETURN NEXT row_to_json(api.add_user(r.username, r.password, r.fullname, r.phone, r.email, r.description));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(username varchar, password text, fullname text, phone text, email text, description text)
	  LOOP
		RETURN NEXT row_to_json(api.add_user(r.username, r.password, r.fullname, r.phone, r.email, r.description));
	  END LOOP;

	END IF;

  WHEN '/user/update' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'username', 'password', 'fullname', 'phone', 'email', 'description', 'passwordchange', 'passwordnotchange']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, username varchar, password text, fullname text, phone text, email text, description text, passwordchange boolean, passwordnotchange boolean)
	  LOOP
		RETURN NEXT row_to_json(api.update_user(r.id, r.username, r.password, r.fullname, r.phone, r.email, r.description, r.passwordchange, r.passwordnotchange));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, username varchar, password text, fullname text, phone text, email text, description text, passwordchange boolean, passwordnotchange boolean)
	  LOOP
		RETURN NEXT row_to_json(api.update_user(r.id, r.username, r.password, r.fullname, r.phone, r.email, r.description, r.passwordchange, r.passwordnotchange));
	  END LOOP;

	END IF;

  WHEN '/user/password' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'username', 'oldpass', 'newpass']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, username varchar, oldpass text, newpass text)
	  LOOP
		RETURN NEXT row_to_json(api.change_password(coalesce(r.id, GetUser(r.username)), r.oldpass, r.newpass));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, username varchar, oldpass text, newpass text)
	  LOOP
		RETURN NEXT row_to_json(api.change_password(coalesce(r.id, GetUser(r.username)), r.oldpass, r.newpass));
	  END LOOP;

	END IF;

  WHEN '/user/get' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
	  LOOP
		FOR e IN SELECT * FROM api.get_user(r.id)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
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

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['id', 'username']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, username varchar)
	  LOOP
		RETURN NEXT row_to_json(api.user_lock(coalesce(r.id, GetUser(r.username))));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, username varchar)
	  LOOP
		RETURN NEXT row_to_json(api.user_lock(coalesce(r.id, GetUser(r.username))));
	  END LOOP;

	END IF;

  WHEN '/user/unlock' THEN

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['id', 'username']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, username varchar)
	  LOOP
		RETURN NEXT row_to_json(api.user_unlock(coalesce(r.id, GetUser(r.username))));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, username varchar)
	  LOOP
		RETURN NEXT row_to_json(api.user_unlock(coalesce(r.id, GetUser(r.username))));
	  END LOOP;

	END IF;

  WHEN '/user/iptable/get' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'username', 'type']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, username varchar, type char)
	  LOOP
		RETURN NEXT row_to_json(api.get_user_iptable(coalesce(r.id, GetUser(r.username)), r.type));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, username varchar, type char)
	  LOOP
		RETURN NEXT row_to_json(api.get_user_iptable(coalesce(r.id, GetUser(r.username)), r.type));
	  END LOOP;

	END IF;

  WHEN '/user/iptable/set' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'username', 'type', 'iptable']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, username varchar, type char, iptable text)
	  LOOP
		RETURN NEXT row_to_json(api.set_user_iptable(coalesce(r.id, GetUser(r.username)), r.type, r.iptable));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, username varchar, type char, iptable text)
	  LOOP
		RETURN NEXT row_to_json(api.set_user_iptable(coalesce(r.id, GetUser(r.username)), r.type, r.iptable));
	  END LOOP;

	END IF;

  WHEN '/group/get' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
	  LOOP
		FOR e IN SELECT * FROM api.get_group(r.id)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
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

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['code', 'name', 'description']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(code varchar, name text, description text)
	  LOOP
		RETURN NEXT row_to_json(api.add_group(r.code, r.name, r.description));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(code varchar, name text, description text)
	  LOOP
		RETURN NEXT row_to_json(api.add_group(r.code, r.name, r.description));
	  END LOOP;

	END IF;

  WHEN '/group/member' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'groupname']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, groupname varchar)
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

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
	  LOOP
		FOR e IN SELECT * FROM api.get_area(r.id)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
	  LOOP
		FOR e IN SELECT * FROM api.get_area(r.id)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/area/member' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'code']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, code varchar)
	LOOP
	  FOR e IN SELECT * FROM api.area_member(coalesce(r.id, GetArea(r.code)))
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

  WHEN '/interface/member' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'sid']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, sid varchar)
	LOOP
	  FOR e IN SELECT * FROM api.interface_member(coalesce(r.id, GetInterface(r.sid)))
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

  WHEN '/member/user' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'username']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, username varchar)
	LOOP
	  FOR e IN SELECT * FROM api.member_user(coalesce(r.id, GetUser(r.username)))
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

  WHEN '/member/group' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'username']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, username varchar)
	LOOP
	  FOR e IN SELECT * FROM api.member_group(coalesce(r.id, GetUser(r.username)))
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

  WHEN '/member/area' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'username']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, username varchar)
	LOOP
	  FOR e IN SELECT * FROM api.member_area(coalesce(r.id, GetUser(r.username)))
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

  WHEN '/member/interface' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'username']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, username varchar)
	LOOP
	  FOR e IN SELECT * FROM api.member_interface(coalesce(r.id, GetUser(r.username)))
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

  WHEN '/language' THEN

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.language', JsonbToFields(r.fields, GetColumns('language', 'api')))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

  WHEN '/essence' THEN

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.essence', JsonbToFields(r.fields, GetColumns('essence', 'api')))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

  WHEN '/class' THEN

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.class', JsonbToFields(r.fields, GetColumns('class', 'api')))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

  WHEN '/action' THEN

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.action', JsonbToFields(r.fields, GetColumns('action', 'api')))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

  WHEN '/state/type' THEN

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.state_type', JsonbToFields(r.fields, GetColumns('state_type', 'api')))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

  WHEN '/state' THEN

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.state', JsonbToFields(r.fields, GetColumns('state', 'api')))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

  WHEN '/type' THEN

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.type', JsonbToFields(r.fields, GetColumns('type', 'api')))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

  WHEN '/method' THEN

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.method', JsonbToFields(r.fields, GetColumns('method', 'api')))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

  WHEN '/method/get' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['object', 'class', 'classcode', 'state', 'statecode', 'action', 'actioncode']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(object numeric, class numeric, classcode varchar, state numeric, statecode varchar, action numeric, actioncode varchar)
	LOOP
	  nId := coalesce(r.class, GetClass(r.classcode), GetObjectClass(r.object));
	  FOR e IN SELECT * FROM api.get_method(nId, coalesce(r.state, GetState(nId, r.statecode), GetObjectState(r.object)), coalesce(r.action, GetAction(r.actioncode)))
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

  WHEN '/action/run' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'action', 'form']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, action numeric, form jsonb)
	  LOOP
		FOR e IN SELECT * FROM api.run_action(r.id, r.action, r.form)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, action numeric, form jsonb)
	  LOOP
		FOR e IN SELECT * FROM api.run_action(r.id, r.action, r.form)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/method/run' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'method', 'form']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, method numeric, form jsonb)
	  LOOP
		FOR e IN SELECT * FROM api.run_method(r.id, r.method, r.form)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, method numeric, form jsonb)
	  LOOP
		FOR e IN SELECT * FROM api.run_method(r.id, r.method, r.form)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/object/class' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
	  LOOP
		FOR e IN SELECT * FROM Class WHERE id = GetObjectClass(r.id)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
	  LOOP
		FOR e IN SELECT * FROM Class WHERE id = GetObjectClass(r.id)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/object/type' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.type WHERE id = GetObjectType($1)', JsonbToFields(r.fields, GetColumns('type', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

	ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.type WHERE id = GetObjectType($1)', JsonbToFields(r.fields, GetColumns('type', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

	END IF;

  WHEN '/object/state' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.state WHERE id = GetObjectState($1)', JsonbToFields(r.fields, GetColumns('state', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

	ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.state WHERE id = GetObjectState($1)', JsonbToFields(r.fields, GetColumns('state', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

	END IF;

  WHEN '/object/force/del' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
	  LOOP
		RETURN NEXT row_to_json(api.object_force_del(r.id));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
	  LOOP
		RETURN NEXT row_to_json(api.object_force_del(r.id));
	  END LOOP;
	END IF;

  WHEN '/object/file' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'files']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, files json)
	  LOOP
		IF r.files IS NOT NULL THEN
		  RETURN NEXT row_to_json(api.set_object_files_json(r.id, r.files));
		ELSE
		  RETURN NEXT api.get_object_files_json(r.id);
		END IF;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, files json)
	  LOOP
		IF r.files IS NOT NULL THEN
		  RETURN NEXT row_to_json(api.set_object_files_json(r.id, r.files));
		ELSE
		  RETURN NEXT api.get_object_files_json(r.id);
		END IF;
	  END LOOP;

	END IF;

  WHEN '/object/file/set' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'files']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, files json)
	  LOOP
		RETURN NEXT row_to_json(api.set_object_files_json(r.id, r.files));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, files json)
	  LOOP
		RETURN NEXT row_to_json(api.set_object_files_json(r.id, r.files));
	  END LOOP;

	END IF;

  WHEN '/object/file/get' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
	  LOOP
		FOR e IN EXECUTE format('SELECT %s FROM api.get_object_file($1)', JsonbToFields(r.fields, GetColumns('object_file', 'api'))) USING r.id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
	  LOOP
		FOR e IN EXECUTE format('SELECT %s FROM api.get_object_file($1)', JsonbToFields(r.fields, GetColumns('object_file', 'api'))) USING r.id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/object/file/list' THEN

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
	LOOP
	  FOR e IN EXECUTE format('SELECT %s FROM api.list_object_file($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('object_file', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

  WHEN '/object/data' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'data']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, data json)
	  LOOP
		IF r.data IS NOT NULL THEN
		  RETURN NEXT row_to_json(api.set_object_data_json(r.id, r.data));
		ELSE
		  RETURN NEXT api.get_object_data_json(r.id);
		END IF;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, data json)
	  LOOP
		IF r.data IS NOT NULL THEN
		  RETURN NEXT row_to_json(api.set_object_data_json(r.id, r.data));
		ELSE
		  RETURN NEXT api.get_object_data_json(r.id);
		END IF;
	  END LOOP;

	END IF;

  WHEN '/object/data/set' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'data']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, data json)
	  LOOP
		RETURN NEXT row_to_json(api.set_object_data_json(r.id, r.data));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, data json)
	  LOOP
		RETURN NEXT row_to_json(api.set_object_data_json(r.id, r.data));
	  END LOOP;

	END IF;

  WHEN '/object/data/get' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
	  LOOP
		FOR e IN EXECUTE format('SELECT %s FROM api.get_object_data($1)', JsonbToFields(r.fields, GetColumns('object_data', 'api'))) USING r.id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
	  LOOP
		FOR e IN EXECUTE format('SELECT %s FROM api.get_object_data($1)', JsonbToFields(r.fields, GetColumns('object_data', 'api'))) USING r.id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/object/data/list' THEN

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
	LOOP
	  FOR e IN EXECUTE format('SELECT %s FROM api.list_object_data($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('object_data', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

  WHEN '/object/address' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'addresses']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, addresses json)
	  LOOP
		IF r.addresses IS NOT NULL THEN
		  RETURN NEXT row_to_json(api.set_object_addresses_json(r.id, r.addresses));
		ELSE
		  RETURN NEXT api.get_object_addresses_json(r.id);
		END IF;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, addresses json)
	  LOOP
		IF r.addresses IS NOT NULL THEN
		  RETURN NEXT row_to_json(api.set_object_addresses_json(r.id, r.addresses));
		ELSE
		  RETURN NEXT api.get_object_addresses_json(r.id);
		END IF;
	  END LOOP;

	END IF;

  WHEN '/object/address/set' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'address', 'datefrom']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, address numeric, datefrom timestamp)
	  LOOP
		RETURN NEXT row_to_json(api.set_object_address(r.id, r.address, coalesce(r.datefrom, oper_date())));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, address numeric, datefrom timestamp)
	  LOOP
		RETURN NEXT row_to_json(api.set_object_address(r.id, r.address, coalesce(r.datefrom, oper_date())));
	  END LOOP;

	END IF;

  WHEN '/object/address/get' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
	  LOOP
		FOR e IN EXECUTE format('SELECT %s FROM api.get_object_address($1)', JsonbToFields(r.fields, GetColumns('object_address', 'api'))) USING r.id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
	  LOOP
		FOR e IN EXECUTE format('SELECT %s FROM api.get_object_address($1)', JsonbToFields(r.fields, GetColumns('object_address', 'api'))) USING r.id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/object/address/list' THEN

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
	LOOP
	  FOR e IN EXECUTE format('SELECT %s FROM api.list_object_address($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('object_address', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

  WHEN '/object/geolocation' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'coordinates']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, coordinates json)
	  LOOP
		IF r.coordinates IS NOT NULL THEN
		  RETURN NEXT row_to_json(api.set_object_coordinates_json(r.id, r.coordinates));
		ELSE
		  RETURN NEXT api.get_object_coordinates_json(r.id);
		END IF;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, coordinates json)
	  LOOP
		IF r.coordinates IS NOT NULL THEN
		  RETURN NEXT row_to_json(api.set_object_coordinates_json(r.id, r.coordinates));
		ELSE
		  RETURN NEXT api.get_object_coordinates_json(r.id);
		END IF;
	  END LOOP;

	END IF;

  WHEN '/object/geolocation/set' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'coordinates']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, coordinates json)
	  LOOP
		RETURN NEXT row_to_json(api.set_object_coordinates_json(r.id, r.coordinates));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, coordinates json)
	  LOOP
		RETURN NEXT row_to_json(api.set_object_coordinates_json(r.id, r.coordinates));
	  END LOOP;

	END IF;


  WHEN '/object/geolocation/get' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
	  LOOP
		FOR e IN EXECUTE format('SELECT %s FROM api.get_object_coordinates($1)', JsonbToFields(r.fields, GetColumns('object_coordinates', 'api'))) USING r.id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
	  LOOP
		FOR e IN EXECUTE format('SELECT %s FROM api.get_object_coordinates($1)', JsonbToFields(r.fields, GetColumns('object_coordinates', 'api'))) USING r.id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/object/geolocation/list' THEN

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
	LOOP
	  FOR e IN EXECUTE format('SELECT %s FROM api.list_object_coordinates($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('object_coordinates', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

  WHEN '/calendar/method' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
	  LOOP
		FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_calendar(r.id) ORDER BY id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
	  LOOP
		FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_calendar(r.id) ORDER BY id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/calendar/count' THEN

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
	  LOOP
		FOR e IN SELECT count(*) FROM api.list_calendar(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
	  LOOP
		FOR e IN SELECT count(*) FROM api.list_calendar(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/calendar/add' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['code', 'name', 'week', 'dayoff', 'holiday', 'workstart', 'workcount', 'reststart', 'restcount', 'description']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(code varchar, name varchar, week numeric, dayoff jsonb, holiday jsonb, workstart interval, workcount interval, reststart interval, restcount interval, description text)
	  LOOP
		RETURN NEXT row_to_json(api.add_calendar(r.code, r.name, r.week, r.dayoff, r.holiday, r.workstart, r.workcount, r.reststart, r.restcount, r.description));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(code varchar, name varchar, week numeric, dayoff jsonb, holiday jsonb, workstart interval, workcount interval, reststart interval, restcount interval, description text)
	  LOOP
		RETURN NEXT row_to_json(api.add_calendar(r.code, r.name, r.week, r.dayoff, r.holiday, r.workstart, r.workcount, r.reststart, r.restcount, r.description));
	  END LOOP;

	END IF;

  WHEN '/calendar/upd' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'code', 'name', 'week', 'dayoff', 'holiday', 'workstart', 'workcount', 'reststart', 'restcount', 'description']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, code varchar, name varchar, week numeric, dayoff jsonb, holiday jsonb, workstart interval, workcount interval, reststart interval, restcount interval, description text)
	  LOOP
		RETURN NEXT row_to_json(api.update_calendar(r.id, r.code, r.name, r.week, r.dayoff, r.holiday, r.workstart, r.workcount, r.reststart, r.restcount, r.description));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, code varchar, name varchar, week numeric, dayoff jsonb, holiday jsonb, workstart interval, workcount interval, reststart interval, restcount interval, description text)
	  LOOP
		RETURN NEXT row_to_json(api.update_calendar(r.id, r.code, r.name, r.week, r.dayoff, r.holiday, r.workstart, r.workcount, r.reststart, r.restcount, r.description));
	  END LOOP;

	END IF;

  WHEN '/calendar/get' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
	  LOOP
		FOR e IN EXECUTE format('SELECT %s FROM api.get_calendar($1)', JsonbToFields(r.fields, GetColumns('calendar', 'api'))) USING r.id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
	  LOOP
		FOR e IN EXECUTE format('SELECT %s FROM api.get_calendar($1)', JsonbToFields(r.fields, GetColumns('calendar', 'api'))) USING r.id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/calendar/list' THEN

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['fields', 'compact', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, compact boolean, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
	LOOP
	  FOR e IN EXECUTE format('SELECT %s FROM api.list_calendar($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('calendar', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

  WHEN '/calendar/fill' THEN

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['calendar', 'calendarcode', 'datefrom', 'dateto', 'userid']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(calendar numeric, calendarcode varchar, datefrom date, dateto date, userid numeric)
	  LOOP
		RETURN NEXT row_to_json(api.fill_calendar(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.datefrom, r.dateto, r.userid));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(calendar numeric, calendarcode varchar, datefrom date, dateto date, userid numeric)
	  LOOP
		RETURN NEXT row_to_json(api.fill_calendar(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.datefrom, r.dateto, r.userid));
	  END LOOP;

	END IF;

  WHEN '/calendar/date/list' THEN

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['calendar', 'calendarcode', 'datefrom', 'dateto', 'userid']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(calendar numeric, calendarcode varchar, datefrom date, dateto date, userid numeric)
	  LOOP
		FOR e IN SELECT * FROM api.list_calendar_date(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.datefrom, r.dateto, r.userid)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(calendar numeric, calendarcode varchar, datefrom date, dateto date, userid numeric)
	  LOOP
		FOR e IN SELECT * FROM api.list_calendar_date(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.datefrom, r.dateto, r.userid)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/calendar/user/list' THEN

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['calendar', 'calendarcode', 'datefrom', 'dateto', 'userid']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(calendar numeric, calendarcode varchar, datefrom date, dateto date, userid numeric)
	  LOOP
		FOR e IN SELECT * FROM api.list_calendar_user(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.datefrom, r.dateto, r.userid)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(calendar numeric, calendarcode varchar, datefrom date, dateto date, userid numeric)
	  LOOP
		FOR e IN SELECT * FROM api.list_calendar_user(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.datefrom, r.dateto, r.userid)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/calendar/date/get' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['calendar', 'calendarcode', 'date', 'userid']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(calendar numeric, calendarcode varchar, date date, userid numeric)
	  LOOP
		RETURN NEXT row_to_json(api.get_calendar_date(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.date, r.userid));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(calendar numeric, calendarcode varchar, date date, userid numeric)
	  LOOP
		RETURN NEXT row_to_json(api.get_calendar_date(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.date, r.userid));
	  END LOOP;

	END IF;

  WHEN '/calendar/date/set' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['calendar', 'calendarcode', 'date', 'flag', 'workstart', 'workcount', 'reststart', 'restcount', 'userid']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(calendar numeric, calendarcode varchar, date date, flag bit(4), workstart interval, workcount interval, reststart interval, restcount interval, userid numeric)
	  LOOP
		RETURN NEXT row_to_json(api.set_calendar_date(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.date, r.flag, r.workstart, r.workcount, r.reststart, r.restcount, r.userid));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(calendar numeric, calendarcode varchar, date date, flag bit(4), workstart interval, workcount interval, reststart interval, restcount interval, userid numeric)
	  LOOP
		RETURN NEXT row_to_json(api.set_calendar_date(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.date, r.flag, r.workstart, r.workcount, r.reststart, r.restcount, r.userid));
	  END LOOP;

	END IF;

  WHEN '/calendar/date/del' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['calendar', 'calendarcode', 'date', 'userid']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(calendar numeric, calendarcode varchar, date date, userid numeric)
	  LOOP
		RETURN NEXT row_to_json(api.del_calendar_date(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.date, r.userid));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(calendar numeric, calendarcode varchar, date date, userid numeric)
	  LOOP
		RETURN NEXT row_to_json(api.del_calendar_date(coalesce(r.calendar, GetCalendar(coalesce(r.calendarcode, 'default'))), r.date, r.userid));
	  END LOOP;

	END IF;

  WHEN '/address/tree/get' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
	  LOOP
		FOR e IN EXECUTE format('SELECT %s FROM api.get_address_tree($1)', JsonbToFields(r.fields, GetColumns('address_tree', 'api'))) USING r.id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
	  LOOP
		FOR e IN EXECUTE format('SELECT %s FROM api.get_address_tree($1)', JsonbToFields(r.fields, GetColumns('address_tree', 'api'))) USING r.id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/address/tree/list' THEN

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
	LOOP
	  FOR e IN EXECUTE format('SELECT %s FROM api.list_address_tree($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('address_tree', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

  WHEN '/address/tree/history' THEN

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['id', 'code']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, code varchar)
	LOOP
	  FOR e IN SELECT api.get_address_tree_history(coalesce(r.id, GetAddressTreeId(r.code))) AS history
	  LOOP
		RETURN NEXT row_to_json(e)->>'history';
	  END LOOP;
	END LOOP;

  WHEN '/address/tree/string' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['code', 'short', 'level']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(code varchar, short integer, level integer)
	  LOOP
		RETURN NEXT row_to_json(api.get_address_tree_string(r.code, coalesce(r.short, 0), coalesce(r.level, 0)));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(code varchar, short integer, level integer)
	  LOOP
		RETURN NEXT row_to_json(api.get_address_tree_string(r.code, coalesce(r.short, 0), coalesce(r.level, 0)));
	  END LOOP;

	END IF;

  WHEN '/address/type' THEN

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.type($1)', JsonbToFields(r.fields, GetColumns('type', 'api'))) USING GetEssence('address')
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

  WHEN '/address/method' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
	  LOOP
		FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_address(r.id) ORDER BY id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
	  LOOP
		FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_address(r.id) ORDER BY id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/address/count' THEN

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
	  LOOP
		FOR e IN SELECT count(*) FROM api.list_address(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
	  LOOP
		FOR e IN SELECT count(*) FROM api.list_address(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/address/add' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['parent', 'type', 'code', 'index', 'country', 'region', 'district', 'city', 'settlement', 'street', 'house', 'building', 'structure', 'apartment', 'address']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(parent numeric, type varchar, code varchar, index varchar, country varchar, region varchar, district varchar, city varchar, settlement varchar, street varchar, house varchar, building varchar, structure varchar, apartment varchar, address text)
	  LOOP
		RETURN NEXT row_to_json(api.add_address(r.parent, r.type, r.code, r.index, r.country, r.region, r.district, r.city, r.settlement, r.street, r.house, r.building, r.structure, r.apartment, r.address));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(parent numeric, type varchar, code varchar, index varchar, country varchar, region varchar, district varchar, city varchar, settlement varchar, street varchar, house varchar, building varchar, structure varchar, apartment varchar, address text)
	  LOOP
		RETURN NEXT row_to_json(api.add_address(r.parent, r.type, r.code, r.index, r.country, r.region, r.district, r.city, r.settlement, r.street, r.house, r.building, r.structure, r.apartment, r.address));
	  END LOOP;

	END IF;

  WHEN '/address/update' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'parent', 'type', 'code', 'index', 'country', 'region', 'district', 'city', 'settlement', 'street', 'house', 'building', 'structure', 'apartment', 'address']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, parent numeric, type varchar, code varchar, index varchar, country varchar, region varchar, district varchar, city varchar, settlement varchar, street varchar, house varchar, building varchar, structure varchar, apartment varchar, address text)
	  LOOP
		RETURN NEXT row_to_json(api.update_address(r.id, r.parent, r.type, r.code, r.index, r.country, r.region, r.district, r.city, r.settlement, r.street, r.house, r.building, r.structure, r.apartment, r.address));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, parent numeric, type varchar, code varchar, index varchar, country varchar, region varchar, district varchar, city varchar, settlement varchar, street varchar, house varchar, building varchar, structure varchar, apartment varchar, address text)
	  LOOP
		RETURN NEXT row_to_json(api.update_address(r.id, r.parent, r.type, r.code, r.index, r.country, r.region, r.district, r.city, r.settlement, r.street, r.house, r.building, r.structure, r.apartment, r.address));
	  END LOOP;

	END IF;

  WHEN '/address/get' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
	  LOOP
		FOR e IN EXECUTE format('SELECT %s FROM api.get_address($1)', JsonbToFields(r.fields, GetColumns('address', 'api'))) USING r.id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
	  LOOP
		FOR e IN EXECUTE format('SELECT %s FROM api.get_address($1)', JsonbToFields(r.fields, GetColumns('address', 'api'))) USING r.id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/address/list' THEN

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
	LOOP
	  FOR e IN EXECUTE format('SELECT %s FROM api.list_address($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('address', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

  WHEN '/address/string' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
	  LOOP
		RETURN NEXT row_to_json(api.get_address_string(r.id));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
	  LOOP
		RETURN NEXT row_to_json(api.get_address_string(r.id));
	  END LOOP;

	END IF;

  WHEN '/client/type' THEN

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.type($1)', JsonbToFields(r.fields, GetColumns('type', 'api'))) USING GetEssence('client')
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

  WHEN '/client/method' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
	  LOOP
		FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_client(r.id) ORDER BY id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
	  LOOP
		FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_client(r.id) ORDER BY id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/client/count' THEN

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
	  LOOP
		FOR e IN SELECT count(*) FROM api.list_client(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
	  LOOP
		FOR e IN SELECT count(*) FROM api.list_client(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/client/add' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['parent', 'type', 'code', 'userid', 'name', 'phone', 'email', 'info', 'description']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(parent numeric, type varchar, code varchar, userid numeric, name jsonb, phone jsonb, email jsonb, info jsonb, description text)
	  LOOP
		RETURN NEXT row_to_json(api.add_client(r.parent, r.type, r.code, r.userid, r.name, r.phone, r.email, r.info, r.description));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(parent numeric, type varchar, code varchar, userid numeric, name jsonb, phone jsonb, email jsonb, info jsonb, description text)
	  LOOP
		RETURN NEXT row_to_json(api.add_client(r.parent, r.type, r.code, r.userid, r.name, r.phone, r.email, r.info, r.description));
	  END LOOP;

	END IF;

  WHEN '/client/update' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'parent', 'type', 'code', 'userid', 'name', 'phone', 'email', 'info', 'description']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, parent numeric, type varchar, code varchar, userid numeric, name jsonb, phone jsonb, email jsonb, info jsonb, description text)
	  LOOP
		RETURN NEXT row_to_json(api.update_client(r.id, r.parent, r.type, r.code, r.userid, r.name, r.phone, r.email, r.info, r.description));
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, parent numeric, type varchar, code varchar, userid numeric, name jsonb, phone jsonb, email jsonb, info jsonb, description text)
	  LOOP
		RETURN NEXT row_to_json(api.update_client(r.id, r.parent, r.type, r.code, r.userid, r.name, r.phone, r.email, r.info, r.description));
	  END LOOP;

	END IF;

  WHEN '/client/get' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
	  LOOP
		FOR e IN EXECUTE format('SELECT %s FROM api.get_client($1)', JsonbToFields(r.fields, GetColumns('client', 'api'))) USING r.id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
	  LOOP
		FOR e IN EXECUTE format('SELECT %s FROM api.get_client($1)', JsonbToFields(r.fields, GetColumns('client', 'api'))) USING r.id
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/client/list' THEN

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
	LOOP
	  FOR e IN EXECUTE format('SELECT %s FROM api.list_client($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('client', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

    WHEN '/client/tariff' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'tariffs']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, tariffs json)
        LOOP
          IF r.tariffs IS NOT NULL THEN
            RETURN NEXT row_to_json(api.set_client_tariffs_json(r.id, r.tariffs));
          ELSE
            RETURN NEXT api.get_client_tariffs_json(r.id);
          END IF;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, tariffs json)
        LOOP
          IF r.tariffs IS NOT NULL THEN
            RETURN NEXT row_to_json(api.set_client_tariffs_json(r.id, r.tariffs));
          ELSE
            RETURN NEXT api.get_client_tariffs_json(r.id);
          END IF;
        END LOOP;

      END IF;

    WHEN '/client/tariff/set' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'tariff', 'datefrom']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, tariff numeric, datefrom timestamp)
        LOOP
          RETURN NEXT row_to_json(api.set_client_tariff(r.id, r.tariff, coalesce(r.datefrom, oper_date())));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, tariff numeric, datefrom timestamp)
        LOOP
          RETURN NEXT row_to_json(api.set_client_tariff(r.id, r.tariff, coalesce(r.datefrom, oper_date())));
        END LOOP;

      END IF;

    WHEN '/client/tariff/get' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_client_tariff($1)', JsonbToFields(r.fields, GetColumns('client_tariff', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_client_tariff($1)', JsonbToFields(r.fields, GetColumns('client_tariff', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/client/tariff/list' THEN

      IF pPayload IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
      ELSE
        pPayload := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.list_client_tariff($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('client_tariff', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/card/type' THEN

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.type($1)', JsonbToFields(r.fields, GetColumns('type', 'api'))) USING GetEssence('card')
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/card/method' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_card(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_card(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/card/count' THEN

      IF pPayload IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
      ELSE
        pPayload := '{}';
      END IF;

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_card(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_card(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/card/add' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['parent', 'type', 'client', 'code', 'name', 'expire', 'description']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(parent numeric, type varchar, client numeric, code varchar, name text, expire date, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_card(r.parent, r.type, r.client,r.code, r.name, r.expire, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(parent numeric, type varchar, client numeric, code varchar, name text, expire date, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_card(r.parent, r.type, r.client,r.code, r.name, r.expire, r.description));
        END LOOP;

      END IF;

    WHEN '/card/update' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'parent', 'type', 'client', 'code', 'name', 'expire', 'description']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, parent numeric, type varchar, client numeric, code varchar, name text, expire date, description text)
        LOOP
          RETURN NEXT row_to_json(api.update_card(r.id, r.parent, r.type, r.client,r.code, r.name, r.expire, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, parent numeric, type varchar, client numeric, code varchar, name text, expire date, description text)
        LOOP
          RETURN NEXT row_to_json(api.update_card(r.id, r.parent, r.type, r.client,r.code, r.name, r.expire, r.description));
        END LOOP;

      END IF;

    WHEN '/card/get' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_card($1)', JsonbToFields(r.fields, GetColumns('card', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_card($1)', JsonbToFields(r.fields, GetColumns('card', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/card/list' THEN

      IF pPayload IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
      ELSE
        pPayload := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.list_card($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('card', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/charge_point/type' THEN

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.type($1)', JsonbToFields(r.fields, GetColumns('type', 'api'))) USING GetEssence('charge_point')
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/charge_point/method' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_charge_point(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_charge_point(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/charge_point/count' THEN

      IF pPayload IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
      ELSE
        pPayload := '{}';
      END IF;

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_charge_point(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_charge_point(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/charge_point/add' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['parent', 'type', 'client', 'identity', 'name', 'model', 'vendor', 'version', 'serialnumber', 'boxserialnumber', 'meterserialnumber', 'iccid', 'imsi', 'description']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(parent numeric, type varchar, client numeric, identity varchar, name varchar, model varchar, vendor varchar, version varchar, serialnumber varchar, boxserialnumber varchar, meterserialnumber varchar, iccid varchar, imsi varchar, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_charge_point(r.parent, r.type, r.client, r.identity, r.name, r.model, r.vendor, r.version, r.serialnumber, r.boxserialnumber, r.meterserialnumber, r.iccid, r.imsi, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(parent numeric, type varchar, client numeric, identity varchar, name varchar, model varchar, vendor varchar, version varchar, serialnumber varchar, boxserialnumber varchar, meterserialnumber varchar, iccid varchar, imsi varchar, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_charge_point(r.parent, r.type, r.client, r.identity, r.name, r.model, r.vendor, r.version, r.serialnumber, r.boxserialnumber, r.meterserialnumber, r.iccid, r.imsi, r.description));
        END LOOP;

      END IF;

    WHEN '/charge_point/update' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'parent', 'type', 'client', 'identity', 'name', 'model', 'vendor', 'version', 'serialnumber', 'boxserialnumber', 'meterserialnumber', 'iccid', 'imsi', 'description']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, parent numeric, type varchar, client numeric, identity varchar, name varchar, model varchar, vendor varchar, version varchar, serialnumber varchar, boxserialnumber varchar, meterserialnumber varchar, iccid varchar, imsi varchar, description text)
        LOOP
          RETURN NEXT row_to_json(api.update_charge_point(r.id, r.parent, r.type, r.client, r.identity, r.name, r.model, r.vendor, r.version, r.serialnumber, r.boxserialnumber, r.meterserialnumber, r.iccid, r.imsi, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, parent numeric, type varchar, client numeric, identity varchar, name varchar, model varchar, vendor varchar, version varchar, serialnumber varchar, boxserialnumber varchar, meterserialnumber varchar, iccid varchar, imsi varchar, description text)
        LOOP
          RETURN NEXT row_to_json(api.update_charge_point(r.id, r.parent, r.type, r.client, r.identity, r.name, r.model, r.vendor, r.version, r.serialnumber, r.boxserialnumber, r.meterserialnumber, r.iccid, r.imsi, r.description));
        END LOOP;

      END IF;

    WHEN '/charge_point/get' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_charge_point($1)', JsonbToFields(r.fields, GetColumns('charge_point', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_charge_point($1)', JsonbToFields(r.fields, GetColumns('charge_point', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/charge_point/list' THEN

      IF pPayload IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
      ELSE
        pPayload := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.list_charge_point($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('charge_point', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/charge_point/status/get' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_status_notification($1)', JsonbToFields(r.fields, GetColumns('status_notification', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_status_notification($1)', JsonbToFields(r.fields, GetColumns('status_notification', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/charge_point/status/list' THEN

      IF pPayload IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
      ELSE
        pPayload := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.list_status_notification($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('status_notification', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/charge_point/transaction/get' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_transaction($1)', JsonbToFields(r.fields, GetColumns('transaction', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_transaction($1)', JsonbToFields(r.fields, GetColumns('transaction', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/charge_point/transaction/list' THEN

      IF pPayload IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
      ELSE
        pPayload := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.list_transaction($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('transaction', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/charge_point/meter_value/get' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_meter_value($1)', JsonbToFields(r.fields, GetColumns('meter_value', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_meter_value($1)', JsonbToFields(r.fields, GetColumns('meter_value', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/charge_point/meter_value/list' THEN

      IF pPayload IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
      ELSE
        pPayload := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.list_meter_value($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('meter_value', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/invoice/type' THEN

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.type($1)', JsonbToFields(r.fields, GetColumns('type', 'api'))) USING GetEssence('invoice')
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/invoice/method' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_invoice(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_invoice(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/invoice/count' THEN

      IF pPayload IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
      ELSE
        pPayload := '{}';
      END IF;

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_invoice(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_invoice(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/invoice/add' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['parent', 'type', 'code', 'transaction', 'description']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(parent numeric, type varchar, code varchar, transaction numeric, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_invoice(r.parent, r.type, r.code, r.transaction, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(parent numeric, type varchar, code varchar, transaction numeric, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_invoice(r.parent, r.type, r.code, r.transaction, r.description));
        END LOOP;

      END IF;

    WHEN '/invoice/update' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'parent', 'type', 'code', 'description']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, parent numeric, type varchar, code varchar, description text)
        LOOP
          RETURN NEXT row_to_json(api.update_invoice(r.id, r.parent, r.type, r.code, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, parent numeric, type varchar, code varchar, description text)
        LOOP
          RETURN NEXT row_to_json(api.update_invoice(r.id, r.parent, r.type, r.code, r.description));
        END LOOP;

      END IF;

    WHEN '/invoice/get' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_invoice($1)', JsonbToFields(r.fields, GetColumns('invoice', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_invoice($1)', JsonbToFields(r.fields, GetColumns('invoice', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/invoice/list' THEN

      IF pPayload IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
      ELSE
        pPayload := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.list_invoice($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('invoice', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/order/type' THEN

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.type($1)', JsonbToFields(r.fields, GetColumns('type', 'api'))) USING GetEssence('order')
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/order/method' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_order(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_order(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/order/count' THEN

      IF pPayload IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
      ELSE
        pPayload := '{}';
      END IF;

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_order(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_order(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/order/add' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['parent', 'type', 'code', 'client', 'amount', 'uuid', 'description']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(parent numeric, type varchar, code varchar, client numeric, amount numeric, uuid uuid, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_order(r.parent, r.type, r.code, r.client, r.amount, r.uuid, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(parent numeric, type varchar, code varchar, client numeric, amount numeric, uuid uuid, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_order(r.parent, r.type, r.code, r.client, r.amount, r.uuid, r.description));
        END LOOP;

      END IF;

    WHEN '/order/update' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'parent', 'type', 'code', 'client', 'amount', 'uuid', 'description']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, parent numeric, type varchar, code varchar, client numeric, amount numeric, uuid uuid, description text)
        LOOP
          RETURN NEXT row_to_json(api.update_order(r.id, r.parent, r.type, r.code, r.client, r.amount, r.uuid, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, parent numeric, type varchar, code varchar, client numeric, amount numeric, uuid uuid, description text)
        LOOP
          RETURN NEXT row_to_json(api.update_order(r.id, r.parent, r.type, r.code, r.client, r.amount, r.uuid, r.description));
        END LOOP;

      END IF;

    WHEN '/order/get' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_order($1)', JsonbToFields(r.fields, GetColumns('order', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_order($1)', JsonbToFields(r.fields, GetColumns('order', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/order/list' THEN

      IF pPayload IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
      ELSE
        pPayload := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.list_order($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('order', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/tariff/type' THEN

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.type($1)', JsonbToFields(r.fields, GetColumns('type', 'api'))) USING GetEssence('tariff')
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/tariff/method' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_tariff(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
        LOOP
          FOR e IN SELECT r.id, api.get_method(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_tariff(r.id) ORDER BY id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/tariff/count' THEN

      IF pPayload IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
      ELSE
        pPayload := '{}';
      END IF;

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_tariff(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
        LOOP
          FOR e IN SELECT count(*) FROM api.list_tariff(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/tariff/add' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['parent', 'type', 'code', 'name', 'cost', 'description']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(parent numeric, type varchar, code varchar, name varchar, cost numeric, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_tariff(r.parent, r.type, r.code, r.name, r.cost, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(parent numeric, type varchar, code varchar, name varchar, cost numeric, description text)
        LOOP
          RETURN NEXT row_to_json(api.add_tariff(r.parent, r.type, r.code, r.name, r.cost, r.description));
        END LOOP;

      END IF;

    WHEN '/tariff/update' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'parent', 'type', 'code', 'name', 'cost', 'description']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, parent numeric, type varchar, code varchar, name varchar, cost numeric, description text)
        LOOP
          RETURN NEXT row_to_json(api.update_tariff(r.id, r.parent, r.type, r.code, r.name, r.cost, r.description));
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, parent numeric, type varchar, code varchar, name varchar, cost numeric, description text)
        LOOP
          RETURN NEXT row_to_json(api.update_tariff(r.id, r.parent, r.type, r.code, r.name, r.cost, r.description));
        END LOOP;

      END IF;

    WHEN '/tariff/get' THEN

      IF pPayload IS NULL THEN
        PERFORM JsonIsEmpty();
      END IF;

      arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

      IF jsonb_typeof(pPayload) = 'array' THEN

        FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_tariff($1)', JsonbToFields(r.fields, GetColumns('tariff', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      ELSE

        FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
        LOOP
          FOR e IN EXECUTE format('SELECT %s FROM api.get_tariff($1)', JsonbToFields(r.fields, GetColumns('tariff', 'api'))) USING r.id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END LOOP;

      END IF;

    WHEN '/tariff/list' THEN

      IF pPayload IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
        PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
      ELSE
        pPayload := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.list_tariff($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('tariff', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    WHEN '/ocpp/log' THEN

      IF pPayload IS NOT NULL THEN
        arKeys := array_cat(arKeys, ARRAY['identity', 'action', 'datefrom', 'dateto']);
        PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
      ELSE
        pPayload := '{}';
      END IF;

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(identity varchar, action varchar, datefrom timestamp, dateto timestamp)
      LOOP
        FOR e IN SELECT * FROM api.ocpp_log(r.identity, r.action, r.datefrom, r.dateto)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

  ELSE
	PERFORM RouteNotFound(pPath);
  END CASE;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
