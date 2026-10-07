-- =====================================================================
-- Hey Helpy · демо-история за последние 30 дней (НЕ миграция)
--
-- Что делает: добавляет в компанию «Демо БЦ» 25 заявок и 16 визитов,
-- чтобы на демо «История» и «Отчёты» были наполнены:
--   • «КлиматСервис» (Климат) — 15 заявок, всё в срок, приёмка почти всегда
--     с первого раза, 15 визитов при норме 4 в месяц;
--   • «ЭлектроПро» (Электрика) — 10 заявок, 2 просрочены, 3 возвращали
--     на доработку, визитов меньше нормы 2 в месяц (один — с подменой GPS).
--
-- Запускать в Supabase → SQL Editor ПОСЛЕ supabase/seed/demo.sql
-- и миграций 0001–0010. Подробно: docs/DEMO_SETUP.md, шаг 4.
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
-- УДАЛЕНИЕ ИСТОРИИ — блок 1 ниже, по умолчанию выключен.
-- =====================================================================

begin;

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
  -- ▼▼▼ ТЕ ЖЕ EMAIL, ЧТО В demo.sql ▼▼▼
  v_manager_email   text := 'manager@example.com';
  v_executor_email  text := 'executor@example.com';
  v_requester_email text := 'requester@example.com';
  -- Необязательно: четвёртый тестовый пользователь — исполнитель «ЭлектроПро».
  -- Если указать, он станет исполнителем «ЭлектроПро», и у подрядчика появится
  -- визит с подменой GPS. Если оставить пустым — у «ЭлектроПро» визитов не будет.
  v_elec_executor_email text := '';
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

  v_manager   uuid;
  v_executor  uuid;
  v_requester uuid;
  v_elec_exec uuid;
  v_layer_hvac uuid;
  v_layer_elec uuid;
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

  -- 3. Нормы визитов по договору: «КлиматСервис» — 4 в месяц, «ЭлектроПро» — 2
  update public.contractor_layers set visits_per_month = 4
   where contractor_id = c_contr_hvac and layer_id = v_layer_hvac and object_id = c_object;
  update public.contractor_layers set visits_per_month = 2
   where contractor_id = c_contr_elec and layer_id = v_layer_elec and object_id is null;
  if (select count(*) from public.contractor_layers
       where (contractor_id, layer_id) in ((c_contr_hvac, v_layer_hvac), (c_contr_elec, v_layer_elec))
         and visits_per_month is not null) < 2 then
    raise exception 'Нет закреплений подрядчиков за слоями. Сначала запустите supabase/seed/demo.sql';
  end if;

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
    c_company, c_object,
    case t.loc when 'meet' then c_loc_meet when 'elec' then c_loc_elec
               when 'open' then c_loc_open else c_loc_hall end,
    t.title, t.descr,
    case t.layer when 'hvac' then 'Климат' else 'Электрика' end,
    case t.layer when 'hvac' then v_layer_hvac else v_layer_elec end,
    t.priority, t.status,
    case t.layer when 'hvac' then v_photo_hvac else v_photo_elec end,
    t.channel,
    case t.author when 'mgr' then v_manager else v_requester end,
    case t.layer when 'hvac' then c_contr_hvac else c_contr_elec end,
    'rule',
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
    (210,'elec','hall','Замена светильника в холле','Светильник над входом треснул, нужна замена.','low','on_review','req','text',4,10,1500,1500,null,120,0,null,null)
  ) as t(n, layer, loc, title, descr, priority, status, author, channel,
         d, h, r, sub, acc, due_h, rc, reason, upd)
  cross join lateral (
    select v_today - make_interval(days => t.d) + make_interval(hours => t.h) as created
  ) x
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
