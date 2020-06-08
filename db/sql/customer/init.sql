--------------------------------------------------------------------------------
-- CreateClassTree -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassTree()
RETURNS void 
AS $$
DECLARE
  nId		    numeric[];
  nEssence		numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.essence (code, name) VALUES ('object', 'Объект');
  INSERT INTO db.essence (code, name) VALUES ('document', 'Документ');
  INSERT INTO db.essence (code, name) VALUES ('reference', 'Справочник');

  INSERT INTO db.essence (code, name) VALUES ('address', 'Адрес');
  INSERT INTO db.essence (code, name) VALUES ('client', 'Клиент');
  INSERT INTO db.essence (code, name) VALUES ('contract', 'Договор');
  INSERT INTO db.essence (code, name) VALUES ('card', 'Карта');
  INSERT INTO db.essence (code, name) VALUES ('charge_point', 'Зарядная станция');
  INSERT INTO db.essence (code, name) VALUES ('invoice', 'Счёт');
  INSERT INTO db.essence (code, name) VALUES ('order', 'Ордер');

  INSERT INTO db.essence (code, name) VALUES ('calendar', 'Календарь');
  INSERT INTO db.essence (code, name) VALUES ('tariff', 'Тариф');

  ------------------------------------------------------------------------------

  INSERT INTO db.state_type (code, name) VALUES ('created', 'Создан');
  INSERT INTO db.state_type (code, name) VALUES ('enabled', 'Включен');
  INSERT INTO db.state_type (code, name) VALUES ('disabled', 'Отключен');
  INSERT INTO db.state_type (code, name) VALUES ('deleted', 'Удалён');

  ------------------------------------------------------------------------------

  INSERT INTO db.action (code, name) VALUES ('anything', 'Ничто');

  INSERT INTO db.action (code, name) VALUES ('create', 'Создать');
  INSERT INTO db.action (code, name) VALUES ('open', 'Открыть');
  INSERT INTO db.action (code, name) VALUES ('edit', 'Изменить');
  INSERT INTO db.action (code, name) VALUES ('save', 'Сохранить');
  INSERT INTO db.action (code, name) VALUES ('enable', 'Включить');
  INSERT INTO db.action (code, name) VALUES ('disable', 'Отключить');
  INSERT INTO db.action (code, name) VALUES ('delete', 'Удалить');
  INSERT INTO db.action (code, name) VALUES ('restore', 'Восстановить');
  INSERT INTO db.action (code, name) VALUES ('drop', 'Уничтожить');
  INSERT INTO db.action (code, name) VALUES ('start', 'Запустить');
  INSERT INTO db.action (code, name) VALUES ('stop', 'Остановить');
  INSERT INTO db.action (code, name) VALUES ('check', 'Проверить');
  INSERT INTO db.action (code, name) VALUES ('cancel', 'Отменить');
  INSERT INTO db.action (code, name) VALUES ('abort', 'Прервать');
  INSERT INTO db.action (code, name) VALUES ('postpone', 'Отложить');
  INSERT INTO db.action (code, name) VALUES ('reserve', 'Резервировать');
  INSERT INTO db.action (code, name) VALUES ('return', 'Вернуть');

  -- OCPP ----------------------------------------------------------------------

  INSERT INTO db.action (code, name) VALUES ('Heartbeat', 'Heartbeat');

  INSERT INTO db.action (code, name) VALUES ('Available', 'Available');
  INSERT INTO db.action (code, name) VALUES ('Preparing', 'Preparing');
  INSERT INTO db.action (code, name) VALUES ('Charging', 'Charging');
  INSERT INTO db.action (code, name) VALUES ('SuspendedEV', 'SuspendedEV');
  INSERT INTO db.action (code, name) VALUES ('SuspendedEVSE', 'SuspendedEVSE');
  INSERT INTO db.action (code, name) VALUES ('Finishing', 'Finishing');
  INSERT INTO db.action (code, name) VALUES ('Reserved', 'Reserved');
  INSERT INTO db.action (code, name) VALUES ('Unavailable', 'Unavailable');
  INSERT INTO db.action (code, name) VALUES ('Faulted', 'Faulted');

  ------------------------------------------------------------------------------

  INSERT INTO db.event_type (code, name) VALUES ('parent', 'События класса родителя');
  INSERT INTO db.event_type (code, name) VALUES ('event', 'Событие');
  INSERT INTO db.event_type (code, name) VALUES ('plpgsql', 'PL/pgSQL код');

  -- Объект

  nEssence := GetEssence('object');

  nId[0] := AddClass(null, nEssence, 'object', 'Объект', true);

    -- Документ

    nEssence := GetEssence('document');

    nId[1] := AddClass(nId[0], nEssence, 'document', 'Документ', true);

      -- Адрес

      nEssence := GetEssence('address');

      nId[2] := AddClass(nId[1], nEssence, 'address', 'Адрес', false);

      -- Клиент

      nEssence := GetEssence('client');

      nId[2] := AddClass(nId[1], nEssence, 'client', 'Клиент', false);

      -- Договор

      nEssence := GetEssence('contract');

      nId[2] := AddClass(nId[1], nEssence, 'contract', 'Договор', false);

      -- Карта

      nEssence := GetEssence('card');

      nId[2] := AddClass(nId[1], nEssence, 'card', 'Карта', false);

      -- Зарядная станция

      nEssence := GetEssence('charge_point');

      nId[2] := AddClass(nId[1], nEssence, 'charge_point', 'Зарядная станция', false);

      -- Счёт-фактура

      nEssence := GetEssence('invoice');

      nId[2] := AddClass(nId[1], nEssence, 'invoice', 'Счёт на оплату', false);

      -- Ордер

      nEssence := GetEssence('order');

      nId[2] := AddClass(nId[1], nEssence, 'order', 'Ордер', false);

    -- Справочник

    nEssence := GetEssence('reference');

    nId[1] := AddClass(nId[0], nEssence, 'reference', 'Справочник', true);

      -- Календарь

      nEssence := GetEssence('calendar');

      nId[2] := AddClass(nId[1], nEssence, 'calendar', 'Календарь', false);

      -- Тариф

      nEssence := GetEssence('tariff');

      nId[2] := AddClass(nId[1], nEssence, 'tariff', 'Тариф', false);

