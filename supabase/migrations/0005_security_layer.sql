-- =====================================================================
-- hey_helpy · Миграция 0005: слой «Системы безопасности»
-- Запускать после миграции 0004. Повторный запуск безопасен.
-- =====================================================================
begin;

-- Слои по умолчанию для новых компаний (добавлен новый слой)
create or replace function public.seed_default_layers(p_company uuid)
returns void language sql security definer set search_path = public as $$
  insert into layers(company_id, name, color, requires_photo, sort) values
    (p_company, 'Климат',                '#0E8C80', false, 10),
    (p_company, 'Электрика',             '#C27A0A', false, 20),
    (p_company, 'Сантехника',            '#2F6FE0', false, 30),
    (p_company, 'Клининг',               '#7A55C7', false, 40),
    (p_company, 'Системы безопасности',  '#3B4A6B', false, 45),
    (p_company, 'Мебель',                '#8A6A4F', false, 50),
    (p_company, 'Другое',                '#5E6D7C', false, 90)
  on conflict (company_id, name) do nothing;
$$;
revoke all on function public.seed_default_layers(uuid) from public, anon, authenticated;

-- Добавляем слой всем существующим компаниям
select public.seed_default_layers(id) from public.companies;

commit;
