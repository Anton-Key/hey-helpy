-- =====================================================================
-- Hey Helpy · демо-история за последние 30 дней (НЕ миграция)
--
-- Что делает: добавляет в компанию «Демо БЦ» 72 заявки и 16 визитов,
-- чтобы на демо «История» и «Отчёты» были наполнены, и 4 объекта на карте:
--   • «КлиматСервис» (Климат) — 15 заявок, всё в срок, приёмка почти всегда
--     с первого раза, 15 визитов при норме 4 в месяц;
--   • «ЭлектроПро» (Электрика) — 10 заявок, 2 просрочены, 3 возвращали
--     на доработку, визитов меньше нормы 2 в месяц (один — с подменой GPS).
--   • эти 25 заявок — на «БЦ «Демо»» (Белград, Савски венац);
--   • ещё 10 заявок (211–220) — на 4 новых объектах в Белграде
--     («ТЦ «Демо Плаза»», «Склад «Демо Логистик»», «Офис «Демо Сити»»,
--     «Отель «Демо Парк»»; 11 помещений) — для карты во вкладке «Локации»:
--     у «Плазы» просроченная critical (красный маркер), у склада открытых
--     заявок нет (серо-зелёный). Из них 5 — «ЭлектроПро» (+1 просрочка в отчёте).
--   • ещё 2 повторяющиеся заявки (221–222) на «БЦ «Демо»» — для фильтра
--     «Ещё → Тип → Повторяющаяся» (шаг 13c).
--   • объекты по миру (шаг 13d): 15 офисов (401–415) в Белграде, Москве, Дубае,
--     Стамбуле, Абиджане, Шэньчжэне и Пекине, 45 помещений (421–465),
--     10 региональных подрядчиков (501–510) с закреплениями по объектам и видам
--     работ, 31 заявка (223–253): 4 просрочены, 3 без подрядчика, 2 повторяющиеся.
--     «ЭлектроПро» переводится с «всех объектов» на белградские.
--   • планы этажей (шаг 14b, блок 5d — генерирует tools/demo_plans/generate.mjs):
--     этажи 601 «1 этаж» и 602 «3 этаж» у «БЦ «Демо»», 603 «15 этаж» у «Skyline»,
--     7 новых помещений (052–056, 466–467), точки помещений на ДЕМО-СХЕМАХ,
--     оборудование 701–720, 4 заявки на нём (254–257, 254 просрочена).
--     Картинки планов (plan_path) скрипт не трогает — их загружают через приложение.
--
-- Запускать в Supabase → SQL Editor ПОСЛЕ supabase/seed/demo.sql
-- и миграций 0001–0010. Подробно: docs/DEMO_SETUP.md, шаг 4.
-- Или без SQL Editor: GitHub → Actions → «Refresh demo» (CLAUDE.md, «Перезаливка демо-данных»).
--
-- Даты считаются от момента запуска: «29 дней назад», «вчера» и т. д.
-- Повторный запуск безопасен: записи с постоянными id (de300000-…-000000000101
-- и дальше) не дублируются, а возвращаются в исходный вид, даты обновляются.
--
-- ПОЧЕМУ ВЫКЛЮЧАЮТСЯ ТРИГГЕРЫ
-- Правила базы (trg_wo_guard, trg_wo_layer_and_route, trg_wo_status_flow,
-- trg_wo_return_count, trg_work_orders_updated_at, trg_visits_fill,
-- trg_wo_close_visits) при вставке ставят текущее время, статус «Новая» или
-- «Назначена», обнуляют счётчик возвратов. Прошлое так не записать.
-- Поэтому основной блок выполняется с `set local session_replication_role = replica`:
--   • `local` — только внутри транзакции этого скрипта (begin … commit).
--     Приложение и другие подключения работают с триггерами как обычно;
--     после commit или при любой ошибке всё возвращается само.
--   • В этом режиме не проверяются и внешние ключи, поэтому скрипт сам
--     проверяет, что компания, объект, подрядчики, слои и пользователи есть.
--   • Расстояние до объекта и «в геозоне» скрипт считает сам — по тем же
--     правилам, что и база (радиус объекта + погрешность GPS не больше 50 м).
--
-- УБОРКА ТЕСТОВЫХ ЗАЯВОК — блок 0 ниже, выполняется всегда: перед питчем
-- в «Демо БЦ» остаются только заявки этого скрипта.
-- УДАЛЕНИЕ ИСТОРИИ — блок 1 ниже, по умолчанию выключен.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Блок 0. Удалить все НЕдемо-заявки компании «Демо БЦ» (всегда)
-- Демо-заявки — только из этого скрипта, с постоянными id
-- de300000-0000-4000-8000-000000000101 … 299 (в demo.sql заявок нет).
-- Всё остальное в «Демо БЦ» — тестовые заявки, созданные руками или
-- голосом на показах; они удаляются вместе с визитами, вложениями,
-- чек-листами и историей (каскад внешних ключей, поэтому блок стоит ДО
-- выключения триггеров). Файлы фото остаются в Storage (work-photos):
-- без заявки их никто не видит. Другие компании не трогаются.
-- ---------------------------------------------------------------------
do $$
declare
  c_company constant uuid := 'de300000-0000-4000-8000-000000000001';
  v_orders int;
begin
  delete from public.work_orders
   where company_id = c_company
     and id::text !~ '^de300000-0000-4000-8000-000000000[12][0-9]{2}$';
  get diagnostics v_orders = row_count;
  raise notice 'Тестовые (недемо) заявки «Демо БЦ» удалены: %.', v_orders;
end $$;

-- ---------------------------------------------------------------------
-- Блок 1. Удалить демо-историю (выключен)
-- Чтобы удалить только записи этого скрипта, поменяйте false на true
-- в строке c_delete_history и нажмите Run. Тогда блок 2 ничего не добавит.
-- Остальные демо-данные (компания, объект, пользователи) не трогаются.
-- Фото, снятые вручную к этим заявкам, удалятся из таблицы вложений,
-- но файлы останутся в Storage (work-photos).
-- ---------------------------------------------------------------------
do $$
declare
  c_delete_history constant boolean := false;   -- ← true = удалить демо-историю
  c_company constant uuid := 'de300000-0000-4000-8000-000000000001';
  v_visits int;
  v_orders int;
begin
  if not c_delete_history then
    perform set_config('demo_history.mode', 'insert', true);
    return;
  end if;
  -- Триггеры здесь включены: вместе с заявками каскадом удаляются
  -- их визиты, вложения, чек-листы и история статусов.
  delete from public.visits
   where company_id = c_company
     and id::text ~ '^de300000-0000-4000-8000-000000000[3][0-9]{2}$';
  get diagnostics v_visits = row_count;
  delete from public.work_orders
   where company_id = c_company
     and id::text ~ '^de300000-0000-4000-8000-000000000[12][0-9]{2}$';
  get diagnostics v_orders = row_count;
  perform set_config('demo_history.mode', 'deleted', true);
  raise notice 'Демо-история удалена: заявок %, визитов %.', v_orders, v_visits;
end $$;

-- ---------------------------------------------------------------------
-- Блок 2. Добавить демо-историю. Триггеры выключены до commit.
-- ---------------------------------------------------------------------
set local session_replication_role = replica;

do $$
declare
  -- ▼▼▼ ТЕ ЖЕ EMAIL, ЧТО В demo.sql (впишите вместо example.com) ▼▼▼
  -- При запуске через GitHub Actions «Refresh demo» email берутся из секретов
  -- окружения production-db (настройки demo.*_email) — тогда строки ниже не важны.
  -- В SQL Editor настроек нет, и действуют email, вписанные здесь.
  v_manager_email   text := coalesce(nullif(current_setting('demo.manager_email', true), ''),
                                     'manager@example.com');
  v_executor_email  text := coalesce(nullif(current_setting('demo.executor_email', true), ''),
                                     'executor@example.com');
  v_requester_email text := coalesce(nullif(current_setting('demo.requester_email', true), ''),
                                     'requester@example.com');
  -- Необязательно: четвёртый тестовый пользователь — исполнитель «ЭлектроПро».
  -- Если указать, он станет исполнителем «ЭлектроПро», и у подрядчика появится
  -- визит с подменой GPS. Если оставить пустым — у «ЭлектроПро» визитов не будет.
  v_elec_executor_email text := coalesce(nullif(current_setting('demo.elec_executor_email', true), ''),
                                         '');
  -- ▲▲▲ ДАЛЬШЕ НИЧЕГО МЕНЯТЬ НЕ НУЖНО ▲▲▲

  c_company    constant uuid := 'de300000-0000-4000-8000-000000000001';
  c_object     constant uuid := 'de300000-0000-4000-8000-000000000010';
  c_loc_meet   constant uuid := 'de300000-0000-4000-8000-000000000021';
  c_loc_elec   constant uuid := 'de300000-0000-4000-8000-000000000022';
  c_loc_open   constant uuid := 'de300000-0000-4000-8000-000000000023';
  c_loc_hall   constant uuid := 'de300000-0000-4000-8000-000000000024';
  c_contr_hvac constant uuid := 'de300000-0000-4000-8000-000000000031';
  c_contr_elec constant uuid := 'de300000-0000-4000-8000-000000000032';
  c_mock_visit constant uuid := 'de300000-0000-4000-8000-000000000316';
  -- Объекты на карте (шаг 13): id 011–014, помещения 041–051, заявки 211–220.
  c_obj_plaza  constant uuid := 'de300000-0000-4000-8000-000000000011';
  c_obj_log    constant uuid := 'de300000-0000-4000-8000-000000000012';
  c_obj_city   constant uuid := 'de300000-0000-4000-8000-000000000013';
  c_obj_park   constant uuid := 'de300000-0000-4000-8000-000000000014';

  v_manager   uuid;
  v_executor  uuid;
  v_requester uuid;
  v_elec_exec uuid;
  v_layer_hvac uuid;
  v_layer_elec uuid;
  v_layer_plumb uuid;
  v_layer_clean uuid;
  v_layer_other uuid;
  v_world_orders int;
  v_plan_orders int;
  v_photo_hvac boolean;
  v_photo_elec boolean;
  v_obj record;
  v_today timestamptz := date_trunc('day', now());
  v_orders int;
  v_visits int;