END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateObjectType ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateObjectType()
RETURNS void 
AS $$
DECLARE
  rec_class	record;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(1001) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  FOR rec_class IN SELECT * FROM Class WHERE NOT abstract
  LOOP
    IF rec_class.code = 'address' THEN
      PERFORM AddType(rec_class.id, 'post.address', 'Почтовый', 'Почтовый адрес');
      PERFORM AddType(rec_class.id, 'actual.address', 'Фактический', 'Фактический адрес');
      PERFORM AddType(rec_class.id, 'legal.address', 'Юридический', 'Юридический адрес');
    END IF;

    IF rec_class.code = 'client' THEN
      PERFORM AddType(rec_class.id, 'entity.client', 'ЮЛ', 'Юридическое лицо');
      PERFORM AddType(rec_class.id, 'physical.client', 'ФЛ', 'Физическое лицо');
      PERFORM AddType(rec_class.id, 'individual.client', 'ИП', 'Индивидуальный предприниматель');
    END IF;

    IF rec_class.code = 'contract' THEN
      PERFORM AddType(rec_class.id, 'service.contract', 'Обслуживания', 'Договор обслуживания');
    END IF;

    IF rec_class.code = 'card' THEN
      PERFORM AddType(rec_class.id, 'rfid.card', 'RFID карта', 'Пластиковая карта c радиочастотной идентификацией');
      PERFORM AddType(rec_class.id, 'bank.card', 'Банковская карта', 'Банковская карта');
      PERFORM AddType(rec_class.id, 'plastic.card', 'Пластиковая карта', 'Пластиковая карта');
    END IF;

    IF rec_class.code = 'charge_point' THEN
      PERFORM AddType(rec_class.id, 'public.charge_point', 'Публичная', 'Публичная зарядная станция');
      PERFORM AddType(rec_class.id, 'private.charge_point', 'Приватная', 'Приватная зарядная станция');
    END IF;

    IF rec_class.code = 'invoice' THEN
      PERFORM AddType(rec_class.id, 'meter.invoice', 'Счёт', 'Счёт на оплату потребленной электроэнергии');
    END IF;

    IF rec_class.code = 'order' THEN
      PERFORM AddType(rec_class.id, 'payment.order', 'Заказ', 'Заказ на оплату через платёжную систему');
    END IF;

    IF rec_class.code = 'calendar' THEN
      PERFORM AddType(rec_class.id, 'workday.calendar', 'Рабочий', 'Календарь рабочих дней');
    END IF;

    IF rec_class.code = 'tariff' THEN
      PERFORM AddType(rec_class.id, 'client.tariff', 'Тариф', 'Тарифы');
    END IF;

  END LOOP;

END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddDefaultMethods -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddDefaultMethods (
  pClass	numeric
)
RETURNS void
AS $$
DECLARE
  nState  	    numeric;

  rec_class	    record;
  rec_type	    record;
  rec_state	    record;
  rec_method	record;
BEGIN

  FOR rec_class IN SELECT * FROM Class WHERE id = pClass
  LOOP
    -- Операции (без учёта состояния)

    PERFORM AddMethod(null, rec_class.id, null, GetAction('create'), null, 'Создать');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('open'), null, 'Открыть');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('edit'), null, 'Изменить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('save'), null, 'Сохранить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('enable'), null, 'Включить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('disable'), null, 'Выключить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('delete'), null, 'Удалить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('restore'), null, 'Восстановить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('drop'), null, 'Уничтожить');

    -- Операции

    FOR rec_type IN SELECT * FROM StateType
    LOOP

      CASE rec_type.code
      WHEN 'created' THEN

        nState := AddState(rec_class.id, rec_type.id, rec_type.code, 'Создан');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('enable'), null, 'Открыть');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('delete'), null, 'Удалить');

      WHEN 'enabled' THEN

        nState := AddState(rec_class.id, rec_type.id, rec_type.code, 'Открыт');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('disable'), null, 'Закрыть');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('delete'), null, 'Удалить');

      WHEN 'disabled' THEN

        nState := AddState(rec_class.id, rec_type.id, rec_type.code, 'Закрыт');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('enable'), null, 'Открыть');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('delete'), null, 'Удалить');

      WHEN 'deleted' THEN

        nState := AddState(rec_class.id, rec_type.id, rec_type.code, 'Удалён');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('restore'), null, 'Восстановить');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('drop'), null, 'Уничтожить');

      END CASE;

    END LOOP;

    FOR rec_method IN SELECT * FROM Method WHERE class = rec_class.id AND state IS NULL
    LOOP
      IF rec_method.actioncode = 'create' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'created'));
      END IF;

      IF rec_method.actioncode = 'enable' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'enabled'));
      END IF;

      IF rec_method.actioncode = 'disable' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'disabled'));
      END IF;

      IF rec_method.actioncode = 'delete' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'deleted'));
      END IF;

      IF rec_method.actioncode = 'restore' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'created'));
      END IF;
    END LOOP;

    FOR rec_state IN SELECT * FROM State WHERE class = rec_class.id
    LOOP
      CASE rec_state.code
      WHEN 'created' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'enable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'enabled'));
          END IF;

          IF rec_method.actioncode = 'delete' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'deleted'));
          END IF;
        END LOOP;

      WHEN 'enabled' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'disable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'disabled'));
          END IF;

          IF rec_method.actioncode = 'delete' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'deleted'));
          END IF;
        END LOOP;

      WHEN 'disabled' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'enable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'enabled'));
          END IF;

          IF rec_method.actioncode = 'delete' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'deleted'));
          END IF;
        END LOOP;

      WHEN 'deleted' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'restore' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'created'));
          END IF;
        END LOOP;
      END CASE;
    END LOOP;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddCardMethods --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddCardMethods (
  pClass	numeric
)
RETURNS void
AS $$
DECLARE
  nState  	    numeric;

  rec_class	    record;
  rec_type	    record;
  rec_state	    record;
  rec_method	record;
