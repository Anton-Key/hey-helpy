-- =====================================================================
-- Hey Helpy · демо-история за последние 30 дней (НЕ миграция)
--
-- Что делает: добавляет в компанию «Demo Properties» 91 заявку (72 + 19 задач ППР шага 16) и 16 визитов,
-- чтобы на демо «История» и «Отчёты» были наполнены, и 4 объекта на карте:
--   • «ClimaService» (Климат) — 15 заявок, всё в срок, приёмка почти всегда
--     с первого раза, 15 визитов при норме 4 в месяц;
--   • «ElectroPro» (Электрика) — 10 заявок, 2 просрочены, 3 возвращали
--     на доработку, визитов меньше нормы 2 в месяц (один — с подменой GPS).
--   • эти 25 заявок — на «Demo Tower» (Белград, Савски венац);
--   • ещё 10 заявок (211–220) — на 4 новых объектах в Белграде
--     («Demo Plaza Mall», «Demo Logistics Warehouse», «Demo City Office»,
--     «Demo Park Hotel»; 11 помещений) — для карты во вкладке «Локации»:
--     у «Плазы» просроченная critical (красный маркер), у склада открытых
--     заявок нет (серо-зелёный). Из них 5 — «ElectroPro» (+1 просрочка в отчёте).
--   • ещё 2 повторяющиеся заявки (221–222) на «Demo Tower» — для фильтра
--     «Ещё → Тип → Повторяющаяся» (шаг 13c).
--   • объекты по миру (шаг 13d): 15 офисов (401–415) в Белграде, Москве, Дубае,
--     Стамбуле, Абиджане, Шэньчжэне и Пекине, 45 помещений (421–465),
--     10 региональных подрядчиков (501–510) с закреплениями по объектам и видам
--     работ, 31 заявка (223–253): 4 просрочены, 3 без подрядчика, 2 повторяющиеся.
--     «ElectroPro» переводится с «всех объектов» на белградские.
--   • планы этажей (шаг 14b, блок 5d — генерирует tools/demo_plans/generate.mjs):
--     этажи 601 «1 этаж» и 602 «3 этаж» у «Demo Tower», 603 «15 этаж» у «Skyline»,
--     7 новых помещений (052–056, 466–467), точки помещений на ДЕМО-СХЕМАХ,
--     оборудование 701–720, 4 заявки на нём (254–257, 254 просрочена).
--     Картинки планов (plan_path) скрипт не трогает — их загружают через приложение.
--   • шаг 16 (блок 5e, нужна миграция 0015): регионы 901–905, страна, город и
--     регион у всех 20 объектов, паспорт оборудования 701–720 и ещё 15 единиц
--     721–735, номера и области помещений на схемах (5d), планы ППР 801–808,
--     задачи периодов 258–276 (266 и 270 просрочены), 234 и 241 — задачи планов.
--   • шаг 22: у всех 37 единиц оборудования — вид (meta.kind, каталог
--     supabase/functions/_shared/kinds.ts); на этаже 3 «Demo Tower» — «Кондиционер
--     AC-301» и огнетушитель 737 в переговорной 301, «Air conditioner AC-302» 736
--     в кабинете 302 (сценарий «Узнать по фото»).
--   • шаг 17 (блок 5f, если применена 0016): бригады «Пекин» и «Шэньчжэнь»
--     подрядчика Riyadh FM (950–951) с зонами по городу (970–971).
--   • шаг 23 (блок 5g, если применена 0018): заявки из Telegram-бота 277
--     (гость по QR-коду) и 278 (сотрудник с привязанным аккаунтом).
--   • шаг 24 (блок 5h, если применена 0020): значки и цвета систем.
--   • шаг 25 (блок 5i): у «Кондиционера AC-301» — открытая заявка 277, принятые
--     101/106/108/110 и план ТО 809 с задачей 279 этого месяца (сцена «Камеры»);
--     (блок 5j, если применена 0018): включённые ссылки Telegram объекта
--     «Demo Tower» и компании с демо-токенами (report_links 981–982).
--   • шаг 27 (блок 6c, нужна 0024): в акте «ClimaService» 109 (фото «из
--     файла») и 112 (снято без сети, часы расходились на 2 ч) — «Требует
--     решения менеджера»;
--   • шаг 24 (блок 6b): доказательства для акта «ClimaService» (фото «после» —
--     картинка из сборки demo/ac_after.jpg, чек-лист, визиты 317–318) и,
--     если применена 0021, ставки трёх подрядчиков.
--
-- Запускать в Supabase → SQL Editor ПОСЛЕ supabase/seed/demo.sql
-- и миграций 0001–0015. Подробно: docs/DEMO_SETUP.md, шаг 4.
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
-- в «Demo Properties» остаются только заявки этого скрипта.
-- УДАЛЕНИЕ ИСТОРИИ — блок 1 ниже, по умолчанию выключен.
-- =====================================================================

begin;

-- Шаг 16: регионы, ППР и реестр оборудования — нужна миграция 0015.
do $$
begin
  if to_regclass('public.maintenance_plans') is null
     or not exists (select 1 from information_schema.columns
                     where table_schema = 'public' and table_name = 'objects'
                       and column_name = 'region_id') then
    raise exception 'Сначала примените миграцию 0015 (supabase/migrations/0015_ppr_regions_equipment.sql): Actions → «Apply migration»';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Блок 0. Удалить все НЕдемо-заявки компании «Demo Properties» (всегда)
