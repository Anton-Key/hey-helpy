-- Проверки 0023 (шаг 26): кто что может делать с заявкой.
-- Работу начинает и сдаёт только исполнитель назначенного подрядчика,
-- принимает / возвращает менеджер с правом на заявку — не тот, кто сдал.
-- Фото «после», отметка чек-листа, визит — только исполнитель.
-- Пользователи fixture компании 1: 100 менеджер, 101 администратор,
-- 102 исполнитель «КлиматСервис» (031), 103 заявитель, 104 менеджер зоны
-- «Климат · объект 010», 105 менеджер зоны «Азия», 106 исполнитель
-- «ЭлектроПро» (032) в бригаде «Пекин», 107 исполнитель 032 без бригады.

select set_config('t.suite', 'order_roles', false);

-- Сменить статус под пользователем: true — получилось.
create or replace function t.try_status(p_uid uuid, p_order uuid, p_status text, p_reason text default null)
returns boolean language plpgsql as $$
declare n int;
begin
  perform t.login(p_uid);
  if p_reason is null then
    update public.work_orders set status = p_status where id = p_order;
  else
    update public.work_orders set status = p_status, return_reason = p_reason where id = p_order;
  end if;
  get diagnostics n = row_count;
  perform t.login(null);
  return n = 1;
exception when others then
  perform t.login(null);
  return false;
end $$;

-- Выполнить SQL под пользователем: true — без ошибки и хотя бы одна строка.
create or replace function t.try_sql(p_uid uuid, p_sql text)
returns boolean language plpgsql as $$
declare n int;
begin
  perform t.login(p_uid);
  execute p_sql;
  get diagnostics n = row_count;
  perform t.login(null);
  return n >= 1;
exception when others then
  perform t.login(null);
  return false;
end $$;

do $$
declare
  c1 uuid := t.id(1, 1);
  climate uuid := (select id from public.layers where company_id = t.id(1, 1) and name = 'Климат');
  elec    uuid := (select id from public.layers where company_id = t.id(1, 1) and name = 'Электрика');
  mgr uuid := t.id(1, 100); adm uuid := t.id(1, 101); ex uuid := t.id(1, 102); req uuid := t.id(1, 103);
  mgr_zone uuid := t.id(1, 104); mgr_asia uuid := t.id(1, 105);
  ex_crew uuid := t.id(1, 106); ex_free uuid := t.id(1, 107);
  w1 uuid := t.id(1, 381);  -- Климат, 031, автор — заявитель, нужно фото «после»
  w2 uuid := t.id(1, 382);  -- без подрядчика
  w3 uuid := t.id(1, 383);  -- менеджер — исполнитель «собственной службы»
  w4 uuid := t.id(1, 384);  -- Шэньчжэнь, ЭлектроПро (бригада «Пекин» — не её зона)
  w5 uuid := t.id(1, 385);  -- Пекин, ЭлектроПро
  w6 uuid := t.id(1, 386);  -- автор отменяет до начала работы
  w7 uuid := t.id(1, 387);  -- автор не отменяет после начала
  ci uuid := t.id(1, 388);  -- пункт чек-листа w1
  r record;
  ok boolean;
