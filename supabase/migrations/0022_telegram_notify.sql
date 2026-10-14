-- 0022 — уведомления автору заявки в Telegram (шаг 24). Требует 0018.
--
-- Без pg_net и pg_cron: после смены статуса приложение (менеджер или
-- исполнитель) вызывает Edge Function telegram-notify со своим JWT. Функция
-- читает заявку под RLS пользователя (видит ли он её, какой статус сейчас
-- В БАЗЕ — не со слов приложения), затем service_role-функцией
-- tg_notify_claim берёт чат автора из telegram.orders и отметку «по этому
-- статусу уже отправлено». Повторный вызов на тот же статус ничего не шлёт.
-- Не получилось отправить — tg_notify_release снимает отметку.
--
-- 1) telegram.notified — (заявка, статус): уже отправлено.
-- 2) telegram.optout — чаты, которые попросили «Не присылать уведомления»
--    (/stop или кнопка). /start или новая заявка — снова присылать.
-- 3) tg_notify_claim(заявка, статус) → кому и что отправить (или null);
--    tg_notify_release(заявка, статус); tg_notify_optout(чат, выкл).
--    Только service_role — как остальные tg_* (0018).
--
-- Статусы с уведомлением: in_progress (взяли в работу), done (выполнена),
-- returned (возвращена на доработку), cancelled (отклонена).
-- Повторный запуск безопасен: if not exists, create or replace.

do $$
begin
  if to_regclass('telegram.orders') is null then
    raise exception '0022: сначала примените миграцию 0018 (Telegram-бот)';
  end if;
end $$;

create table if not exists telegram.notified (
  work_order_id uuid not null references public.work_orders(id) on delete cascade,
  status        text not null,
  sent_at       timestamptz not null default now(),
  primary key (work_order_id, status)
);

create table if not exists telegram.optout (
  chat_id    bigint primary key,
  created_at timestamptz not null default now()
);

revoke all on all tables in schema telegram from public, anon, authenticated, service_role;

-- Кому и что отправить. null — не отправлять: заявка не из Telegram, статус
-- без уведомления, по нему уже отправлено, чат отписался или отвязан.
create or replace function public.tg_notify_claim(p_order uuid, p_status text)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  o record;
  w record;
  v_kind text;
  v_lang text;
  inserted int;
begin
  if p_status not in ('in_progress', 'done', 'returned', 'cancelled') then
    return null;
  end if;
  select t.chat_id, t.profile_id, t.link_id into o from telegram.orders t where t.work_order_id = p_order;
  if not found then return null; end if;
  select wo.status, wo.title, wo.company_id, wo.return_reason into w from work_orders wo where wo.id = p_order;
  -- Только текущий статус заявки в базе — не то, что прислали.
  if not found or w.status <> p_status then return null; end if;
  if exists (select 1 from telegram.optout x where x.chat_id = o.chat_id) then return null; end if;

  if o.chat_id < 0 then
    if not exists (select 1 from telegram_groups g where g.chat_id = o.chat_id and g.company_id = w.company_id) then
      return null;
    end if;
    v_kind := 'group';
    v_lang := 'ru';
  elsif o.profile_id is not null
        and exists (select 1 from telegram_links l where l.chat_id = o.chat_id and l.profile_id = o.profile_id) then
    v_kind := 'user';
    select l.language into v_lang from telegram_links l where l.chat_id = o.chat_id;
  elsif exists (select 1 from telegram_guests g where g.chat_id = o.chat_id and g.company_id = w.company_id) then
    v_kind := 'guest';
    select g.language into v_lang from telegram_guests g where g.chat_id = o.chat_id;
  else
    return null;
  end if;

  insert into telegram.notified(work_order_id, status) values (p_order, p_status)
  on conflict do nothing;
  get diagnostics inserted = row_count;
  if inserted = 0 then return null; end if;

  return jsonb_build_object(
    'chat_id', o.chat_id, 'kind', v_kind, 'lang', coalesce(v_lang, 'ru'),
    'number', upper(left(p_order::text, 6)), 'title', w.title, 'status', p_status,
    'return_reason', case when p_status = 'returned' then left(coalesce(w.return_reason, ''), 300) end);
end $$;

-- Отправить не удалось — снять отметку, чтобы следующий вызов попробовал снова.
create or replace function public.tg_notify_release(p_order uuid, p_status text)
returns void language sql volatile security definer set search_path = public as $$
  delete from telegram.notified where work_order_id = p_order and status = p_status;
$$;

-- «Не присылать уведомления» (p_off = true) / снова присылать (false).
create or replace function public.tg_notify_optout(p_chat bigint, p_off boolean)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if p_off then
    insert into telegram.optout(chat_id) values (p_chat) on conflict do nothing;
  else
    delete from telegram.optout where chat_id = p_chat;
  end if;
end $$;

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.tg_notify_claim(uuid, text)',
    'public.tg_notify_release(uuid, text)',
    'public.tg_notify_optout(bigint, boolean)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;
