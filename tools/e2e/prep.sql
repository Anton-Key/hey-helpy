-- Подготовка локальной базы hh_test к сквозным тестам (после run.sh).
-- Только локально: как в рабочей базе после 0016 демо-менеджер становится
-- администратором (в «Демо БЦ» не было администратора); второй менеджер
-- «Менеджер Москва» — БЕЗ зоны (зону ему задаёт администратор в тесте 7).

update public.profiles set role = 'admin'
 where id = (select id from auth.users where email = 'manager@example.com');

insert into auth.users(id, email) values ('d0000000-0000-4000-8000-000000000004', 'manager2@example.com')
  on conflict do nothing;
update public.profiles set company_id = 'de300000-0000-4000-8000-000000000001', role = 'manager',
       full_name = 'Менеджер Москва'
 where id = 'd0000000-0000-4000-8000-000000000004';
delete from public.access_zones where profile_id = 'd0000000-0000-4000-8000-000000000004';

-- Исполнитель бригады «Пекин» Huaxin FM (тест 7): учётная запись только здесь.
insert into auth.users(id, email) values ('d0000000-0000-4000-8000-000000000005', 'beijing@example.com')
  on conflict do nothing;
update public.profiles set company_id = 'de300000-0000-4000-8000-000000000001', role = 'executor',
       full_name = 'Исполнитель Пекин'
 where id = 'd0000000-0000-4000-8000-000000000005';
insert into public.executors(id, profile_id, contractor_id)
values ('de300000-0000-4000-8000-000000000960', 'd0000000-0000-4000-8000-000000000005',
        'de300000-0000-4000-8000-000000000509')
on conflict (id) do nothing;
insert into public.crew_members(company_id, crew_id, executor_id)
values ('de300000-0000-4000-8000-000000000001', 'de300000-0000-4000-8000-000000000950',
        'de300000-0000-4000-8000-000000000960')
on conflict do nothing;

-- Исполнитель «МосКлимат» (сценарий ППР «ТО кондиционеров», Москва · Офис 1).
insert into auth.users(id, email) values ('d0000000-0000-4000-8000-000000000006', 'mosklimat@example.com')
  on conflict do nothing;
update public.profiles set company_id = 'de300000-0000-4000-8000-000000000001', role = 'executor',
       full_name = 'Исполнитель МосКлимат'
 where id = 'd0000000-0000-4000-8000-000000000006';
insert into public.executors(id, profile_id, contractor_id)
values ('de300000-0000-4000-8000-000000000961', 'd0000000-0000-4000-8000-000000000006',
        'de300000-0000-4000-8000-000000000501')
on conflict (id) do nothing;
