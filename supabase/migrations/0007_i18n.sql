-- =====================================================================
-- hey_helpy · Миграция 0007: мультиязычность
-- 1) profiles.locale — язык интерфейса, который выбрал пользователь.
--    Менять его может сам пользователь (как имя и телефон); роль и
--    компания по-прежнему меняются только через RPC.
-- 2) layers.name_i18n — переводы названий слоёв {"ru": "...", "en": "..."}.
--    layers.name не меняется: по нему работают автоназначение и
--    уникальность. Приложение показывает перевод, если его нет — name_i18n.ru,
--    затем name.
-- 3) Слои по умолчанию для новых компаний — сразу с переводами.
--
-- Не зависит от 0006 (фото): применять можно в любом порядке.
-- Повторный запуск безопасен.
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1. Язык пользователя
-- ---------------------------------------------------------------------
alter table public.profiles add column if not exists locale text;

alter table public.profiles drop constraint if exists profiles_locale_check;
alter table public.profiles add constraint profiles_locale_check
  check (locale is null or locale in ('ru', 'en', 'ar'));

-- Своя строка профиля обновляется политикой profiles_update_self (0001),
-- а 0003 разрешил менять только full_name и phone. Добавляем locale.
grant update (locale) on public.profiles to authenticated;

-- ---------------------------------------------------------------------
-- 2. Переводы слоёв
-- ---------------------------------------------------------------------
alter table public.layers add column if not exists name_i18n jsonb not null default '{}'::jsonb;

alter table public.layers drop constraint if exists layers_name_i18n_object;
alter table public.layers add constraint layers_name_i18n_object
  check (jsonb_typeof(name_i18n) = 'object');

-- Переводы стандартных слоёв. Уже заданные вручную переводы не трогаем:
-- справа от || стоят существующие значения, они важнее.
update public.layers l
   set name_i18n = jsonb_build_object('ru', l.name, 'en', t.en) || l.name_i18n
  from (values
    ('Климат',               'HVAC'),
    ('Электрика',            'Electrical'),
    ('Сантехника',           'Plumbing'),
    ('Клининг',              'Cleaning'),
    ('Системы безопасности', 'Security systems'),
    ('Мебель',               'Furniture'),
    ('Другое',               'Other')
  ) as t(ru, en)
 where l.name = t.ru
   and not (l.name_i18n ? 'en' and l.name_i18n ? 'ru');

-- ---------------------------------------------------------------------
-- 3. Слои по умолчанию для новых компаний — с переводами.
--    requires_photo не указываем: берётся значение по умолчанию столбца
--    (его включает миграция 0006, когда в приложении появится фото).
-- ---------------------------------------------------------------------
create or replace function public.seed_default_layers(p_company uuid)
returns void language sql security definer set search_path = public as $$
  insert into layers(company_id, name, name_i18n, color, sort) values
    (p_company, 'Климат',               '{"ru": "Климат", "en": "HVAC"}',                         '#0E8C80', 10),
    (p_company, 'Электрика',            '{"ru": "Электрика", "en": "Electrical"}',                '#C27A0A', 20),
    (p_company, 'Сантехника',           '{"ru": "Сантехника", "en": "Plumbing"}',                 '#2F6FE0', 30),
    (p_company, 'Клининг',              '{"ru": "Клининг", "en": "Cleaning"}',                    '#7A55C7', 40),
    (p_company, 'Системы безопасности', '{"ru": "Системы безопасности", "en": "Security systems"}', '#3B4A6B', 45),
    (p_company, 'Мебель',               '{"ru": "Мебель", "en": "Furniture"}',                    '#8A6A4F', 50),
    (p_company, 'Другое',               '{"ru": "Другое", "en": "Other"}',                        '#5E6D7C', 90)
  on conflict (company_id, name) do nothing;
$$;
revoke all on function public.seed_default_layers(uuid) from public, anon, authenticated;

commit;