BEGIN

  FOR rec_class IN SELECT * FROM Class WHERE id = pClass
  LOOP
    -- Операции (без учёта состояния)

    PERFORM AddMethod(null, rec_class.id, null, GetAction('create'), null, 'Создать');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('open'), null, 'Открыть');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('edit'), null, 'Изменить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('save'), null, 'Сохранить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('enable'), null, 'Включить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('disable'), null, 'Выключить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('delete'), null, 'Удалить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('restore'), null, 'Восстановить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('drop'), null, 'Уничтожить');

    -- Операции

    FOR rec_type IN SELECT * FROM StateType
    LOOP

      CASE rec_type.code
      WHEN 'created' THEN

        nState := AddState(rec_class.id, rec_type.id, rec_type.code, 'Создана');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('enable'), null, 'Активировать');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('delete'), null, 'Удалить');

      WHEN 'enabled' THEN

        nState := AddState(rec_class.id, rec_type.id, rec_type.code, 'Активна');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('disable'), null, 'Заблокировать');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('delete'), null, 'Удалить');

      WHEN 'disabled' THEN

        nState := AddState(rec_class.id, rec_type.id, rec_type.code, 'Заблокирована');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('enable'), null, 'Активировать');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('delete'), null, 'Удалить');

      WHEN 'deleted' THEN

        nState := AddState(rec_class.id, rec_type.id, rec_type.code, 'Удалёна');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('restore'), null, 'Восстановить');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('drop'), null, 'Уничтожить');

      END CASE;

    END LOOP;

    FOR rec_method IN SELECT * FROM Method WHERE class = rec_class.id AND state IS NULL
    LOOP
      IF rec_method.actioncode = 'create' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'created'));
      END IF;

      IF rec_method.actioncode = 'enable' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'enabled'));
      END IF;

      IF rec_method.actioncode = 'disable' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'disabled'));
      END IF;

      IF rec_method.actioncode = 'delete' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'deleted'));
      END IF;

      IF rec_method.actioncode = 'restore' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'created'));
      END IF;
    END LOOP;

    FOR rec_state IN SELECT * FROM State WHERE class = rec_class.id
    LOOP
      CASE rec_state.code
      WHEN 'created' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'enable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'enabled'));
          END IF;

          IF rec_method.actioncode = 'delete' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'deleted'));
          END IF;
        END LOOP;

      WHEN 'enabled' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'disable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'disabled'));
          END IF;

          IF rec_method.actioncode = 'delete' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'deleted'));
          END IF;
        END LOOP;

      WHEN 'disabled' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'enable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'enabled'));
          END IF;

          IF rec_method.actioncode = 'delete' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'deleted'));
          END IF;
        END LOOP;

      WHEN 'deleted' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'restore' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'created'));
          END IF;
        END LOOP;
      END CASE;
    END LOOP;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddChargePointMethods -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddChargePointMethods (
  pClass        numeric
)
RETURNS void
AS $$
DECLARE
  nState        numeric;

  rec_class     record;
  rec_type      record;
  rec_state     record;
  rec_method    record;
