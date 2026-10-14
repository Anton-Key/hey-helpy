-- Проверки 0021: ставки и акты подрядчикам — видят и формируют менеджеры
-- (с зоной — только подрядчиков своей зоны) и администратор; исполнители,
-- заявители и чужая компания — нет; номер АКТ-<год>-<NNN> по компании,
-- переформирование помечает прежний акт «заменён».

select set_config('t.suite', 'contractor_acts', false);

do $$
declare
  n int;
  ok boolean;
  c1 uuid := t.id(1, 1);
  r record;
  r2 record;
  st text;
begin
  -- Видимость.
  perform t.login(t.id(1, 100));
  select count(*) into n from public.contractor_acts;
  perform t.check(n = 1, 'менеджер видит акт своей компании (1), видно ' || n);
  select count(*) into n from public.contractor_rates;
  perform t.check(n = 1, 'менеджер видит ставки своей компании');
  select count(*) into n from storage.objects where bucket_id = 'contractor-acts';
  perform t.check(n = 1, 'менеджер видит PDF акта своей компании');
  foreach st in array array['102', '103', '106', '107'] loop
    perform t.login(t.id(1, st::int));
    perform t.check((select count(*) from public.contractor_acts) = 0, 'роль ' || st || ' не видит актов');
    perform t.check((select count(*) from public.contractor_rates) = 0, 'роль ' || st || ' не видит ставок');
    perform t.check((select count(*) from storage.objects where bucket_id = 'contractor-acts') = 0,
                    'роль ' || st || ' не видит PDF актов');
  end loop;
  -- Менеджер зоны «Азия» не видит акт подрядчика Москвы (031).
  perform t.login(t.id(1, 105));
  perform t.check((select count(*) from public.contractor_acts) = 0, 'менеджер другой зоны не видит акт');
  begin
    perform public.contractor_act_issue(t.id(1, 31), '2026-10-01', '2026-10-31', '{}', '[]');
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  perform t.check(ok, 'менеджер другой зоны не формирует акт');

  -- Формирование: номер по порядку, прежний акт за тот же период — «заменён».
  perform t.login(t.id(1, 104));
  select * into r from public.contractor_act_issue(t.id(1, 31), '2026-10-01', '2026-10-31',
                                                   '{"paid":3,"rejected":2}', '[{"id":"x"}]');
  perform t.check(r.number = 'АКТ-2026-002', 'номер акта по порядку: ' || coalesce(r.number, '—'));
  perform t.login(t.id(1, 100));
  select * into r2 from public.contractor_act_issue(t.id(1, 31), '2026-10-01', '2026-10-31', '{}', '[]');
  perform t.check(r2.number = 'АКТ-2026-003', 'переформированный акт — новый номер');
  select status into st from public.contractor_acts where id = r.id;
  perform t.check(st = 'replaced', 'прежний акт за период помечен «заменён»');
  perform t.check((select status from public.contractor_acts where id = t.id(1, 181)) = 'active',
                  'акт другого периода не тронут');

  -- Подрядчик чужой компании — отказ; кривой период — отказ.
  begin
    perform public.contractor_act_issue(t.id(2, 31), '2026-10-01', '2026-10-31', '{}', '[]');
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  perform t.check(ok, 'акт подрядчику чужой компании — отказ');
  begin
    perform public.contractor_act_issue(t.id(1, 31), '2026-10-31', '2026-10-01', '{}', '[]');
    ok := false;
  exception when others then ok := sqlstate = '22023';
  end;
  perform t.check(ok, 'период «до» раньше «с» — отказ');

  -- PDF: путь только папки своего акта.
  begin
    perform public.contractor_act_set_pdf(r2.id, format('%s/%s/act.pdf', t.id(2, 1), r2.id));
    ok := false;
  exception when others then ok := sqlstate = '22023';
  end;
  perform t.check(ok, 'путь PDF чужой компании — отказ');
  perform public.contractor_act_set_pdf(r2.id, format('%s/%s/AKT-2026-003.pdf', c1, r2.id));
  perform t.check((select pdf_path from public.contractor_acts where id = r2.id) like '%AKT-2026-003.pdf',
                  'путь PDF своего акта записан');
  begin
    insert into storage.objects(bucket_id, name, owner, owner_id)
    values ('contractor-acts', format('%s/%s/x.pdf', t.id(2, 1), t.id(2, 181)), t.id(1, 100), t.id(1, 100)::text);
    ok := false;
  exception when others then ok := true;
  end;
  perform t.check(ok, 'PDF в папку чужой компании — отказ');

  -- Прямо писать в таблицу актов нельзя никому из приложения.
  begin
    insert into public.contractor_acts(company_id, contractor_id, year, seq, number, period_start, period_end)
    values (c1, t.id(1, 31), 2026, 99, 'АКТ-2026-099', '2026-10-01', '2026-10-31');
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  perform t.check(ok, 'вставка в contractor_acts напрямую — отказ');
  update public.contractor_acts set status = 'active' where company_id = c1;
  get diagnostics n = row_count;
  perform t.check(n = 0, 'изменить акт напрямую нельзя');

  -- Исполнитель не формирует акт.
  perform t.login(t.id(1, 102));
  begin
    perform public.contractor_act_issue(t.id(1, 31), '2026-10-01', '2026-10-31', '{}', '[]');
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  perform t.check(ok, 'исполнитель не формирует акт');

  -- Ставки: менеджер без зон и админ меняют, менеджер с зоной — нет.
  perform t.login(t.id(1, 104));
  update public.contractor_rates set rate_order = 1 where contractor_id = t.id(1, 31);
  get diagnostics n = row_count;
  perform t.check(n = 0, 'менеджер с зоной не меняет ставки');
  perform t.login(t.id(1, 100));
  update public.contractor_rates set rate_order = 5000 where contractor_id = t.id(1, 31);
  get diagnostics n = row_count;
  perform t.check(n = 1, 'менеджер без зон меняет ставку');
  begin
    insert into public.contractor_rates(contractor_id, company_id, rate_order) values (t.id(2, 32), c1, 1);
    ok := false;
  exception when others then ok := true;
  end;
  perform t.check(ok, 'ставка подрядчику чужой компании — отказ');
  begin
    update public.contractor_rates set currency = 'rub' where contractor_id = t.id(1, 31);
    ok := false;
  exception when others then ok := sqlstate = '23514';
  end;
  perform t.check(ok, 'валюта — только код ISO');
  perform t.login(null);
end $$;
