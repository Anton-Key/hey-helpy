-- 0011_profile_company_notifications.sql
-- Назначение: то, что нужно разделам профиля «Моя компания» и «Уведомления».
-- 1) Отметка «уведомления прочитаны» в профиле — одна дата на человека,
--    чтобы счётчик у колокольчика был одинаковым на телефоне и на сайте.
--    До применения приложение хранит эту отметку на самом устройстве.
-- 2) Менеджер и администратор могут переименовать свою компанию
--    (раньше правила на изменение companies не было ни у кого).
-- 3) Смена роли сотрудника (set_member_role): кроме администратора, теперь
--    и менеджер — но только между ролями «менеджер / заявитель /
--    исполнитель / подрядчик». Назначить или снять администратора
--    по-прежнему может только администратор; свою роль менять нельзя.
-- Зависит от: 0001 (profiles, companies), 0003 (set_member_role, права на
-- profiles), 0004 (is_manager), 0008 (новые функции закрыты по умолчанию).
-- Применяется вручную: Supabase → SQL Editor. Безопасно запускать повторно.

begin;

-- ---------------------------------------------------------------------
-- 1. Когда человек последний раз открывал «Уведомления»
--    Меняет только сам владелец профиля: политика profiles_update_self (0001)
--    и право на колонку (как full_name, phone в 0003 и locale в 0007).
-- ---------------------------------------------------------------------
alter table public.profiles
  add column if not exists notifications_seen_at timestamptz;
grant update (notifications_seen_at) on public.profiles to authenticated;

-- ---------------------------------------------------------------------
-- 2. Название компании меняет менеджер или администратор этой компании.
--    Менять можно только название (не id и не дату создания).
-- ---------------------------------------------------------------------
alter table public.companies drop constraint if exists companies_name_check;
alter table public.companies add constraint companies_name_check
  check (length(trim(name)) between 1 and 200) not valid;

revoke update on public.companies from anon, authenticated;
grant update (name) on public.companies to authenticated;

drop policy if exists companies_update_manager on public.companies;
create policy companies_update_manager on public.companies for update
  using (id = (select public.my_company_id()) and (select public.is_manager()))
  with check (id = (select public.my_company_id()) and (select public.is_manager()));

-- ---------------------------------------------------------------------
-- 3. Смена роли сотрудника. Тексты ошибок те же, что в 0003:
--    приложение переводит их по ним.
-- ---------------------------------------------------------------------
create or replace function public.set_member_role(p_profile uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me     text := coalesce(public.my_role(), '');
  v_target text;
begin
  if v_me not in ('admin', 'manager') then
    raise exception 'forbidden: admin only';
  end if;
  if p_role not in ('admin', 'manager', 'requester', 'contractor', 'executor') then
    raise exception 'unknown role %', p_role;
  end if;
  if p_profile = auth.uid() then
    raise exception 'cannot change own role';
  end if;

  select role into v_target from profiles
   where id = p_profile and company_id = public.my_company_id()
   for update;
  if not found then
    raise exception 'profile not found in your company';
  end if;

  -- Менеджер не назначает администраторов и не меняет их роль.
  if v_me = 'manager' and (p_role = 'admin' or v_target = 'admin') then
    raise exception 'forbidden: admin only';
  end if;

  update profiles set role = p_role where id = p_profile;
end;
$$;

revoke all on function public.set_member_role(uuid, text) from public, anon;
grant execute on function public.set_member_role(uuid, text) to authenticated;

commit;
