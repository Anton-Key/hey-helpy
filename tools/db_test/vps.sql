-- Проверки 0025, раздел 1 (шаг 28): VPS-скан помещения и метки оборудования.
-- Скан видят менеджеры своей зоны и исполнители подрядчиков объекта;
-- метки — те, кто видит оборудование; ставят и удаляют — менеджер с правом
-- на объект / администратор. Компания и объект — из помещения (база).

select set_config('t.suite', 'vps', false);

do $$
declare
  n int;
  ok boolean;
  err text;
  c1 uuid := t.id(1, 1);
  site21 uuid := t.id(1, 194);
  loc21 uuid := t.id(1, 21);      -- Переговорная, объект 010 (Москва)
  loc22 uuid := t.id(1, 22);      -- Серверная, объект 011 (Пекин)
  new_id uuid;
begin
  -- ===================== кто видит скан =====================
  perform t.login(t.id(1, 100));
  select count(*) into n from public.vps_sites;
  perform t.check(n = 1, 'менеджер видит скан своей компании (1), видно ' || n);

  perform t.login(t.id(1, 102));   -- исполнитель КлиматСервис, закреплён за 010
  select count(*) into n from public.vps_sites;
  perform t.check(n = 1, 'исполнитель подрядчика объекта видит скан');

  perform t.login(t.id(1, 103));   -- заявитель
  select count(*) into n from public.vps_sites;
  perform t.check(n = 0, 'заявитель не видит anchor payload, видно ' || n);

  perform t.login(t.id(1, 105));   -- менеджер с зоной «Азия»
  select count(*) into n from public.vps_sites;
  perform t.check(n = 0, 'менеджер другой зоны не видит скан, видно ' || n);

  perform t.login(t.id(1, 104));   -- менеджер «Климат + Сантехника · 010»
  select count(*) into n from public.vps_sites;
  perform t.check(n = 1, 'менеджер зоны объекта видит скан');

  perform t.login(t.id(1, 106));   -- исполнитель ЭлектроПро в бригаде «Пекин»
  select count(*) into n from public.vps_sites;
  perform t.check(n = 0, 'исполнитель бригады другого города не видит скан, видно ' || n);

  -- ===================== метки: кто ставит =====================
  perform t.login(t.id(1, 102));
  begin
    insert into public.vps_marks(company_id, site_id, asset_id, pos_x, pos_y, pos_z)
    values (c1, site21, t.id(1, 704), 0, 1, 0);
    ok := true;
  exception when others then ok := false;
  end;
  perform t.check(not ok, 'исполнитель не ставит метку');

  perform t.login(t.id(1, 104));   -- зона «Климат», а щит 704 — Электрика
  begin
    insert into public.vps_marks(company_id, site_id, asset_id, pos_x, pos_y, pos_z)
    values (c1, site21, t.id(1, 704), 0, 1, 0);
    ok := true;
  exception when others then ok := false;
  end;
  perform t.check(not ok, 'менеджер без системы оборудования в зоне не ставит метку');

  perform t.login(t.id(1, 100));
  begin
    insert into public.vps_marks(company_id, site_id, asset_id, pos_x, pos_y, pos_z, rot_x, rot_y, rot_z, rot_w)
    values (t.id(2, 1), site21, t.id(1, 704), 0.5, 1.4, -2, 0, 0.7071068, 0, 0.7071068)
    returning id into new_id;
    ok := true;
  exception when others then ok := false;
  end;
  perform t.check(ok, 'менеджер ставит метку щита');
  select count(*) into n from public.vps_marks where id = new_id and company_id = c1 and created_by = t.id(1, 100);
  perform t.check(n = 1, 'компанию и автора метки ставит база (подмена company_id не проходит)');
  -- (кондиционер 701 с меткой из fixture удаляет photo_identify.sql — считаем метку щита)
  select count(*) into n from public.vps_marks where asset_id = t.id(1, 704);
  perform t.check(n = 1, 'менеджер видит метку');
  perform t.login(t.id(1, 105));
  select count(*) into n from public.vps_marks where asset_id = t.id(1, 704);
  perform t.check(n = 0, 'менеджер другой зоны не видит метку, видно ' || n);
  perform t.login(t.id(1, 104));   -- зона «Климат»: щит (Электрика) не видит
  select count(*) into n from public.vps_marks where asset_id = t.id(1, 704);
  perform t.check(n = 0, 'менеджер без системы оборудования не видит его метку, видно ' || n);
  perform t.login(t.id(1, 100));

  -- повтор той же пары (скан, оборудование) — upsert приложения
  begin
    insert into public.vps_marks(site_id, asset_id, pos_x, pos_y, pos_z, company_id)
    values (site21, t.id(1, 704), 0.6, 1.4, -2, c1)
    on conflict (site_id, asset_id) do update set pos_x = excluded.pos_x;
    ok := true;
  exception when others then ok := false;
  end;
  select count(*) into n from public.vps_marks where site_id = site21 and asset_id = t.id(1, 704) and pos_x = 0.6;
  perform t.check(ok and n = 1, 'переставить метку (on conflict) — одна строка');

  begin
    insert into public.vps_marks(company_id, site_id, asset_id, pos_x, pos_y, pos_z)
    values (c1, site21, t.id(1, 702), 0, 1, 0);   -- ИБП стоит в Пекине
    ok := true;
  exception when others then
    ok := false; err := sqlerrm;
  end;
  perform t.check(not ok and err like '%vps_mark_bad_asset%', 'оборудование другого объекта — отказ: ' || coalesce(err, ''));

  begin
    insert into public.vps_marks(company_id, site_id, asset_id, pos_x, pos_y, pos_z, rot_w)
    values (c1, site21, t.id(1, 705), 0, 1, 0, 2);
    ok := true;
  exception when others then ok := false;
  end;
  perform t.check(not ok, 'поворот не единичный — отказ');

  begin
    insert into public.vps_marks(company_id, site_id, asset_id, pos_x, pos_y, pos_z)
    values (c1, site21, t.id(1, 705), 500, 1, 0);
    ok := true;
  exception when others then ok := false;
  end;
  perform t.check(not ok, 'метка дальше 50 м от якоря — отказ');

  -- ===================== скан: создать, второй, перенести =====================
  begin
    insert into public.vps_sites(company_id, object_id, location_id, anchor_payload)
    values (c1, t.id(1, 12), loc22, '  CjIKMAo-payload-22  ')
    returning id into new_id;
    ok := true;
  exception when others then ok := false;
  end;
  perform t.check(ok, 'менеджер добавляет скан помещения');
  select count(*) into n from public.vps_sites
   where id = new_id and object_id = t.id(1, 11) and anchor_payload = 'CjIKMAo-payload-22';
  perform t.check(n = 1, 'объект скана — из помещения (не от приложения), payload без пробелов');

  begin
    insert into public.vps_sites(company_id, object_id, location_id, anchor_payload)
    values (c1, t.id(1, 10), loc21, 'another-payload');
    ok := true;
  exception when others then ok := false;
  end;
  perform t.check(not ok, 'второй скан того же помещения — отказ');

  begin
    update public.vps_sites set location_id = loc22 where id = site21;
    ok := true;
  exception when others then
    ok := false; err := sqlerrm;
  end;
  perform t.check(not ok, 'перенести скан в другое помещение нельзя');

  perform t.login(t.id(1, 102));
  update public.vps_sites set anchor_payload = 'hacked-payload' where id = site21;
  get diagnostics n = row_count;
  perform t.check(n = 0, 'исполнитель не меняет payload');
  delete from public.vps_marks where site_id = site21;
  get diagnostics n = row_count;
  perform t.check(n = 0, 'исполнитель не удаляет метки');

  perform t.login(t.id(1, 105));
  begin
    insert into public.vps_sites(company_id, object_id, location_id, anchor_payload)
    values (c1, t.id(1, 10), t.id(1, 24), 'zone-payload');
    ok := true;
  exception when others then ok := false;
  end;
  perform t.check(not ok, 'менеджер другой зоны не добавляет скан объекта 010');

  -- Удаление скана удаляет метки (каскад)
  perform t.login(t.id(1, 101));
  delete from public.vps_sites where id = new_id;
  get diagnostics n = row_count;
  perform t.check(n = 1, 'администратор удаляет скан');

  perform t.login(null);
end $$;