begin
  perform t.login(null);
  insert into public.work_orders(id, company_id, object_id, location_id, layer_id, title, status,
                                 created_by, assigned_contractor_id, requires_photo) values
    (w1, c1, t.id(1, 10), t.id(1, 21), climate, 'Шумит кондиционер', 'assigned', req, t.id(1, 31), true),
    (w2, c1, t.id(1, 10), t.id(1, 21), climate, 'Без подрядчика',    'new',      mgr, null,         false),
    (w3, c1, t.id(1, 10), t.id(1, 21), climate, 'Своя служба',       'assigned', mgr, t.id(1, 31), false),
    (w4, c1, t.id(1, 12), t.id(1, 23), elec,    'Шэньчжэнь',         'assigned', mgr, t.id(1, 32), false),
    (w5, c1, t.id(1, 11), t.id(1, 22), elec,    'Пекин',             'assigned', mgr, t.id(1, 32), false),
    (w6, c1, t.id(1, 10), t.id(1, 21), climate, 'Отменю сам',        'assigned', req, t.id(1, 31), false),
    (w7, c1, t.id(1, 10), t.id(1, 21), climate, 'Уже в работе',      'assigned', req, t.id(1, 31), false);
  -- правило слоя при вставке назначает подрядчика и включает фото — вернуть как задумано
  update public.work_orders set assigned_contractor_id = null, status = 'new' where id = w2;
  update public.work_orders set requires_photo = false where id in (w2, w3, w4, w5, w6, w7);
  insert into public.checklist_items(id, work_order_id, text) values (ci, w1, 'Очистить фильтр');

  -- ===== Начать работу =====
  perform t.check(not t.try_status(mgr, w1, 'in_progress'), 'менеджер не начинает работу за подрядчика');
  perform t.check(not t.try_status(adm, w1, 'in_progress'), 'администратор не начинает работу за подрядчика');
  perform t.check(not t.try_status(req, w1, 'in_progress'), 'автор-заявитель не начинает работу');
  perform t.check(not t.try_status(ex_free, w1, 'in_progress'), 'исполнитель чужого подрядчика не начинает');
  perform t.check(not t.try_status(ex, w2, 'in_progress'), 'без подрядчика исполнитель не начинает');
  perform t.check(not t.try_status(mgr, w2, 'in_progress'), 'без подрядчика менеджер не начинает');
  perform t.check(not t.try_status(ex_crew, w4, 'in_progress'), 'исполнитель бригады «Пекин» не начинает заявку в Шэньчжэне');
  perform t.check(t.try_status(ex_free, w4, 'in_progress'), 'исполнитель без бригады начинает заявку своего подрядчика (как 0016)');
  perform t.check(t.try_status(ex_crew, w5, 'in_progress'), 'исполнитель бригады начинает заявку в зоне бригады');
  perform t.check(t.try_status(ex, w1, 'in_progress'), 'исполнитель назначенного подрядчика начинает работу');
  perform t.check((select started_at is not null from public.work_orders where id = w1), 'started_at заполнен');

  -- ===== Фото, чек-лист, визит =====
  -- файлы уже загружены (0024, Н-2: строка фото — только к своему файлу)
  insert into storage.objects(bucket_id, name, owner, owner_id) values
    ('work-photos', c1 || '/' || w1 || '/m.jpg', mgr, mgr::text),
    ('work-photos', c1 || '/' || w1 || '/b.jpg', mgr, mgr::text),
    ('work-photos', c1 || '/' || w1 || '/e.jpg', ex, ex::text),
    ('work-photos', c1 || '/' || w1 || '/d.jpg', ex, ex::text);
  perform t.check(not t.try_sql(mgr, format(
    $q$insert into public.attachments(work_order_id, kind, stage, storage_path, uploaded_by, source)
       values (%L, 'photo', 'after', %L, %L, 'camera')$q$, w1, c1 || '/' || w1 || '/m.jpg', mgr)),
    'менеджер не прикладывает фото «после»');
  perform t.check(t.try_sql(mgr, format(
    $q$insert into public.attachments(work_order_id, kind, stage, storage_path, uploaded_by, source)
       values (%L, 'photo', 'before', %L, %L, 'file')$q$, w1, c1 || '/' || w1 || '/b.jpg', mgr)),
    'менеджер прикладывает фото «до»');
  perform t.check(not t.try_status(ex, w1, 'on_review'), 'без фото «после» на проверку нельзя');
  perform t.check(t.try_sql(ex, format(
    $q$insert into public.attachments(work_order_id, kind, stage, storage_path, uploaded_by, source, taken_at)
       values (%L, 'photo', 'after', %L, %L, 'camera', now())$q$, w1, c1 || '/' || w1 || '/e.jpg', ex)),
    'исполнитель прикладывает фото «после»');
  perform t.check((select source from public.attachments where storage_path = c1 || '/' || w1 || '/e.jpg') = 'camera',
    'источник «camera» сохранён');
  perform t.check(t.try_sql(ex, format(
    $q$insert into public.attachments(work_order_id, kind, stage, storage_path, uploaded_by, source)
       values (%L, 'photo', 'after', %L, %L, 'demo')$q$, w1, c1 || '/' || w1 || '/d.jpg', ex)),
    'исполнитель прикладывает фото с источником demo');
  perform t.check((select source from public.attachments where storage_path = c1 || '/' || w1 || '/d.jpg') = 'file',
    'источник «demo» от пользователя превращается в «file»');
  perform t.login(null);
  update public.attachments set source = 'file' where storage_path = c1 || '/' || w1 || '/e.jpg';
  perform t.check((select source from public.attachments where storage_path = c1 || '/' || w1 || '/e.jpg') = 'file',
    'обслуживание (без входа) может поправить источник');
  update public.attachments set source = 'camera' where storage_path = c1 || '/' || w1 || '/e.jpg';
  -- Пользователь задним числом источник не меняет (обновление в обход RLS
  -- триггер всё равно откатывает к прежнему значению).
  perform t.login(ex);
  perform set_config('request.jwt.claim.sub', ex::text, false);
  execute 'reset role';  -- как функция security definer с auth.uid() пользователя
  update public.attachments set source = 'camera' where storage_path = c1 || '/' || w1 || '/d.jpg';
  perform t.login(null);
  perform t.check((select source from public.attachments where storage_path = c1 || '/' || w1 || '/d.jpg') = 'file',
    'источник нельзя сменить на camera задним числом');

  perform t.check(not t.try_sql(mgr, format('update public.checklist_items set is_done = true where id = %L', ci)),
    'менеджер не отмечает пункт чек-листа');
  perform t.check(t.try_sql(ex, format('update public.checklist_items set is_done = true where id = %L', ci)),
    'исполнитель отмечает пункт чек-листа');
  perform t.check((select done_by = ex and done_at is not null from public.checklist_items where id = ci),
    'кто и когда отметил — пишет база');
  perform t.check(not t.try_sql(ex, format($q$update public.checklist_items set text = 'x' where id = %L$q$, ci)),
    'исполнитель не меняет текст пункта');
  perform t.check(t.try_sql(mgr, format($q$update public.checklist_items set text = 'Очистить фильтры' where id = %L$q$, ci)),
    'менеджер меняет текст пункта');
  perform t.check((select is_done and done_by = ex from public.checklist_items where id = ci),
    'правка текста менеджером не снимает отметку');

  perform t.check(not t.try_sql(mgr, format(
    $q$insert into public.visits(company_id, object_id, profile_id, work_order_id, lat, lng)
       values (%L, %L, %L, %L, 55.75, 37.61)$q$, c1, t.id(1, 10), mgr, w1)),
    'менеджер не отмечает визит');
  perform t.check(t.try_sql(ex, format(
    $q$insert into public.visits(company_id, object_id, profile_id, work_order_id, lat, lng)
       values (%L, %L, %L, %L, 55.75, 37.61)$q$, c1, t.id(1, 10), ex, w1)),
    'исполнитель отмечает визит');

  -- ===== На проверку =====
  perform t.check(not t.try_status(mgr, w1, 'on_review'), 'менеджер не отправляет на проверку');
  perform t.check(not t.try_status(req, w1, 'on_review'), 'автор не отправляет на проверку');
  perform t.check(t.try_status(ex, w1, 'on_review'), 'исполнитель отправляет на проверку');
  perform t.check((select submitted_by = ex and submitted_at is not null from public.work_orders where id = w1),
    'submitted_by — исполнитель');
  perform t.check(t.try_sql(mgr, format('update public.work_orders set submitted_by = %L where id = %L', mgr, w1)),
    'менеджер может сохранить заявку…');
  perform t.check((select submitted_by = ex from public.work_orders where id = w1),
    '…но submitted_by подменить нельзя');

  -- ===== Принять / вернуть =====
  perform t.check(not t.try_status(ex, w1, 'done'), 'исполнитель не принимает свою работу');
  perform t.check(not t.try_status(req, w1, 'done'), 'автор-заявитель не принимает (только менеджер)');
  perform t.check(not t.try_status(mgr_asia, w1, 'done'), 'менеджер чужой зоны не принимает');
  perform t.check(t.try_status(mgr_zone, w1, 'returned', 'Фильтр грязный'), 'менеджер своей зоны возвращает');
  perform t.check(t.try_status(ex, w1, 'in_progress'), 'исполнитель снова берёт в работу');
  perform t.check(t.try_status(ex, w1, 'on_review'), 'исполнитель снова сдаёт');
  perform t.check(t.try_status(adm, w1, 'done'), 'администратор принимает');
  perform t.check((select accepted_by = adm from public.work_orders where id = w1), 'accepted_by — администратор');

  -- ===== Своя служба: менеджер — исполнитель подрядчика =====
  insert into public.executors(id, profile_id, contractor_id) values (t.id(1, 389), mgr, t.id(1, 31));
  perform t.check(t.try_status(mgr, w3, 'in_progress'), 'менеджер-исполнитель своей службы начинает работу');
  perform t.check(t.try_status(mgr, w3, 'on_review'), 'менеджер-исполнитель сдаёт');
  perform t.check(not t.try_status(mgr, w3, 'done'), 'сдавший не принимает свою же работу');
  perform t.check(not t.try_status(mgr, w3, 'returned', 'нет'), 'сдавший не возвращает свою же работу');
  perform t.check(t.try_status(adm, w3, 'done'), 'другой менеджер (администратор) принимает');
  delete from public.executors where id = t.id(1, 389);

  -- ===== Отменить =====
  perform t.check(t.try_status(req, w6, 'cancelled'), 'автор отменяет, пока работа не начата');
  perform t.check(t.try_status(ex, w7, 'in_progress'), 'w7 в работе');
  perform t.check(not t.try_status(req, w7, 'cancelled'), 'автор не отменяет начатую работу');
  perform t.check(not t.try_status(ex, w7, 'cancelled'), 'исполнитель не отменяет');
  perform t.check(not t.try_sql(req, format($q$update public.work_orders set title = 'Другое' where id = %L$q$, w7)),
    'автор не правит текст начатой заявки');
  perform t.check(t.try_status(mgr, w7, 'cancelled'), 'менеджер отменяет начатую');

  -- ===== Новая заявка =====
  perform t.check(not t.try_sql(mgr, format(
    $q$insert into public.work_orders(company_id, object_id, title, status, created_by)
       values (%L, %L, 'Сразу выполнена', 'done', %L)$q$, c1, t.id(1, 10), mgr)),
    'менеджер не создаёт заявку сразу «Выполнена»');
  perform t.check(t.try_sql(mgr, format(
    $q$insert into public.work_orders(company_id, object_id, title, status, created_by, submitted_by)
       values (%L, %L, 'Обычная', 'new', %L, %L)$q$, c1, t.id(1, 10), mgr, mgr)),
    'менеджер создаёт новую заявку');
  perform t.check((select submitted_by is null from public.work_orders where title = 'Обычная' and company_id = c1),
    'submitted_by новой заявки — пусто');
  perform t.check(t.try_sql(req, format(
    $q$insert into public.work_orders(company_id, object_id, title, created_by)
       values (%L, %L, 'От заявителя', %L)$q$, c1, t.id(1, 10), req)),
    'заявитель создаёт заявку');

  -- ===== Обслуживание без входа (Refresh demo) — как раньше =====
  update public.work_orders set status = 'done' where id = w2;
  perform t.check((select status = 'done' from public.work_orders where id = w2), 'без auth.uid() статус меняется свободно');

  -- убрать за собой (tenant_isolation и другие тесты считают строки)
  delete from public.work_orders where id in (w1, w2, w3, w4, w5, w6, w7)
     or (company_id = c1 and title in ('Обычная', 'От заявителя'));
end $$;
