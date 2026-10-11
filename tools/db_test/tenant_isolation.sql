-- Тест жёсткого разделения компаний.
-- Сам находит ВСЕ таблицы схемы public (information_schema) и для каждой
-- под менеджером, администратором, исполнителем и заявителем компании 1:
--   • чтение: 0 строк компании 2;
--   • изменение и удаление строк компании 2: 0 строк или отказ;
--   • вставка копии строки компании 2 (новый id): отказ;
--   • вставка копии с company_id компании 1, но ссылками на компанию 2: отказ.
-- То же для storage.objects и для анонима. ppr_generate() не создаёт
-- ничего в компании 2. Новая таблица без RLS, без политики или без строк
-- компании 2 в 10_fixture.sql сразу роняет тест.
-- Строка компании 2 = любой uuid-столбец начинается с «c2000000-0000-4000-8000-» (см. 10_fixture.sql).

select set_config('t.suite', 'tenant_isolation', false);

do $$
declare
  r        record;
  i        int;
  n        bigint;
  tbls     text[] := '{}';
  conds    text[] := '{}';
  copies   jsonb[] := '{}';
  swaps    jsonb[] := '{}';
  firstcol text[] := '{}';
  sample   jsonb;
  cp       jsonb;
  sw       jsonb;
  cond     text;
  refs     int;
  u        uuid;
  who      text;
  users    uuid[] := array[t.id(1, 100), t.id(1, 101), t.id(1, 102), t.id(1, 103)];
  names    text[] := array['менеджер', 'администратор', 'исполнитель', 'заявитель'];
  wo_c2_before bigint;
  wo_c2_after  bigint;
  k        text;
