-- =====================================================================
-- Hey Helpy — миграция 0001: базовые сущности и авторизация
-- =====================================================================

create extension if not exists "pgcrypto";

-- Компании-заказчики
create table if not exists public.companies (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  created_at timestamptz not null default now()
);

-- Профили пользователей (1:1 с auth.users)
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  company_id uuid references public.companies(id) on delete set null,
  full_name  text,
  role       text not null default 'requester'
             check (role in ('admin','manager','requester','contractor','executor')),
  phone      text,
  created_at timestamptz not null default now()
);

-- Автосоздание профиля при регистрации пользователя
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data->>'full_name')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Хелперы (security definer — обходят RLS, чтобы не было рекурсии в политиках)
create or replace function public.my_company_id()
returns uuid
language sql stable security definer set search_path = public
as $$
  select company_id from public.profiles where id = auth.uid();
$$;

create or replace function public.my_role()
returns text
language sql stable security definer set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

-- ------------------------- RLS -------------------------
alter table public.companies enable row level security;
alter table public.profiles  enable row level security;

-- profiles: свой профиль читать/редактировать; коллеги по компании — читать
create policy profiles_select_self on public.profiles
  for select using (id = auth.uid());

create policy profiles_select_company on public.profiles
  for select using (company_id is not null and company_id = public.my_company_id());

create policy profiles_update_self on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- companies: члены компании видят свою компанию
create policy companies_select_members on public.companies
  for select using (id = public.my_company_id());