BEGIN

  FOR rec_class IN SELECT * FROM Class WHERE id = pClass
  LOOP
    -- Операции (без учёта состояния)

    PERFORM AddMethod(null, rec_class.id, null, GetAction('create'), null, 'Создать');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('open'), null, 'Открыть');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('edit'), null, 'Изменить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('save'), null, 'Сохранить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('enable'), null, 'Включить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('disable'), null, 'Выключить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('delete'), null, 'Удалить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('restore'), null, 'Восстановить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('drop'), null, 'Уничтожить');

    PERFORM AddMethod(null, rec_class.id, null, GetAction('Heartbeat'), null, 'Heartbeat', null, false);

    -- Операции

    FOR rec_type IN SELECT * FROM StateType
    LOOP

      CASE rec_type.code
      WHEN 'created' THEN

        nState := AddState(rec_class.id, rec_type.id, rec_type.code, 'Добавлена');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('enable'), null, 'Включить');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('delete'), null, 'Удалить');

      WHEN 'enabled' THEN

        nState := AddState(rec_class.id, rec_type.id, 'unavailable', 'Недоступна');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Heartbeat'), null, 'Heartbeat', null, false);

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Available'), null, 'Доступна', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Preparing'), null, 'Подготовка', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Charging'), null, 'Зарядка', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('SuspendedEV'), null, 'SuspendedEV', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('SuspendedEVSE'), null, 'SuspendedEVSE', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Faulted'), null, 'Неисправность', null, false);

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('disable'), null, 'Отключить');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('delete'), null, 'Удалить');

        nState := AddState(rec_class.id, rec_type.id, 'available', 'Доступна');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Heartbeat'), null, 'Heartbeat', null, false);

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Preparing'), null, 'Подготовка', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Charging'), null, 'Зарядка', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('SuspendedEV'), null, 'SuspendedEV', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('SuspendedEVSE'), null, 'SuspendedEVSE', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Reserved'), null, 'Зарезервирована', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Unavailable'), null, 'Недоступна', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Faulted'), null, 'Неисправность', null, false);

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('disable'), null, 'Отключить');

        nState := AddState(rec_class.id, rec_type.id, 'charging', 'Заряжает');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Heartbeat'), null, 'Heartbeat', null, false);

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Available'), null, 'Доступна', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('SuspendedEV'), null, 'SuspendedEV', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('SuspendedEVSE'), null, 'SuspendedEVSE', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Finishing'), null, 'Завершение', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Unavailable'), null, 'Недоступна', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Faulted'), null, 'Неисправна', null, false);

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('disable'), null, 'Отключить');

        nState := AddState(rec_class.id, rec_type.id, 'reserved', 'Зарезервирована');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Heartbeat'), null, 'Heartbeat', null, false);

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Available'), null, 'Доступна', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Preparing'), null, 'Подготовка', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Unavailable'), null, 'Недоступна', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Faulted'), null, 'Неисправна', null, false);

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('disable'), null, 'Отключить');

        nState := AddState(rec_class.id, rec_type.id, 'faulted', 'Неисправна');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Heartbeat'), null, 'Heartbeat', null, false);

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Available'), null, 'Доступна', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Preparing'), null, 'Подготовка', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Charging'), null, 'Зарядка', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('SuspendedEV'), null, 'SuspendedEV', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('SuspendedEVSE'), null, 'SuspendedEVSE', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Finishing'), null, 'Завершение', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Reserved'), null, 'Зарезервирована', null, false);
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('Unavailable'), null, 'Недоступна');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('disable'), null, 'Отключить');

      WHEN 'disabled' THEN

        nState := AddState(rec_class.id, rec_type.id, rec_type.code, 'Отключена');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('enable'), null, 'Включить');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('delete'), null, 'Удалить');

      WHEN 'deleted' THEN

        nState := AddState(rec_class.id, rec_type.id, rec_type.code, 'Удалёна');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('restore'), null, 'Восстановить');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('drop'), null, 'Уничтожить');

      END CASE;

    END LOOP;

    FOR rec_method IN SELECT * FROM Method WHERE class = rec_class.id AND state IS NULL
    LOOP
      IF rec_method.actioncode = 'create' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'created'));
      END IF;

      IF rec_method.actioncode = 'enable' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'enabled'));
      END IF;

      IF rec_method.actioncode = 'disable' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'disabled'));
      END IF;

      IF rec_method.actioncode = 'delete' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'deleted'));
      END IF;

      IF rec_method.actioncode = 'restore' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'created'));
      END IF;
    END LOOP;

    FOR rec_state IN SELECT * FROM State WHERE class = rec_class.id
    LOOP
      CASE rec_state.code
      WHEN 'created' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'enable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'unavailable'));
          END IF;

          IF rec_method.actioncode = 'delete' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'deleted'));
          END IF;
        END LOOP;

      WHEN 'unavailable' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'Available' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'available'));
          END IF;

          IF rec_method.actioncode = 'Charging' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'charging'));
          END IF;

          IF rec_method.actioncode = 'Faulted' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'faulted'));
          END IF;

          IF rec_method.actioncode = 'disable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'disabled'));
          END IF;

          IF rec_method.actioncode = 'delete' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'deleted'));
          END IF;
        END LOOP;

      WHEN 'available' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'Charging' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'charging'));
          END IF;

          IF rec_method.actioncode = 'Reserved' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'reserved'));
          END IF;

          IF rec_method.actioncode = 'Unavailable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'unavailable'));
          END IF;

          IF rec_method.actioncode = 'Faulted' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'faulted'));
          END IF;

          IF rec_method.actioncode = 'disable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'disabled'));
          END IF;
        END LOOP;

      WHEN 'charging' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'Available' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'available'));
          END IF;

          IF rec_method.actioncode = 'Finishing' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'available'));
          END IF;

          IF rec_method.actioncode = 'Unavailable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'unavailable'));
          END IF;

          IF rec_method.actioncode = 'Faulted' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'faulted'));
          END IF;

          IF rec_method.actioncode = 'disable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'disabled'));
          END IF;
        END LOOP;

      WHEN 'reserved' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'Available' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'available'));
          END IF;

          IF rec_method.actioncode = 'Unavailable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'unavailable'));
          END IF;

          IF rec_method.actioncode = 'Faulted' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'faulted'));
          END IF;

          IF rec_method.actioncode = 'disable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'disabled'));
          END IF;
        END LOOP;

      WHEN 'faulted' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'Available' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'available'));
          END IF;

          IF rec_method.actioncode = 'Charging' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'charging'));
          END IF;

          IF rec_method.actioncode = 'Finishing' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'available'));
          END IF;

          IF rec_method.actioncode = 'Reserved' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'reserved'));
          END IF;

          IF rec_method.actioncode = 'Unavailable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'unavailable'));
          END IF;

          IF rec_method.actioncode = 'disable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'disabled'));
          END IF;
        END LOOP;

      WHEN 'disabled' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'enable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'unavailable'));
          END IF;

          IF rec_method.actioncode = 'delete' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'deleted'));
          END IF;
        END LOOP;

      WHEN 'deleted' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'restore' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'created'));
          END IF;
        END LOOP;
      END CASE;
    END LOOP;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddInvoiceMethods -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddInvoiceMethods (
  pClass	numeric
)
RETURNS void
AS $$
DECLARE
  nState  	    numeric;

  rec_class	    record;
  rec_type	    record;
  rec_state	    record;
  rec_method	record;
BEGIN

  FOR rec_class IN SELECT * FROM Class WHERE id = pClass
  LOOP
    -- Операции (без учёта состояния)

    PERFORM AddMethod(null, rec_class.id, null, GetAction('create'), null, 'Создать');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('open'), null, 'Открыть');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('edit'), null, 'Изменить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('save'), null, 'Сохранить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('enable'), null, 'Включить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('disable'), null, 'Выключить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('delete'), null, 'Удалить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('restore'), null, 'Восстановить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('drop'), null, 'Уничтожить');

    -- Операции

    FOR rec_type IN SELECT * FROM StateType
    LOOP

      CASE rec_type.code
      WHEN 'created' THEN

        nState := AddState(rec_class.id, rec_type.id, rec_type.code, 'Не оплачен');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('enable'), null, 'В работу');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('disable'), null, 'Оплатить');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('delete'), null, 'Удалить');

      WHEN 'enabled' THEN

        nState := AddState(rec_class.id, rec_type.id, rec_type.code, 'В работе');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('cancel'), null, 'Отменить');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('disable'), null, 'Оплатить');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('delete'), null, 'Удалить');

      WHEN 'disabled' THEN

        nState := AddState(rec_class.id, rec_type.id, rec_type.code, 'Оплачен');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('enable'), null, 'В работу');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('delete'), null, 'Удалить');

      WHEN 'deleted' THEN

        nState := AddState(rec_class.id, rec_type.id, rec_type.code, 'Удалён');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('restore'), null, 'Восстановить');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('drop'), null, 'Уничтожить');

      END CASE;

    END LOOP;

    FOR rec_method IN SELECT * FROM Method WHERE class = rec_class.id AND state IS NULL
    LOOP
      IF rec_method.actioncode = 'create' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'created'));
      END IF;

      IF rec_method.actioncode = 'enable' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'enabled'));
      END IF;

      IF rec_method.actioncode = 'disable' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'disabled'));
      END IF;

      IF rec_method.actioncode = 'delete' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'deleted'));
      END IF;

      IF rec_method.actioncode = 'restore' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'created'));
      END IF;
    END LOOP;

    FOR rec_state IN SELECT * FROM State WHERE class = rec_class.id
    LOOP
      CASE rec_state.code
      WHEN 'created' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'enable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'enabled'));
          END IF;

          IF rec_method.actioncode = 'disable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'disabled'));
          END IF;

          IF rec_method.actioncode = 'delete' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'deleted'));
          END IF;
        END LOOP;

      WHEN 'enabled' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'cancel' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'created'));
          END IF;

          IF rec_method.actioncode = 'disable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'disabled'));
          END IF;

          IF rec_method.actioncode = 'delete' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'deleted'));
          END IF;
        END LOOP;

      WHEN 'disabled' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'enable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'enabled'));
          END IF;

          IF rec_method.actioncode = 'delete' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'deleted'));
          END IF;
        END LOOP;

      WHEN 'deleted' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'restore' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'created'));
          END IF;
        END LOOP;
      END CASE;
    END LOOP;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddOrderMethods -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddOrderMethods (
  pClass	numeric
)
RETURNS void
AS $$
DECLARE
  nState  	    numeric;

  rec_class	    record;
  rec_type	    record;
  rec_state	    record;
  rec_method	record;
