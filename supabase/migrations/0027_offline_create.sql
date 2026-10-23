-- =====================================================================
-- hey_helpy · Миграция 0027: новая заявка без сети; удаление ar_anchors
-- (шаг 32)
--
-- 1) offline_sync(p_actions) принимает ещё два действия очереди:
--      create — новая заявка, созданная без сети: id из приложения, title,
--               description?, priority, input_channel, layer_id?, object_id?,
--               location_id?, asset_id?. Права — как у политики wo_insert
--               (своя компания, автор = пользователь, зона доступа 0016),
--               статус «Новая» и подрядчик — те же триггеры, что при обычной
--               вставке (trg_wo_status_flow: только new / assigned; правило
--               слоя назначает подрядчика). Время создания (created_at) —
--               доверенное (offline_time, как у остальных действий). Повтор
--               того же id — заявка не дублируется.
--      photo  — теперь и stage = 'before' (фото «до» новой заявки): автор
--               заявки или менеджер с правом на неё, пока заявка не принята
--               и не отменена (как attachments_insert 0023); офлайн-пометки,
--               доверенное время и SHA-256 — как у фото «после» (шаг 27).
--    Файл снимка телефон кладёт в work-photos по обычной политике
--    work_photos_insert (0006: автор видит папку своей заявки) — новая
--    политика хранилища не нужна.
--    Пометку «Создано без сети» приложение берёт из offline_actions
--    (kind = 'create'): видят сам автор и менеджеры с правом на заявку.
-- 2) Старая таблица ar_anchors (0002) не используется (заменена vps_sites /
--    vps_marks, 0025), в рабочей базе пуста (проверено 23.10.2026) —
--    удаляется.
--
-- Новых таблиц нет. Требует 0024. Повторный запуск безопасен: drop … if
-- exists, create or replace.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Журнал офлайн-действий: вид create
-- ---------------------------------------------------------------------
alter table public.offline_actions drop constraint if exists offline_actions_kind_check;
alter table public.offline_actions add constraint offline_actions_kind_check
  check (kind in ('create', 'start', 'visit', 'check', 'photo', 'submit'));

