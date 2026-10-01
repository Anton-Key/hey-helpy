-- =====================================================================
-- Hey Helpy · тестовые данные для демо (НЕ миграция)
--
-- Запускать в Supabase → SQL Editor после миграций 0001–0005
-- (английские названия слоёв — после 0007; без неё шаг пропускается).
-- Перед запуском создайте трёх пользователей в Authentication → Users
-- и впишите их email ниже. Подробно: docs/DEMO_SETUP.md
--
-- Повторный запуск безопасен: записи с постоянными id обновляются,
-- связи добавляются, только если их ещё нет.
-- ВНИМАНИЕ: указанные пользователи будут перенесены в демо-компанию.
-- Используйте отдельные тестовые аккаунты, не рабочие.
-- =====================================================================

do $$
declare
  -- ▼▼▼ ВПИШИТЕ EMAIL ТЕСТОВЫХ ПОЛЬЗОВАТЕЛЕЙ ▼▼▼
  v_manager_email   text := 'manager@example.com';
  v_executor_email  text := 'executor@example.com';
  v_requester_email text := 'requester@example.com';
  -- ▲▲▲ ДАЛЬШЕ НИЧЕГО МЕНЯТЬ НЕ НУЖНО ▲▲▲

  -- Постоянные id демо-записей (за счёт них повторный запуск не плодит дубликаты)
  c_company    constant uuid := 'de300000-0000-4000-8000-000000000001';
  c_object     constant uuid := 'de300000-0000-4000-8000-000000000010';
  c_loc_meet   constant uuid := 'de300000-0000-4000-8000-000000000021';
  c_loc_elec   constant uuid := 'de300000-0000-4000-8000-000000000022';
  c_loc_open   constant uuid := 'de300000-0000-4000-8000-000000000023';
  c_loc_hall   constant uuid := 'de300000-0000-4000-8000-000000000024';
  c_contr_hvac constant uuid := 'de300000-0000-4000-8000-000000000031';
  c_contr_elec constant uuid := 'de300000-0000-4000-8000-000000000032';

  v_manager   uuid;
  v_executor  uuid;
  v_requester uuid;
  v_layer_hvac uuid;
  v_layer_elec uuid;
begin
  -- 1. Пользователи (созданы вручную в Authentication)
  select id into v_manager   from auth.users where lower(email) = lower(trim(v_manager_email));
  select id into v_executor  from auth.users where lower(email) = lower(trim(v_executor_email));
  select id into v_requester from auth.users where lower(email) = lower(trim(v_requester_email));
  if v_manager is null then
    raise exception 'Не найден пользователь менеджера: %. Создайте его в Authentication → Users', v_manager_email;
  end if;
  if v_executor is null then
    raise exception 'Не найден пользователь исполнителя: %. Создайте его в Authentication → Users', v_executor_email;
  end if;
  if v_requester is null then
    raise exception 'Не найден пользователь заявителя: %. Создайте его в Authentication → Users', v_requester_email;
  end if;
  if v_manager = v_executor or v_manager = v_requester or v_executor = v_requester then
    raise exception 'Нужны три разных пользователя';
  end if;

  -- 2. Компания. Слои по умолчанию добавляет триггер trg_company_default_layers;
  --    вызов seed_default_layers ниже — на случай, если компания уже была.
  insert into public.companies (id, name) values (c_company, 'Демо БЦ')
  on conflict (id) do update set name = excluded.name;
  perform public.seed_default_layers(c_company);

  select id into v_layer_hvac from public.layers where company_id = c_company and name = 'Климат';
  select id into v_layer_elec from public.layers where company_id = c_company and name = 'Электрика';
  if v_layer_hvac is null or v_layer_elec is null then
    raise exception 'Не найдены слои «Климат» и «Электрика». Проверьте, что применена миграция 0004';
  end if;

  -- Слои на двух языках (поле name_i18n появляется в миграции 0007;
  -- до неё этот шаг пропускается, остальной скрипт работает).
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'layers' and column_name = 'name_i18n') then
    execute $sql$
      update public.layers l
         set name_i18n = jsonb_build_object('ru', l.name, 'en', t.en)
        from (values
          ('Климат',               'HVAC'),
          ('Электрика',            'Electrical'),
          ('Сантехника',           'Plumbing'),
          ('Клининг',              'Cleaning'),
          ('Системы безопасности', 'Security systems'),
          ('Мебель',               'Furniture'),
          ('Другое',               'Other')
        ) as t(ru, en)
       where l.company_id = $1 and l.name = t.ru
    $sql$ using c_company;
  else
    raise notice 'Миграция 0007 не применена — английские названия слоёв пропущены.';
  end if;

  -- 3. Объект с координатами (для отметки визита по геозоне)
  insert into public.objects (id, company_id, name, type, address, lat, lng)
  values (c_object, c_company, 'БЦ «Демо»', 'office', 'Москва, ул. Примерная, 1', 55.749400, 37.537600)
  on conflict (id) do update
    set name = excluded.name, type = excluded.type, address = excluded.address,
        lat = excluded.lat, lng = excluded.lng;

  -- 4. Помещения
  insert into public.locations (id, object_id, name) values
    (c_loc_meet, c_object, 'Переговорная, 3 этаж'),
    (c_loc_elec, c_object, 'Электрощитовая, 1 этаж'),
    (c_loc_open, c_object, 'Open space, 2 этаж'),
    (c_loc_hall, c_object, 'Холл, 1 этаж')
  on conflict (id) do update set name = excluded.name, object_id = excluded.object_id;

  -- 5. Подрядчики
  insert into public.contractors (id, company_id, org_name) values
    (c_contr_hvac, c_company, 'КлиматСервис'),
    (c_contr_elec, c_company, 'ЭлектроПро')
  on conflict (id) do update set org_name = excluded.org_name;

  -- 6. Закрепление за слоями:
  --    «КлиматСервис» — «Климат» только на этом объекте,
  --    «ЭлектроПро» — «Электрика» на всех объектах компании.
  insert into public.contractor_layers (contractor_id, layer_id, object_id) values
    (c_contr_hvac, v_layer_hvac, c_object),
    (c_contr_elec, v_layer_elec, null)
  on conflict do nothing;

  -- 7. Пользователи: компания и роль
  insert into public.profiles (id, company_id, role, full_name) values
    (v_manager,   c_company, 'manager',   'Менеджер Демо'),
    (v_executor,  c_company, 'executor',  'Исполнитель Демо'),
    (v_requester, c_company, 'requester', 'Заявитель Демо')
  on conflict (id) do update
    set company_id = excluded.company_id,
        role       = excluded.role,
        full_name  = coalesce(public.profiles.full_name, excluded.full_name);

  -- 8. Исполнитель работает в «КлиматСервисе»
  insert into public.executors (profile_id, contractor_id)
  select v_executor, c_contr_hvac
  where not exists (select 1 from public.executors
                    where profile_id = v_executor and contractor_id = c_contr_hvac);

  raise notice 'Готово: компания «Демо БЦ», 4 помещения, 2 подрядчика, 3 пользователя.';
end $$;