BEGIN

  FOR rec_class IN SELECT * FROM Class WHERE id = pClass
  LOOP
    -- Операции (без учёта состояния)

    PERFORM AddMethod(null, rec_class.id, null, GetAction('create'), null, 'Создать');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('open'), null, 'Открыть');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('edit'), null, 'Изменить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('save'), null, 'Сохранить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('enable'), null, 'Включить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('disable'), null, 'Выключить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('delete'), null, 'Удалить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('restore'), null, 'Восстановить');
    PERFORM AddMethod(null, rec_class.id, null, GetAction('drop'), null, 'Уничтожить');

    -- Операции

    FOR rec_type IN SELECT * FROM StateType
    LOOP

      CASE rec_type.code
      WHEN 'created' THEN

        nState := AddState(rec_class.id, rec_type.id, rec_type.code, 'Новый');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('enable'), null, 'Отправить');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('delete'), null, 'Удалить');

      WHEN 'enabled' THEN

        nState := AddState(rec_class.id, rec_type.id, rec_type.code, 'Отправлен');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('cancel'), null, 'Отменить');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('disable'), null, 'Принять');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('delete'), null, 'Удалить');

      WHEN 'disabled' THEN

        nState := AddState(rec_class.id, rec_type.id, rec_type.code, 'Принят');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('return'), null, 'Вернуть');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('delete'), null, 'Удалить');

      WHEN 'deleted' THEN

        nState := AddState(rec_class.id, rec_type.id, rec_type.code, 'Удалён');

          PERFORM AddMethod(null, rec_class.id, nState, GetAction('restore'), null, 'Восстановить');
          PERFORM AddMethod(null, rec_class.id, nState, GetAction('drop'), null, 'Уничтожить');

      END CASE;

    END LOOP;

    FOR rec_method IN SELECT * FROM Method WHERE class = rec_class.id AND state IS NULL
    LOOP
      IF rec_method.actioncode = 'create' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'created'));
      END IF;

      IF rec_method.actioncode = 'enable' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'enabled'));
      END IF;

      IF rec_method.actioncode = 'disable' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'disabled'));
      END IF;

      IF rec_method.actioncode = 'delete' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'deleted'));
      END IF;

      IF rec_method.actioncode = 'restore' THEN
        PERFORM AddTransition(null, rec_method.id, GetState(rec_class.id, 'created'));
      END IF;
    END LOOP;

    FOR rec_state IN SELECT * FROM State WHERE class = rec_class.id
    LOOP
      CASE rec_state.code
      WHEN 'created' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'enable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'enabled'));
          END IF;

          IF rec_method.actioncode = 'delete' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'deleted'));
          END IF;
        END LOOP;

      WHEN 'enabled' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'cancel' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'created'));
          END IF;

          IF rec_method.actioncode = 'disable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'disabled'));
          END IF;

          IF rec_method.actioncode = 'delete' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'deleted'));
          END IF;
        END LOOP;

      WHEN 'disabled' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'enable' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'enabled'));
          END IF;

          IF rec_method.actioncode = 'delete' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'deleted'));
          END IF;
        END LOOP;

      WHEN 'deleted' THEN

        FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
        LOOP
          IF rec_method.actioncode = 'restore' THEN
            PERFORM AddTransition(rec_state.id, rec_method.id, GetState(rec_class.id, 'created'));
          END IF;
        END LOOP;
      END CASE;
    END LOOP;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- KernelInit ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION KernelInit()
RETURNS void 
AS $$
DECLARE
  nEvent	numeric;
  nParent	numeric;

  rec_class	record;
  rec_action	record;