begin
  -- 1. Таблицы схемы public, условие «строка компании 2», образцы строк.
  for r in
    select c.relname as tbl, c.relrowsecurity as rls,
           (select count(*) from pg_policies p where p.schemaname = 'public' and p.tablename = c.relname) as pols
      from pg_class c join pg_namespace ns on ns.oid = c.relnamespace
     where ns.nspname = 'public' and c.relkind in ('r', 'p')
     order by c.relname
  loop
    perform t.check(r.rls, format('%s: RLS включён', r.tbl));
    perform t.check(r.pols > 0, format('%s: есть хотя бы одна политика', r.tbl));

    select string_agg(format('%I::text like %L', column_name, 'c2000000-0000-4000-8000-%'), ' or ' order by ordinal_position)
      into cond
      from information_schema.columns
     where table_schema = 'public' and table_name = r.tbl and data_type = 'uuid';
    if cond is null then
      perform t.check(false, format('%s: нет uuid-столбцов — тест не отличит компании', r.tbl));
      continue;
    end if;

    execute format('select count(*) from public.%I where %s', r.tbl, cond) into n;
    perform t.check(n > 0, format('%s: в 10_fixture.sql есть строки компании 2 (%s)', r.tbl, n));
    if n = 0 then continue; end if;

    -- образец: строка компании 2 с наибольшим числом ссылок на компанию 2
    execute format(
      'select to_jsonb(x) from public.%I x where %s
        order by (length(to_jsonb(x)::text) - length(replace(to_jsonb(x)::text, ''"c2'', ''''))) desc
        limit 1', r.tbl, cond) into sample;

    -- копия с новым id (и изменёнными названиями — чтобы не упереться в уникальность)
    cp := sample;
    if cp ? 'id' then cp := jsonb_set(cp, '{id}', to_jsonb(t.id(2, 9000 + coalesce(array_length(tbls, 1), 0) + 1))); end if;
    foreach k in array array['name', 'title', 'code', 'token', 'anchor_id', 'org_name', 'storage_path'] loop
      if cp ? k and jsonb_typeof(cp -> k) = 'string' then
        cp := jsonb_set(cp, array[k], to_jsonb((cp ->> k) || '-x'));
      end if;
    end loop;

    -- «подмена»: company_id своей компании, а ссылки остались на компанию 2
    sw := null;
    if sample ? 'company_id' then
      select count(*) into refs from jsonb_each_text(sample) e
       where e.key not in ('id', 'company_id') and e.value like 'c2000000-0000-4000-8000-%';
      if refs > 0 then
        sw := jsonb_set(cp, '{company_id}', to_jsonb(t.id(1, 1)));
        if sw ? 'id' then sw := jsonb_set(sw, '{id}', to_jsonb(t.id(1, 9000 + coalesce(array_length(tbls, 1), 0) + 1))); end if;
      end if;
    end if;

    tbls := tbls || r.tbl::text;
    conds := conds || cond;
    copies := copies || cp;
    swaps := swaps || sw;
    firstcol := firstcol || (select column_name::text from information_schema.columns
                              where table_schema = 'public' and table_name = r.tbl
                              order by ordinal_position limit 1);
  end loop;

  select count(*) into wo_c2_before from public.work_orders where company_id = t.id(2, 1);

  -- 2. Под каждым пользователем компании 1.
  for j in 1 .. array_length(users, 1) loop
    u := users[j];
    who := names[j];
    perform t.login(u);

    for i in 1 .. coalesce(array_length(tbls, 1), 0) loop
      execute format('select count(*) from public.%I where %s', tbls[i], conds[i]) into n;
      perform t.check(n = 0, format('%s: %s видит строк компании 2: %s', tbls[i], who, n));

      begin
        execute format('update public.%I set %I = %I where %s', tbls[i], firstcol[i], firstcol[i], conds[i]);
        get diagnostics n = row_count;
        perform t.check(n = 0, format('%s: %s изменил строк компании 2: %s', tbls[i], who, n));
      exception when others then
        perform t.check(true, format('%s: %s — изменение отклонено (%s)', tbls[i], who, sqlstate));
      end;

      begin
        execute format('delete from public.%I where %s', tbls[i], conds[i]);
        get diagnostics n = row_count;
        perform t.check(n = 0, format('%s: %s удалил строк компании 2: %s', tbls[i], who, n));
      exception when others then
        perform t.check(true, format('%s: %s — удаление отклонено (%s)', tbls[i], who, sqlstate));
      end;

      begin
        execute format('insert into public.%I select * from jsonb_populate_record(null::public.%I, $1)', tbls[i], tbls[i])
          using copies[i];
        perform t.check(false, format('%s: %s вставил строку компании 2', tbls[i], who));
      exception when others then
        perform t.check(sqlstate not in ('23505', '23503'),
          format('%s: %s — вставка в компанию 2 отклонена (%s %s)', tbls[i], who, sqlstate, sqlerrm));
      end;

      if swaps[i] is not null then
        -- автор — сам пользователь, чтобы отказ был из-за ссылок, а не из-за автора
        sw := swaps[i];
        foreach k in array array['created_by', 'profile_id', 'uploaded_by', 'by_profile'] loop
          if sw ? k then sw := jsonb_set(sw, array[k], to_jsonb(u)); end if;
        end loop;
        begin
          execute format('insert into public.%I select * from jsonb_populate_record(null::public.%I, $1)', tbls[i], tbls[i])
            using sw;
          perform t.check(false, format('%s: %s вставил строку своей компании со ссылками на компанию 2', tbls[i], who));
        exception when others then
          perform t.check(sqlstate not in ('23505', '23503'),
            format('%s: %s — ссылки на компанию 2 отклонены (%s %s)', tbls[i], who, sqlstate, sqlerrm));
        end;
      end if;
    end loop;

    -- хранилище
    select count(*) into n from storage.objects where name like 'c2000000-0000-4000-8000-%';
    perform t.check(n = 0, format('storage.objects: %s видит файлов компании 2: %s', who, n));
    update storage.objects set name = name where name like 'c2000000-0000-4000-8000-%';
    get diagnostics n = row_count;
    perform t.check(n = 0, format('storage.objects: %s изменил файлов компании 2: %s', who, n));
    delete from storage.objects where name like 'c2000000-0000-4000-8000-%';
    get diagnostics n = row_count;
    perform t.check(n = 0, format('storage.objects: %s удалил файлов компании 2: %s', who, n));
    begin
      insert into storage.objects(bucket_id, name, owner_id) values
        ('floor-plans', format('%s/%s/%s/x.png', t.id(2, 1), t.id(2, 10), t.id(2, 601)), u::text);
      perform t.check(false, format('storage: %s загрузил план в папку компании 2', who));
    exception when others then
      perform t.check(true, format('storage: %s — план в папку компании 2 отклонён', who));
    end;
    begin
      insert into storage.objects(bucket_id, name, owner_id) values
        ('floor-plans', format('%s/%s/%s/x.png', t.id(1, 1), t.id(2, 10), t.id(2, 601)), u::text);
      perform t.check(false, format('storage: %s загрузил план в своей папке на этаж компании 2', who));
    exception when others then
      perform t.check(true, format('storage: %s — этаж компании 2 в своей папке отклонён', who));
    end;
    begin
      insert into storage.objects(bucket_id, name, owner_id) values
        ('work-photos', format('%s/%s/x.jpg', t.id(1, 1), t.id(2, 101)), u::text);
      perform t.check(false, format('storage: %s загрузил фото к заявке компании 2', who));
    exception when others then
      perform t.check(true, format('storage: %s — фото к заявке компании 2 отклонено', who));
    end;

    -- генерация ППР
    begin
      perform public.ppr_generate();
    exception when others then
      perform t.check(false, format('ppr_generate: %s — ошибка %s %s', who, sqlstate, sqlerrm));
    end;

    perform t.login(null);
  end loop;

  select count(*) into wo_c2_after from public.work_orders where company_id = t.id(2, 1);
  perform t.check(wo_c2_after = wo_c2_before,
    format('ppr_generate под компанией 1 не создал задач в компании 2 (%s → %s)', wo_c2_before, wo_c2_after));

  -- 3. Аноним: ничего не видит и не может вызвать функции.
  execute 'set role anon';
  for i in 1 .. coalesce(array_length(tbls, 1), 0) loop
    begin
      execute format('select count(*) from public.%I', tbls[i]) into n;
      perform t.check(n = 0, format('%s: аноним видит строк: %s', tbls[i], n));
    exception when others then
      perform t.check(true, format('%s: аноним — нет доступа (%s)', tbls[i], sqlstate));
    end;
  end loop;
  begin
    perform public.ppr_generate();
    perform t.check(false, 'ppr_generate: аноним смог вызвать');
  exception when others then
    perform t.check(sqlstate = '42501', format('ppr_generate: аноним — нет права (%s)', sqlstate));
  end;
  execute 'reset role';
end $$;

-- Справка для отчёта: политики public без прямого условия по компании
-- (такие идут через заявку / подрядчика / объект или через auth.uid()).
select tablename, policyname, cmd
  from pg_policies
 where schemaname = 'public'
   and coalesce(qual, '') not like '%my_company_id%'
   and coalesce(with_check, '') not like '%my_company_id%'
 order by 1, 2;
