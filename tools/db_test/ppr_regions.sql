-- Проверки 0015: границы и подписи периодов, регионы без дублей, страна,
-- номера помещений, права на регионы и планы, ppr_generate.

select set_config('t.suite', 'ppr_regions', false);

do $$
declare
  b record;
  n int;
  n2 int;
  c1 uuid := t.id(1, 1);
  l1 uuid := (select id from public.layers where company_id = t.id(1, 1) and name = 'Климат');
begin
  -- Границы периодов
  b := public.period_bounds('month', null, '2026-01-01', '2026-10-10');
  perform t.check(b.period_start = '2026-10-01' and b.period_end = '2026-10-31', 'месяц: октябрь 2026');
  b := public.period_bounds('month', null, '2024-01-01', '2024-02-15');
  perform t.check(b.period_end = '2024-02-29', 'месяц: високосный февраль 2024 до 29-го');
  b := public.period_bounds('month', null, '2026-01-01', '2026-02-28');
  perform t.check(b.period_end = '2026-02-28', 'месяц: февраль 2026 до 28-го');
  b := public.period_bounds('month', null, '2026-01-01', '2026-12-31');
  perform t.check(b.period_start = '2026-12-01' and b.period_end = '2026-12-31', 'месяц: 31 декабря — декабрь');
  b := public.period_bounds('quarter', null, '2026-01-01', '2026-10-10');
  perform t.check(b.period_start = '2026-10-01' and b.period_end = '2026-12-31', 'квартал: IV кв. 2026');
  b := public.period_bounds('quarter', null, '2026-01-01', '2026-03-31');
  perform t.check(b.period_start = '2026-01-01' and b.period_end = '2026-03-31', 'квартал: 31 марта — I кв.');
  b := public.period_bounds('half_year', null, '2026-01-01', '2026-06-30');
  perform t.check(b.period_start = '2026-01-01' and b.period_end = '2026-06-30', 'полугодие: 30 июня — первое');
  b := public.period_bounds('half_year', null, '2026-01-01', '2026-07-01');
  perform t.check(b.period_start = '2026-07-01' and b.period_end = '2026-12-31', 'полугодие: 1 июля — второе');
  b := public.period_bounds('year', null, '2026-01-01', '2026-10-10');
  perform t.check(b.period_start = '2026-01-01' and b.period_end = '2026-12-31', 'год: 2026');
  b := public.period_bounds('days', 10, '2026-10-01', '2026-10-10');
  perform t.check(b.period_start = '2026-10-01' and b.period_end = '2026-10-10', 'N дней: 10 дней с 1 октября, 10-е — первый период');
  b := public.period_bounds('days', 10, '2026-10-01', '2026-10-11');
  perform t.check(b.period_start = '2026-10-11' and b.period_end = '2026-10-20', 'N дней: 11-е — второй период');
  b := public.period_bounds('days', 7, '2026-12-28', '2027-01-04');
  perform t.check(b.period_start = '2027-01-04' and b.period_end = '2027-01-10', 'N дней: через конец года');
  b := public.period_bounds('days', 10, '2026-10-01', '2026-09-30');
  perform t.check(b.period_start = '2026-09-21' and b.period_end = '2026-09-30', 'N дней: дата раньше начала — предыдущий шаг');

  -- Подписи
  perform t.check(public.period_label('month', '2026-10-01', '2026-10-31', 'ru') = 'октябрь 2026', 'подпись: октябрь 2026');
  perform t.check(public.period_label('month', '2026-10-01', '2026-10-31', 'en') = 'October 2026', 'подпись: October 2026');
  perform t.check(public.period_label('quarter', '2026-10-01', '2026-12-31', 'ru') = 'IV кв. 2026', 'подпись: IV кв. 2026');
  perform t.check(public.period_label('quarter', '2026-10-01', '2026-12-31', 'en') = 'Q4 2026', 'подпись: Q4 2026');
  perform t.check(public.period_label('half_year', '2026-07-01', '2026-12-31', 'ru') = 'II полугодие 2026', 'подпись: II полугодие 2026');
  perform t.check(public.period_label('year', '2026-01-01', '2026-12-31', 'ru') = '2026 год', 'подпись: 2026 год');
  perform t.check(public.period_label('days', '2026-10-01', '2026-10-10', 'ru') = '01.10–10.10.2026', 'подпись: N дней');

  -- Нормализация
  perform t.check(public.norm_name('  ЕвРоПа  ') = public.norm_name('европа'), 'норма: регистр и пробелы');
  perform t.check(public.norm_name('Ближний   Восток') = 'ближний восток', 'норма: пробелы внутри');
  perform t.check(public.norm_name('Ёлки') = public.norm_name('елки'), 'норма: ё = е');

  perform t.login(t.id(1, 100));   -- менеджер компании 1

  -- Регионы: дубль после нормализации не пропускается
  begin
    insert into public.regions(company_id, name) values (c1, ' европа ');
    perform t.check(false, 'регион « европа » при «Европа» — ПРОШЛО');
  exception when unique_violation then
    perform t.check(true, 'регион « европа » при «Европа» — отклонён (23505)');
  end;
  begin
    insert into public.regions(company_id, name) values (c1, 'ЕВРОПА');
    perform t.check(false, 'регион «ЕВРОПА» — ПРОШЛО');
  exception when unique_violation then
    perform t.check(true, 'регион «ЕВРОПА» — отклонён');
  end;
  insert into public.regions(company_id, name, sort) values (c1, 'Африка', 3);
  perform t.check(true, 'регион «Африка» создан');
  begin
    insert into public.regions(company_id, name) values (c1, '   ');
    perform t.check(false, 'пустой регион — ПРОШЛО');
  exception when check_violation then
    perform t.check(true, 'пустой регион — отклонён');
  end;

  -- Страна — только код ISO
  begin
    update public.objects set country_code = 'ru' where id = t.id(1, 10);
    perform t.check(false, 'страна «ru» — ПРОШЛО');
  exception when check_violation then
    perform t.check(true, 'страна «ru» (строчные) — отклонена');
  end;
  begin
    update public.objects set country_code = 'Р1' where id = t.id(1, 10);
    perform t.check(false, 'страна «Р1» — ПРОШЛО');
  exception when check_violation then
    perform t.check(true, 'страна «Р1» — отклонена');
  end;
  update public.objects set country_code = 'RS' where id = t.id(1, 10);
  perform t.check(true, 'страна «RS» — принята');

  -- Номер помещения уникален в объекте без учёта регистра
  insert into public.locations(object_id, name, code) values (t.id(1, 10), 'Кабинет', '306A');
  begin
    insert into public.locations(object_id, name, code) values (t.id(1, 10), 'Кабинет 2', '306a');
    perform t.check(false, 'номер «306a» при «306A» — ПРОШЛО');
  exception when unique_violation then
    perform t.check(true, 'номер «306a» при «306A» в том же объекте — отклонён');
  end;
  insert into public.locations(object_id, name, code) values (t.id(1, 11), 'Кабинет', '306A');
  perform t.check(true, 'номер «306A» в другом объекте — можно');

  -- ppr_generate: менеджер — создаёт, повторно — 0
  n := public.ppr_generate();
  n2 := public.ppr_generate();
  perform t.check(n2 = 0, format('ppr_generate: повторный вызов ничего не создаёт (%s, затем %s)', n, n2));
  select count(*) into n from public.work_orders
   where plan_id = t.id(1, 801) and period_start = date_trunc('month', now() at time zone 'utc')::date;
  perform t.check(n = 1, 'ppr_generate: одна задача текущего месяца по плану');
  select count(*) into n from public.checklist_items ci join public.work_orders w on w.id = ci.work_order_id
   where w.plan_id = t.id(1, 801) and w.period_start = date_trunc('month', now() at time zone 'utc')::date;
  perform t.check(n = 3, format('ppr_generate: чек-лист из плана (3 пункта, есть %s)', n));
  select count(*) into n from public.work_orders
   where plan_id = t.id(1, 801) and input_channel = 'ppr' and assigned_contractor_id = t.id(1, 31)
     and due_at = ((period_end::timestamp + interval '23 hours 59 minutes') at time zone 'utc');
  perform t.check(n >= 1, 'ppr_generate: подрядчик по слою и объекту, срок — конец периода 23:59 UTC');

  -- приостановленный план не генерирует
  update public.maintenance_plans set active = false where id = t.id(1, 802);
  delete from public.work_orders where plan_id = t.id(1, 802) and period_start >= date_trunc('quarter', now())::date;
  n := public.ppr_generate();
  perform t.check(n = 0, 'ppr_generate: приостановленный план не создаёт задач');
  update public.maintenance_plans set active = true where id = t.id(1, 802);
  n := public.ppr_generate();
  perform t.check(n = 1, 'ppr_generate: после возобновления — задача текущего квартала');

  -- план с периодом «days»
  insert into public.maintenance_plans(company_id, object_id, layer_id, title, period_kind, period_days, starts_on)
  values (c1, t.id(1, 10), l1, 'Обход', 'days', 7, current_date - 3);
  n := public.ppr_generate();
  perform t.check(n = 1, 'ppr_generate: план «каждые 7 дней»');
  begin
    insert into public.maintenance_plans(company_id, object_id, layer_id, title, period_kind)
    values (c1, t.id(1, 10), l1, 'Без дней', 'days');
    perform t.check(false, 'план days без period_days — ПРОШЛО');
  exception when check_violation then
    perform t.check(true, 'план days без period_days — отклонён');
  end;
  begin
    insert into public.maintenance_plans(company_id, object_id, layer_id, title)
    values (c1, t.id(1, 10), l1, ' то   кондиционеров ');
    perform t.check(false, 'дубль названия плана в объекте — ПРОШЛО');
  exception when unique_violation then
    perform t.check(true, 'дубль названия плана в объекте — отклонён');
  end;

  perform t.login(null);

  -- Исполнитель и заявитель: регионы и планы только читают; ppr_generate → 0
  perform t.login(t.id(1, 102));
  select count(*) into n from public.regions;
  perform t.check(n >= 2, 'исполнитель видит регионы своей компании');
  begin
    insert into public.regions(company_id, name) values (c1, 'Океания');
    perform t.check(false, 'исполнитель создал регион — ПРОШЛО');
  exception when others then
    perform t.check(sqlstate = '42501', 'исполнитель не создаёт регион');
  end;
  update public.maintenance_plans set title = 'взлом' where company_id = c1;
  get diagnostics n = row_count;
  perform t.check(n = 0, 'исполнитель не меняет планы');
  perform t.check(public.ppr_generate() = 0, 'исполнитель: ppr_generate ничего не создаёт');
  perform t.login(null);

  perform t.login(t.id(1, 103));
  update public.objects set region_id = null where company_id = c1;
  get diagnostics n = row_count;
  perform t.check(n = 0, 'заявитель не меняет регион объекта');
  perform t.check(public.ppr_generate() = 0, 'заявитель: ppr_generate ничего не создаёт');
  perform t.login(null);

  -- Удаление региона → у объектов пусто
  delete from public.regions where id = t.id(1, 902);
  select count(*) into n from public.objects where company_id = c1 and region_id is null;
  perform t.check(n >= 2, 'удаление региона — у объектов регион пуст');

  -- Одинаковые названия у разных компаний — можно
  select count(*) into n from public.regions where name = 'Европа';
  perform t.check(n = 2, 'регион «Европа» есть у обеих компаний');
end $$;