BEGIN
  nParent := GetEventType('parent');
  nEvent := GetEventType('event');

  FOR rec_class IN SELECT * FROM ClassTree
  LOOP
    IF rec_class.essencecode = 'object' THEN

      FOR rec_action IN SELECT * FROM Action
      LOOP
        IF rec_action.code = 'create' THEN
          PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Создать', 'EventObjectCreate();');
          PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Смена состояния', 'ChangeObjectState();');
        END IF;

        IF rec_action.code = 'open' THEN
          PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Открыть', 'EventObjectOpen();');
        END IF;

        IF rec_action.code = 'edit' THEN
          PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Изменить', 'EventObjectEdit();');
        END IF;

        IF rec_action.code = 'save' THEN
          PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Сохранить', 'EventObjectSave();');
        END IF;

        IF rec_action.code = 'enable' THEN
          PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Включить', 'EventObjectEnable();');
          PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Смена состояния', 'ChangeObjectState();');
        END IF;

        IF rec_action.code = 'disable' THEN
          PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Выключить', 'EventObjectDisable();');
          PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Смена состояния', 'ChangeObjectState();');
        END IF;

        IF rec_action.code = 'delete' THEN
          PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Удалить', 'EventObjectDelete();');
          PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Смена состояния', 'ChangeObjectState();');
        END IF;

        IF rec_action.code = 'restore' THEN
          PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Восстановить', 'EventObjectRestore();');
          PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Смена состояния', 'ChangeObjectState();');
        END IF;

        IF rec_action.code = 'drop' THEN
          PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Уничтожить', 'EventObjectDrop();');
        END IF;
      END LOOP;

      PERFORM AddDefaultMethods(rec_class.id);

    ELSIF rec_class.essencecode = 'document' THEN

      IF rec_class.code = 'document' THEN

        FOR rec_action IN SELECT * FROM Action
        LOOP

          IF rec_action.code = 'create' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Документ создан', 'EventDocumentCreate();');
          END IF;

          IF rec_action.code = 'open' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Документ открыт', 'EventDocumentOpen();');
          END IF;

          IF rec_action.code = 'edit' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Документ изменён', 'EventDocumentEdit();');
          END IF;

          IF rec_action.code = 'save' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Документ сохранён', 'EventDocumentSave();');
          END IF;

          IF rec_action.code = 'enable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Документ включен', 'EventDocumentEnable();');
          END IF;

          IF rec_action.code = 'disable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Документ отключен', 'EventDocumentDisable();');
          END IF;

          IF rec_action.code = 'delete' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Документ будет удалён', 'EventDocumentDelete();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

          IF rec_action.code = 'restore' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Документ восстановлен', 'EventDocumentRestore();');
          END IF;

          IF rec_action.code = 'drop' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Документ будет уничтожен', 'EventDocumentDrop();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

        END LOOP;

      ELSE
        -- Для всех остальных события класса родителя
        FOR rec_action IN SELECT * FROM Action
        LOOP
          PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
        END LOOP;

      END IF;

      PERFORM AddDefaultMethods(rec_class.id);

    ELSIF rec_class.essencecode = 'address' THEN

      IF rec_class.code = 'address' THEN

        FOR rec_action IN SELECT * FROM Action
        LOOP

          IF rec_action.code = 'create' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Адрес создан', 'EventAddressCreate();');
          END IF;

          IF rec_action.code = 'open' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Адрес открыт', 'EventAddressOpen();');
          END IF;

          IF rec_action.code = 'edit' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Адрес изменён', 'EventAddressEdit();');
          END IF;

          IF rec_action.code = 'save' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Адрес сохранён', 'EventAddressSave();');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Обновить кеш', 'UpdateObjectCache();');
          END IF;

          IF rec_action.code = 'enable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Смена состояния у всех детей', 'ExecuteMethodForAllChild();');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Адрес доступен', 'EventAddressEnable();');
          END IF;

          IF rec_action.code = 'disable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Смена состояния у всех детей', 'ExecuteMethodForAllChild();');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Адрес недоступен', 'EventAddressDisable();');
          END IF;

          IF rec_action.code = 'delete' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Адрес будет удалён', 'EventAddressDelete();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

          IF rec_action.code = 'restore' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Адрес восстановлен', 'EventAddressRestore();');
          END IF;

          IF rec_action.code = 'drop' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Адрес будет уничтожен', 'EventAddressDrop();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

        END LOOP;

      ELSE
        -- Для всех остальных события класса родителя
        FOR rec_action IN SELECT * FROM Action
        LOOP
          PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
        END LOOP;

      END IF;

      PERFORM AddDefaultMethods(rec_class.id);

    ELSIF rec_class.essencecode = 'client' THEN

      IF rec_class.code = 'client' THEN

        FOR rec_action IN SELECT * FROM Action
        LOOP

          IF rec_action.code = 'create' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Клиент создан', 'EventClientCreate();');
          END IF;

          IF rec_action.code = 'open' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Клиент открыт', 'EventClientOpen();');
          END IF;

          IF rec_action.code = 'edit' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Клиент изменён', 'EventClientEdit();');
          END IF;

          IF rec_action.code = 'save' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Клиент сохранён', 'EventClientSave();');
          END IF;

          IF rec_action.code = 'enable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Клиент активен', 'EventClientEnable();');
          END IF;

          IF rec_action.code = 'disable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Клиент не активен', 'EventClientDisable();');
          END IF;

          IF rec_action.code = 'delete' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Клиент будет удалён', 'EventClientDelete();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

          IF rec_action.code = 'restore' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Клиент восстановлен', 'EventClientRestore();');
          END IF;

          IF rec_action.code = 'drop' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Клиент будет уничтожен', 'EventClientDrop();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

        END LOOP;

      ELSE
        -- Для всех остальных события класса родителя
        FOR rec_action IN SELECT * FROM Action
        LOOP
          PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
        END LOOP;

      END IF;

      PERFORM AddDefaultMethods(rec_class.id);

    ELSIF rec_class.essencecode = 'contract' THEN

      IF rec_class.code = 'contract' THEN

        FOR rec_action IN SELECT * FROM Action
        LOOP

          IF rec_action.code = 'create' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Договор создан', 'EventContractCreate();');
          END IF;

          IF rec_action.code = 'open' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Договор открыт', 'EventContractOpen();');
          END IF;

          IF rec_action.code = 'edit' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Договор изменён', 'EventContractEdit();');
          END IF;

          IF rec_action.code = 'save' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Договор сохранён', 'EventContractSave();');
          END IF;

          IF rec_action.code = 'enable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Договор начал действовать', 'EventContractEnable();');
          END IF;

          IF rec_action.code = 'disable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Договор перестал действовать', 'EventContractDisable();');
          END IF;

          IF rec_action.code = 'delete' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Договор будет удалён', 'EventContractDelete();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

          IF rec_action.code = 'restore' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Договор восстановлен', 'EventContractDelete();');
          END IF;

          IF rec_action.code = 'drop' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Договор будет уничтожен', 'EventContractDrop();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

        END LOOP;

      ELSE
        -- Для всех остальных события класса родителя
        FOR rec_action IN SELECT * FROM Action
        LOOP
          PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
        END LOOP;

      END IF;

      PERFORM AddDefaultMethods(rec_class.id);

    ELSIF rec_class.essencecode = 'card' THEN

      IF rec_class.code = 'card' THEN

        FOR rec_action IN SELECT * FROM Action
        LOOP

          IF rec_action.code = 'create' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Карта создана', 'EventCardCreate();');
          END IF;

          IF rec_action.code = 'open' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Карта открыта', 'EventCardOpen();');
          END IF;

          IF rec_action.code = 'edit' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Карта изменёна', 'EventCardEdit();');
          END IF;

          IF rec_action.code = 'save' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Карта сохранёна', 'EventCardSave();');
          END IF;

          IF rec_action.code = 'enable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Карта активирована', 'EventCardEnable();');
          END IF;

          IF rec_action.code = 'disable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Карта заблокирована', 'EventCardDisable();');
          END IF;

          IF rec_action.code = 'delete' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Карта будет удалёна', 'EventCardDelete();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

          IF rec_action.code = 'restore' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Карта восстановлена', 'EventCardDelete();');
          END IF;

          IF rec_action.code = 'drop' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Карта будет уничтожена', 'EventCardDrop();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

        END LOOP;

      ELSE
        -- Для всех остальных события класса родителя
        FOR rec_action IN SELECT * FROM Action
        LOOP
          PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
        END LOOP;

      END IF;

      PERFORM AddCardMethods(rec_class.id);

    ELSIF rec_class.essencecode = 'charge_point' THEN

      IF rec_class.code = 'charge_point' THEN

        FOR rec_action IN SELECT * FROM Action
        LOOP

          IF rec_action.code = 'create' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Зарядная станция создана', 'EventChargePointCreate();');
          END IF;

          IF rec_action.code = 'open' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Зарядная станция открыта', 'EventChargePointOpen();');
          END IF;

          IF rec_action.code = 'edit' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Зарядная станция измена', 'EventChargePointEdit();');
          END IF;

          IF rec_action.code = 'save' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Зарядная станция сохрана', 'EventChargePointSave();');
          END IF;

          IF rec_action.code = 'enable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Зарядная станция включена', 'EventChargePointEnable();');
          END IF;

          IF rec_action.code = 'Heartbeat' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Зарядная станция на связи', 'EventChargePointHeartbeat();');
          END IF;

          IF rec_action.code = 'Available' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Зарядная станция доступна', 'EventChargePointAvailable();');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Смена состояния', 'ChangeObjectState();');
          END IF;

          IF rec_action.code = 'Preparing' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Зарядная станция отправила статус: Preparing', 'EventChargePointPreparing();');
          END IF;

          IF rec_action.code = 'Charging' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Зарядная станция заряжает', 'EventChargePointCharging();');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Смена состояния', 'ChangeObjectState();');
          END IF;

          IF rec_action.code = 'SuspendedEV' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Зарядная станция отправила статус: SuspendedEV', 'EventChargePointSuspendedEV();');
          END IF;

          IF rec_action.code = 'SuspendedEVSE' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Зарядная станция отправила статус: SuspendedEVSE', 'EventChargePointSuspendedEVSE();');
          END IF;

          IF rec_action.code = 'Finishing' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Зарядная станция отправила статус: Finishing', 'EventChargePointFinishing();');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Смена состояния', 'ChangeObjectState();');
          END IF;

          IF rec_action.code = 'Reserved' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Зарядная станция зарезервирована', 'EventChargePointReserved();');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Смена состояния', 'ChangeObjectState();');
          END IF;

          IF rec_action.code = 'Unavailable' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Зарядная станция недоступна', 'EventChargePointUnavailable();');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Смена состояния', 'ChangeObjectState();');
          END IF;

          IF rec_action.code = 'Faulted' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Зарядная станция неисправна', 'EventChargePointFaulted();');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Смена состояния', 'ChangeObjectState();');
          END IF;

          IF rec_action.code = 'disable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Зарядная станция отключена', 'EventChargePointDisable();');
          END IF;

          IF rec_action.code = 'delete' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Зарядная станция будет удалёна', 'EventChargePointDelete();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

          IF rec_action.code = 'restore' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Зарядная станция восстановлена', 'EventChargePointRestore();');
          END IF;

          IF rec_action.code = 'drop' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Зарядная станция будет уничтожена', 'EventChargePointDrop();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

        END LOOP;

      ELSE
        -- Для всех остальных события класса родителя
        FOR rec_action IN SELECT * FROM Action
        LOOP
          PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
        END LOOP;

      END IF;

      PERFORM AddChargePointMethods(rec_class.id);

    ELSIF rec_class.essencecode = 'invoice' THEN

      IF rec_class.code = 'invoice' THEN

        FOR rec_action IN SELECT * FROM Action
        LOOP

          IF rec_action.code = 'create' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Счёт на оплату создан', 'EventInvoiceCreate();');
          END IF;

          IF rec_action.code = 'open' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Счёт на оплату открыт', 'EventInvoiceOpen();');
          END IF;

          IF rec_action.code = 'edit' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Счёт на оплату изменён', 'EventInvoiceEdit();');
          END IF;

          IF rec_action.code = 'save' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Счёт на оплату сохранён', 'EventInvoiceSave();');
          END IF;

          IF rec_action.code = 'enable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Счёт на оплату в работе', 'EventInvoiceEnable();');
          END IF;

          IF rec_action.code = 'cancel' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Счёт на оплату будет отменён', 'EventInvoiceCancel();');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Смена состояния', 'ChangeObjectState();');
          END IF;

          IF rec_action.code = 'disable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Счёт на оплату оплачен', 'EventInvoiceDisable();');
          END IF;

          IF rec_action.code = 'delete' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Счёт на оплату будет удалён', 'EventInvoiceDelete();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

          IF rec_action.code = 'restore' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Счёт на оплату восстановлен', 'EventInvoiceDelete();');
          END IF;

          IF rec_action.code = 'drop' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Счёт на оплату будет уничтожен', 'EventInvoiceDrop();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

        END LOOP;

      ELSE
        -- Для всех остальных события класса родителя
        FOR rec_action IN SELECT * FROM Action
        LOOP
          PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
        END LOOP;

      END IF;

      PERFORM AddInvoiceMethods(rec_class.id);

    ELSIF rec_class.essencecode = 'order' THEN

      IF rec_class.code = 'order' THEN

        FOR rec_action IN SELECT * FROM Action
        LOOP

          IF rec_action.code = 'create' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Ордер создан', 'EventOrderCreate();');
          END IF;

          IF rec_action.code = 'open' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Ордер открыт', 'EventOrderOpen();');
          END IF;

          IF rec_action.code = 'edit' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Ордер изменён', 'EventOrderEdit();');
          END IF;

          IF rec_action.code = 'save' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Ордер сохранён', 'EventOrderSave();');
          END IF;

          IF rec_action.code = 'enable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Ордер отправлен', 'EventOrderEnable();');
          END IF;

          IF rec_action.code = 'cancel' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Ордер будет отменён', 'EventOrderCancel();');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Смена состояния', 'ChangeObjectState();');
          END IF;

          IF rec_action.code = 'return' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Ордер будет возвращён', 'EventOrderReturn();');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Смена состояния', 'ChangeObjectState();');
          END IF;

          IF rec_action.code = 'disable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Ордер принят', 'EventOrderDisable();');
          END IF;

          IF rec_action.code = 'delete' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Ордер будет удалён', 'EventOrderDelete();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

          IF rec_action.code = 'restore' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Ордер восстановлен', 'EventOrderDelete();');
          END IF;

          IF rec_action.code = 'drop' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Ордер будет уничтожен', 'EventOrderDrop();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

        END LOOP;

      ELSE
        -- Для всех остальных события класса родителя
        FOR rec_action IN SELECT * FROM Action
        LOOP
          PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
        END LOOP;

      END IF;

      PERFORM AddOrderMethods(rec_class.id);

    ELSIF rec_class.essencecode = 'reference' THEN

      IF rec_class.code = 'reference' THEN

        FOR rec_action IN SELECT * FROM Action
        LOOP

          IF rec_action.code = 'create' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Справочник создан', 'EventReferenceCreate();');
          END IF;

          IF rec_action.code = 'open' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Справочник открыт', 'EventReferenceOpen();');
          END IF;

          IF rec_action.code = 'edit' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Справочник изменён', 'EventReferenceEdit();');
          END IF;

          IF rec_action.code = 'save' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Справочник сохранён', 'EventReferenceSave();');
          END IF;

          IF rec_action.code = 'enable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Справочник доступен', 'EventReferenceEnable();');
          END IF;

          IF rec_action.code = 'disable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Справочник недоступен', 'EventReferenceDisable();');
          END IF;

          IF rec_action.code = 'delete' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Справочник будет удалён', 'EventReferenceDelete();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

          IF rec_action.code = 'restore' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Справочник восстановлен', 'EventReferenceRestore();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

          IF rec_action.code = 'drop' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Справочник будет уничтожен', 'EventReferenceDrop();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

        END LOOP;

      ELSE
        -- Для всех остальных события класса родителя
        FOR rec_action IN SELECT * FROM Action
        LOOP
          PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
        END LOOP;

      END IF;

      PERFORM AddDefaultMethods(rec_class.id);

    ELSIF rec_class.essencecode = 'calendar' THEN

      IF rec_class.code = 'calendar' THEN

        FOR rec_action IN SELECT * FROM Action
        LOOP

          IF rec_action.code = 'create' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Календарь создан', 'EventCalendarCreate();');
          END IF;

          IF rec_action.code = 'open' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Календарь открыт', 'EventCalendarOpen();');
          END IF;

          IF rec_action.code = 'edit' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Календарь изменён', 'EventCalendarEdit();');
          END IF;

          IF rec_action.code = 'save' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Календарь сохранён', 'EventCalendarSave();');
          END IF;

          IF rec_action.code = 'enable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Календарь доступен', 'EventCalendarEnable();');
          END IF;

          IF rec_action.code = 'disable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Календарь недоступен', 'EventCalendarDisable();');
          END IF;

          IF rec_action.code = 'delete' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Календарь будет удалён', 'EventCalendarDelete();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

          IF rec_action.code = 'restore' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Календарь восстановлен', 'EventCalendarRestore();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

          IF rec_action.code = 'drop' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Календарь будет уничтожен', 'EventCalendarDrop();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

        END LOOP;

      ELSE
        -- Для всех остальных события класса родителя
        FOR rec_action IN SELECT * FROM Action
        LOOP
          PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
        END LOOP;

      END IF;

      PERFORM AddDefaultMethods(rec_class.id);

    ELSIF rec_class.essencecode = 'tariff' THEN

      IF rec_class.code = 'tariff' THEN

        FOR rec_action IN SELECT * FROM Action
        LOOP

          IF rec_action.code = 'create' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Тариф создан', 'EventTariffCreate();');
          END IF;

          IF rec_action.code = 'open' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Тариф открыт', 'EventTariffOpen();');
          END IF;

          IF rec_action.code = 'edit' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Тариф изменён', 'EventTariffEdit();');
          END IF;

          IF rec_action.code = 'save' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Тариф сохранён', 'EventTariffSave();');
          END IF;

          IF rec_action.code = 'enable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Тариф доступен', 'EventTariffEnable();');
          END IF;

          IF rec_action.code = 'disable' THEN
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Тариф недоступен', 'EventTariffDisable();');
          END IF;

          IF rec_action.code = 'delete' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Тариф будет удалён', 'EventTariffDelete();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

          IF rec_action.code = 'restore' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Тариф восстановлен', 'EventTariffRestore();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

          IF rec_action.code = 'drop' THEN
            PERFORM AddEvent(rec_class.id, nEvent, rec_action.id, 'Тариф будет уничтожен', 'EventTariffDrop();');
            PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
          END IF;

        END LOOP;

      ELSE
        -- Для всех остальных события класса родителя
        FOR rec_action IN SELECT * FROM Action
        LOOP
          PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
        END LOOP;

      END IF;

      PERFORM AddDefaultMethods(rec_class.id);

    ELSE

      FOR rec_action IN SELECT * FROM Action
      LOOP
        PERFORM AddEvent(rec_class.id, nParent, rec_action.id, 'События класса родителя');
      END LOOP;

      PERFORM AddDefaultMethods(rec_class.id);

    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