begin
  if current_setting('demo_history.mode', true) = 'deleted' then
    raise notice 'Включено удаление (блок 1) — новая история не добавлялась.';
    return;
  end if;
  if current_setting('session_replication_role') <> 'replica' then
    raise exception 'Триггеры не выключились. Запускайте скрипт целиком, от begin до commit';
  end if;

  -- 1. Пользователи
  select id into v_manager   from auth.users where lower(email) = lower(trim(v_manager_email));
  select id into v_executor  from auth.users where lower(email) = lower(trim(v_executor_email));
  select id into v_requester from auth.users where lower(email) = lower(trim(v_requester_email));
  if v_manager is null or v_executor is null or v_requester is null then
    raise exception 'Не найден один из трёх пользователей. Впишите те же email, что в demo.sql';
  end if;
  if v_manager = v_executor or v_manager = v_requester or v_executor = v_requester then
    raise exception 'Нужны три разных пользователя';
  end if;
  if not exists (select 1 from public.profiles p
                  where p.id in (v_manager, v_executor, v_requester)
                    and p.company_id = c_company
                 having count(*) = 3) then
    raise exception 'Пользователи не в компании «Демо БЦ». Сначала запустите supabase/seed/demo.sql';
  end if;
  if trim(v_elec_executor_email) <> '' then
    select id into v_elec_exec from auth.users where lower(email) = lower(trim(v_elec_executor_email));
    if v_elec_exec is null then
      raise exception 'Не найден исполнитель «ЭлектроПро»: %. Создайте его в Authentication → Users или оставьте пустую строку', v_elec_executor_email;
    end if;
    if v_elec_exec in (v_manager, v_executor, v_requester) then
      raise exception 'Исполнитель «ЭлектроПро» должен быть четвёртым, отдельным пользователем';
    end if;
  end if;

  -- 2. Справочники из demo.sql
  select o.lat, o.lng, o.geofence_radius_m into v_obj
    from public.objects o where o.id = c_object and o.company_id = c_company;
  if not found then
    raise exception 'Нет объекта «БЦ «Демо»». Сначала запустите supabase/seed/demo.sql';
  end if;
  if v_obj.lat is null or v_obj.lng is null then
    raise exception 'У объекта «БЦ «Демо»» нет координат. Укажите их в карточке объекта';
  end if;
  if (select count(*) from public.locations
       where object_id = c_object and id in (c_loc_meet, c_loc_elec, c_loc_open, c_loc_hall)) <> 4 then
    raise exception 'Нет помещений «БЦ «Демо»». Сначала запустите supabase/seed/demo.sql';
  end if;
  if (select count(*) from public.contractors
       where company_id = c_company and id in (c_contr_hvac, c_contr_elec)) <> 2 then
    raise exception 'Нет подрядчиков «КлиматСервис» и «ЭлектроПро». Сначала запустите supabase/seed/demo.sql';
  end if;
  select id, requires_photo into v_layer_hvac, v_photo_hvac
    from public.layers where company_id = c_company and name = 'Климат';
  select id, requires_photo into v_layer_elec, v_photo_elec
    from public.layers where company_id = c_company and name = 'Электрика';
  if v_layer_hvac is null or v_layer_elec is null then
    raise exception 'Не найдены слои «Климат» и «Электрика». Сначала запустите supabase/seed/demo.sql';
  end if;
  -- Слои для объектов по миру (шаг 13d): создаются у компании сами (0004/0005).
  select id into v_layer_plumb from public.layers where company_id = c_company and name = 'Сантехника';
  select id into v_layer_clean from public.layers where company_id = c_company and name = 'Клининг';
  select id into v_layer_other from public.layers where company_id = c_company and name = 'Другое';
  if v_layer_plumb is null or v_layer_clean is null or v_layer_other is null then
    raise exception 'Не найдены слои «Сантехника», «Клининг» или «Другое» у компании «Демо БЦ»';
  end if;

  -- 3. Нормы визитов по договору: «КлиматСервис» — 4 в месяц, «ЭлектроПро» — 2.
  --    Шаг 13d: подрядчики работают по регионам. «ЭлектроПро» в demo.sql закреплён
  --    за «Электрикой» на ВСЕХ объектах (object_id = null) — тогда заявки по
  --    электрике в Москве или Дубае тоже уходили бы ему. Переводим его на
  --    белградские объекты: здесь — «БЦ «Демо»» (с нормой 2), остальные — в 3c.
  if not exists (select 1 from public.contractor_layers
                  where contractor_id = c_contr_elec and layer_id = v_layer_elec) then
    raise exception 'Нет закреплений подрядчиков за слоями. Сначала запустите supabase/seed/demo.sql';
  end if;
  insert into public.contractor_layers (contractor_id, layer_id, object_id)
  select c_contr_elec, v_layer_elec, c_object
  where not exists (select 1 from public.contractor_layers
                     where contractor_id = c_contr_elec and layer_id = v_layer_elec
                       and object_id = c_object);
  delete from public.contractor_layers
   where contractor_id = c_contr_elec and layer_id = v_layer_elec and object_id is null;
  update public.contractor_layers set visits_per_month = 4
   where contractor_id = c_contr_hvac and layer_id = v_layer_hvac and object_id = c_object;
  update public.contractor_layers set visits_per_month = 2
   where contractor_id = c_contr_elec and layer_id = v_layer_elec and object_id = c_object;
  if (select count(*) from public.contractor_layers
       where (contractor_id, layer_id) in ((c_contr_hvac, v_layer_hvac), (c_contr_elec, v_layer_elec))
         and visits_per_month is not null) < 2 then
    raise exception 'Нет закреплений подрядчиков за слоями. Сначала запустите supabase/seed/demo.sql';
  end if;

  -- 3b. Объекты на карте (шаг 13). «БЦ «Демо»» стоит в Белграде — адрес
  --     под его координаты. Ещё 4 объекта в разных районах Белграда
  --     (2–10 км друг от друга), по 2–3 помещения. Адреса — без реальных улиц.
  update public.objects set address = 'Белград, Савски венац (демо)'
   where id = c_object;

  insert into public.objects (id, company_id, name, type, address, lat, lng, geofence_radius_m)
  values
    (c_obj_plaza, c_company, 'ТЦ «Демо Плаза»',       'other',     'Белград, Нови Београд (демо)', 44.803000, 20.404000, 200),
    (c_obj_log,   c_company, 'Склад «Демо Логистик»', 'warehouse', 'Белград, Земун (демо)',        44.859000, 20.380000, 300),
    (c_obj_city,  c_company, 'Офис «Демо Сити»',      'office',    'Белград, Дорчол (демо)',       44.823500, 20.470000, 150),
    (c_obj_park,  c_company, 'Отель «Демо Парк»',     'hotel',     'Белград, Вождовац (демо)',     44.770000, 20.480000, 250)
  on conflict (id) do update set
    company_id = excluded.company_id, name = excluded.name, type = excluded.type,
    address = excluded.address, lat = excluded.lat, lng = excluded.lng,
    geofence_radius_m = excluded.geofence_radius_m;

  insert into public.locations (id, object_id, name)
  select ('de300000-0000-4000-8000-' || lpad(p.n::text, 12, '0'))::uuid,
         ('de300000-0000-4000-8000-' || lpad(p.o::text, 12, '0'))::uuid, p.name
  from (values
    (41, 11, 'Фуд-корт, 2 этаж'),
    (42, 11, 'Торговая галерея, 1 этаж'),
    (43, 11, 'Парковка, −1 этаж'),
    (44, 12, 'Зона приёмки, ворота 3'),
    (45, 12, 'Холодильная камера'),
    (46, 12, 'Офис склада'),
    (47, 13, 'Ресепшен, 1 этаж'),
    (48, 13, 'Серверная, 4 этаж'),
    (49, 14, 'Лобби'),
    (50, 14, 'Номер 214'),
    (51, 14, 'Ресторан')
  ) as p(n, o, name)
  on conflict (id) do update set name = excluded.name, object_id = excluded.object_id;

  -- «КлиматСервис» — «Климат» и на новых объектах (как на «БЦ «Демо»»);
  -- «ЭлектроПро» — за «Электрикой» на этих же 4 объектах (а на «БЦ «Демо»» — в шаге 3).
  -- У contractor_layers нет уникального ключа — поэтому «если ещё нет».
  insert into public.contractor_layers (contractor_id, layer_id, object_id)
  select c.id, c.layer, o.id
  from (values (c_contr_hvac, v_layer_hvac), (c_contr_elec, v_layer_elec)) as c(id, layer)
  cross join unnest(array[c_obj_plaza, c_obj_log, c_obj_city, c_obj_park]) as o(id)
  where not exists (select 1 from public.contractor_layers cl
                     where cl.contractor_id = c.id
                       and cl.layer_id = c.layer and cl.object_id = o.id);

  -- 3c. Объекты по миру (шаг 13d): id 401–415, помещения 421–465, подрядчики 501–510.
  --     Город — часть адреса до первой запятой (по нему приложение группирует
  --     объекты), «(демо)» — в конце адреса. Адреса и координаты примерные.
  --     Колонки: n — номер (часть id), название, тип, адрес, широта, долгота, радиус геозоны.
  insert into public.objects (id, company_id, name, type, address, lat, lng, geofence_radius_m)
  select ('de300000-0000-4000-8000-' || lpad(w.n::text, 12, '0'))::uuid, c_company,
         w.name, w.type, w.address, w.lat, w.lng, w.radius
  from (values
    (401, 'Хаб 1',               'office', 'Белград, бул. Войводы Бойовича, 12 (демо)',             44.826200,  20.456600, 200),
    (402, 'Skyline',             'office', 'Белград, Kneza Miloša 90a (демо)',                      44.799990,  20.452140, 150),
    (403, 'Офис 1',              'office', 'Москва, Пресненская наб., Москва-Сити (демо)',          55.749000,  37.537000, 250),
    (404, 'Офис 2',              'office', 'Москва, ул. Лесная (демо)',                             55.777000,  37.582000, 150),
    (405, 'Офис 3',              'office', 'Москва, Павелецкая пл. (демо)',                         55.730000,  37.639000, 200),
    (406, 'Офис 4',              'office', 'Москва, Земляной Вал (демо)',                           55.758000,  37.660000, 150),
    (407, 'Офис 5',              'office', 'Москва, Сколково (демо)',                               55.697000,  37.359000, 300),
    (408, 'Офис 1',              'office', 'Дубай, Business Bay (демо)',                            25.186000,  55.265000, 200),
    (409, 'Офис 2',              'office', 'Дубай, Dubai Marina (демо)',                            25.080500,  55.140300, 200),
    (410, 'Офис 1',              'office', 'Стамбул, Левент (демо)',                                41.082000,  29.011000, 200),
    (411, 'Офис 2',              'office', 'Стамбул, Аташехир (демо)',                              40.992000,  29.124000, 200),
    (412, 'Ivoire Trade Center', 'office', 'Абиджан, Кокоди, рядом с Sofitel Hôtel Ivoire (демо)',   5.325000,  -4.006000, 300),
    (413, 'Офис 1',              'office', 'Шэньчжэнь, Футянь (демо)',                              22.540000, 114.055000, 200),
    (414, 'Офис 2',              'office', 'Шэньчжэнь, Наньшань (демо)',                            22.533000, 113.944000, 200),
    (415, 'Офис 1',              'office', 'Пекин, Гоумао (демо)',                                  39.908000, 116.460000, 250)
  ) as w(n, name, type, address, lat, lng, radius)
  on conflict (id) do update set
    company_id = excluded.company_id, name = excluded.name, type = excluded.type,
    address = excluded.address, lat = excluded.lat, lng = excluded.lng,
    geofence_radius_m = excluded.geofence_radius_m;

  -- Помещения: n — номер (часть id), o — номер объекта.
  insert into public.locations (id, object_id, name)
  select ('de300000-0000-4000-8000-' || lpad(p.n::text, 12, '0'))::uuid,
         ('de300000-0000-4000-8000-' || lpad(p.o::text, 12, '0'))::uuid, p.name
  from (values
    (421, 401, 'Лобби'),
    (422, 401, 'Переговорная «Сава»'),
    (423, 401, 'Серверная'),
    (424, 402, 'Open space, 15 этаж'),
    (425, 402, 'Кухня, 15 этаж'),
    (426, 402, 'Парковка, −2 этаж'),
    (427, 403, 'Лобби, 1 этаж'),
    (428, 403, 'Open space, 32 этаж'),
    (429, 403, 'Серверная, 31 этаж'),
    (430, 403, 'Переговорная «Неглинка»'),
    (431, 404, 'Ресепшен'),
    (432, 404, 'Кухня, 3 этаж'),
    (433, 404, 'Санузлы, 2 этаж'),
    (434, 405, 'Лобби'),
    (435, 405, 'Open space, 5 этаж'),
    (436, 405, 'Тепловой пункт, подвал'),
    (437, 406, 'Переговорная «Яуза»'),
    (438, 406, 'Кухня'),
    (439, 406, 'Санузлы, 4 этаж'),
    (440, 407, 'Атриум'),
    (441, 407, 'Лаборатория'),
    (442, 407, 'Парковка'),
    (443, 408, 'Лобби'),
    (444, 408, 'Open space, 21 этаж'),
    (445, 408, 'Серверная'),
    (446, 409, 'Ресепшен'),
    (447, 409, 'Переговорная'),
    (448, 409, 'Парковка'),
    (449, 410, 'Лобби'),
    (450, 410, 'Open space, 12 этаж'),
    (451, 410, 'Кухня'),
    (452, 411, 'Ресепшен'),
    (453, 411, 'Санузлы, 3 этаж'),
    (454, 412, 'Холл'),
    (455, 412, 'Переговорная'),
    (456, 412, 'Серверная'),
    (457, 412, 'Генераторная'),
    (458, 413, 'Лобби'),
    (459, 413, 'Open space, 28 этаж'),
    (460, 413, 'Кухня'),
    (461, 414, 'Ресепшен'),
    (462, 414, 'Серверная'),
    (463, 415, 'Лобби'),
    (464, 415, 'Переговорная'),
    (465, 415, 'Open space, 18 этаж')
  ) as p(n, o, name)
  on conflict (id) do update set name = excluded.name, object_id = excluded.object_id;

  -- Подрядчики по регионам — только организации, без учётных записей.
  insert into public.contractors (id, company_id, org_name)
  select ('de300000-0000-4000-8000-' || lpad(c.n::text, 12, '0'))::uuid, c_company, c.name
  from (values
    (501, 'МосКлимат'),
    (502, 'ЭлектроСити'),
    (503, 'ЧистоГрад'),
    (504, 'ЛифтСервис'),
    (505, 'Gulf FM Services'),
    (506, 'Boğaziçi Teknik'),
    (507, 'Temiz Hizmet'),
    (508, 'Ivoire Maintenance'),
    (509, 'Huaxin FM'),
    (510, 'Shenzhen Clean')
  ) as c(n, name)
  on conflict (id) do update set company_id = excluded.company_id, org_name = excluded.org_name;

  -- Закрепления: подрядчик (31, 32 — белградские из demo.sql, 501–510 — новые),
  -- вид работ, объект, норма визитов в месяц. По ним база сама назначает
  -- подрядчика новой заявке (слой + объект). «ЛифтСервис» — слой «Другое»
  -- (слоя «Лифты» у компании нет).
  insert into public.contractor_layers (contractor_id, layer_id, object_id, visits_per_month)
  select ('de300000-0000-4000-8000-' || lpad(b.c::text, 12, '0'))::uuid,
         case b.layer when 'hvac' then v_layer_hvac when 'elec' then v_layer_elec
                      when 'plumb' then v_layer_plumb when 'clean' then v_layer_clean
                      else v_layer_other end,
         ('de300000-0000-4000-8000-' || lpad(b.o::text, 12, '0'))::uuid, b.norm
  from (values
    -- Белград: «КлиматСервис» и «ЭлектроПро» — ещё «Хаб 1» и «Skyline»
    (31, 'hvac', 401, null::int), (31, 'hvac', 402, null),
    (32, 'elec', 401, null), (32, 'elec', 402, null),
    -- Москва: частичное покрытие
    (501, 'hvac', 403, 2), (501, 'hvac', 404, 2), (501, 'hvac', 405, 2), (501, 'hvac', 406, 2), (501, 'hvac', 407, 2),
    (502, 'elec', 403, 2), (502, 'elec', 405, 2),
    (503, 'clean', 403, 8), (503, 'clean', 404, 8), (503, 'clean', 406, 8),
    (504, 'other', 403, 1), (504, 'other', 407, 1),
    -- Дубай
    (505, 'hvac', 408, 4), (505, 'hvac', 409, 4), (505, 'elec', 408, 1), (505, 'elec', 409, 1),
    -- Стамбул
    (506, 'hvac', 410, 2), (506, 'hvac', 411, 2), (506, 'elec', 410, 1), (506, 'elec', 411, 1),
    (506, 'plumb', 410, 1), (506, 'plumb', 411, 1),
    (507, 'clean', 410, 8),
    -- Абиджан
    (508, 'hvac', 412, 2), (508, 'elec', 412, 2), (508, 'plumb', 412, 1),
    -- Китай: «Huaxin FM» — весь Китай, «Shenzhen Clean» — только Шэньчжэнь
    (509, 'hvac', 413, 2), (509, 'hvac', 414, 2), (509, 'hvac', 415, 2),
    (509, 'elec', 413, 1), (509, 'elec', 414, 1), (509, 'elec', 415, 1),
    (510, 'clean', 413, 8), (510, 'clean', 414, 8)
  ) as b(c, layer, o, norm)
  where not exists (
    select 1 from public.contractor_layers cl
     where cl.contractor_id = ('de300000-0000-4000-8000-' || lpad(b.c::text, 12, '0'))::uuid
       and cl.object_id = ('de300000-0000-4000-8000-' || lpad(b.o::text, 12, '0'))::uuid
       and cl.layer_id = case b.layer when 'hvac' then v_layer_hvac when 'elec' then v_layer_elec
                                      when 'plumb' then v_layer_plumb when 'clean' then v_layer_clean
                                      else v_layer_other end);

  -- Подрядчик ↔ объект (для полноты справочника; назначение идёт по contractor_layers).
  insert into public.contractor_objects (contractor_id, object_id)
  select distinct cl.contractor_id, cl.object_id
  from public.contractor_layers cl
  join public.contractors c on c.id = cl.contractor_id and c.company_id = c_company
  where cl.object_id is not null
  on conflict do nothing;

  -- 4. Четвёртый пользователь (если указан) — исполнитель «ЭлектроПро»
  if v_elec_exec is not null then
    insert into public.profiles (id, company_id, role, full_name)
    values (v_elec_exec, c_company, 'executor', 'Электрик Демо')
    on conflict (id) do update
      set company_id = excluded.company_id,
          role       = excluded.role,
          full_name  = coalesce(public.profiles.full_name, excluded.full_name);
    insert into public.executors (profile_id, contractor_id)
    select v_elec_exec, c_contr_elec
    where not exists (select 1 from public.executors
                      where profile_id = v_elec_exec and contractor_id = c_contr_elec);
  end if;

  -- 5. Заявки
  -- Колонки: n — номер (часть id); layer — hvac/elec; loc — помещение;
  -- d, h — создана d дней назад в h:00 UTC; r — через сколько минут взяли
  -- в работу; sub — сколько минут от начала работы до сдачи на проверку
  -- (у возвращённых — включая доработку); acc — через сколько минут после
  -- сдачи приняли; due_h — срок, часов от создания; rc — сколько раз
  -- возвращали; upd — для отменённой и возвращённой: минут от создания до
  -- последнего изменения.
  insert into public.work_orders (
    id, company_id, object_id, location_id, title, description, work_type, layer_id,
    priority, status, requires_photo, input_channel, created_by,
    assigned_contractor_id, assigned_by, due_at, time_spent_minutes,
    created_at, updated_at, started_at, submitted_at, accepted_at, accepted_by,
    return_reason, return_count)
  select
    ('de300000-0000-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
    c_company, coalesce(lo.object_id, c_object), lc.id,
    t.title, t.descr,
    case t.layer when 'hvac' then 'Климат' else 'Электрика' end,
    case t.layer when 'hvac' then v_layer_hvac else v_layer_elec end,
    t.priority, t.status,
    case t.layer when 'hvac' then v_photo_hvac else v_photo_elec end,
    t.channel,
    case t.author when 'mgr' then v_manager else v_requester end,
    case when t.status <> 'new' then
      case t.layer when 'hvac' then c_contr_hvac else c_contr_elec end end,
    case when t.status <> 'new' then 'rule' end,
    x.created + make_interval(hours => t.due_h),
    case when t.sub is not null then t.sub end,
    x.created,
    case
      when t.status = 'done'        then x.created + make_interval(mins => t.r + t.sub + t.acc)
      when t.status = 'on_review'   then x.created + make_interval(mins => t.r + t.sub)
      when t.status = 'in_progress' then x.created + make_interval(mins => t.r)
      when t.upd is not null        then x.created + make_interval(mins => t.upd)
      else x.created
    end,
    case when t.r is not null then x.created + make_interval(mins => t.r) end,
    case when t.sub is not null then x.created + make_interval(mins => t.r + t.sub) end,
    case when t.status = 'done' then x.created + make_interval(mins => t.r + t.sub + t.acc) end,
    case when t.status = 'done' then
      case when t.author = 'req' and t.n % 3 = 0 then v_requester else v_manager end end,
    t.reason, t.rc
  from (values
    -- «КлиматСервис»: быстро, в срок, один возврат
    (101,'hvac','meet','Не охлаждает кондиционер в переговорной','Кондиционер работает, но дует тёплым воздухом. В 11:00 встреча с клиентом.','normal','done','req','text',29,7,35,55,90,72,0,null::text,null::int),
    (102,'hvac','open','Плановое ТО кондиционеров: чистка фильтров','Ежемесячное ТО внутренних блоков open space, 6 шт.','low','done','mgr','button',27,6,120,110,240,120,0,null,null),
    (103,'hvac','open','Шумит внутренний блок у окна','Сильный гул и треск, мешает работать.','normal','done','req','voice',26,9,40,45,60,72,0,null,null),
    (104,'hvac','hall','Течёт вода из кондиционера на ресепшене','Капает на стойку администратора, подставили ведро.','high','done','req','text',24,7,20,175,70,24,1,'После ремонта снова капает: дренаж прочищен не до конца.',null),
    (105,'hvac','open','Не работает вентиляция в open space','Душно, приток не включается с утра.','high','done','req','voice',22,6,25,80,45,24,0,null,null),
    (106,'hvac','meet','Жарко в переговорной: настроить кондиционер','На пульте 22°, в комнате 27°.','normal','done','req','text',20,11,45,30,120,72,0,null,null),
    (107,'hvac','hall','Замена фильтров приточной установки','Плановая замена фильтров по графику ТО.','low','done','mgr','button',17,6,90,70,180,120,0,null,null),
    (108,'hvac','meet','Неприятный запах из кондиционера','Нужна антибактериальная обработка внутреннего блока.','normal','done','req','text',15,8,50,65,100,72,0,null,null),
    (109,'hvac','open','Сквозняк от диффузора над рабочими местами','Дует прямо на ряд у окна, сотрудники жалуются.','low','done','req','voice',13,10,60,40,150,120,0,null,null),
    (110,'hvac','meet','Кондиционер не включается с пульта','Индикатор мигает, на пульт не реагирует.','high','done','req','text',10,7,15,35,60,24,0,null,null),
    (111,'hvac','open','Плановое ТО: проверка давления хладагента','Проверка 6 блоков open space по графику ТО.','low','done','mgr','button',8,6,100,120,200,120,0,null,null),
    (112,'hvac','hall','Не работает тепловая завеса у входа','Холодно у входной группы, завеса не включается.','high','done','req','voice',5,7,20,75,50,24,0,null,null),
    (113,'hvac','open','Капает конденсат над рабочим местом','На потолке мокрое пятно у колонны.','normal','done','req','text',3,9,30,50,80,72,0,null,null),
    (114,'hvac','meet','Шумит вентилятор в переговорной','Вентилятор внутреннего блока стучит на высокой скорости.','normal','on_review','req','voice',1,8,40,60,null,72,0,null,null),
    (115,'hvac','meet','Дубль: не охлаждает кондиционер в переговорной','Создана повторно по ошибке.','normal','cancelled','req','text',12,9,null,null,null,72,0,null,20),
    -- «ЭлектроПро»: долго берёт в работу, возвраты, 2 просрочки
    (201,'elec','hall','Мигает свет в холле','Два светильника у лифтов мигают с утра.','normal','done','req','text',28,8,300,70,240,72,0,null,null),
    (202,'elec','open','Не работает розетка у рабочего места','Розетка у места 2-14 не даёт питания.','low','done','req','text',25,9,1560,1500,300,120,1,'Розетка снова не работает: причина не устранена.',null),
    (203,'elec','elec','Выбивает автомат в электрощитовой','Автомат группы 3 этажа отключается 2–3 раза в день.','high','done','mgr','text',23,7,180,90,300,24,0,null,null),
    (204,'elec','meet','Замена ламп в переговорной','Не горят 3 лампы из 8.','low','done','req','button',19,10,1500,45,600,120,0,null,null),
    (205,'elec','hall','Не горит аварийное освещение на лестнице','Аварийные светильники между 1 и 2 этажом не горят.','normal','done','mgr','text',14,8,240,3000,240,120,2,'Аварийный светильник на 2 этаже по-прежнему не горит.',null),
    (206,'elec','open','Искрит выключатель в open space','При включении света искрит и щёлкает выключатель у кухни.','critical','done','req','voice',9,7,120,50,60,8,0,null,null),
    (207,'elec','elec','Не работает освещение в электрощитовой','В щитовой темно, работать со щитом невозможно.','normal','returned','mgr','text',6,8,1560,150,null,72,1,'Заменили не тот светильник: в щитовой по-прежнему темно.',2940),
    (208,'elec','meet','Нет питания на розетках в переговорной','Не работают все розетки у стола, в 15:00 совещание.','high','assigned','req','voice',5,9,null,null,null,24,0,null,null),
    (209,'elec','elec','Проверить щит после скачка напряжения','Ночью был скачок, часть линий отключилась.','normal','in_progress','mgr','text',2,9,1500,null,null,120,0,null,null),
    (210,'elec','hall','Замена светильника в холле','Светильник над входом треснул, нужна замена.','low','on_review','req','text',4,10,1500,1500,null,120,0,null,null),
    -- Объекты на карте (шаг 13); loc — номер помещения (041–051), объект — по помещению.
    -- «ТЦ «Демо Плаза»»: просроченная critical — красный маркер
    (211,'elec','41','Нет света в фуд-корте','Обесточена половина фуд-корта, арендаторы не могут работать.','critical','assigned','mgr','text',1,7,null,null,null,4,0,null,null),
    (212,'hvac','42','Душно в торговой галерее','Не работает приточная вентиляция у эскалатора.','normal','new','req','voice',1,10,null,null,null,72,0,null,null),
    (213,'elec','43','Заменить лампы на парковке','Не горят 5 светильников у въезда.','low','done','req','text',6,9,300,60,120,120,0,null,null),
    -- «Склад «Демо Логистик»»: открытых заявок нет — серо-зелёный маркер
    (214,'hvac','45','ТО холодильной камеры','Плановая проверка компрессора и уплотнителей.','low','done','mgr','button',9,7,90,120,180,120,0,null,null),
    (215,'elec','44','Дубль: свет у ворот 3','Создана повторно по ошибке.','low','cancelled','req','text',4,8,null,null,null,120,0,null,30),
    -- «Офис «Демо Сити»»: срочная в работе — оранжевый маркер
    (216,'hvac','48','Перегрев в серверной','В серверной 31°, кондиционер не справляется.','high','in_progress','mgr','text',1,8,40,null,null,72,0,null,null),
    (217,'elec','47','Мигает подсветка ресепшена','Светодиодная лента над стойкой мигает.','normal','on_review','req','text',2,9,200,90,null,72,0,null,null),
    -- «Отель «Демо Парк»»: обычные открытые — бирюзовый маркер
    (218,'hvac','50','Не работает кондиционер в номере 214','Гость жалуется: в номере жарко.','normal','new','req','voice',1,9,null,null,null,72,0,null,null),
    (219,'elec','51','Не работает розетка у барной стойки','Не включается кофемашина, розетка без питания.','low','assigned','mgr','text',2,11,null,null,null,120,0,null,null),
    (220,'hvac','49','Чистка фильтров в лобби','Плановое ТО кондиционеров лобби.','low','done','mgr','button',12,6,100,80,200,120,0,null,null),
    -- Повторяющиеся (регламентные) заявки (шаг 13c) — recurrence задаётся ниже, в 5b
    (221,'hvac','open','Ежемесячный осмотр кондиционеров','Регламент: осмотр и чистка внутренних блоков open space раз в месяц.','normal','assigned','mgr','button',2,7,null,null,null,168,0,null,null),
    (222,'elec','hall','Еженедельная проверка аварийного освещения','Регламент: проверка аварийных светильников на лестницах и в холле раз в неделю.','low','in_progress','mgr','button',1,8,120,null,null,48,0,null,null)
  ) as t(n, layer, loc, title, descr, priority, status, author, channel,
         d, h, r, sub, acc, due_h, rc, reason, upd)
  cross join lateral (
    select v_today - make_interval(days => t.d) + make_interval(hours => t.h) as created
  ) x
  cross join lateral (
    select case t.loc when 'meet' then c_loc_meet when 'elec' then c_loc_elec
                      when 'open' then c_loc_open when 'hall' then c_loc_hall
           else ('de300000-0000-4000-8000-' || lpad(t.loc, 12, '0'))::uuid end as id
  ) lc
  left join public.locations lo on lo.id = lc.id
  on conflict (id) do update set
    company_id = excluded.company_id, object_id = excluded.object_id,
    location_id = excluded.location_id, asset_id = null,
    title = excluded.title, description = excluded.description,
    work_type = excluded.work_type, layer_id = excluded.layer_id,
    priority = excluded.priority, status = excluded.status, recurrence = null,
    requires_photo = excluded.requires_photo, requires_scan = false,
    input_channel = excluded.input_channel, created_by = excluded.created_by,
    assigned_contractor_id = excluded.assigned_contractor_id,
    assigned_executor_id = null, assigned_by = excluded.assigned_by,
    due_at = excluded.due_at, time_spent_minutes = excluded.time_spent_minutes,
    created_at = excluded.created_at, updated_at = excluded.updated_at,
    started_at = excluded.started_at, submitted_at = excluded.submitted_at,
    accepted_at = excluded.accepted_at, accepted_by = excluded.accepted_by,
    return_reason = excluded.return_reason, return_count = excluded.return_count;
  get diagnostics v_orders = row_count;

  -- 5b. Повторяющиеся заявки: формат recurrence — как у приложения
  --     ({"kind":"regular"}), плюс частота для будущего планировщика ТО.
  update public.work_orders set recurrence = '{"kind":"regular","freq":"monthly","interval":1}'::jsonb
   where id = 'de300000-0000-4000-8000-000000000221';
  update public.work_orders set recurrence = '{"kind":"regular","freq":"weekly","interval":1}'::jsonb
   where id = 'de300000-0000-4000-8000-000000000222';

  -- 5c. Заявки на объектах по миру (шаг 13d): 223–253.
  --     Колонки как в шаге 5, плюс layer — hvac/elec/plumb/clean/other,
  --     loc — номер помещения (421–465, объект — по помещению), c — номер
  --     подрядчика (null — без подрядчика; назначен только тот, кто закреплён
  --     за этим объектом и видом работ), rec — повторяющаяся (monthly/weekly).
  --     Просрочены (красные маркеры на карте мира): 227 Москва, 238 Дубай,
  --     244 Стамбул, 246 Абиджан. Без подрядчика: 232, 233, 245.
  insert into public.work_orders (
    id, company_id, object_id, location_id, title, description, work_type, layer_id,
    priority, status, requires_photo, input_channel, created_by,
    assigned_contractor_id, assigned_by, due_at, time_spent_minutes,
    created_at, updated_at, started_at, submitted_at, accepted_at, accepted_by,
    return_reason, return_count, recurrence)
  select
    ('de300000-0000-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
    c_company, lo.object_id, lo.id,
    t.title, t.descr, ly.name, ly.id,
    t.priority, t.status, ly.requires_photo, t.channel,
    case t.author when 'mgr' then v_manager else v_requester end,
    case when t.c is not null then ('de300000-0000-4000-8000-' || lpad(t.c::text, 12, '0'))::uuid end,
    case when t.c is not null then 'rule' end,
    x.created + make_interval(hours => t.due_h),
    t.sub,
    x.created,
    case
      when t.status = 'done'        then x.created + make_interval(mins => t.r + t.sub + t.acc)
      when t.status = 'on_review'   then x.created + make_interval(mins => t.r + t.sub)
      when t.status = 'in_progress' then x.created + make_interval(mins => t.r)
      when t.upd is not null        then x.created + make_interval(mins => t.upd)
      else x.created
    end,
    case when t.r is not null then x.created + make_interval(mins => t.r) end,
    case when t.sub is not null then x.created + make_interval(mins => t.r + t.sub) end,
    case when t.status = 'done' then x.created + make_interval(mins => t.r + t.sub + t.acc) end,
    case when t.status = 'done' then v_manager end,
    t.reason, t.rc,
    case when t.rec is not null then
      jsonb_build_object('kind', 'regular', 'freq', t.rec, 'interval', 1) end
  from (values
    -- Белград: «Хаб 1», «Skyline»
    (223,'hvac',421,31,'Шумит кондиционер в лобби','Внутренний блок над входом гудит и потрескивает.','normal','assigned','req','voice',1,9,null::int,null::int,null::int,72,0,null::text,null::int,null::text),
    (224,'elec',424,32,'Мигает свет в open space','Три светильника у окон мигают с утра.','normal','in_progress','mgr','text',2,8,90,null,null,72,0,null,null,null),
    (225,'hvac',422,31,'Жарко в переговорной «Сава»','Кондиционер не держит 22°, к обеду 27°.','low','done','req','text',6,10,30,60,90,120,0,null,null,null),
    (226,'elec',426,32,'Не горят светильники на парковке','Темно у выезда, 4 светильника не горят.','normal','on_review','req','button',3,9,200,120,null,120,0,null,null,null),
    -- Москва
    (227,'hvac',435,501,'Холодно в open space: не греют батареи','Батареи у окон холодные, в офисе +17.','critical','in_progress','req','voice',1,8,30,null,null,6,0,null,null,null),
    (228,'other',427,504,'Застрял лифт в лобби','Лифт №2 остановился между 1 и 2 этажом, людей вывели.','critical','done','mgr','voice',4,9,15,60,30,4,0,null,null,null),
    (229,'elec',429,502,'Скачки напряжения в серверной','ИБП дважды переходил на батареи за ночь.','high','assigned','mgr','text',1,11,null,null,null,48,0,null,null,null),
    (230,'clean',432,503,'Генеральная уборка кухни','После корпоратива нужна генеральная уборка.','low','assigned','mgr','button',2,7,null,null,null,96,0,null,null,null),
    (231,'hvac',438,501,'Не работает вентиляция на кухне','Вытяжка не тянет, запах по всему этажу.','normal','returned','req','text',5,9,60,240,null,168,1,'После ремонта вытяжка снова не тянет.',3000,null),
    (232,'elec',431,null,'Не работает розетка на ресепшене','Не включается кофемашина у стойки.','normal','new','req','voice',1,10,null,null,null,72,0,null,null,null),
    (233,'plumb',433,null,'Протекает кран в санузле','Кран у раковины не закрывается до конца.','high','new','req','text',1,14,null,null,null,48,0,null,null,null),
    (234,'other',440,504,'Ежемесячное ТО лифтов','Регламент: осмотр лифтов атриума раз в месяц.','low','assigned','mgr','button',3,7,null,null,null,240,0,null,null,'monthly'),
    (235,'hvac',437,501,'Душно в переговорной «Яуза»','Приток не включается, после встречи нечем дышать.','normal','done','req','voice',8,10,40,50,120,72,0,null,null,null),
    (236,'clean',439,503,'Нет мыла и бумаги в санузлах','Закончились расходники на 4 этаже.','low','done','req','button',2,9,60,30,60,24,0,null,null,null),
    (237,'hvac',442,501,'Не греет тепловая завеса на въезде','На въезде на парковку сквозняк, завеса не включается.','high','on_review','mgr','text',2,8,100,120,null,72,0,null,null,null),
    -- Дубай
    (238,'hvac',444,505,'Кондиционер не охлаждает: +29 в open space','Сотрудники уходят работать в переговорные.','critical','assigned','req','voice',1,7,null,null,null,4,0,null,null,null),
    (239,'hvac',443,505,'Капает конденсат в лобби','Лужа у стойки ресепшена, поставили знак.','normal','in_progress','req','text',1,12,60,null,null,72,0,null,null,null),
    (240,'elec',448,505,'Не работает зарядка электромобилей','Станция на парковке не включается.','low','assigned','req','button',3,9,null,null,null,120,0,null,null,null),
    (241,'hvac',446,505,'Ежемесячная чистка фильтров кондиционеров','Регламент: чистка фильтров всех блоков раз в месяц.','low','assigned','mgr','button',2,6,null,null,null,240,0,null,null,'monthly'),
    -- Стамбул
    (242,'plumb',451,506,'Засор в раковине на кухне','Вода не уходит, раковина полная.','normal','in_progress','req','voice',1,10,45,null,null,48,0,null,null,null),
    (243,'clean',450,507,'Уборка после мероприятия','Вечером было мероприятие на 80 человек.','low','done','mgr','button',4,18,60,180,60,24,0,null,null,null),
    (244,'elec',452,506,'Не работает свет на ресепшене','Половина светильников над стойкой не горит.','high','assigned','req','text',2,8,null,null,null,12,0,null,null,null),
    (245,'clean',453,null,'Уборка санузлов после ремонта','После замены плитки остались строительная пыль и мусор.','normal','new','req','voice',1,15,null,null,null,48,0,null,null,null),
    -- Абиджан
    (246,'elec',457,508,'Генератор не запускается при отключении света','Утром отключали сеть — генератор не стартовал.','critical','in_progress','mgr','voice',2,9,60,null,null,6,0,null,null,null),
    (247,'hvac',455,508,'Шумит кондиционер в переговорной','Сильный гул, мешает звонкам.','normal','assigned','req','text',1,10,null,null,null,72,0,null,null,null),
    (248,'plumb',454,508,'Протечка в холле после дождя','С потолка капает у входа.','high','done','req','voice',6,8,90,120,60,24,0,null,null,null),
    -- Шэньчжэнь
    (249,'hvac',459,509,'Не работает кондиционер в open space','Блоки у окон не включаются с пульта.','high','in_progress','req','voice',1,9,30,null,null,48,0,null,null,null),
    (250,'clean',460,510,'Уборка кухни: жалоба на запах','Сотрудники жалуются на запах из мусорных баков.','normal','done','req','text',3,11,60,60,120,24,0,null,null,null),
    (251,'elec',462,509,'Перегрев ИБП в серверной','ИБП сигналит о высокой температуре.','high','on_review','mgr','text',2,8,60,90,null,72,0,null,null,null),
    -- Пекин
    (252,'hvac',465,509,'Сухой воздух в open space','Проверить увлажнители приточной установки.','low','assigned','req','text',2,10,null,null,null,120,0,null,null,null),
    (253,'elec',464,509,'Не работает проектор в переговорной','Нет питания на розетке под потолком.','normal','assigned','req','text',1,9,null,null,null,72,0,null,null,null)
  ) as t(n, layer, loc, c, title, descr, priority, status, author, channel,
         d, h, r, sub, acc, due_h, rc, reason, upd, rec)
  cross join lateral (
    select v_today - make_interval(days => t.d) + make_interval(hours => t.h) as created
  ) x
  join public.locations lo
    on lo.id = ('de300000-0000-4000-8000-' || lpad(t.loc::text, 12, '0'))::uuid
  join public.layers ly
    on ly.id = case t.layer when 'hvac' then v_layer_hvac when 'elec' then v_layer_elec
                            when 'plumb' then v_layer_plumb when 'clean' then v_layer_clean
                            else v_layer_other end
  on conflict (id) do update set
    company_id = excluded.company_id, object_id = excluded.object_id,
    location_id = excluded.location_id, asset_id = null,
    title = excluded.title, description = excluded.description,
    work_type = excluded.work_type, layer_id = excluded.layer_id,
    priority = excluded.priority, status = excluded.status, recurrence = excluded.recurrence,
    requires_photo = excluded.requires_photo, requires_scan = false,
    input_channel = excluded.input_channel, created_by = excluded.created_by,
    assigned_contractor_id = excluded.assigned_contractor_id,
    assigned_executor_id = null, assigned_by = excluded.assigned_by,
    due_at = excluded.due_at, time_spent_minutes = excluded.time_spent_minutes,
    created_at = excluded.created_at, updated_at = excluded.updated_at,
    started_at = excluded.started_at, submitted_at = excluded.submitted_at,
    accepted_at = excluded.accepted_at, accepted_by = excluded.accepted_by,
    return_reason = excluded.return_reason, return_count = excluded.return_count;
  get diagnostics v_world_orders = row_count;
  v_orders := v_orders + v_world_orders;

  -- >>> demo_plans: сгенерировано tools/demo_plans/generate.mjs из plans.json — руками не править
  -- 5d. Этажи и ДЕМО-СХЕМЫ планов (шаг 14b): этажи 601–603, помещения на планах,
  --     оборудование 701–720, заявки 254–257 на этом оборудовании (254 — просрочена).
  --     plan_path / plan_w / plan_h НЕ трогаются: картинки загружают через приложение
  --     (assets/demo_plans/*.png), повторный запуск их не затирает.
  update public.floors f set name = left(f.name, 50) || ' (старый)'
   where f.company_id = c_company
     and f.id not in ('de300000-0000-4000-8000-000000000601'::uuid, 'de300000-0000-4000-8000-000000000602'::uuid, 'de300000-0000-4000-8000-000000000603'::uuid)
     and exists (select 1 from (values
       ('de300000-0000-4000-8000-000000000010'::uuid, '1 этаж'),
       ('de300000-0000-4000-8000-000000000010'::uuid, '3 этаж'),
       ('de300000-0000-4000-8000-000000000402'::uuid, '15 этаж')
     ) as d(o, n) where d.o = f.object_id and d.n = f.name);
  insert into public.floors (id, company_id, object_id, name, level, sort) values
    ('de300000-0000-4000-8000-000000000601'::uuid, c_company, 'de300000-0000-4000-8000-000000000010'::uuid, '1 этаж', 1, 0),
    ('de300000-0000-4000-8000-000000000602'::uuid, c_company, 'de300000-0000-4000-8000-000000000010'::uuid, '3 этаж', 3, 1),
    ('de300000-0000-4000-8000-000000000603'::uuid, c_company, 'de300000-0000-4000-8000-000000000402'::uuid, '15 этаж', 15, 0)
  on conflict (id) do update set name = excluded.name, level = excluded.level, sort = excluded.sort;

  -- Новые помещения на схемах.
  insert into public.locations (id, object_id, name) values
    ('de300000-0000-4000-8000-000000000053'::uuid, 'de300000-0000-4000-8000-000000000010'::uuid, 'Кафе, 1 этаж'),
    ('de300000-0000-4000-8000-000000000052'::uuid, 'de300000-0000-4000-8000-000000000010'::uuid, 'Ресепшен, 1 этаж'),
    ('de300000-0000-4000-8000-000000000054'::uuid, 'de300000-0000-4000-8000-000000000010'::uuid, 'Кабинет директора, 3 этаж'),
    ('de300000-0000-4000-8000-000000000055'::uuid, 'de300000-0000-4000-8000-000000000010'::uuid, 'Серверная, 3 этаж'),
    ('de300000-0000-4000-8000-000000000056'::uuid, 'de300000-0000-4000-8000-000000000010'::uuid, 'Кухня, 3 этаж'),
    ('de300000-0000-4000-8000-000000000466'::uuid, 'de300000-0000-4000-8000-000000000402'::uuid, 'Переговорная «Дунав», 15 этаж'),
    ('de300000-0000-4000-8000-000000000467'::uuid, 'de300000-0000-4000-8000-000000000402'::uuid, 'Санузлы, 15 этаж')
  on conflict (id) do update set name = excluded.name, object_id = excluded.object_id;
  -- Этаж и точка помещений (центр комнаты на схеме, доли 0..1).
  update public.locations l set floor_id = v.f, plan_x = v.x, plan_y = v.y
    from (values
      ('de300000-0000-4000-8000-000000000022'::uuid, 'de300000-0000-4000-8000-000000000601'::uuid, 0.15::real, 0.2063::real),
      ('de300000-0000-4000-8000-000000000053'::uuid, 'de300000-0000-4000-8000-000000000601'::uuid, 0.8::real, 0.2688::real),
      ('de300000-0000-4000-8000-000000000052'::uuid, 'de300000-0000-4000-8000-000000000601'::uuid, 0.15::real, 0.5125::real),
      ('de300000-0000-4000-8000-000000000024'::uuid, 'de300000-0000-4000-8000-000000000601'::uuid, 0.45::real, 0.5125::real),
      ('de300000-0000-4000-8000-000000000021'::uuid, 'de300000-0000-4000-8000-000000000602'::uuid, 0.1833::real, 0.25::real),
      ('de300000-0000-4000-8000-000000000054'::uuid, 'de300000-0000-4000-8000-000000000602'::uuid, 0.8167::real, 0.25::real),
      ('de300000-0000-4000-8000-000000000055'::uuid, 'de300000-0000-4000-8000-000000000602'::uuid, 0.1583::real, 0.75::real),
      ('de300000-0000-4000-8000-000000000056'::uuid, 'de300000-0000-4000-8000-000000000602'::uuid, 0.8417::real, 0.75::real),
      ('de300000-0000-4000-8000-000000000424'::uuid, 'de300000-0000-4000-8000-000000000603'::uuid, 0.3417::real, 0.3563::real),
      ('de300000-0000-4000-8000-000000000466'::uuid, 'de300000-0000-4000-8000-000000000603'::uuid, 0.7917::real, 0.2375::real),
      ('de300000-0000-4000-8000-000000000425'::uuid, 'de300000-0000-4000-8000-000000000603'::uuid, 0.7917::real, 0.5188::real),
      ('de300000-0000-4000-8000-000000000467'::uuid, 'de300000-0000-4000-8000-000000000603'::uuid, 0.1667::real, 0.7813::real)
    ) as v(id, f, x, y)
   where l.id = v.id;

  -- Оборудование: вид (meta.kind) — для значка на плане.
  insert into public.assets (id, location_id, name, category, inventory_no, meta, floor_id, plan_x, plan_y) values
    ('de300000-0000-4000-8000-000000000701'::uuid, 'de300000-0000-4000-8000-000000000022'::uuid, 'Электрощит ЩР-1', 'equipment', 'ЭЛ-1-001', '{"kind":"panel","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000601'::uuid, 0.1083, 0.1625),
    ('de300000-0000-4000-8000-000000000702'::uuid, 'de300000-0000-4000-8000-000000000022'::uuid, 'ИБП щитовой 3 кВА', 'equipment', 'ЭЛ-1-002', '{"kind":"ups","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000601'::uuid, 0.1917, 0.25),
    ('de300000-0000-4000-8000-000000000703'::uuid, 'de300000-0000-4000-8000-000000000024'::uuid, 'Кондиционер холла', 'equipment', 'КЛ-1-001', '{"kind":"ac","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000601'::uuid, 0.3167, 0.4),
    ('de300000-0000-4000-8000-000000000704'::uuid, 'de300000-0000-4000-8000-000000000024'::uuid, 'Светильник холла у лифтов', 'equipment', 'ЭЛ-1-010', '{"kind":"light","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000601'::uuid, 0.5833, 0.4),
    ('de300000-0000-4000-8000-000000000705'::uuid, 'de300000-0000-4000-8000-000000000024'::uuid, 'Датчик дыма холла', 'infra', 'ПБ-1-001', '{"kind":"smoke","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000601'::uuid, 0.45, 0.625),
    ('de300000-0000-4000-8000-000000000706'::uuid, 'de300000-0000-4000-8000-000000000052'::uuid, 'Фанкойл ресепшена', 'equipment', 'КЛ-1-002', '{"kind":"fancoil","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000601'::uuid, 0.1, 0.425),
    ('de300000-0000-4000-8000-000000000707'::uuid, 'de300000-0000-4000-8000-000000000053'::uuid, 'Кондиционер кафе', 'equipment', 'КЛ-1-003', '{"kind":"ac","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000601'::uuid, 0.8917, 0.15),
    ('de300000-0000-4000-8000-000000000708'::uuid, 'de300000-0000-4000-8000-000000000021'::uuid, 'Кондиционер переговорной', 'equipment', 'КЛ-3-001', '{"kind":"ac","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000602'::uuid, 0.1083, 0.1438),
    ('de300000-0000-4000-8000-000000000709'::uuid, 'de300000-0000-4000-8000-000000000021'::uuid, 'Датчик дыма переговорной', 'infra', 'ПБ-3-001', '{"kind":"smoke","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000602'::uuid, 0.2667, 0.35),
    ('de300000-0000-4000-8000-000000000710'::uuid, 'de300000-0000-4000-8000-000000000054'::uuid, 'Фанкойл кабинета директора', 'equipment', 'КЛ-3-002', '{"kind":"fancoil","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000602'::uuid, 0.8917, 0.15),
    ('de300000-0000-4000-8000-000000000711'::uuid, 'de300000-0000-4000-8000-000000000055'::uuid, 'Серверная стойка R1', 'equipment', 'ИТ-3-001', '{"kind":"server","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000602'::uuid, 0.1083, 0.8125),
    ('de300000-0000-4000-8000-000000000712'::uuid, 'de300000-0000-4000-8000-000000000055'::uuid, 'ИБП серверной 10 кВА', 'equipment', 'ЭЛ-3-001', '{"kind":"ups","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000602'::uuid, 0.2083, 0.8625),
    ('de300000-0000-4000-8000-000000000713'::uuid, 'de300000-0000-4000-8000-000000000055'::uuid, 'Кондиционер серверной', 'equipment', 'КЛ-3-003', '{"kind":"ac","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000602'::uuid, 0.1083, 0.65),
    ('de300000-0000-4000-8000-000000000714'::uuid, 'de300000-0000-4000-8000-000000000056'::uuid, 'Светильник кухни', 'equipment', 'ЭЛ-3-010', '{"kind":"light","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000602'::uuid, 0.8417, 0.8125),
    ('de300000-0000-4000-8000-000000000715'::uuid, 'de300000-0000-4000-8000-000000000424'::uuid, 'Кондиционер open space №1', 'equipment', 'SK-15-001', '{"kind":"ac","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000603'::uuid, 0.15, 0.15),
    ('de300000-0000-4000-8000-000000000716'::uuid, 'de300000-0000-4000-8000-000000000424'::uuid, 'Кондиционер open space №2', 'equipment', 'SK-15-002', '{"kind":"ac","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000603'::uuid, 0.5333, 0.15),
    ('de300000-0000-4000-8000-000000000717'::uuid, 'de300000-0000-4000-8000-000000000466'::uuid, 'Фанкойл переговорной «Дунав»', 'equipment', 'SK-15-003', '{"kind":"fancoil","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000603'::uuid, 0.8917, 0.15),
    ('de300000-0000-4000-8000-000000000718'::uuid, 'de300000-0000-4000-8000-000000000425'::uuid, 'Электрощит ЩР-15', 'equipment', 'SK-15-010', '{"kind":"panel","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000603'::uuid, 0.9, 0.575),
    ('de300000-0000-4000-8000-000000000719'::uuid, 'de300000-0000-4000-8000-000000000467'::uuid, 'Датчик протечки санузла', 'infra', 'SK-15-020', '{"kind":"water","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000603'::uuid, 0.1, 0.8625),
    ('de300000-0000-4000-8000-000000000720'::uuid, 'de300000-0000-4000-8000-000000000424'::uuid, 'Датчик дыма open space', 'infra', 'SK-15-021', '{"kind":"smoke","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000603'::uuid, 0.3417, 0.55)
  on conflict (id) do update set
    location_id = excluded.location_id, name = excluded.name, category = excluded.category,
    inventory_no = excluded.inventory_no, meta = excluded.meta, floor_id = excluded.floor_id,
    plan_x = excluded.plan_x, plan_y = excluded.plan_y;

  -- Заявки на оборудовании этажей. Колонки как в 5c, плюс a — оборудование.
  insert into public.work_orders (
    id, company_id, object_id, location_id, asset_id, title, description, work_type, layer_id,
    priority, status, requires_photo, input_channel, created_by,
    assigned_contractor_id, assigned_by, due_at, created_at, updated_at, started_at,
    return_count, recurrence)
  select
    ('de300000-0000-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
    c_company, lo.object_id, lo.id,
    ('de300000-0000-4000-8000-' || lpad(t.a::text, 12, '0'))::uuid,
    t.title, t.descr, ly.name, ly.id, t.priority, t.status, ly.requires_photo, t.channel,
    case t.author when 'mgr' then v_manager else v_requester end,
    case when t.c is not null then ('de300000-0000-4000-8000-' || lpad(t.c::text, 12, '0'))::uuid end,
    case when t.c is not null then 'rule' end,
    x.created + make_interval(hours => t.due_h),
    x.created,
    case when t.r is not null then x.created + make_interval(mins => t.r) else x.created end,
    case when t.r is not null then x.created + make_interval(mins => t.r) end,
    0, null
  from (values
    (254,'hvac',55,713,31::int,'Течёт конденсат из кондиционера серверной','Под внутренним блоком лужа, капает рядом со стойкой.','high','assigned','req','voice',1,8,null::int,6),
    (255,'hvac',54,710,31,'Не греет фанкойл в кабинете директора','Фанкойл гудит, но воздух холодный.','normal','assigned','req','text',1,9,null,72),
    (256,'elec',24,704,32,'Мигает светильник в холле у лифтов','Светильник над лифтами мигает с утра.','normal','in_progress','req','text',1,10,60,48),
    (257,'plumb',467,719,null,'Сработал датчик протечки в санузле','Датчик под раковиной пищит, на полу вода.','high','new','mgr','button',1,7,null,24)
  ) as t(n, layer, loc, a, c, title, descr, priority, status, author, channel, d, h, r, due_h)
  cross join lateral (
    select v_today - make_interval(days => t.d) + make_interval(hours => t.h) as created
  ) x
  join public.locations lo
    on lo.id = ('de300000-0000-4000-8000-' || lpad(t.loc::text, 12, '0'))::uuid
  join public.layers ly
    on ly.id = case t.layer when 'hvac' then v_layer_hvac when 'elec' then v_layer_elec
                            when 'plumb' then v_layer_plumb when 'clean' then v_layer_clean
                            else v_layer_other end
  on conflict (id) do update set
    company_id = excluded.company_id, object_id = excluded.object_id,
    location_id = excluded.location_id, asset_id = excluded.asset_id,
    title = excluded.title, description = excluded.description,
    work_type = excluded.work_type, layer_id = excluded.layer_id,
    priority = excluded.priority, status = excluded.status, recurrence = null,
    requires_photo = excluded.requires_photo, requires_scan = false,
    input_channel = excluded.input_channel, created_by = excluded.created_by,
    assigned_contractor_id = excluded.assigned_contractor_id,
    assigned_executor_id = null, assigned_by = excluded.assigned_by,
    due_at = excluded.due_at, time_spent_minutes = null,
    created_at = excluded.created_at, updated_at = excluded.updated_at,
    started_at = excluded.started_at, submitted_at = null,
    accepted_at = null, accepted_by = null,
    return_reason = null, return_count = 0;
  get diagnostics v_plan_orders = row_count;
  v_orders := v_orders + v_plan_orders;
  -- <<< demo_plans

  -- 6. Визиты
  -- Колонки: vn — номер (часть id); n — заявка; off — минут от начала работы
  -- до прихода; dur — минут на объекте; dist — метров до объекта
  -- (null = обычный визит, точка в 8–97 м от центра); mock — подмена GPS.
  -- Визит «ЭлектроПро» (316) — только если указан четвёртый пользователь.
  if v_elec_exec is null then
    delete from public.visits where id = c_mock_visit;
  end if;

  insert into public.visits (
    id, company_id, object_id, profile_id, contractor_id, work_order_id,
    started_at, ended_at, source, lat, lng, accuracy_m, distance_m,
    in_geofence, mock_location, created_at)
  select
    ('de300000-0000-4000-8000-' || lpad(v.vn::text, 12, '0'))::uuid,
    c_company, c_object,
    case when v.n >= 200 then v_elec_exec else v_executor end,
    w.assigned_contractor_id, w.id,
    w.started_at + make_interval(mins => v.off),
    w.started_at + make_interval(mins => v.off + v.dur),
    'geofence',
    v_obj.lat + g.dist / 111320.0, v_obj.lng, g.acc, g.dist,
    g.dist <= v_obj.geofence_radius_m + least(g.acc, 50),
    v.mock,
    w.started_at + make_interval(mins => v.off)
  from (values
    (301,101,0,55,null::int,false),
    (302,102,0,110,null,false),
    (303,103,0,45,null,false),
    (304,104,0,50,null,false),     -- первый заход, потом возврат
    (315,104,140,35,null,false),   -- повторный заход после возврата
    (305,105,0,80,null,false),
    (306,106,0,30,null,false),
    (307,107,0,70,null,false),
    (308,108,0,65,340,false),      -- вне геозоны: отметился с парковки
    (309,109,0,40,null,false),
    (310,110,0,35,520,false),      -- вне геозоны
    (311,111,0,120,null,false),
    (312,112,0,75,null,false),
    (313,113,0,50,null,false),
    (314,114,0,60,null,false),
    (316,206,0,50,3,true)          -- «ЭлектроПро»: подмена GPS
  ) as v(vn, n, off, dur, dist, mock)
  join public.work_orders w
    on w.id = ('de300000-0000-4000-8000-' || lpad(v.n::text, 12, '0'))::uuid
  cross join lateral (
    select coalesce(v.dist, 8 + (v.n * 37) % 90)::double precision as dist,
           case when v.mock then 1.0 else 4 + (v.n * 7) % 15 end::double precision as acc
  ) g
  where v.n < 200 or v_elec_exec is not null
  on conflict (id) do update set
    company_id = excluded.company_id, object_id = excluded.object_id,
    profile_id = excluded.profile_id, contractor_id = excluded.contractor_id,
    work_order_id = excluded.work_order_id, started_at = excluded.started_at,
    ended_at = excluded.ended_at, source = excluded.source,
    lat = excluded.lat, lng = excluded.lng, accuracy_m = excluded.accuracy_m,
    distance_m = excluded.distance_m, in_geofence = excluded.in_geofence,
    mock_location = excluded.mock_location, created_at = excluded.created_at;
  get diagnostics v_visits = row_count;

  raise notice 'Готово: демо-история — заявок %, визитов %.%', v_orders, v_visits,
    case when v_elec_exec is null
         then ' Исполнитель «ЭлектроПро» не указан — визита с подменой GPS нет.' else '' end;
end $$;

set local session_replication_role = origin;

commit;