-- ---------------------------------------------------------------------
-- 2. Можно ли пользователю создать заявку с такими объектом / системой /
--    оборудованием / помещением — то же условие зоны, что в политике
--    wo_insert (0016). Компанию и автора offline_sync подставляет сам.
-- ---------------------------------------------------------------------
create or replace function public.wo_insert_allowed(
  p_object uuid, p_layer uuid, p_asset uuid, p_location uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.zones_unrestricted()
      or p_object in (select z.object_id from public.zone_obj_layers() z where z.layer_id is null)
      or (p_object, p_layer) in (select z.object_id, z.layer_id from public.zone_obj_layers() z
                                  where z.layer_id is not null)
      or (p_object in (select public.zone_partial_objects())
          and public.can_see(p_object, p_layer, p_asset, p_location));
$$;
revoke all on function public.wo_insert_allowed(uuid, uuid, uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. Принять очередь (0024 + create и фото «до»)
--    p_actions — массив по порядку:
--    {id, kind, order_id, device_at, gps_at?, boot?, mono_ms?, ...}
--      create — title, description?, priority, input_channel, layer_id?,
--               object_id?, location_id?, asset_id?   (шаг 32)
--      start  — «Начать работу»
--      visit  — lat, lng, accuracy, mock
--      check  — item_id, done
--      photo  — path (<компания>/<заявка>/off_<id>.jpg), sha256, lat, lng, mock,
--               stage? (after — по умолчанию, before — шаг 32)
--      submit — «Выполнено, на проверку»
--    Ответ: [{id, result: applied | rejected | saved_late, reason?, trust}].
-- ---------------------------------------------------------------------
create or replace function public.offline_sync(p_actions jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid     uuid := auth.uid();
  v_company uuid := public.my_company_id();
  a         jsonb;
  v_id      uuid;
  v_kind    text;
  v_order   uuid;
  v_device  timestamptz;
  v_gps     timestamptz;
  v_time    record;
  v_result  text;
  v_reason  text;
  v_prev    record;
  v_status  text;
  v_path    text;
  v_sha     text;
  v_known   text;
  v_note    text;
  v_n       int;
  v_out     jsonb := '[]'::jsonb;
  -- шаг 32: новая заявка и фото «до» без сети
  v_stage   text;
  v_title   text;
  v_prio    text;
  v_channel text;
  v_layer   uuid;
  v_wtype   text;
  v_object  uuid;
  v_loc     uuid;
  v_asset   uuid;
begin
  if v_uid is null or v_company is null then
    raise exception 'offline_denied' using errcode = '42501';
  end if;
  if jsonb_typeof(p_actions) <> 'array' or jsonb_array_length(p_actions) > 200 then
    raise exception 'offline_bad_payload' using errcode = '22023';
  end if;

  for a in select value from jsonb_array_elements(p_actions) loop
    v_result := null; v_reason := null; v_note := null;
    begin
      v_id     := (a->>'id')::uuid;
      v_kind   := a->>'kind';
      v_order  := (a->>'order_id')::uuid;
      v_device := (a->>'device_at')::timestamptz;
      v_gps    := (a->>'gps_at')::timestamptz;
    exception when others then
      v_out := v_out || jsonb_build_object('id', a->>'id', 'result', 'rejected', 'reason', 'bad_action');
      continue;
    end;
    if v_id is null or v_order is null
       or v_kind not in ('create', 'start', 'visit', 'check', 'photo', 'submit') then
      v_out := v_out || jsonb_build_object('id', a->>'id', 'result', 'rejected', 'reason', 'bad_action');
      continue;
    end if;

    -- повтор: тот же ответ, ничего не делаем
    select o.result, o.reason, o.time_trust, o.profile_id into v_prev
      from offline_actions o where o.id = v_id;
    if found then
      if v_prev.profile_id <> v_uid then
        v_out := v_out || jsonb_build_object('id', v_id, 'result', 'rejected', 'reason', 'denied');
      else
        v_out := v_out || jsonb_build_object('id', v_id, 'result', v_prev.result,
                                             'reason', v_prev.reason, 'trust', v_prev.time_trust, 'repeat', true);
      end if;
      continue;
    end if;

    select * into v_time from public.offline_time(
      v_device, v_gps, a->>'boot', nullif(a->>'mono_ms', '')::bigint);
    perform set_config('hh.offline', '1', true);
    perform set_config('hh.offline_at', v_time.trusted_at::text, true);

    begin
      if v_kind = 'create' then
        -- Новая заявка (шаг 32): id — из приложения. Права — как у политики
        -- wo_insert (компания, автор, зона 0016), статус и подрядчик — те же
        -- триггеры, что при обычной вставке; время создания — доверенное.
        if exists (select 1 from work_orders where id = v_order) then
          if not exists (select 1 from work_orders
                          where id = v_order and company_id = v_company and created_by = v_uid) then
            raise exception 'offline:denied';
          end if;
          v_result := 'applied';  -- уже создана (ответ потерялся по дороге)
        else
          v_title   := btrim(coalesce(a->>'title', ''));
          v_prio    := coalesce(nullif(a->>'priority', ''), 'normal');
          v_channel := coalesce(nullif(a->>'input_channel', ''), 'button');
          v_layer   := nullif(a->>'layer_id', '')::uuid;
          v_object  := nullif(a->>'object_id', '')::uuid;
          v_loc     := nullif(a->>'location_id', '')::uuid;
          v_asset   := nullif(a->>'asset_id', '')::uuid;
          if length(v_title) not between 1 and 500
             or length(coalesce(a->>'description', '')) > 5000
             or v_prio not in ('low', 'normal', 'high', 'critical')
             or v_channel not in ('button', 'text', 'voice', 'camera') then
            raise exception 'offline:bad_action';
          end if;
          v_wtype := null;
          if v_layer is not null then
            select l.name into v_wtype from layers l
             where l.id = v_layer and l.company_id = v_company;
            if not found then raise exception 'offline:bad_action'; end if;
          end if;
          if not public.wo_insert_allowed(v_object, v_layer, v_asset, v_loc) then
            raise exception 'offline:denied';
          end if;
          insert into work_orders(id, company_id, title, description, work_type, layer_id, priority,
                                  status, input_channel, object_id, location_id, asset_id,
                                  created_by, created_at)
          values (v_order, v_company, v_title, nullif(btrim(coalesce(a->>'description', '')), ''),
                  v_wtype, v_layer, v_prio, 'new', v_channel, v_object, v_loc, v_asset,
                  v_uid, v_time.trusted_at);
          v_result := 'applied';
        end if;
      else

      select status into v_status from work_orders
       where id = v_order and company_id = v_company;
      if not found then
        raise exception 'offline:not_found';
      end if;

      if v_kind = 'start' then
        if v_status = 'in_progress' then
          if not public.wo_is_executor(v_order) then
            raise exception 'offline:conflict';
          end if;
          v_result := 'applied';  -- уже в работе
        else
          update work_orders set status = 'in_progress' where id = v_order;
          v_result := 'applied';
        end if;

      elsif v_kind = 'visit' then
        if v_status <> 'in_progress' or not public.wo_is_executor(v_order) then
          raise exception 'offline:conflict';
        end if;
        if exists (select 1 from visits where work_order_id = v_order
                     and profile_id = v_uid and ended_at is null) then
          v_result := 'applied';  -- визит уже открыт
        else
          insert into visits(work_order_id, company_id, profile_id, lat, lng, accuracy_m, mock_location,
                             offline, time_trust, claimed_at, trusted_at, time_drift_s, synced_at)
          values (v_order, v_company, v_uid,
                  (a->>'lat')::double precision, (a->>'lng')::double precision,
                  (a->>'accuracy')::double precision, coalesce((a->>'mock')::boolean, false),
                  true, v_time.trust, v_device, v_time.trusted_at, v_time.drift_s, now());
          v_result := 'applied';
        end if;

      elsif v_kind = 'check' then
        update checklist_items set is_done = coalesce((a->>'done')::boolean, true)
         where id = (a->>'item_id')::uuid and work_order_id = v_order;
        get diagnostics v_n = row_count;
        if v_n = 0 then raise exception 'offline:not_found'; end if;
        v_result := 'applied';

      elsif v_kind = 'photo' then
        v_path := a->>'path';
        v_sha  := lower(a->>'sha256');
        if v_path is null
           or v_path !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/off_[0-9a-f-]{36}\.jpg$'
           or split_part(v_path, '/', 1) <> v_company::text
           or split_part(v_path, '/', 2) <> v_order::text
           or v_sha is null or v_sha !~ '^[0-9a-f]{64}$' then
          raise exception 'offline:bad_photo';
        end if;
        if not exists (select 1 from storage.objects so
                        where so.bucket_id = 'work-photos' and so.name = v_path
                          and so.owner_id = v_uid::text) then
          raise exception 'offline:photo_missing';
        end if;
        select h.sha256 into v_known from offline_photo_hashes h where h.storage_path = v_path;
        if v_known is not null and v_known <> v_sha then
          raise exception 'offline:photo_hash_mismatch';
        end if;
        v_stage := coalesce(nullif(a->>'stage', ''), 'after');
        if v_stage not in ('before', 'after') then
          raise exception 'offline:bad_photo';
        end if;
        if exists (select 1 from attachments where storage_path = v_path) then
          v_result := 'applied';  -- уже сохранено
        elsif v_stage = 'before' then
          -- Фото «до» (шаг 32) — как обычное: автор заявки или менеджер с
          -- правом на неё, пока заявка не принята и не отменена.
          if v_status = 'cancelled' then raise exception 'offline:cancelled'; end if;
          if v_status = 'done' then raise exception 'offline:accepted'; end if;
          if not exists (select 1 from work_orders where id = v_order and created_by = v_uid)
             and not public.wo_is_manager(v_order) then
            raise exception 'offline:denied';
          end if;
          insert into attachments(work_order_id, kind, stage, storage_path, taken_at, lat, lng,
                                  mock_location, uploaded_by, source, offline, time_trust,
                                  trusted_at, time_drift_s, synced_at, sha256, sha256_ok)
          values (v_order, 'photo', 'before', v_path, v_device,
                  (a->>'lat')::double precision, (a->>'lng')::double precision,
                  coalesce((a->>'mock')::boolean, false), v_uid, 'camera', true, v_time.trust,
                  v_time.trusted_at, v_time.drift_s, now(), v_sha,
                  case when v_known is null then null else true end);
          v_result := 'applied';
        else
          if v_status = 'in_progress' and public.wo_is_executor(v_order) then
            v_result := 'applied';
          elsif public.wo_was_executor(v_order) then
            -- работа не пропадает: фото сохраняется с пометкой
            v_note := case
              when v_status = 'cancelled' then 'after_cancel'
              when not public.wo_is_executor(v_order) then 'after_reassign'
              else 'after_close' end;
            v_result := 'saved_late';
            v_reason := public.offline_conflict(v_order, v_kind);
          else
            raise exception 'offline:conflict';
          end if;
          insert into attachments(work_order_id, kind, stage, storage_path, taken_at, lat, lng,
                                  mock_location, uploaded_by, source, offline, time_trust,
                                  trusted_at, time_drift_s, synced_at, sha256, sha256_ok, sync_note)
          values (v_order, 'photo', 'after', v_path, v_device,
                  (a->>'lat')::double precision, (a->>'lng')::double precision,
                  coalesce((a->>'mock')::boolean, false), v_uid, 'camera', true, v_time.trust,
                  v_time.trusted_at, v_time.drift_s, now(), v_sha,
                  case when v_known is null then null else true end, v_note);
        end if;

      elsif v_kind = 'submit' then
        if v_status = 'on_review' and exists (
             select 1 from work_orders where id = v_order and submitted_by = v_uid) then
          v_result := 'applied';  -- уже сдано этим же исполнителем
        else
          update work_orders set status = 'on_review' where id = v_order;
          v_result := 'applied';
        end if;
      end if;
      end if;  -- create / остальные
    exception when others then
      -- подтранзакция откатилась; причину — по нынешнему состоянию заявки
      v_result := 'rejected';
      v_reason := case
        when sqlerrm = 'offline:not_found' then 'not_found'
        when sqlerrm = 'offline:bad_photo' then 'bad_photo'
        when sqlerrm = 'offline:photo_missing' then 'photo_missing'
        when sqlerrm = 'offline:photo_hash_mismatch' then 'photo_hash_mismatch'
        when sqlerrm = 'photo required' then 'photo_required'
        when sqlerrm = 'offline:bad_action' then 'bad_action'
        when sqlerrm = 'offline:denied' then 'denied'
        when sqlerrm = 'offline:cancelled' then 'cancelled'
        when sqlerrm = 'offline:accepted' then 'accepted'
        when v_kind = 'create' then 'denied'
        else public.offline_conflict(v_order, v_kind) end;
    end;

    perform set_config('hh.offline', '', true);
    perform set_config('hh.offline_at', '', true);

    insert into offline_actions(id, company_id, profile_id, work_order_id, kind, device_at, trusted_at,
                                time_trust, time_drift_s, result, reason)
    values (v_id, v_company, v_uid,
            case when exists (select 1 from work_orders where id = v_order and company_id = v_company)
                 then v_order end,
            v_kind, v_device, v_time.trusted_at, v_time.trust, v_time.drift_s, v_result, v_reason);
    v_out := v_out || jsonb_build_object('id', v_id, 'result', v_result, 'reason', v_reason,
                                         'trust', v_time.trust, 'drift_s', v_time.drift_s);
  end loop;
  return v_out;
end $$;
revoke all on function public.offline_sync(jsonb) from public, anon;
grant execute on function public.offline_sync(jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 4. Старая таблица AR-якорей (0002) — не используется
-- ---------------------------------------------------------------------
drop table if exists public.ar_anchors cascade;
