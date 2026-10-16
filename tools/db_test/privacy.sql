-- Проверки 0025, раздел 3 (шаг 28): история заявки пишет только база;
-- телефоны сотрудников видят сам человек и менеджеры своей компании.

select set_config('t.suite', 'privacy', false);

do $$
declare
  n int;
  ok boolean;
  v text;
begin
  -- ===================== work_logs =====================
  perform t.login(t.id(1, 103));   -- заявитель, автор заявки 102
  begin
    insert into public.work_logs(work_order_id, from_status, to_status, by_profile)
    values (t.id(1, 102), 'on_review', 'done', t.id(1, 103));
    ok := true;
  exception when others then ok := false;
  end;
  perform t.check(not ok, 'заявитель не подделывает строку истории');
  perform t.login(t.id(1, 100));
  begin
    insert into public.work_logs(work_order_id, from_status, to_status, by_profile)
    values (t.id(1, 101), 'on_review', 'done', t.id(1, 100));
    ok := true;
  exception when others then ok := false;
  end;
  perform t.check(not ok, 'и менеджер не пишет историю напрямую — только база');
  select count(*) into n from public.work_logs where work_order_id = t.id(1, 101);
  perform t.check(n >= 1, 'историю своей заявки по-прежнему видно');

  -- ===================== телефоны =====================
  perform t.login(null);
  select count(*) into n from public.profiles where phone is not null;
  perform t.check(n = 0, 'в profiles.phone пусто — телефоны перенесены, осталось ' || n);

  perform t.login(t.id(1, 103));   -- заявитель
  select count(*) into n from public.profile_contacts;
  perform t.check(n = 1, 'заявитель видит только свой телефон, видно ' || n);
  select phone into v from public.profile_contacts where profile_id = t.id(1, 103);
  perform t.check(v = '+7 900 000-1-03', 'свой телефон: ' || coalesce(v, 'null'));

  perform t.login(t.id(1, 102));   -- исполнитель
  select count(*) into n from public.profile_contacts where profile_id <> t.id(1, 102);
  perform t.check(n = 0, 'исполнитель не видит чужие телефоны, видно ' || n);

  perform t.login(t.id(1, 100));   -- менеджер
  select count(*) into n from public.profile_contacts;
  perform t.check(n = 2, 'менеджер видит телефоны своей компании (2), видно ' || n);

  -- Свой телефон меняют через профиль (как экран «Настройки»).
  perform t.login(t.id(1, 103));
  update public.profiles set phone = ' +7 999 111-22-33 ' where id = t.id(1, 103);
  select phone into v from public.profile_contacts where profile_id = t.id(1, 103);
  perform t.check(v = '+7 999 111-22-33', 'новый телефон — в контактах: ' || coalesce(v, 'null'));
  select count(*) into n from public.profiles where id = t.id(1, 103) and phone is null;
  perform t.check(n = 1, 'в profiles.phone не остаётся');
  update public.profiles set phone = '' where id = t.id(1, 103);
  select count(*) into n from public.profile_contacts where profile_id = t.id(1, 103);
  perform t.check(n = 0, 'пустой телефон — удаляется');

  -- Чужой телефон не поменять ни через профиль, ни напрямую.
  update public.profiles set phone = '+7 000' where id = t.id(1, 102);
  perform t.login(null);
  select phone into v from public.profile_contacts where profile_id = t.id(1, 102);
  perform t.check(v = '+7 900 000-1-02', 'чужой профиль не меняется: ' || coalesce(v, 'null'));
  perform t.login(t.id(1, 103));
  begin
    insert into public.profile_contacts(profile_id, company_id, phone) values (t.id(1, 103), t.id(1, 1), '1');
    ok := true;
  exception when others then ok := false;
  end;
  perform t.check(not ok, 'прямой записи в profile_contacts нет');
  perform t.login(null);
end $$;