-- Демо-заявки — только из этого скрипта, с постоянными id
-- de300000-0000-4000-8000-000000000101 … 299 (в demo.sql заявок нет).
-- Всё остальное в «Demo Properties» — тестовые заявки, созданные руками или
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
  raise notice 'Тестовые (недемо) заявки «Demo Properties» удалены: %.', v_orders;
  -- Шаг 33: сформированные акты — снимки строк с прежними (русскими)
  -- названиями и суммами в рублях. Удаляются: в демо их формируют заново
  -- (Отчёты → Акты подрядчикам). Файлы PDF остаются в Storage (contractor-acts).
  if to_regclass('public.contractor_acts') is not null then
    delete from public.contractor_acts where company_id = c_company;
  end if;
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
  -- Необязательно: четвёртый тестовый пользователь — исполнитель «ElectroPro».
  -- Если указать, он станет исполнителем «ElectroPro», и у подрядчика появится
  -- визит с подменой GPS. Если оставить пустым — у «ElectroPro» визитов не будет.
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
  v_layer_sec uuid;
  v_ppr_orders int;
  v_plan_start date := (date_trunc('month', now()) - interval '6 months')::date;
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
    raise exception 'Пользователи не в компании «Demo Properties». Сначала запустите supabase/seed/demo.sql';
  end if;
  if trim(v_elec_executor_email) <> '' then
    select id into v_elec_exec from auth.users where lower(email) = lower(trim(v_elec_executor_email));
    if v_elec_exec is null then
      raise exception 'Не найден исполнитель «ElectroPro»: %. Создайте его в Authentication → Users или оставьте пустую строку', v_elec_executor_email;
    end if;
    if v_elec_exec in (v_manager, v_executor, v_requester) then
      raise exception 'Исполнитель «ElectroPro» должен быть четвёртым, отдельным пользователем';
    end if;
  end if;

  -- 2. Справочники из demo.sql
  select o.lat, o.lng, o.geofence_radius_m into v_obj
    from public.objects o where o.id = c_object and o.company_id = c_company;
  if not found then
    raise exception 'Нет объекта «Demo Tower». Сначала запустите supabase/seed/demo.sql';
  end if;
  if v_obj.lat is null or v_obj.lng is null then
    raise exception 'У объекта «Demo Tower» нет координат. Укажите их в карточке объекта';
  end if;
  if (select count(*) from public.locations
       where object_id = c_object and id in (c_loc_meet, c_loc_elec, c_loc_open, c_loc_hall)) <> 4 then
    raise exception 'Нет помещений «Demo Tower». Сначала запустите supabase/seed/demo.sql';
  end if;
  if (select count(*) from public.contractors
       where company_id = c_company and id in (c_contr_hvac, c_contr_elec)) <> 2 then
    raise exception 'Нет подрядчиков «ClimaService» и «ElectroPro». Сначала запустите supabase/seed/demo.sql';
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
  select id into v_layer_sec   from public.layers where company_id = c_company and name = 'Системы безопасности';
  if v_layer_plumb is null or v_layer_clean is null or v_layer_other is null
     or v_layer_sec is null then
    raise exception 'Не найдены слои «Сантехника», «Клининг», «Другое» или «Системы безопасности» у компании «Demo Properties»';
  end if;

  -- 3. Нормы визитов по договору: «ClimaService» — 4 в месяц, «ElectroPro» — 2.
  --    Шаг 13d: подрядчики работают по регионам. «ElectroPro» в demo.sql закреплён
  --    за «Электрикой» на ВСЕХ объектах (object_id = null) — тогда заявки по
  --    электрике в Москве или Дубае тоже уходили бы ему. Переводим его на
  --    белградские объекты: здесь — «Demo Tower» (с нормой 2), остальные — в 3c.
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

  -- 3a. Шаг 33: демо — на английском. То, что создаёт только demo.sql, —
  --     переименовать по постоянным id (повторный запуск ничего не меняет).
  update public.companies set name = 'Demo Properties' where id = c_company;
  update public.objects set name = 'Demo Tower' where id = c_object;
  update public.locations l set name = v.name
    from (values (c_loc_meet, 'Meeting room, floor 3'), (c_loc_elec, 'Electrical room, floor 1'),
                 (c_loc_open, 'Open space, floor 2'), (c_loc_hall, 'Hall, floor 1')) as v(id, name)
   where l.id = v.id;
  update public.contractors set org_name = 'ClimaService' where id = c_contr_hvac;
  update public.contractors set org_name = 'ElectroPro' where id = c_contr_elec;
  -- Имена демо-пользователей — только если остались прежними из demo.sql
  -- (своё имя, заданное в настройках, не трогаем).
  update public.profiles p set full_name = v.en
    from (values ('Менеджер Демо', 'Demo Manager'), ('Исполнитель Демо', 'Demo Technician'),
                 ('Заявитель Демо', 'Demo Requester'), ('Электрик Демо', 'Demo Electrician')) as v(ru, en)
   where p.company_id = c_company and p.full_name = v.ru;

  -- 3b. Объекты на карте (шаг 13). «Demo Tower» стоит в Белграде — адрес
  --     под его координаты. Ещё 4 объекта в разных районах Белграда
  --     (2–10 км друг от друга), по 2–3 помещения. Адреса — без реальных улиц.
  update public.objects set address = 'Belgrade, Savski Venac (demo)'
   where id = c_object;

  insert into public.objects (id, company_id, name, type, address, lat, lng, geofence_radius_m)
  values
    (c_obj_plaza, c_company, 'Demo Plaza Mall',       'other',     'Belgrade, New Belgrade (demo)', 44.803000, 20.404000, 200),
    (c_obj_log,   c_company, 'Demo Logistics Warehouse', 'warehouse', 'Belgrade, Zemun (demo)',        44.859000, 20.380000, 300),
    (c_obj_city,  c_company, 'Demo City Office',      'office',    'Belgrade, Dorćol (demo)',       44.823500, 20.470000, 150),
    (c_obj_park,  c_company, 'Demo Park Hotel',     'hotel',     'Belgrade, Voždovac (demo)',     44.770000, 20.480000, 250)
  on conflict (id) do update set
    company_id = excluded.company_id, name = excluded.name, type = excluded.type,
    address = excluded.address, lat = excluded.lat, lng = excluded.lng,
    geofence_radius_m = excluded.geofence_radius_m;

  insert into public.locations (id, object_id, name)
  select ('de300000-0000-4000-8000-' || lpad(p.n::text, 12, '0'))::uuid,
         ('de300000-0000-4000-8000-' || lpad(p.o::text, 12, '0'))::uuid, p.name
  from (values
    (41, 11, 'Food court, floor 2'),
    (42, 11, 'Shopping gallery, floor 1'),
    (43, 11, 'Parking, level −1'),
    (44, 12, 'Receiving area, gate 3'),
    (45, 12, 'Cold room'),
    (46, 12, 'Warehouse office'),
    (47, 13, 'Reception, floor 1'),
    (48, 13, 'Server room, floor 4'),
    (49, 14, 'Lobby'),
    (50, 14, 'Room 214'),
    (51, 14, 'Restaurant')
  ) as p(n, o, name)
  on conflict (id) do update set name = excluded.name, object_id = excluded.object_id;

  -- «ClimaService» — «Климат» и на новых объектах (как на «Demo Tower»);
  -- «ElectroPro» — за «Электрикой» на этих же 4 объектах (а на «Demo Tower» — в шаге 3).
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
    (401, 'Hub 1',               'office', 'Belgrade, Bulevar vojvode Bojovića 12 (demo)',             44.826200,  20.456600, 200),
    (402, 'Skyline',             'office', 'Belgrade, Kneza Miloša 90a (demo)',                      44.799990,  20.452140, 150),
    (403, 'Office 1',              'office', 'New York, Midtown Manhattan (demo)',          40.754900, -73.984000, 250),
    (404, 'Office 2',              'office', 'New York, Financial District (demo)',                             40.707500, -74.011300, 150),
    (405, 'Office 3',              'office', 'New York, Chelsea (demo)',                         40.746500, -74.001400, 200),
    (406, 'Office 4',              'office', 'New York, Hudson Yards (demo)',                           40.753600, -74.002100, 150),
    (407, 'Office 5',              'office', 'New York, Upper East Side (demo)',                               40.773600, -73.956600, 300),
    (408, 'Office 1',              'office', 'Dubai, Business Bay (demo)',                            25.186000,  55.265000, 200),
    (409, 'Office 2',              'office', 'Dubai, Dubai Marina (demo)',                            25.080500,  55.140300, 200),
    (410, 'Office 1',              'office', 'Berlin, Mitte (demo)',                                52.520000, 13.405000, 200),
    (411, 'Office 2',              'office', 'Berlin, Kreuzberg (demo)',                              52.498600, 13.403300, 200),
    (412, 'Thames House', 'office', 'London, Southwark (demo)',   51.504500, -0.086500, 300),
    (413, 'Office 1',              'office', 'Abu Dhabi, Al Maryah Island (demo)',                              24.501000, 54.389000, 200),
    (414, 'Office 2',              'office', 'Abu Dhabi, Al Reem Island (demo)',                            24.496000, 54.404000, 200),
    (415, 'Office 1',              'office', 'Riyadh, King Abdullah Financial District (demo)',                                  24.764000, 46.640000, 250)
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
    (421, 401, 'Lobby'),
    (422, 401, 'Meeting room “Sava”'),
    (423, 401, 'Server room'),
    (424, 402, 'Open space, floor 15'),
    (425, 402, 'Kitchen, floor 15'),
    (426, 402, 'Parking, level −2'),
    (427, 403, 'Lobby, floor 1'),
    (428, 403, 'Open space, floor 32'),
    (429, 403, 'Server room, floor 31'),
    (430, 403, 'Meeting room “Hudson”'),
    (431, 404, 'Reception'),
    (432, 404, 'Kitchen, floor 3'),
    (433, 404, 'Restrooms, floor 2'),
    (434, 405, 'Lobby'),
    (435, 405, 'Open space, floor 5'),
    (436, 405, 'Heating substation, basement'),
    (437, 406, 'Meeting room “East River”'),
    (438, 406, 'Kitchen'),
    (439, 406, 'Restrooms, floor 4'),
    (440, 407, 'Atrium'),
    (441, 407, 'Laboratory'),
    (442, 407, 'Parking'),
    (443, 408, 'Lobby'),
    (444, 408, 'Open space, floor 21'),
    (445, 408, 'Server room'),
    (446, 409, 'Reception'),
    (447, 409, 'Meeting room'),
    (448, 409, 'Parking'),
    (449, 410, 'Lobby'),
    (450, 410, 'Open space, floor 12'),
    (451, 410, 'Kitchen'),
    (452, 411, 'Reception'),
    (453, 411, 'Restrooms, floor 3'),
    (454, 412, 'Hall'),
    (455, 412, 'Meeting room'),
    (456, 412, 'Server room'),
    (457, 412, 'Generator room'),
    (458, 413, 'Lobby'),
    (459, 413, 'Open space, floor 28'),
    (460, 413, 'Kitchen'),
    (461, 414, 'Reception'),
    (462, 414, 'Server room'),
    (463, 415, 'Lobby'),
    (464, 415, 'Meeting room'),
    (465, 415, 'Open space, floor 18')
  ) as p(n, o, name)
  on conflict (id) do update set name = excluded.name, object_id = excluded.object_id;

  -- Подрядчики по регионам — только организации, без учётных записей.
  insert into public.contractors (id, company_id, org_name)
  select ('de300000-0000-4000-8000-' || lpad(c.n::text, 12, '0'))::uuid, c_company, c.name
  from (values
    (501, 'NYC Climate'),
    (502, 'CityElectric'),
    (503, 'CleanCity'),
    (504, 'LiftService'),
    (505, 'Gulf FM Services'),
    (506, 'Berlin Technik'),
    (507, 'Berlin Clean'),
    (508, 'Thames Maintenance'),
    (509, 'Riyadh FM'),
    (510, 'Abu Dhabi Clean')
  ) as c(n, name)
  on conflict (id) do update set company_id = excluded.company_id, org_name = excluded.org_name;

  -- Закрепления: подрядчик (31, 32 — белградские из demo.sql, 501–510 — новые),
  -- вид работ, объект, норма визитов в месяц. По ним база сама назначает
  -- подрядчика новой заявке (слой + объект). «LiftService» — слой «Другое»
  -- (слоя «Лифты» у компании нет).
  insert into public.contractor_layers (contractor_id, layer_id, object_id, visits_per_month)
  select ('de300000-0000-4000-8000-' || lpad(b.c::text, 12, '0'))::uuid,
         case b.layer when 'hvac' then v_layer_hvac when 'elec' then v_layer_elec
                      when 'plumb' then v_layer_plumb when 'clean' then v_layer_clean
                      else v_layer_other end,
         ('de300000-0000-4000-8000-' || lpad(b.o::text, 12, '0'))::uuid, b.norm
  from (values
    -- Белград: «ClimaService» и «ElectroPro» — ещё «Хаб 1» и «Skyline»
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
    -- Китай: «Riyadh FM» — весь Китай, «Abu Dhabi Clean» — только Шэньчжэнь
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

  -- 4. Четвёртый пользователь (если указан) — исполнитель «ElectroPro»
  if v_elec_exec is not null then
    insert into public.profiles (id, company_id, role, full_name)
    values (v_elec_exec, c_company, 'executor', 'Demo Electrician')
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
    -- «ClimaService»: быстро, в срок, один возврат
    (101,'hvac','meet','AC not cooling in the meeting room','The AC is on but blowing warm air. Client meeting at 11:00.','normal','done','req','text',29,7,35,55,90,72,0,null::text,null::int),
    (102,'hvac','open','Scheduled AC maintenance: filter cleaning','Monthly maintenance of 6 open space indoor units.','low','done','mgr','button',27,6,120,110,240,120,0,null,null),
    (103,'hvac','open','Noisy indoor unit by the window','Loud hum and crackle, hard to work.','normal','done','req','voice',26,9,40,45,60,72,0,null,null),
    (104,'hvac','hall','Water leaking from the AC at reception','Dripping onto the front desk, a bucket has been placed.','high','done','req','text',24,7,20,175,70,24,1,'Dripping again after the repair: the drain was not fully cleared.',null),
    (105,'hvac','open','Ventilation not working in the open space','Stuffy, the supply ventilation has been off since morning.','high','done','req','voice',22,6,25,80,45,24,0,null,null),
    (106,'hvac','meet','Too hot in the meeting room: adjust the AC','The remote shows 22 °C, the room is 27 °C.','normal','done','req','text',20,11,45,30,120,72,0,null,null),
    (107,'hvac','hall','Replace air handling unit filters','Scheduled filter replacement.','low','done','mgr','button',17,6,90,70,180,120,0,null,null),
    (108,'hvac','meet','Unpleasant smell from the AC','The indoor unit needs antibacterial treatment.','normal','done','req','text',15,8,50,65,100,72,0,null,null),
    (109,'hvac','open','Draft from a diffuser over workstations','It blows straight at the row by the window, staff complain.','low','done','req','voice',13,10,60,40,150,120,0,null,null),
    (110,'hvac','meet','AC does not turn on from the remote','The indicator is blinking, no response to the remote.','high','done','req','text',10,7,15,35,60,24,0,null,null),
    (111,'hvac','open','Scheduled maintenance: refrigerant pressure check','Scheduled check of 6 open space units.','low','done','mgr','button',8,6,100,120,200,120,0,null,null),
    (112,'hvac','hall','Air curtain at the entrance not working','Cold at the entrance, the air curtain does not turn on.','high','done','req','voice',5,7,20,75,50,24,0,null,null),
    (113,'hvac','open','Condensate dripping over a workstation','Wet spot on the ceiling by the column.','normal','done','req','text',3,9,30,50,80,72,0,null,null),
    (114,'hvac','meet','Noisy fan in the meeting room','The indoor unit fan knocks at high speed.','normal','on_review','req','voice',1,8,40,60,null,72,0,null,null),
    (115,'hvac','meet','Duplicate: AC not cooling in the meeting room','Created twice by mistake.','normal','cancelled','req','text',12,9,null,null,null,72,0,null,20),
    -- «ElectroPro»: долго берёт в работу, возвраты, 2 просрочки
    (201,'elec','hall','Lights flickering in the hall','Two lights by the lifts have been flickering since morning.','normal','done','req','text',28,8,300,70,240,72,0,null,null),
    (202,'elec','open','Socket at a workstation not working','The socket at desk 2-14 has no power.','low','done','req','text',25,9,1560,1500,300,120,1,'The socket is dead again: the cause was not fixed.',null),
    (203,'elec','elec','Breaker keeps tripping in the electrical room','The floor 3 breaker trips 2–3 times a day.','high','done','mgr','text',23,7,180,90,300,24,0,null,null),
    (204,'elec','meet','Replace lamps in the meeting room','3 of 8 lamps are out.','low','done','req','button',19,10,1500,45,600,120,0,null,null),
    (205,'elec','hall','Emergency lighting out on the stairs','Emergency lights between floors 1 and 2 are out.','normal','done','mgr','text',14,8,240,3000,240,120,2,'The emergency light on floor 2 is still out.',null),
    (206,'elec','open','Switch sparking in the open space','The switch by the kitchen sparks and clicks when turning on the lights.','critical','done','req','voice',9,7,120,50,60,8,0,null,null),
    (207,'elec','elec','Lighting out in the electrical room','The electrical room is dark, impossible to work on the panel.','normal','returned','mgr','text',6,8,1560,150,null,72,1,'The wrong light was replaced: the electrical room is still dark.',2940),
    (208,'elec','meet','No power at the meeting room sockets','All sockets at the table are dead, meeting at 15:00.','high','assigned','req','voice',5,9,null,null,null,24,0,null,null),
    (209,'elec','elec','Check the panel after a power surge','There was a surge overnight, some circuits went off.','normal','in_progress','mgr','text',2,9,1500,null,null,120,0,null,null),
    (210,'elec','hall','Replace a light in the hall','The light above the entrance is cracked, needs replacement.','low','on_review','req','text',4,10,1500,1500,null,120,0,null,null),
    -- Объекты на карте (шаг 13); loc — номер помещения (041–051), объект — по помещению.
    -- «Demo Plaza Mall»: просроченная critical — красный маркер
    (211,'elec','41','No lights in the food court','Half of the food court has no power, tenants cannot work.','critical','assigned','mgr','text',1,7,null,null,null,4,0,null,null),
    (212,'hvac','42','Stuffy in the shopping gallery','Supply ventilation by the escalator is not working.','normal','new','req','voice',1,10,null,null,null,72,0,null,null),
    (213,'elec','43','Replace lamps in the parking','5 lights at the entrance are out.','low','done','req','text',6,9,300,60,120,120,0,null,null),
    -- «Demo Logistics Warehouse»: открытых заявок нет — серо-зелёный маркер
    (214,'hvac','45','Cold room maintenance','Scheduled compressor and seal check.','low','done','mgr','button',9,7,90,120,180,120,0,null,null),
    (215,'elec','44','Duplicate: light at gate 3','Created twice by mistake.','low','cancelled','req','text',4,8,null,null,null,120,0,null,30),
    -- «Demo City Office»: срочная в работе — оранжевый маркер
    (216,'hvac','48','Server room overheating','31 °C in the server room, the AC cannot keep up.','high','in_progress','mgr','text',1,8,40,null,null,72,0,null,null),
    (217,'elec','47','Reception backlight flickering','The LED strip above the counter is flickering.','normal','on_review','req','text',2,9,200,90,null,72,0,null,null),
    -- «Demo Park Hotel»: обычные открытые — бирюзовый маркер
    (218,'hvac','50','AC not working in room 214','Guest complains the room is too hot.','normal','new','req','voice',1,9,null,null,null,72,0,null,null),
    (219,'elec','51','Socket at the bar not working','The coffee machine does not turn on, the socket has no power.','low','assigned','mgr','text',2,11,null,null,null,120,0,null,null),
    (220,'hvac','49','Filter cleaning in the lobby','Scheduled maintenance of the lobby air conditioners.','low','done','mgr','button',12,6,100,80,200,120,0,null,null),
    -- Повторяющиеся (регламентные) заявки (шаг 13c) — recurrence задаётся ниже, в 5b
    (221,'hvac','open','Monthly AC inspection','Schedule: inspect and clean the open space indoor units monthly.','normal','assigned','mgr','button',2,7,null,null,null,168,0,null,null),
    (222,'elec','hall','Weekly emergency lighting check','Schedule: check emergency lights on stairs and in the hall weekly.','low','in_progress','mgr','button',1,8,120,null,null,48,0,null,null)
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
    (223,'hvac',421,31,'Noisy AC in the lobby','The indoor unit above the entrance hums and crackles.','normal','assigned','req','voice',1,9,null::int,null::int,null::int,72,0,null::text,null::int,null::text),
    (224,'elec',424,32,'Lights flickering in the open space','Three lights by the windows have been flickering since morning.','normal','in_progress','mgr','text',2,8,90,null,null,72,0,null,null,null),
    (225,'hvac',422,31,'Too hot in meeting room “Sava”','The AC cannot hold 22 °C, by lunch it is 27 °C.','low','done','req','text',6,10,30,60,90,120,0,null,null,null),
    (226,'elec',426,32,'Parking lights out','Dark at the exit, 4 lights are out.','normal','on_review','req','button',3,9,200,120,null,120,0,null,null,null),
    -- Москва
    (227,'hvac',435,501,'Cold in the open space: radiators not heating','Radiators by the windows are cold, 17 °C in the office.','critical','in_progress','req','voice',1,8,30,null,null,6,0,null,null,null),
    (228,'other',427,504,'Lift stuck in the lobby','Lift #2 stopped between floors 1 and 2, people were evacuated.','critical','done','mgr','voice',4,9,15,60,30,4,0,null,null,null),
    (229,'elec',429,502,'Voltage spikes in the server room','The UPS switched to battery twice overnight.','high','assigned','mgr','text',1,11,null,null,null,48,0,null,null,null),
    (230,'clean',432,503,'Kitchen deep cleaning','Deep cleaning needed after a corporate event.','low','assigned','mgr','button',2,7,null,null,null,96,0,null,null,null),
    (231,'hvac',438,501,'Kitchen ventilation not working','The extractor does not draw, the smell is all over the floor.','normal','returned','req','text',5,9,60,240,null,168,1,'After the repair the extractor does not draw again.',3000,null),
    (232,'elec',431,null,'Socket at reception not working','The coffee machine at the counter does not turn on.','normal','new','req','voice',1,10,null,null,null,72,0,null,null,null),
    (233,'plumb',433,null,'Leaking faucet in the restroom','The sink faucet does not close fully.','high','new','req','text',1,14,null,null,null,48,0,null,null,null),
    (234,'other',440,504,'Monthly lift maintenance','Schedule: inspect the atrium lifts monthly.','low','assigned','mgr','button',3,7,null,null,null,240,0,null,null,'monthly'),
    (235,'hvac',437,501,'Stuffy in meeting room “East River”','The supply ventilation does not turn on, stuffy after meetings.','normal','done','req','voice',8,10,40,50,120,72,0,null,null,null),
    (236,'clean',439,503,'No soap or paper in the restrooms','Supplies ran out on floor 4.','low','done','req','button',2,9,60,30,60,24,0,null,null,null),
    (237,'hvac',442,501,'Air curtain at the entrance not heating','Draft at the parking entrance, the air curtain does not turn on.','high','on_review','mgr','text',2,8,100,120,null,72,0,null,null,null),
    -- Дубай
    (238,'hvac',444,505,'AC not cooling: 29 °C in the open space','Staff move to meeting rooms to work.','critical','assigned','req','voice',1,7,null,null,null,4,0,null,null,null),
    (239,'hvac',443,505,'Condensate dripping in the lobby','Puddle at the reception desk, a sign has been placed.','normal','in_progress','req','text',1,12,60,null,null,72,0,null,null,null),
    (240,'elec',448,505,'EV charger not working','The charging station in the parking does not turn on.','low','assigned','req','button',3,9,null,null,null,120,0,null,null,null),
    (241,'hvac',446,505,'Monthly AC filter cleaning','Schedule: clean the filters of all units monthly.','low','assigned','mgr','button',2,6,null,null,null,240,0,null,null,'monthly'),
    -- Стамбул
    (242,'plumb',451,506,'Kitchen sink clogged','Water does not drain, the sink is full.','normal','in_progress','req','voice',1,10,45,null,null,48,0,null,null,null),
    (243,'clean',450,507,'Cleaning after an event','There was an event for 80 people in the evening.','low','done','mgr','button',4,18,60,180,60,24,0,null,null,null),
    (244,'elec',452,506,'Reception lights not working','Half of the lights above the counter are out.','high','assigned','req','text',2,8,null,null,null,12,0,null,null,null),
    (245,'clean',453,null,'Restroom cleaning after repairs','Construction dust and debris left after tile replacement.','normal','new','req','voice',1,15,null,null,null,48,0,null,null,null),
    -- Абиджан
    (246,'elec',457,508,'Generator does not start during a power cut','The grid was off this morning and the generator did not start.','critical','in_progress','mgr','voice',2,9,60,null,null,6,0,null,null,null),
    (247,'hvac',455,508,'Noisy AC in the meeting room','Loud hum, disturbs calls.','normal','assigned','req','text',1,10,null,null,null,72,0,null,null,null),
    (248,'plumb',454,508,'Leak in the hall after rain','Dripping from the ceiling at the entrance.','high','done','req','voice',6,8,90,120,60,24,0,null,null,null),
    -- Шэньчжэнь
    (249,'hvac',459,509,'AC not working in the open space','The units by the windows do not turn on from the remote.','high','in_progress','req','voice',1,9,30,null,null,48,0,null,null,null),
    (250,'clean',460,510,'Kitchen cleaning: smell complaint','Staff complain about the smell from the bins.','normal','done','req','text',3,11,60,60,120,24,0,null,null,null),
    (251,'elec',462,509,'UPS overheating in the server room','The UPS is alarming about high temperature.','high','on_review','mgr','text',2,8,60,90,null,72,0,null,null,null),
    -- Пекин
    (252,'hvac',465,509,'Dry air in the open space','Check the air handling unit humidifiers.','low','assigned','req','text',2,10,null,null,null,120,0,null,null,null),
    (253,'elec',464,509,'Projector not working in the meeting room','No power at the ceiling socket.','normal','assigned','req','text',1,9,null,null,null,72,0,null,null,null)
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
       ('de300000-0000-4000-8000-000000000010'::uuid, 'Floor 1'),
       ('de300000-0000-4000-8000-000000000010'::uuid, 'Floor 3'),
       ('de300000-0000-4000-8000-000000000402'::uuid, 'Floor 15')
     ) as d(o, n) where d.o = f.object_id and d.n = f.name);
  insert into public.floors (id, company_id, object_id, name, level, sort) values
    ('de300000-0000-4000-8000-000000000601'::uuid, c_company, 'de300000-0000-4000-8000-000000000010'::uuid, 'Floor 1', 1, 0),
    ('de300000-0000-4000-8000-000000000602'::uuid, c_company, 'de300000-0000-4000-8000-000000000010'::uuid, 'Floor 3', 3, 1),
    ('de300000-0000-4000-8000-000000000603'::uuid, c_company, 'de300000-0000-4000-8000-000000000402'::uuid, 'Floor 15', 15, 0)
  on conflict (id) do update set name = excluded.name, level = excluded.level, sort = excluded.sort;

  -- Новые помещения на схемах.
  insert into public.locations (id, object_id, name) values
    ('de300000-0000-4000-8000-000000000053'::uuid, 'de300000-0000-4000-8000-000000000010'::uuid, 'Café, floor 1'),
    ('de300000-0000-4000-8000-000000000052'::uuid, 'de300000-0000-4000-8000-000000000010'::uuid, 'Reception, floor 1'),
    ('de300000-0000-4000-8000-000000000054'::uuid, 'de300000-0000-4000-8000-000000000010'::uuid, 'Director''s office, floor 3'),
    ('de300000-0000-4000-8000-000000000055'::uuid, 'de300000-0000-4000-8000-000000000010'::uuid, 'Server room, floor 3'),
    ('de300000-0000-4000-8000-000000000056'::uuid, 'de300000-0000-4000-8000-000000000010'::uuid, 'Kitchen, floor 3'),
    ('de300000-0000-4000-8000-000000000466'::uuid, 'de300000-0000-4000-8000-000000000402'::uuid, 'Meeting room “Danube”, floor 15'),
    ('de300000-0000-4000-8000-000000000467'::uuid, 'de300000-0000-4000-8000-000000000402'::uuid, 'Restrooms, floor 15')
  on conflict (id) do update set name = excluded.name, object_id = excluded.object_id;
  -- Номера помещений (шаг 16): тот же номер у помещения, созданного руками, снимается.
  update public.locations l set code = null
    from (values
      ('de300000-0000-4000-8000-000000000022'::uuid, 'de300000-0000-4000-8000-000000000010'::uuid, '101'),
      ('de300000-0000-4000-8000-000000000053'::uuid, 'de300000-0000-4000-8000-000000000010'::uuid, '104'),
      ('de300000-0000-4000-8000-000000000052'::uuid, 'de300000-0000-4000-8000-000000000010'::uuid, '102'),
      ('de300000-0000-4000-8000-000000000024'::uuid, 'de300000-0000-4000-8000-000000000010'::uuid, '103'),
      ('de300000-0000-4000-8000-000000000021'::uuid, 'de300000-0000-4000-8000-000000000010'::uuid, '301'),
      ('de300000-0000-4000-8000-000000000054'::uuid, 'de300000-0000-4000-8000-000000000010'::uuid, '302'),
      ('de300000-0000-4000-8000-000000000055'::uuid, 'de300000-0000-4000-8000-000000000010'::uuid, '303'),
      ('de300000-0000-4000-8000-000000000056'::uuid, 'de300000-0000-4000-8000-000000000010'::uuid, '304'),
      ('de300000-0000-4000-8000-000000000424'::uuid, 'de300000-0000-4000-8000-000000000402'::uuid, '1501'),
      ('de300000-0000-4000-8000-000000000466'::uuid, 'de300000-0000-4000-8000-000000000402'::uuid, '1502'),
      ('de300000-0000-4000-8000-000000000425'::uuid, 'de300000-0000-4000-8000-000000000402'::uuid, '1503'),
      ('de300000-0000-4000-8000-000000000467'::uuid, 'de300000-0000-4000-8000-000000000402'::uuid, '1504')
    ) as v(id, o, code)
   where l.object_id = v.o and lower(btrim(l.code)) = lower(v.code) and l.id <> v.id
     and l.id not in ('de300000-0000-4000-8000-000000000022'::uuid, 'de300000-0000-4000-8000-000000000053'::uuid, 'de300000-0000-4000-8000-000000000052'::uuid, 'de300000-0000-4000-8000-000000000024'::uuid, 'de300000-0000-4000-8000-000000000021'::uuid, 'de300000-0000-4000-8000-000000000054'::uuid, 'de300000-0000-4000-8000-000000000055'::uuid, 'de300000-0000-4000-8000-000000000056'::uuid, 'de300000-0000-4000-8000-000000000424'::uuid, 'de300000-0000-4000-8000-000000000466'::uuid, 'de300000-0000-4000-8000-000000000425'::uuid, 'de300000-0000-4000-8000-000000000467'::uuid);
  -- Этаж, точка (центр комнаты на схеме, доли 0..1), номер и область помещения
  -- (прямоугольник комнаты — многоугольник из 4 точек, шаг 16).
  update public.locations l set floor_id = v.f, plan_x = v.x, plan_y = v.y, code = v.code, plan_shape = v.shape
    from (values
      ('de300000-0000-4000-8000-000000000022'::uuid, 'de300000-0000-4000-8000-000000000601'::uuid, 0.15::real, 0.2063::real, '101', '{"type":"polygon","points":[[0.05,0.075],[0.25,0.075],[0.25,0.3375],[0.05,0.3375]]}'::jsonb),
      ('de300000-0000-4000-8000-000000000053'::uuid, 'de300000-0000-4000-8000-000000000601'::uuid, 0.8::real, 0.2688::real, '104', '{"type":"polygon","points":[[0.65,0.075],[0.95,0.075],[0.95,0.4625],[0.65,0.4625]]}'::jsonb),
      ('de300000-0000-4000-8000-000000000052'::uuid, 'de300000-0000-4000-8000-000000000601'::uuid, 0.15::real, 0.5125::real, '102', '{"type":"polygon","points":[[0.05,0.3375],[0.25,0.3375],[0.25,0.6875],[0.05,0.6875]]}'::jsonb),
      ('de300000-0000-4000-8000-000000000024'::uuid, 'de300000-0000-4000-8000-000000000601'::uuid, 0.45::real, 0.5125::real, '103', '{"type":"polygon","points":[[0.25,0.3375],[0.65,0.3375],[0.65,0.6875],[0.25,0.6875]]}'::jsonb),
      ('de300000-0000-4000-8000-000000000021'::uuid, 'de300000-0000-4000-8000-000000000602'::uuid, 0.1833::real, 0.25::real, '301', '{"type":"polygon","points":[[0.05,0.075],[0.3167,0.075],[0.3167,0.425],[0.05,0.425]]}'::jsonb),
      ('de300000-0000-4000-8000-000000000054'::uuid, 'de300000-0000-4000-8000-000000000602'::uuid, 0.8167::real, 0.25::real, '302', '{"type":"polygon","points":[[0.6833,0.075],[0.95,0.075],[0.95,0.425],[0.6833,0.425]]}'::jsonb),
      ('de300000-0000-4000-8000-000000000055'::uuid, 'de300000-0000-4000-8000-000000000602'::uuid, 0.1583::real, 0.75::real, '303', '{"type":"polygon","points":[[0.05,0.575],[0.2667,0.575],[0.2667,0.925],[0.05,0.925]]}'::jsonb),
      ('de300000-0000-4000-8000-000000000056'::uuid, 'de300000-0000-4000-8000-000000000602'::uuid, 0.8417::real, 0.75::real, '304', '{"type":"polygon","points":[[0.7333,0.575],[0.95,0.575],[0.95,0.925],[0.7333,0.925]]}'::jsonb),
      ('de300000-0000-4000-8000-000000000424'::uuid, 'de300000-0000-4000-8000-000000000603'::uuid, 0.3417::real, 0.3563::real, '1501', '{"type":"polygon","points":[[0.05,0.075],[0.6333,0.075],[0.6333,0.6375],[0.05,0.6375]]}'::jsonb),
      ('de300000-0000-4000-8000-000000000466'::uuid, 'de300000-0000-4000-8000-000000000603'::uuid, 0.7917::real, 0.2375::real, '1502', '{"type":"polygon","points":[[0.6333,0.075],[0.95,0.075],[0.95,0.4],[0.6333,0.4]]}'::jsonb),
      ('de300000-0000-4000-8000-000000000425'::uuid, 'de300000-0000-4000-8000-000000000603'::uuid, 0.7917::real, 0.5188::real, '1503', '{"type":"polygon","points":[[0.6333,0.4],[0.95,0.4],[0.95,0.6375],[0.6333,0.6375]]}'::jsonb),
      ('de300000-0000-4000-8000-000000000467'::uuid, 'de300000-0000-4000-8000-000000000603'::uuid, 0.1667::real, 0.7813::real, '1504', '{"type":"polygon","points":[[0.05,0.6375],[0.2833,0.6375],[0.2833,0.925],[0.05,0.925]]}'::jsonb)
    ) as v(id, f, x, y, code, shape)
   where l.id = v.id;

  -- Оборудование: вид (meta.kind) — для значка на плане.
  insert into public.assets (id, location_id, name, category, inventory_no, meta, floor_id, plan_x, plan_y) values
    ('de300000-0000-4000-8000-000000000701'::uuid, 'de300000-0000-4000-8000-000000000022'::uuid, 'Electrical panel DB-1', 'equipment', 'EL-1-001', '{"kind":"panel","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000601'::uuid, 0.1083, 0.1625),
    ('de300000-0000-4000-8000-000000000702'::uuid, 'de300000-0000-4000-8000-000000000022'::uuid, 'Electrical room UPS 3 kVA', 'equipment', 'EL-1-002', '{"kind":"ups","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000601'::uuid, 0.1917, 0.25),
    ('de300000-0000-4000-8000-000000000703'::uuid, 'de300000-0000-4000-8000-000000000024'::uuid, 'Air conditioner, hall', 'equipment', 'HV-1-001', '{"kind":"ac","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000601'::uuid, 0.3167, 0.4),
    ('de300000-0000-4000-8000-000000000704'::uuid, 'de300000-0000-4000-8000-000000000024'::uuid, 'Hall light by the lifts', 'equipment', 'EL-1-010', '{"kind":"light","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000601'::uuid, 0.5833, 0.4),
    ('de300000-0000-4000-8000-000000000705'::uuid, 'de300000-0000-4000-8000-000000000024'::uuid, 'Smoke detector, hall', 'infra', 'FS-1-001', '{"kind":"smoke","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000601'::uuid, 0.45, 0.625),
    ('de300000-0000-4000-8000-000000000706'::uuid, 'de300000-0000-4000-8000-000000000052'::uuid, 'Fan coil, reception', 'equipment', 'HV-1-002', '{"kind":"fancoil","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000601'::uuid, 0.1, 0.425),
    ('de300000-0000-4000-8000-000000000707'::uuid, 'de300000-0000-4000-8000-000000000053'::uuid, 'Air conditioner, café', 'equipment', 'HV-1-003', '{"kind":"ac","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000601'::uuid, 0.8917, 0.15),
    ('de300000-0000-4000-8000-000000000708'::uuid, 'de300000-0000-4000-8000-000000000021'::uuid, 'Air conditioner AC-301', 'equipment', 'HV-3-001', '{"kind":"ac","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000602'::uuid, 0.1083, 0.1438),
    ('de300000-0000-4000-8000-000000000709'::uuid, 'de300000-0000-4000-8000-000000000021'::uuid, 'Smoke detector, meeting room', 'infra', 'FS-3-001', '{"kind":"smoke","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000602'::uuid, 0.2667, 0.35),
    ('de300000-0000-4000-8000-000000000710'::uuid, 'de300000-0000-4000-8000-000000000054'::uuid, 'Fan coil, director''s office', 'equipment', 'HV-3-002', '{"kind":"fancoil","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000602'::uuid, 0.8917, 0.15),
    ('de300000-0000-4000-8000-000000000711'::uuid, 'de300000-0000-4000-8000-000000000055'::uuid, 'Server rack R1', 'equipment', 'IT-3-001', '{"kind":"server","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000602'::uuid, 0.1083, 0.8125),
    ('de300000-0000-4000-8000-000000000712'::uuid, 'de300000-0000-4000-8000-000000000055'::uuid, 'Server room UPS 10 kVA', 'equipment', 'EL-3-001', '{"kind":"ups","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000602'::uuid, 0.2083, 0.8625),
    ('de300000-0000-4000-8000-000000000713'::uuid, 'de300000-0000-4000-8000-000000000055'::uuid, 'Air conditioner, server room', 'equipment', 'HV-3-003', '{"kind":"ac","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000602'::uuid, 0.1083, 0.65),
    ('de300000-0000-4000-8000-000000000714'::uuid, 'de300000-0000-4000-8000-000000000056'::uuid, 'Kitchen light', 'equipment', 'EL-3-010', '{"kind":"light","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000602'::uuid, 0.8417, 0.8125),
    ('de300000-0000-4000-8000-000000000736'::uuid, 'de300000-0000-4000-8000-000000000054'::uuid, 'Air conditioner AC-302', 'equipment', 'HV-3-004', '{"kind":"ac","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000602'::uuid, 0.7917, 0.15),
    ('de300000-0000-4000-8000-000000000737'::uuid, 'de300000-0000-4000-8000-000000000021'::uuid, 'Fire extinguisher, meeting room', 'infra', 'FS-3-002', '{"kind":"extinguisher","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000602'::uuid, 0.075, 0.375),
    ('de300000-0000-4000-8000-000000000715'::uuid, 'de300000-0000-4000-8000-000000000424'::uuid, 'Air conditioner, open space #1', 'equipment', 'SK-15-001', '{"kind":"ac","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000603'::uuid, 0.15, 0.15),
    ('de300000-0000-4000-8000-000000000716'::uuid, 'de300000-0000-4000-8000-000000000424'::uuid, 'Air conditioner, open space #2', 'equipment', 'SK-15-002', '{"kind":"ac","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000603'::uuid, 0.5333, 0.15),
    ('de300000-0000-4000-8000-000000000717'::uuid, 'de300000-0000-4000-8000-000000000466'::uuid, 'Fan coil, meeting room “Danube”', 'equipment', 'SK-15-003', '{"kind":"fancoil","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000603'::uuid, 0.8917, 0.15),
    ('de300000-0000-4000-8000-000000000718'::uuid, 'de300000-0000-4000-8000-000000000425'::uuid, 'Electrical panel DB-15', 'equipment', 'SK-15-010', '{"kind":"panel","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000603'::uuid, 0.9, 0.575),
    ('de300000-0000-4000-8000-000000000719'::uuid, 'de300000-0000-4000-8000-000000000467'::uuid, 'Leak sensor, restroom', 'infra', 'SK-15-020', '{"kind":"water","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000603'::uuid, 0.1, 0.8625),
    ('de300000-0000-4000-8000-000000000720'::uuid, 'de300000-0000-4000-8000-000000000424'::uuid, 'Smoke detector, open space', 'infra', 'SK-15-021', '{"kind":"smoke","demo":true}'::jsonb, 'de300000-0000-4000-8000-000000000603'::uuid, 0.3417, 0.55)
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
    (254,'hvac',55,713,31::int,'Condensate leaking from the server room AC','Puddle under the indoor unit, dripping next to the counter.','high','assigned','req','voice',1,8,null::int,6),
    (255,'hvac',54,710,31,'Fan coil in the director''s office not heating','The fan coil hums but the air is cold.','normal','assigned','req','text',1,9,null,72),
    (256,'elec',24,704,32,'Light flickering in the hall by the lifts','The light above the lifts has been flickering since morning.','normal','in_progress','req','text',1,10,60,48),
    (257,'plumb',467,719,null,'Leak sensor triggered in the restroom','The sensor under the sink is beeping, water on the floor.','high','new','mgr','button',1,7,null,24)
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

  -- 5e. Шаг 16: регионы и страны, реестр оборудования, планы ППР и задачи периодов.
  --     Регионы 901–905, у всех 20 объектов — код страны (ISO), город, регион.
  --     Оборудование 701–720 — система, производитель, модель, серийный номер,
  --     дата ввода; ещё 15 единиц 721–735 (Москва · Офис 1, Дубай · Офис 1,
  --     Абиджан) без точек на плане — для реестра. Планы ППР 801–808, задачи
  --     периодов 258–276; заявки 234 и 241 — задачи текущего периода планов
  --     803 и 802. Номер «305» — у «Open space» Demo Tower (для «в 305-й»).
  -- Регион с тем же названием, созданный руками, мешал бы (название уникально
  -- в компании без учёта регистра) — переименовываем его.
  update public.regions r set name = left(r.name, 50) || ' (старый)'
   where r.company_id = c_company
     and r.id::text !~ '^de300000-0000-4000-8000-00000000090[1-9]$'
     and public.norm_name(r.name) in ('europe', 'north america', 'middle east', 'africa', 'asia');
  insert into public.regions (id, company_id, name, sort)
  select ('de300000-0000-4000-8000-' || lpad(g.n::text, 12, '0'))::uuid, c_company, g.name, g.sort
  -- Шаг 33: рынки — Европа, Северная Америка, Ближний Восток (3 региона).
  from (values (901, 'Europe', 1), (902, 'North America', 2), (903, 'Middle East', 3)) as g(n, name, sort)
  on conflict (id) do update set company_id = excluded.company_id, name = excluded.name, sort = excluded.sort;

  update public.objects o
     set country_code = v.cc,
         city = btrim(split_part(o.address, ',', 1)),
         region_id = ('de300000-0000-4000-8000-' || lpad(v.rg::text, 12, '0'))::uuid
    from (values
      (10, 'RS', 901), (11, 'RS', 901), (12, 'RS', 901), (13, 'RS', 901), (14, 'RS', 901),
      (401, 'RS', 901), (402, 'RS', 901),
      (403, 'US', 902), (404, 'US', 902), (405, 'US', 902), (406, 'US', 902), (407, 'US', 902),
      (408, 'AE', 903), (409, 'AE', 903), (410, 'DE', 901), (411, 'DE', 901),
      (412, 'GB', 901),
      (413, 'AE', 903), (414, 'AE', 903), (415, 'SA', 903)
    ) as v(n, cc, rg)
   where o.id = ('de300000-0000-4000-8000-' || lpad(v.n::text, 12, '0'))::uuid
     and o.company_id = c_company;
  -- Шаг 33: регионов стало 3 — прежние «Африка» (904) и «Азия» (905) удаляются
  -- (их объекты выше перенесены в Europe и Middle East).
  delete from public.regions
   where company_id = c_company
     and id in ('de300000-0000-4000-8000-000000000904', 'de300000-0000-4000-8000-000000000905');

  -- Номер «305» — Open space Demo Tower (номера помещений на схемах — в 5d).
  update public.locations set code = null
   where object_id = c_object and lower(btrim(code)) = '305' and id <> c_loc_open;
  update public.locations set code = '305' where id = c_loc_open;

  -- Оборудование на схемах (701–720): система и паспортные данные.
  update public.assets a
     set layer_id = case v.layer when 'hvac' then v_layer_hvac when 'elec' then v_layer_elec
                                 when 'plumb' then v_layer_plumb when 'sec' then v_layer_sec
                                 else v_layer_other end,
         manufacturer = v.mf, model = v.model,
         serial_no = v.sn, installed_at = v_today::date - v.age_days
    from (values
      (701, 'elec',  'ABB',        'MNS iS',              'ABB-24-118733', 1460),
      (702, 'elec',  'APC',        'Smart-UPS SRT 3000',  'AS2207114392',  900),
      (703, 'hvac',  'Daikin',     'FTXM35R',             'DK-E0412233',   730),
      (704, 'elec',  'Philips',    'CoreLine RC132V',     'PH-77812',      400),
      (705, 'sec',   'Bosch',      'FAP-425-O',           'BS-1180034',    1100),
      (706, 'hvac',  'Carrier',    '42NH',                'CR-42N-5521',   1300),
      (707, 'hvac',  'Daikin',     'FTXM50R',             'DK-E0415501',   650),
      (708, 'hvac',  'Daikin',     'FTXM35R',             'DK-E0412290',   730),
      (709, 'sec',   'Bosch',      'FAP-425-O',           'BS-1180102',    1100),
      (710, 'hvac',  'Carrier',    '42NH',                'CR-42N-5577',   1300),
      (711, 'other', 'Dell',       'PowerEdge R750',      'DL-7X9K2M3',    500),
      (712, 'elec',  'APC',        'Smart-UPS SRT 10000', 'AS2301145007',  620),
      (713, 'hvac',  'Mitsubishi', 'PKA-M60KAL',          'ME-31005612',   880),
      (714, 'elec',  'Philips',    'CoreLine RC132V',     'PH-77890',      400),
      (715, 'hvac',  'Daikin',     'FXZQ32A',             'DK-V2201871',   300),
      (716, 'hvac',  'Daikin',     'FXZQ32A',             'DK-V2201872',   300),
      (717, 'hvac',  'Carrier',    '42NH',                'CR-42N-6120',   300),
      (718, 'elec',  'Schneider',  'Prisma P',            'SE-PP-449120',  300),
      (719, 'plumb', 'Neptun',     'ProW+ Wi-Fi',         'NP-0098123',    280),
      (720, 'sec',   'Bosch',      'FAP-425-O',           'BS-1180555',    300),
      -- Шаг 22 («Узнать по фото»): второй кондиционер этажа 3 и огнетушитель
      -- переговорной 301 — помещение решает, «какая именно это единица».
      (736, 'hvac',  'Daikin',     'FTXM35R',             'DK-E0412291',   730),
      (737, 'sec',   'Ogneborets', 'OP-4(z)',             'OB-4Z-220917',  500)
    ) as v(n, layer, mf, model, sn, age_days)
   where a.id = ('de300000-0000-4000-8000-' || lpad(v.n::text, 12, '0'))::uuid;

  -- Ещё 15 единиц для реестра (без точек на плане).
  insert into public.assets (id, location_id, name, category, inventory_no, meta, layer_id,
                             manufacturer, model, serial_no, installed_at)
  select ('de300000-0000-4000-8000-' || lpad(v.n::text, 12, '0'))::uuid,
         ('de300000-0000-4000-8000-' || lpad(v.loc::text, 12, '0'))::uuid,
         v.name, 'equipment', v.inv, jsonb_build_object('kind', v.kind, 'demo', true),
         case v.layer when 'hvac' then v_layer_hvac when 'elec' then v_layer_elec
                      when 'plumb' then v_layer_plumb when 'sec' then v_layer_sec
                      else v_layer_other end,
         v.mf, v.model, v.sn, v_today::date - v.age_days
  from (values
    -- Москва · Офис 1 (403): лобби 427, open space 428, серверная 429, переговорная 430
    (721, 427, 'Lift #1',                         'other', 'lift_panel', 'MSK1-LF-01', 'Otis',        'Gen2 Life',          'OT-RU-55012',  2100),
    (722, 427, 'Lift #2',                         'other', 'lift_panel', 'MSK1-LF-02', 'Otis',        'Gen2 Life',          'OT-RU-55013',  2100),
    (723, 428, 'Air conditioner, open space #1',       'hvac',  'ac',        'MSK1-KL-01', 'Daikin',      'FXZQ50A',            'DK-V2108811',  1200),
    (724, 428, 'Air conditioner, open space #2',       'hvac',  'ac',        'MSK1-KL-02', 'Daikin',      'FXZQ50A',            'DK-V2108812',  1200),
    (725, 429, 'Precision air conditioner',        'hvac',  'ac',        'MSK1-KL-03', 'Stulz',       'CyberAir 3PRO',      'ST-3P-20211',  950),
    (726, 429, 'Server room UPS 20 kVA',            'elec',  'ups',       'MSK1-EL-01', 'APC',         'Symmetra PX 20',     'AS1912000877', 1500),
    (727, 428, 'Electrical panel DB-32',                'elec',  'panel',     'MSK1-EL-02', 'ABB',         'MNS iS',             'ABB-19-554120', 2100),
    (728, 430, 'Smoke detector, meeting room',        'sec',   'smoke',     'MSK1-PB-01', 'Bosch',       'FAP-425-O',          'BS-1170221',   1400),
    -- Дубай · Офис 1 (408): лобби 443, open space 444, серверная 445
    (729, 443, 'Air conditioner, lobby',               'hvac',  'ac',        'DXB1-KL-01', 'Daikin',      'FXFQ100A',           'DK-AE-771203', 800),
    (730, 444, 'VRF outdoor unit',               'hvac',  'ac_outdoor', 'DXB1-KL-02', 'Daikin',      'VRV 5 RXYSA',        'DK-AE-771500', 800),
    (731, 444, 'Air conditioner, open space',          'hvac',  'ac',        'DXB1-KL-03', 'Gree',        'GMV6',               'GR-6611823',   600),
    (732, 445, 'Server room UPS',                   'elec',  'ups',       'DXB1-EL-01', 'APC',         'Smart-UPS SRT 6000', 'AS2105112240', 700),
    (733, 445, 'Precision air conditioner, server room', 'hvac', 'ac',      'DXB1-KL-04', 'Stulz',       'CyberRow',           'ST-CR-30992',  700),
    (734, 444, 'Smoke detector, open space',          'sec',   'smoke',     'DXB1-PB-01', 'Bosch',       'FAP-425-O',          'BS-1201882',   800),
    -- Абиджан (412): генераторная 457
    (735, 457, 'Diesel generator 250 kVA',        'elec',  'other',     'ABJ-EL-01',  'Caterpillar', 'C9 250 kVA',         'CAT-C9-66120', 1800)
  ) as v(n, loc, name, layer, kind, inv, mf, model, sn, age_days)
  on conflict (id) do update set
    location_id = excluded.location_id, name = excluded.name, category = excluded.category,
    inventory_no = excluded.inventory_no, meta = excluded.meta, layer_id = excluded.layer_id,
    manufacturer = excluded.manufacturer, model = excluded.model, serial_no = excluded.serial_no,
    installed_at = excluded.installed_at, floor_id = null, plan_x = null, plan_y = null;

  -- Планы ППР 801–808. Объект плана — там же, где старые регламентные заявки:
  -- 234 «ТО лифтов» стоит на Москва · Офис 5 (Сколково), 241 «Чистка фильтров» —
  -- на Дубай · Офис 2 (Marina), поэтому и планы 803 и 802 там.
  -- Начало — 1-е число месяца полгода назад (видна история периодов).
  update public.maintenance_plans p set title = left(p.title, 100) || ' (старый)'
   where p.company_id = c_company
     and p.id::text !~ '^de300000-0000-4000-8000-0000000008[0-4][0-9]$'
     and exists (select 1 from (values
       (403, 'AC maintenance'), (409, 'AC filter cleaning'), (407, 'Lift maintenance'),
       (10, 'Electrical panel inspection'), (410, 'Deep cleaning'), (412, 'Generator check'),
       (10, 'Server room UPS check'), (10, 'Smoke detector testing')) as d(o, t)
       where p.object_id = ('de300000-0000-4000-8000-' || lpad(d.o::text, 12, '0'))::uuid
         and public.norm_name(p.title) = public.norm_name(d.t));
  insert into public.maintenance_plans (id, company_id, object_id, location_id, asset_id, layer_id,
    title, description, period_kind, starts_on, checklist, requires_photo, priority, active, created_by,
    created_at, updated_at)
  select ('de300000-0000-4000-8000-' || lpad(v.n::text, 12, '0'))::uuid, c_company,
         ('de300000-0000-4000-8000-' || lpad(v.o::text, 12, '0'))::uuid,
         case when v.loc is not null then ('de300000-0000-4000-8000-' || lpad(v.loc::text, 12, '0'))::uuid end,
         case when v.a is not null then ('de300000-0000-4000-8000-' || lpad(v.a::text, 12, '0'))::uuid end,
         case v.layer when 'hvac' then v_layer_hvac when 'elec' then v_layer_elec
                      when 'clean' then v_layer_clean when 'sec' then v_layer_sec
                      else v_layer_other end,
         v.title, v.descr, v.kind, v_plan_start, v.checklist::jsonb, true, v.priority, true, v_manager,
         v_plan_start, v_plan_start
  from (values
    (801, 403, null::int, null::int, 'hvac',  'AC maintenance', 'Monthly maintenance of the office indoor units and precision air conditioners.', 'month', 'normal',
     '["Clean indoor unit filters", "Check drainage and drip trays", "Check refrigerant pressure", "Measure outlet temperature", "Record readings in the log"]'),
    (802, 409, null, null, 'hvac',  'AC filter cleaning', 'Clean the filters of all indoor units monthly.', 'month', 'low',
     '["Remove and wash filters", "Disinfect the heat exchanger", "Check cooling mode"]'),
    (803, 407, 440, null, 'other', 'Lift maintenance', 'Monthly inspection of the atrium lifts under contract.', 'month', 'normal',
     '["Check stops at each floor", "Check doors and sensors", "Check the intercom to dispatch", "Record in the lift log"]'),
    (804, 10,  22,  null, 'elec',  'Electrical panel inspection', 'Quarterly panel inspection: tighten contacts, thermal camera.', 'quarter', 'normal',
     '["Tighten terminal connections", "Take a thermal image of the panel", "Check breakers and RCDs", "Remove dust inside the panel"]'),
    (805, 410, null, null, 'clean', 'Deep cleaning', 'Monthly deep cleaning of the office.', 'month', 'low',
     '["Clean windows from inside", "Clean carpets", "Clean kitchen and fridges", "Disinfect restrooms"]'),
    (806, 412, 457, 735,  'elec',  'Generator check', 'Monthly diesel generator check: 30-minute run under load.', 'month', 'high',
     '["Check fuel and oil levels", "Check the battery", "Run under load for 30 minutes", "Record engine hours"]'),
    (807, 10,  55,  712,  'elec',  'Server room UPS check', 'Quarterly server room UPS check: batteries, switchover test.', 'quarter', 'normal',
     '["Check battery condition", "Test switchover to battery", "Check the UPS event log"]'),
    (808, 10,  null, null, 'sec',  'Smoke detector testing', 'Smoke detector testing with test aerosol every six months.', 'half_year', 'normal',
     '["Test each detector with test aerosol", "Check the signal at the security desk", "Replace faulty detectors", "Fill in the inspection report"]')
  ) as v(n, o, loc, a, layer, title, descr, kind, priority, checklist)
  on conflict (id) do update set
    company_id = excluded.company_id, object_id = excluded.object_id, location_id = excluded.location_id,
    asset_id = excluded.asset_id, layer_id = excluded.layer_id, title = excluded.title,
    description = excluded.description, period_kind = excluded.period_kind, period_days = null,
    starts_on = excluded.starts_on, checklist = excluded.checklist, requires_photo = excluded.requires_photo,
    priority = excluded.priority, active = true, created_by = excluded.created_by,
    created_at = excluded.created_at, updated_at = excluded.updated_at;

  -- Задачи периодов 258–276. per: 0 — текущий период, -1 — прошлый, -2 … — раньше.
  -- Прошлые периоды почти все приняты; 266 (генератор, сентябрь) и 270 (датчики
  -- дыма, I полугодие) не выполнены к концу периода — просрочены.
  -- Время: создана в начале периода; r — минут до начала работы, sub — работа,
  -- acc — до приёмки (у текущего периода — «сейчас минус 6 часов» и позже).
  insert into public.work_orders (
    id, company_id, object_id, location_id, asset_id, title, description, work_type, layer_id,
    priority, status, requires_photo, input_channel, created_by,
    assigned_contractor_id, assigned_by, due_at, time_spent_minutes,
    created_at, updated_at, started_at, submitted_at, accepted_at, accepted_by,
    return_reason, return_count, recurrence, plan_id, period_start, period_end)
  select
    ('de300000-0000-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
    c_company, p.object_id, coalesce(p.location_id, a.location_id), p.asset_id,
    p.title || ' — ' || public.period_label(p.period_kind, b.period_start, b.period_end, 'en'),
    p.description, ly.name, ly.id, p.priority, t.status, true, 'ppr', v_manager,
    case when t.c is not null then ('de300000-0000-4000-8000-' || lpad(t.c::text, 12, '0'))::uuid end,
    case when t.c is not null then 'rule' end,
    (b.period_end::timestamp + interval '23 hours 59 minutes') at time zone 'utc',
    t.sub,
    x.created,
    x.created + make_interval(mins => coalesce(t.r, 0) + coalesce(t.sub, 0) + coalesce(t.acc, 0)),
    case when t.r is not null then x.created + make_interval(mins => t.r) end,
    case when t.sub is not null then x.created + make_interval(mins => t.r + t.sub) end,
    case when t.status = 'done' then x.created + make_interval(mins => t.r + t.sub + t.acc) end,
    case when t.status = 'done' then v_manager end,
    null, 0,
    jsonb_build_object('kind', 'ppr', 'period', p.period_kind, 'days', null),
    p.id, b.period_start, b.period_end
  from (values
    (258, 801, -1, 501,  'done',        2,  60,  180,  120),
    (259, 801,  0, 501,  'in_progress', 1,  60,  null::int, null::int),
    (272, 801, -2, 501,  'done',        3,  90,  150,  200),
    (273, 801, -3, 501,  'done',        2,  45,  170,  90),
    (274, 801, -4, 501,  'done',        4,  60,  160,  300),
    (260, 802, -1, 505,  'done',        5,  120, 90,   60),
    (261, 803, -1, 504,  'done',        6,  30,  120,  60),
    (262, 804, -1, 32,   'done',        10, 300, 240,  600),
    (263, 804,  0, 32,   'assigned',    2,  null, null, null),
    (264, 805, -1, 507,  'done',        12, 60,  360,  120),
    (265, 805,  0, 507,  'on_review',   1,  30,  120,  null),
    (266, 806, -1, 508,  'in_progress', 20, 240, null, null),
    (267, 806,  0, 508,  'assigned',    1,  null, null, null),
    (275, 806, -2, 508,  'done',        3,  60,  45,   90),
    (276, 806, -3, 508,  'done',        2,  60,  50,   60),
    (268, 807, -1, 32,   'done',        15, 120, 90,   300),
    (269, 807,  0, 32,   'done',        1,  30,  60,   60),
    (270, 808, -1, null, 'new',         30, null, null, null),
    (271, 808,  0, null, 'new',         1,  null, null, null)
  ) as t(n, plan, per, c, status, day, r, sub, acc)
  join public.maintenance_plans p on p.id = ('de300000-0000-4000-8000-' || lpad(t.plan::text, 12, '0'))::uuid
  join public.layers ly on ly.id = p.layer_id
  left join public.assets a on a.id = p.asset_id
  cross join lateral (
    select * from public.period_bounds(
      p.period_kind, null, p.starts_on,
      (date_trunc('month', v_today)
         + case p.period_kind when 'month' then make_interval(months => t.per)
                              when 'quarter' then make_interval(months => 3 * t.per)
                              when 'half_year' then make_interval(months => 6 * t.per)
                              else make_interval(years => t.per) end)::date)
  ) b
  cross join lateral (
    select case when t.per = 0
                then least(b.period_start + make_interval(days => t.day - 1, hours => 6),
                           now() - interval '6 hours')
                else b.period_start + make_interval(days => t.day - 1, hours => 6) end as created
  ) x
  on conflict (id) do update set
    company_id = excluded.company_id, object_id = excluded.object_id,
    location_id = excluded.location_id, asset_id = excluded.asset_id,
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
    return_reason = null, return_count = 0,
    plan_id = excluded.plan_id, period_start = excluded.period_start, period_end = excluded.period_end;
  get diagnostics v_ppr_orders = row_count;
  v_orders := v_orders + v_ppr_orders;

  -- Старые регламентные заявки 234 и 241 — задачи текущего месяца планов 803 и 802.
  update public.work_orders w
     set plan_id = p.id, period_start = b.period_start, period_end = b.period_end,
         recurrence = jsonb_build_object('kind', 'ppr', 'period', p.period_kind, 'days', null),
         due_at = (b.period_end::timestamp + interval '23 hours 59 minutes') at time zone 'utc'
    from (values (234, 803), (241, 802)) as v(n, plan)
    join public.maintenance_plans p on p.id = ('de300000-0000-4000-8000-' || lpad(v.plan::text, 12, '0'))::uuid
    cross join lateral public.period_bounds(p.period_kind, null, p.starts_on, v_today::date) b
   where w.id = ('de300000-0000-4000-8000-' || lpad(v.n::text, 12, '0'))::uuid;

  -- Чек-листы задач ППР — из плана; у принятых все пункты отмечены.
  delete from public.checklist_items ci
   using public.work_orders w
   where ci.work_order_id = w.id and w.company_id = c_company and w.plan_id is not null
     and w.id::text ~ '^de300000-0000-4000-8000-000000000[12][0-9]{2}$';
  insert into public.checklist_items (work_order_id, text, is_done, done_at, done_by, created_at)
  select w.id, e.item #>> '{}', w.status in ('done', 'on_review'),
         case when w.status in ('done', 'on_review') then w.submitted_at end,
         case when w.status in ('done', 'on_review') then v_executor end,
         w.created_at + make_interval(secs => e.ord)
    from public.work_orders w
    join public.maintenance_plans p on p.id = w.plan_id
    cross join lateral jsonb_array_elements(p.checklist) with ordinality as e(item, ord)
   where w.company_id = c_company and w.plan_id is not null
     and w.id::text ~ '^de300000-0000-4000-8000-000000000[12][0-9]{2}$';

  -- 5f. Шаг 17 (миграция 0016, если применена): бригады подрядчика
  --     «Riyadh FM» (509) — «Пекин» (950) и «Шэньчжэнь» (951) с зонами
  --     «город Пекин» (970) и «город Шэньчжэнь» (971). Исполнителей у
  --     региональных подрядчиков в демо нет — состав бригад пустой (его
  --     можно задать в карточке подрядчика). Зоны менеджеров демо НЕ задаются:
  --     демо-менеджер видит всю компанию (на нём идёт показ).
  if to_regclass('public.crews') is not null then
    delete from public.crews
     where contractor_id = 'de300000-0000-4000-8000-000000000509'
       and id not in ('de300000-0000-4000-8000-000000000950', 'de300000-0000-4000-8000-000000000951')
       and public.norm_name(name) in ('riyadh', 'abu dhabi');
    insert into public.crews (id, company_id, contractor_id, name) values
      ('de300000-0000-4000-8000-000000000950', c_company, 'de300000-0000-4000-8000-000000000509', 'Riyadh'),
      ('de300000-0000-4000-8000-000000000951', c_company, 'de300000-0000-4000-8000-000000000509', 'Abu Dhabi')
    on conflict (id) do update set company_id = excluded.company_id,
      contractor_id = excluded.contractor_id, name = excluded.name;
    insert into public.crew_zones (id, company_id, crew_id, layer_ids, scope_kind, scope_ref) values
      ('de300000-0000-4000-8000-000000000970', c_company, 'de300000-0000-4000-8000-000000000950', '{}', 'city', 'Riyadh'),
      ('de300000-0000-4000-8000-000000000971', c_company, 'de300000-0000-4000-8000-000000000951', '{}', 'city', 'Abu Dhabi')
    on conflict (id) do update set company_id = excluded.company_id, crew_id = excluded.crew_id,
      layer_ids = excluded.layer_ids, scope_kind = excluded.scope_kind, scope_ref = excluded.scope_ref;
  else
    raise notice 'Миграция 0016 не применена — бригады шага 17 пропущены.';
  end if;

  -- 5g. Шаг 23 (миграция 0018, если применена): две заявки из Telegram-бота
  --     на «Demo Tower» — 277 от гостя по QR-коду объекта (уборщица, без
  --     аккаунта; автор — демо-заявитель, как у бота: created_by = автор
  --     ссылки) и 278 от сотрудника с привязанным аккаунтом. В reporter —
  --     только имя (без телефона и chat_id), как пишет бот.
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'work_orders' and column_name = 'reporter') then
    insert into public.work_orders (
      id, company_id, object_id, location_id, title, description, work_type, layer_id,
      priority, status, requires_photo, input_channel, created_by, reporter,
      assigned_contractor_id, assigned_by, due_at, created_at, updated_at, started_at)
    select
      ('de300000-0000-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
      c_company, c_object, ('de300000-0000-4000-8000-' || lpad(t.loc::text, 12, '0'))::uuid,
      t.title, t.descr, ly.name, ly.id, t.priority, t.status, ly.requires_photo, 'telegram',
      v_requester, t.reporter,
      ('de300000-0000-4000-8000-' || lpad(t.c::text, 12, '0'))::uuid, 'rule',
      v_today + make_interval(hours => t.h + 24), v_today + make_interval(hours => t.h),
      v_today + make_interval(hours => t.h, mins => coalesce(t.r, 0)),
      case when t.r is not null then v_today + make_interval(hours => t.h, mins => t.r) end
    from (values
      (277, 'hvac', 21, 31, 'Water dripping from the AC',
       'In meeting room 301 water is dripping from the AC onto the carpet. Photo: the AC with a leak under the unit.',
       'high', 'assigned', '{"name":"Emma W.","guest":true}'::jsonb, 9, null::int),
      (278, 'elec', 24, 32, 'Socket at the reception desk not working',
       'Hall: the socket left of the reception desk has no power, charging does not work.',
       'normal', 'in_progress', '{"name":"Anna D.","username":"anna_demo","guest":false}'::jsonb, 8, 40)
    ) as t(n, layer, loc, c, title, descr, priority, status, reporter, h, r)
    join public.layers ly on ly.id = case t.layer when 'hvac' then v_layer_hvac else v_layer_elec end
    on conflict (id) do update set
      company_id = excluded.company_id, object_id = excluded.object_id,
      location_id = excluded.location_id, asset_id = null,
      title = excluded.title, description = excluded.description,
      work_type = excluded.work_type, layer_id = excluded.layer_id,
      priority = excluded.priority, status = excluded.status, recurrence = null,
      requires_photo = excluded.requires_photo, input_channel = excluded.input_channel,
      created_by = excluded.created_by, reporter = excluded.reporter,
      assigned_contractor_id = excluded.assigned_contractor_id,
      assigned_executor_id = null, assigned_by = excluded.assigned_by,
      due_at = excluded.due_at, created_at = excluded.created_at,
      updated_at = excluded.updated_at, started_at = excluded.started_at,
      submitted_at = null, accepted_at = null, accepted_by = null,
      return_reason = null, return_count = 0;
    get diagnostics v_world_orders = row_count;
    v_orders := v_orders + v_world_orders;
  else
    raise notice 'Миграция 0018 не применена — заявки из Telegram (шаг 23) пропущены.';
  end if;

  -- 5h. Шаг 24 (миграция 0020, если применена): значки и цвета систем
  --     «Demo Properties» для раздела «Моя компания → Системы». Порядок — как в 0004.
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'layers' and column_name = 'icon') then
    update public.layers ly set icon = v.icon, color = v.color, archived_at = null
      from (values
        ('Климат', 'climate', '#0E8C80'),
        ('Электрика', 'electric', '#C27A0A'),
        ('Сантехника', 'plumbing', '#2F6FE0'),
        ('Клининг', 'cleaning', '#7A55C7'),
        ('Мебель', 'furniture', '#8A6A4F'),
        ('Системы безопасности', 'security', '#B42318'),
        ('Другое', 'other', '#5E6D7C')
      ) as v(name, icon, color)
     where ly.company_id = c_company and ly.name = v.name;
  else
    raise notice 'Миграция 0020 не применена — значки систем (шаг 24) пропущены.';
  end if;

  -- 5i. Шаг 25 — «Камера-помощник»: у «Кондиционера AC-301» (708, переговорная
  --     301) одна открытая заявка (277 из Telegram, если применена 0018),
  --     история принятых (101, 106, 108, 110 — последняя 110, «ClimaService»)
  --     и плановое ТО в этом месяце: план 809, задача 279 текущего периода
  --     (назначена, срок — конец месяца). 114 (на проверке) к единице не
  --     привязана — иначе открытых было бы две. У «AC-302» (736) заявок нет.
  --     Задача 279 не «принята» и не «на проверке» — в акт не попадает.
  update public.work_orders set asset_id = 'de300000-0000-4000-8000-000000000708'
   where id in ('de300000-0000-4000-8000-000000000101', 'de300000-0000-4000-8000-000000000106',
                'de300000-0000-4000-8000-000000000108', 'de300000-0000-4000-8000-000000000110',
                'de300000-0000-4000-8000-000000000277');
  update public.work_orders set asset_id = null
   where company_id = c_company and asset_id = 'de300000-0000-4000-8000-000000000736'
     and id::text like 'de300000-0000-4000-8000-000000000%';

  insert into public.maintenance_plans (id, company_id, object_id, location_id, asset_id, layer_id,
    title, description, period_kind, starts_on, checklist, requires_photo, priority, active, created_by,
    created_at, updated_at)
  values ('de300000-0000-4000-8000-000000000809', c_company, c_object, c_loc_meet,
    'de300000-0000-4000-8000-000000000708', v_layer_hvac,
    'AC-301 maintenance', 'Monthly maintenance of the meeting room 301 air conditioner.', 'month', v_plan_start,
    '["Clean filters", "Check drainage and drip tray", "Measure outlet temperature"]'::jsonb,
    true, 'normal', true, v_manager, v_plan_start, v_plan_start)
  on conflict (id) do update set
    company_id = excluded.company_id, object_id = excluded.object_id, location_id = excluded.location_id,
    asset_id = excluded.asset_id, layer_id = excluded.layer_id, title = excluded.title,
    description = excluded.description, period_kind = excluded.period_kind, period_days = null,
    starts_on = excluded.starts_on, checklist = excluded.checklist, requires_photo = true,
    priority = excluded.priority, active = true, created_by = excluded.created_by,
    created_at = excluded.created_at, updated_at = excluded.updated_at;

  -- Задача текущего периода: если менеджер уже входил в этом месяце,
  -- ppr_generate мог создать её со случайным id — та строка удаляется.
  delete from public.work_orders
   where plan_id = 'de300000-0000-4000-8000-000000000809'
     and id <> 'de300000-0000-4000-8000-000000000279';
  insert into public.work_orders (
    id, company_id, object_id, location_id, asset_id, title, description, work_type, layer_id,
    priority, status, requires_photo, input_channel, created_by,
    assigned_contractor_id, assigned_by, due_at, created_at, updated_at,
    return_count, recurrence, plan_id, period_start, period_end)
  select 'de300000-0000-4000-8000-000000000279', c_company, p.object_id, p.location_id, p.asset_id,
    p.title || ' — ' || public.period_label(p.period_kind, b.period_start, b.period_end, 'en'),
    p.description, ly.name, ly.id, p.priority, 'assigned', true, 'ppr', v_manager,
    'de300000-0000-4000-8000-000000000031', 'rule',
    (b.period_end::timestamp + interval '23 hours 59 minutes') at time zone 'utc',
    x.created, x.created, 0,
    jsonb_build_object('kind', 'ppr', 'period', p.period_kind, 'days', null),
    p.id, b.period_start, b.period_end
  from public.maintenance_plans p
  join public.layers ly on ly.id = p.layer_id
  cross join lateral public.period_bounds(p.period_kind, null, p.starts_on, v_today::date) b
  cross join lateral (
    select least(b.period_start + interval '6 hours', now() - interval '6 hours') as created
  ) x
  where p.id = 'de300000-0000-4000-8000-000000000809'
  on conflict (id) do update set
    company_id = excluded.company_id, object_id = excluded.object_id,
    location_id = excluded.location_id, asset_id = excluded.asset_id,
    title = excluded.title, description = excluded.description,
    work_type = excluded.work_type, layer_id = excluded.layer_id,
    priority = excluded.priority, status = excluded.status, recurrence = excluded.recurrence,
    requires_photo = true, requires_scan = false, input_channel = excluded.input_channel,
    created_by = excluded.created_by, assigned_contractor_id = excluded.assigned_contractor_id,
    assigned_executor_id = null, assigned_by = excluded.assigned_by, due_at = excluded.due_at,
    time_spent_minutes = null, created_at = excluded.created_at, updated_at = excluded.updated_at,
    started_at = null, submitted_at = null, accepted_at = null, accepted_by = null,
    return_reason = null, return_count = 0, plan_id = excluded.plan_id,
    period_start = excluded.period_start, period_end = excluded.period_end;
  get diagnostics v_world_orders = row_count;
  v_orders := v_orders + v_world_orders;
  -- Чек-лист задачи 279 — из плана 809, уже обновлённого выше (общий блок
  -- чек-листов ППР стоит раньше и при первом запуске видел прежний план).
  delete from public.checklist_items where work_order_id = 'de300000-0000-4000-8000-000000000279';
  insert into public.checklist_items (work_order_id, text, is_done, created_at)
  select 'de300000-0000-4000-8000-000000000279', e.item #>> '{}', false, now() + make_interval(secs => e.ord)
    from public.maintenance_plans p
    cross join lateral jsonb_array_elements(p.checklist) with ordinality as e(item, ord)
   where p.id = 'de300000-0000-4000-8000-000000000809';

  -- 5j. Шаг 25 (миграция 0018, если применена): включённые ссылки Telegram —
  --     QR объекта «Demo Tower» и ссылка компании «Demo Properties», с постоянными
  --     ДЕМО-токенами (плакат и QR готовы к показу без ручных действий).
  --     Токены открыты в репозитории: по ним гость может писать заявки только
  --     в «Demo Properties», с лимитами бота (5 в час с чата, 30 в сутки на ссылку).
  --     Другие включённые ссылки этого объекта и компании выключаются (одна
  --     включённая на объект / компанию). Отключить — в приложении («Отключить»).
  if to_regclass('public.report_links') is not null then
    update public.report_links set enabled = false, disabled_at = now()
     where company_id = c_company and enabled
       and (object_id = c_object or object_id is null)
       and id not in ('de300000-0000-4000-8000-000000000981', 'de300000-0000-4000-8000-000000000982');
    insert into public.report_links (id, company_id, object_id, token, enabled, created_by, created_at, disabled_at)
    values
      ('de300000-0000-4000-8000-000000000981', c_company, c_object, 'demo-bc-object-qr-2026', true, v_manager, now(), null),
      ('de300000-0000-4000-8000-000000000982', c_company, null, 'demo-bc-company-link-2026', true, v_manager, now(), null)
    on conflict (id) do update set
      company_id = excluded.company_id, object_id = excluded.object_id, token = excluded.token,
      enabled = true, disabled_at = null, created_by = excluded.created_by;
  else
    raise notice 'Миграция 0018 не применена — ссылки Telegram (шаг 25) пропущены.';
  end if;

  -- 6. Визиты
  -- Колонки: vn — номер (часть id); n — заявка; off — минут от начала работы
  -- до прихода; dur — минут на объекте; dist — метров до объекта
  -- (null = обычный визит, точка в 8–97 м от центра); mock — подмена GPS.
  -- Визит «ElectroPro» (316) — только если указан четвёртый пользователь.
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
    (316,206,0,50,3,true)          -- «ElectroPro»: подмена GPS
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

  -- 6b. Шаг 24 — «Оплата по доказательству»: доказательства в истории
  --     «ClimaService», чтобы в акте за текущий месяц были и доказанные
  --     заявки, и «без доказательства» с разными причинами:
  --       111, 112, 113, 214, 220 — фото «после» + визит в геозоне
  --         (111 ещё и выполненный чек-лист; 113 сдана позже срока);
  --       109 — нет фото «после»; 110 — визит вне геозоны;
  --       225 — нет отметки визита; 114 — не принята менеджером.
  --     Фото «после» — нарисованная картинка из сборки приложения
  --     (путь demo/ac_after.jpg = assets/demo_photos/ac_after.jpg), не файл
  --     в Storage и не фото реального объекта. id вложений …a1NN,
  --     пунктов чек-листа …b1NN, визиты 317–318.
  insert into public.attachments (id, work_order_id, kind, stage, storage_path, taken_at,
                                  lat, lng, uploaded_by, mock_location, created_at)
  select ('de300000-0000-4000-8000-00000000a' || lpad(v.n::text, 3, '0'))::uuid,
         w.id, 'photo', 'after', 'demo/ac_after.jpg',
         coalesce(w.submitted_at, w.updated_at) - interval '10 minutes',
         o.lat + 0.0001, o.lng, v_executor, false,
         coalesce(w.submitted_at, w.updated_at) - interval '10 minutes'
    from (values (111), (112), (113), (214), (220), (110), (225)) as v(n)
    join public.work_orders w on w.id = ('de300000-0000-4000-8000-' || lpad(v.n::text, 12, '0'))::uuid
    left join public.objects o on o.id = w.object_id
   where v_executor is not null
  on conflict (id) do update set
    work_order_id = excluded.work_order_id, stage = excluded.stage,
    storage_path = excluded.storage_path, taken_at = excluded.taken_at,
    lat = excluded.lat, lng = excluded.lng, uploaded_by = excluded.uploaded_by,
    created_at = excluded.created_at;

  -- Шаг 25: фото «до» у 111 (кадр питча «Заявка: фото «до/после»») —
  -- нарисованный кондиционер demo/ac_indoor.jpg, автор — заявитель.
  insert into public.attachments (id, work_order_id, kind, stage, storage_path, taken_at,
                                  lat, lng, uploaded_by, mock_location, created_at)
  select 'de300000-0000-4000-8000-00000000a201'::uuid, w.id, 'photo', 'before', 'demo/ac_indoor.jpg',
         w.created_at + interval '2 minutes', o.lat, o.lng + 0.0001, v_requester, false,
         w.created_at + interval '2 minutes'
    from public.work_orders w
    left join public.objects o on o.id = w.object_id
   where w.id = 'de300000-0000-4000-8000-000000000111' and v_requester is not null
  on conflict (id) do update set
    work_order_id = excluded.work_order_id, stage = excluded.stage,
    storage_path = excluded.storage_path, taken_at = excluded.taken_at,
    lat = excluded.lat, lng = excluded.lng, uploaded_by = excluded.uploaded_by,
    created_at = excluded.created_at;

  -- Шаг 26 (0023): источник демо-картинок — «demo», в акте они считаются
  -- доказательством, как раньше. Без 0023 столбца нет — пропускаем.
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'attachments'
                and column_name = 'source') then
    execute $q$update public.attachments set source = 'demo'
                where storage_path like 'demo/%' and source <> 'demo'$q$;
  end if;

  -- 6c. Шаг 27 (0024): «Требует решения менеджера» в акте «ClimaService»:
  --       112 — фото «после» снято без сети, часы телефона расходились
  --             с доверенным временем на 2 ч (time_trust = unverified);
  --       109 — фото «после» «из файла» (вложение …a109).
  --     Прежние решения менеджера по ним удаляются — показ начинается
  --     с жёлтой группы и кнопок. Без 0024 — пропускаем.
  if to_regclass('public.act_proof_decisions') is not null then
    insert into public.attachments (id, work_order_id, kind, stage, storage_path, taken_at,
                                    lat, lng, uploaded_by, mock_location, created_at)
    select 'de300000-0000-4000-8000-00000000a109'::uuid, w.id, 'photo', 'after', 'demo/ac_after.jpg',
           coalesce(w.submitted_at, w.updated_at) - interval '10 minutes', o.lat + 0.0001, o.lng,
           v_executor, false, coalesce(w.submitted_at, w.updated_at) - interval '10 minutes'
      from public.work_orders w
      left join public.objects o on o.id = w.object_id
     where w.id = 'de300000-0000-4000-8000-000000000109' and v_executor is not null
    on conflict (id) do update set work_order_id = excluded.work_order_id, stage = 'after',
      storage_path = excluded.storage_path, taken_at = excluded.taken_at;
    execute $q$
      update public.attachments set source = 'file', offline = false, time_trust = 'online',
             trusted_at = null, time_drift_s = null, synced_at = null, sha256 = null,
             sha256_ok = null, sync_note = null
       where id = 'de300000-0000-4000-8000-00000000a109';
      update public.attachments a set offline = true, time_trust = 'unverified',
             trusted_at = a.taken_at, time_drift_s = 7200,
             taken_at = a.taken_at + interval '2 hours',
             synced_at = a.created_at + interval '25 minutes',
             sha256 = repeat('5', 64), sha256_ok = true, sync_note = null
       where a.id = 'de300000-0000-4000-8000-00000000a112';
      delete from public.act_proof_decisions
       where work_order_id in ('de300000-0000-4000-8000-000000000109',
                               'de300000-0000-4000-8000-000000000112');
    $q$;
  else
    raise notice 'Миграция 0024 не применена — «Требует решения менеджера» (шаг 27) пропущено.';
  end if;

  insert into public.checklist_items (id, work_order_id, text, is_done, done_at, done_by, created_at)
  select ('de300000-0000-4000-8000-00000000b' || lpad(v.k::text, 3, '0'))::uuid, w.id, v.txt, true,
         coalesce(w.submitted_at, w.updated_at) - interval '20 minutes', v_executor, w.created_at
    from (values (101, 'Refrigerant pressure OK'), (102, 'Filters cleaned'),
                 (103, 'Drainage checked')) as v(k, txt)
    join public.work_orders w on w.id = 'de300000-0000-4000-8000-000000000111'::uuid
   where v_executor is not null
  on conflict (id) do update set work_order_id = excluded.work_order_id, text = excluded.text,
    is_done = true, done_at = excluded.done_at, done_by = excluded.done_by;

  -- Визиты в геозоне у 214 и 220 (объекты карты) — 317, 318.
  insert into public.visits (id, company_id, object_id, profile_id, contractor_id, work_order_id,
                             started_at, ended_at, source, lat, lng, accuracy_m, distance_m,
                             in_geofence, mock_location, created_at)
  select ('de300000-0000-4000-8000-' || lpad(v.vn::text, 12, '0'))::uuid,
         c_company, w.object_id, v_executor, w.assigned_contractor_id, w.id,
         coalesce(w.started_at, w.submitted_at - interval '1 hour'),
         coalesce(w.started_at, w.submitted_at - interval '1 hour') + interval '45 minutes',
         'geofence', o.lat + 0.0002, o.lng, 6, 22, true, false,
         coalesce(w.started_at, w.submitted_at - interval '1 hour')
    from (values (317, 214), (318, 220)) as v(vn, n)
    join public.work_orders w on w.id = ('de300000-0000-4000-8000-' || lpad(v.n::text, 12, '0'))::uuid
    join public.objects o on o.id = w.object_id
   where v_executor is not null and o.lat is not null
  on conflict (id) do update set
    object_id = excluded.object_id, work_order_id = excluded.work_order_id,
    started_at = excluded.started_at, ended_at = excluded.ended_at,
    lat = excluded.lat, lng = excluded.lng, distance_m = excluded.distance_m,
    in_geofence = true, mock_location = false, created_at = excluded.created_at;

  -- 113 сдана на день позже срока (в акте — «просрочена», но к оплате).
  update public.work_orders set due_at = submitted_at - interval '1 day'
   where id = 'de300000-0000-4000-8000-000000000113';

  -- Ставки (миграция 0021, если применена): за заявку и за визит ТО.
  if to_regclass('public.contractor_rates') is not null then
    insert into public.contractor_rates (contractor_id, company_id, rate_order, rate_visit, currency)
    -- Шаг 33: ставки в USD (за заявку / за визит планового ТО).
    values (c_contr_hvac, c_company, 60, 35, 'USD'),
           (c_contr_elec, c_company, 50, 30, 'USD'),
           ('de300000-0000-4000-8000-000000000501', c_company, 70, 40, 'USD')
    on conflict (contractor_id) do update set
      rate_order = excluded.rate_order, rate_visit = excluded.rate_visit, currency = excluded.currency;
  else
    raise notice 'Миграция 0021 не применена — ставки подрядчиков (шаг 24) пропущены.';
  end if;

  raise notice 'Готово: демо-история — заявок %, визитов %.%', v_orders, v_visits,
    case when v_elec_exec is null
         then ' Исполнитель «ElectroPro» не указан — визита с подменой GPS нет.' else '' end;
end $$;

set local session_replication_role = origin;

commit;
