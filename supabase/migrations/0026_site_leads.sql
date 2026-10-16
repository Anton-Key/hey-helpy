-- 0026 — заявки на демо с сайта через Telegram-бота (шаг 29).
--
-- Кнопка «Запросить демо» на сайте ведёт на https://t.me/HeyHelpy_bot?start=demo.
-- Бот просит одно сообщение (компания, объекты, города, что показать) и
-- сохраняет его как «лид» — заявку на демо ВЛАДЕЛЬЦУ продукта, а не заявку
-- компании-клиента. Поэтому:
--
-- 1) Таблица в отдельной схеме sales (через API не видна, как схема telegram):
--    sales.site_leads (id, chat_id, tg_username, tg_name, language, text,
--    created_at, status new | contacted | closed). RLS включён, политик нет,
--    у anon / authenticated прав нет — приложение (в том числе администраторы
--    компаний-клиентов) лиды не видит. Смотрит и меняет статус только
--    владелец проекта: Supabase → Table Editor (схема sales) или SQL Editor.
-- 2) public.tg_lead_save(чат, username, имя, язык, текст) — только
--    service_role (бот). Лимиты: 3 лида в сутки с одного чата, 300 в сутки
--    всего. Текст 1–2000 символов.
--
-- Повторный запуск безопасен: if not exists, create or replace, drop … if exists.
-- Других таблиц и функций не меняет.

create schema if not exists sales;
revoke all on schema sales from public, anon, authenticated;

create table if not exists sales.site_leads (
  id          uuid primary key default gen_random_uuid(),
  chat_id     bigint not null,
  tg_username text check (tg_username is null or char_length(tg_username) <= 64),
  tg_name     text check (tg_name is null or char_length(tg_name) <= 128),
  language    text not null default 'ru' check (language in ('ru', 'en')),
  text        text not null check (char_length(btrim(text)) between 1 and 2000),
  created_at  timestamptz not null default now(),
  status      text not null default 'new' check (status in ('new', 'contacted', 'closed'))
);

create index if not exists site_leads_chat_created_idx on sales.site_leads (chat_id, created_at desc);
create index if not exists site_leads_created_idx on sales.site_leads (created_at desc);

alter table sales.site_leads enable row level security;
revoke all on table sales.site_leads from public, anon, authenticated;

comment on table sales.site_leads is
  'Шаг 29: заявки на демо с сайта (бот, /start demo). Только владелец: Table Editor / SQL Editor. Статус: new → contacted → closed.';

create or replace function public.tg_lead_save(
  p_chat bigint, p_username text, p_name text, p_lang text, p_text text)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  v_text text := btrim(coalesce(p_text, ''));
  v_id uuid;
begin
  if p_chat is null then
    return jsonb_build_object('ok', false, 'error', 'bad_chat');
  end if;
  if char_length(v_text) = 0 or char_length(v_text) > 2000 then
    return jsonb_build_object('ok', false, 'error', 'bad_text');
  end if;
  -- Лимиты: защита от спама в таблицу и в чат владельца.
  if (select count(*) from sales.site_leads
       where chat_id = p_chat and created_at > now() - interval '24 hours') >= 3 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;
  if (select count(*) from sales.site_leads where created_at > now() - interval '24 hours') >= 300 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;
  insert into sales.site_leads (chat_id, tg_username, tg_name, language, text)
  values (
    p_chat,
    nullif(left(btrim(coalesce(p_username, '')), 64), ''),
    nullif(left(btrim(coalesce(p_name, '')), 128), ''),
    case when p_lang = 'en' then 'en' else 'ru' end,
    v_text)
  returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id);
end $$;

-- Только бот (service_role), как остальные tg_* (0018).
revoke all on function public.tg_lead_save(bigint, text, text, text, text) from public, anon, authenticated;
grant execute on function public.tg_lead_save(bigint, text, text, text, text) to service_role;
grant usage on schema sales to service_role;
grant select, insert, update on sales.site_leads to service_role;
