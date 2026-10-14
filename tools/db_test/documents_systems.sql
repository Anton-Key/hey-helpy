-- Проверки 0019 (документы заявки, хранилище order-files) и 0020 (системы:
-- видимость по зоне менеджера, изменение — только администратор, удаление —
-- только неиспользуемой системы).

select set_config('t.suite', 'documents_systems', false);

do $$
declare
  n int;
  ok boolean;
  c1 uuid := t.id(1, 1);
  c2 uuid := t.id(2, 1);
  wo101 uuid := t.id(1, 101);   -- в работе, подрядчик 031 (исполнитель 102)
  wo102 uuid := t.id(1, 102);   -- новая, автор — заявитель 103
  path_ok text;
  lid uuid;
begin
  -- ===================== 0019: документы =====================
  -- Видят: менеджер, исполнитель назначенного подрядчика.
  perform t.login(t.id(1, 100));
  select count(*) into n from public.attachments where kind = 'document';
  perform t.check(n = 1, 'менеджер видит документ своей компании (1), видно ' || n);
  select count(*) into n from storage.objects where bucket_id = 'order-files';
  perform t.check(n = 1, 'менеджер видит файл order-files своей компании (1), видно ' || n);

  perform t.login(t.id(1, 102));
  select count(*) into n from storage.objects where bucket_id = 'order-files';
  perform t.check(n = 1, 'исполнитель назначенного подрядчика видит файл');

  -- Исполнитель чужого подрядчика (107, ЭлектроПро) — не видит.
  perform t.login(t.id(1, 107));
  select count(*) into n from public.attachments where kind = 'document';
  perform t.check(n = 0, 'исполнитель чужого подрядчика не видит документ, видно ' || n);
  select count(*) into n from storage.objects where bucket_id = 'order-files';
  perform t.check(n = 0, 'исполнитель чужого подрядчика не видит файл, видно ' || n);

  -- Менеджер с зоной «Климат + Сантехника · Офис 1» видит документ заявки
  -- 101 (Климат, Офис 1); менеджер с зоной «Азия» — нет.
  perform t.login(t.id(1, 104));
  select count(*) into n from public.attachments where kind = 'document';
  perform t.check(n = 1, 'менеджер с зоной заявки видит документ');
  perform t.login(t.id(1, 105));
  select count(*) into n from storage.objects where bucket_id = 'order-files';
  perform t.check(n = 0, 'менеджер другой зоны не видит файл, видно ' || n);

  -- Заявитель 103 прикладывает документ к своей заявке 102.
  path_ok := format('%s/%s/%s-schema.pdf', c1, wo102, gen_random_uuid());
  perform t.login(t.id(1, 103));
  begin
    insert into storage.objects(bucket_id, name, owner, owner_id)
    values ('order-files', path_ok, t.id(1, 103), t.id(1, 103)::text);
    insert into public.attachments(work_order_id, kind, storage_path, uploaded_by, file_name, mime, size_bytes)
    values (wo102, 'document', path_ok, t.id(1, 103), 'Схема (копия).pdf', 'application/pdf', 2048);
    ok := true;
  exception when others then ok := false;
  end;
  perform t.check(ok, 'автор прикладывает документ к своей заявке');

  -- Путь чужой компании — отказ (и файл, и запись).
  begin
    insert into storage.objects(bucket_id, name, owner, owner_id)
    values ('order-files', format('%s/%s/x-a.pdf', c2, t.id(2, 102)), t.id(1, 103), t.id(1, 103)::text);
    ok := false;
  exception when others then ok := true;
  end;
  perform t.check(ok, 'файл в папку чужой компании — отказ');
  begin
    insert into public.attachments(work_order_id, kind, storage_path, uploaded_by, file_name, mime, size_bytes)
    values (wo102, 'document', format('%s/%s/x-a.pdf', c2, t.id(2, 102)), t.id(1, 103), 'a.pdf', 'application/pdf', 1);
    ok := false;
  exception when others then ok := true;
  end;
  perform t.check(ok, 'запись документа с путём чужой компании — отказ');
  begin
    insert into public.attachments(work_order_id, kind, storage_path, uploaded_by, file_name, mime, size_bytes)
    values (t.id(2, 102), 'document', format('%s/%s/x-a.pdf', c2, t.id(2, 102)), t.id(1, 103), 'a.pdf', 'application/pdf', 1);
    ok := false;
  exception when others then ok := true;
  end;
  perform t.check(ok, 'документ к заявке чужой компании — отказ');

  -- Заявитель не прикладывает к чужой заявке (101 создал менеджер).
  begin
    insert into public.attachments(work_order_id, kind, storage_path, uploaded_by, file_name, mime, size_bytes)
    values (wo101, 'document', format('%s/%s/x-a.pdf', c1, wo101), t.id(1, 103), 'a.pdf', 'application/pdf', 1);
    ok := false;
  exception when others then ok := true;
  end;
  perform t.check(ok, 'заявитель не прикладывает документ к чужой заявке');

  -- Исполнитель чужого подрядчика — отказ.
  perform t.login(t.id(1, 107));
  begin
    insert into storage.objects(bucket_id, name, owner, owner_id)
    values ('order-files', format('%s/%s/x-b.pdf', c1, wo101), t.id(1, 107), t.id(1, 107)::text);
    ok := false;
  exception when others then ok := true;
  end;
  perform t.check(ok, 'исполнитель чужого подрядчика не загружает файл');

  -- Больше 20 МБ и без имени — отказ (проверка в таблице).
  perform t.login(t.id(1, 100));
  begin
    insert into public.attachments(work_order_id, kind, storage_path, uploaded_by, file_name, mime, size_bytes)
    values (wo101, 'document', format('%s/%s/x-big.pdf', c1, wo101), t.id(1, 100), 'big.pdf', 'application/pdf', 20971521);
    ok := false;
  exception when others then ok := sqlstate = '23514';
  end;
  perform t.check(ok, 'документ больше 20 МБ — отказ');
  begin
    insert into public.attachments(work_order_id, kind, storage_path, uploaded_by, file_name, mime, size_bytes)
    values (wo101, 'document', format('%s/%s/x-n.pdf', c1, wo101), t.id(1, 100), '  ', 'application/pdf', 5);
    ok := false;
  exception when others then ok := sqlstate = '23514';
  end;
  perform t.check(ok, 'документ без имени — отказ');

  -- Удаление: исполнитель чужого подрядчика — 0 строк; загрузивший — да;
  -- менеджер — чужой документ тоже.
  perform t.login(t.id(1, 107));
  delete from public.attachments where kind = 'document';
  get diagnostics n = row_count;
  perform t.check(n = 0, 'исполнитель чужого подрядчика не удаляет документ');
  perform t.login(t.id(1, 103));
  delete from public.attachments where storage_path = path_ok;
  get diagnostics n = row_count;
  perform t.check(n = 1, 'загрузивший удаляет свой документ');
  delete from storage.objects where bucket_id = 'order-files' and name = path_ok;
  get diagnostics n = row_count;
  perform t.check(n = 1, 'загрузивший удаляет свой файл');
  perform t.login(t.id(1, 100));
  delete from storage.objects where bucket_id = 'order-files' and name like c2::text || '/%';
  get diagnostics n = row_count;
  perform t.check(n = 0, 'менеджер не удаляет файл чужой компании');
  -- Фото — по-старому: документ не мешает фото «после» на заявке в работе.
  perform t.login(null);

  -- ===================== 0020: системы =====================
  -- Видимость: менеджер без зон, администратор, исполнитель, заявитель — все
  -- системы компании; менеджер с зоной «Климат + Сантехника» — только две;
  -- менеджер с зоной «все системы · Азия» — все.
  select count(*) into n from public.layers where company_id = c1;
  perform t.login(t.id(1, 100));
  perform t.check((select count(*) from public.layers) = n, 'менеджер без зон видит все системы');
  perform t.login(t.id(1, 101));
  perform t.check((select count(*) from public.layers) = n, 'администратор видит все системы');
  perform t.login(t.id(1, 102));
  perform t.check((select count(*) from public.layers) = n, 'исполнитель видит все системы (названия в заявках)');
  perform t.login(t.id(1, 106));
  perform t.check((select count(*) from public.layers) = n, 'исполнитель бригады видит все системы');
  perform t.login(t.id(1, 103));
  perform t.check((select count(*) from public.layers) = n, 'заявитель видит все системы');
  perform t.login(t.id(1, 104));
  select count(*) into n from public.layers;
  perform t.check(n = 2, 'менеджер с зоной «Климат + Сантехника» видит 2 системы, видно ' || n);
  perform t.check(not exists (select 1 from public.layers where name = 'Электрика'),
                  'менеджер с зоной не видит «Электрику»');
  perform t.login(t.id(1, 105));
  perform t.check((select count(*) from public.layers) = (select count(*) from public.layers l where l.company_id = c1),
                  'менеджер с зоной «все системы» видит все');
  perform t.check((select count(*) from public.layers where company_id = c2) = 0, 'системы чужой компании не видны');

  -- Менеджер (не администратор) не создаёт и не меняет системы.
  perform t.login(t.id(1, 100));
  begin
    insert into public.layers(company_id, name, color) values (c1, 'Лифты', '#2F6FE0');
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  perform t.check(ok, 'менеджер не создаёт систему');
  update public.layers set color = '#000000' where company_id = c1;
  get diagnostics n = row_count;
  perform t.check(n = 0, 'менеджер не меняет системы');
  delete from public.layers where company_id = c1;
  get diagnostics n = row_count;
  perform t.check(n = 0, 'менеджер не удаляет системы');

  -- Администратор: создаёт, меняет, архивирует, удаляет неиспользуемую.
  perform t.login(t.id(1, 101));
  insert into public.layers(company_id, name, name_i18n, color, icon, sort)
  values (c1, 'Лифты', '{"ru":"Лифты","en":"Lifts"}', '#3B4A6B', 'lift', 70) returning id into lid;
  perform t.check(lid is not null, 'администратор создаёт систему');
  update public.layers set archived_at = now(), color = '#0E8C80' where id = lid;
  get diagnostics n = row_count;
  perform t.check(n = 1, 'администратор архивирует и меняет цвет');
  begin
    update public.layers set color = 'red' where id = lid;
    ok := false;
  exception when others then ok := sqlstate = '23514';
  end;
  perform t.check(ok, 'цвет только #RRGGBB');
  begin
    update public.layers set icon = 'Bad Icon!' where id = lid;
    ok := false;
  exception when others then ok := sqlstate = '23514';
  end;
  perform t.check(ok, 'значок — только код');
  begin
    delete from public.layers where company_id = c1 and name = 'Климат';
    ok := false;
  exception when others then ok := sqlerrm = 'system_in_use';
  end;
  perform t.check(ok, 'используемую систему удалить нельзя (system_in_use)');
  delete from public.layers where id = lid;
  get diagnostics n = row_count;
  perform t.check(n = 1, 'неиспользуемую систему администратор удаляет');
  update public.layers set color = '#000000' where company_id = c2;
  get diagnostics n = row_count;
  perform t.check(n = 0, 'администратор не меняет системы чужой компании');
  begin
    insert into public.layers(company_id, name, color) values (c2, 'Чужая', '#2F6FE0');
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  perform t.check(ok, 'администратор не создаёт систему в чужой компании');
  -- Удаление компании целиком (обслуживание) не блокируется проверкой.
  perform t.login(null);
end $$;
