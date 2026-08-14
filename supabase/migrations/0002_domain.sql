-- =====================================================================
-- Hey Helpy — миграция 0002: предметная модель (объекты, заявки и т.д.)
-- Геоданные хранятся как lat/lng (double precision), без зависимости
-- от PostGIS. RLS-политики в этой фазе — единый company-scope; в Фазе 1
-- уточним права по ролям.
-- =====================================================================

-- Объекты недвижимости
create table if not exists public.objects (
  id         uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name       text not null,
  type       text not null default 'office'
             check (type in ('office','hotel','apartments','warehouse','other')),
  address    text,
  lat        double precision,
  lng        double precision,
  created_at timestamptz not null default now()
);

-- Направления / департаменты объекта
create table if not exists public.departments (
  id         uuid primary key default gen_random_uuid(),
  object_id  uuid not null references public.objects(id) on delete cascade,
  name       text not null,
  created_at timestamptz not null default now()
);

-- Помещения/зоны (дерево внутри объекта)
create table if not exists public.locations (
  id         uuid primary key default gen_random_uuid(),
  object_id  uuid not null references public.objects(id) on delete cascade,
  parent_id  uuid references public.locations(id) on delete set null,
  name       text not null,
  created_at timestamptz not null default now()
);

-- Оборудование / мебель / инфраструктура
create table if not exists public.assets (
  id           uuid primary key default gen_random_uuid(),
  location_id  uuid not null references public.locations(id) on delete cascade,
  name         text not null,
  category     text default 'equipment'
               check (category in ('equipment','furniture','infra','other')),
  inventory_no text,
  meta         jsonb,
  created_at   timestamptz not null default now()
);

-- Подрядные организации
create table if not exists public.contractors (
  id         uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  org_name   text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.contractor_objects (
  contractor_id uuid not null references public.contractors(id) on delete cascade,
  object_id     uuid not null references public.objects(id) on delete cascade,
  primary key (contractor_id, object_id)
);

-- Инвайт-ссылки для подключения исполнителей подрядчика
create table if not exists public.invites (
  id            uuid primary key default gen_random_uuid(),
  contractor_id uuid not null references public.contractors(id) on delete cascade,
  token         text not null unique default encode(gen_random_bytes(16), 'hex'),
  expires_at    timestamptz,
  used_at       timestamptz,
  created_at    timestamptz not null default now()
);

-- Исполнители подрядчика
create table if not exists public.executors (
  id            uuid primary key default gen_random_uuid(),
  profile_id    uuid references public.profiles(id) on delete set null,
  contractor_id uuid not null references public.contractors(id) on delete cascade,
  work_types    text[] not null default '{}',
  created_at    timestamptz not null default now()
);

-- Заявки
create table if not exists public.work_orders (
  id                   uuid primary key default gen_random_uuid(),
  company_id           uuid not null references public.companies(id) on delete cascade,
  object_id            uuid references public.objects(id) on delete set null,
  location_id          uuid references public.locations(id) on delete set null,
  asset_id             uuid references public.assets(id) on delete set null,
  title                text not null,
  description          text,
  work_type            text,
  priority             text not null default 'normal'
                       check (priority in ('low','normal','high','critical')),
  status               text not null default 'new'
                       check (status in ('new','assigned','in_progress','done','cancelled','overdue')),
  recurrence           jsonb,                 -- null = разовая; иначе период повторения
  requires_photo       boolean not null default false,
  requires_scan        boolean not null default false,
  input_channel        text default 'button'
                       check (input_channel in ('button','text','voice','camera')),
  created_by           uuid references public.profiles(id) on delete set null,
  assigned_executor_id uuid references public.executors(id) on delete set null,
  assigned_by          text check (assigned_by in ('ai','manager')),
  due_at               timestamptz,
  time_spent_minutes   integer,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- Пункты чек-листа (для регулярных заявок)
create table if not exists public.checklist_items (
  id            uuid primary key default gen_random_uuid(),
  work_order_id uuid not null references public.work_orders(id) on delete cascade,
  text          text not null,
  is_done       boolean not null default false,
  done_at       timestamptz,
  done_by       uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now()
);

-- История статусов
create table if not exists public.work_logs (
  id            uuid primary key default gen_random_uuid(),
  work_order_id uuid not null references public.work_orders(id) on delete cascade,
  from_status   text,
  to_status     text,
  by_profile    uuid references public.profiles(id) on delete set null,
  note          text,
  created_at    timestamptz not null default now()
);

-- Вложения (фото/аудио/видео/модели). Гео фото — для анти-фрода.
create table if not exists public.attachments (
  id            uuid primary key default gen_random_uuid(),
  work_order_id uuid not null references public.work_orders(id) on delete cascade,
  kind          text not null default 'photo'
                check (kind in ('photo','audio','video','model')),
  storage_path  text not null,
  lat           double precision,
  lng           double precision,
  taken_at      timestamptz,
  created_at    timestamptz not null default now()
);

-- Метки для скан-доступа к регулярной заявке (наклейка QR или AR-метка)
create table if not exists public.scan_tags (
  id          uuid primary key default gen_random_uuid(),
  asset_id    uuid references public.assets(id) on delete cascade,
  location_id uuid references public.locations(id) on delete cascade,
  code        text not null unique,
  kind        text not null default 'qr' check (kind in ('qr','ar')),
  created_at  timestamptz not null default now()
);

-- AR-якоря (Фаза 4)
create table if not exists public.ar_anchors (
  id         uuid primary key default gen_random_uuid(),
  asset_id   uuid not null references public.assets(id) on delete cascade,
  anchor_id  text not null,
  lat        double precision,
  lng        double precision,
  pose       jsonb,
  created_at timestamptz not null default now()
);

-- Индексы под частые выборки
create index if not exists idx_objects_company     on public.objects(company_id);
create index if not exists idx_wo_company           on public.work_orders(company_id);
create index if not exists idx_wo_status            on public.work_orders(status);
create index if not exists idx_wo_executor          on public.work_orders(assigned_executor_id);
create index if not exists idx_checklist_wo         on public.checklist_items(work_order_id);
create index if not exists idx_logs_wo              on public.work_logs(work_order_id);
create index if not exists idx_attachments_wo       on public.attachments(work_order_id);

-- =====================================================================
-- RLS: базовый company-scope. Включаем на всех таблицах и даём доступ
-- в рамках своей компании. Уточнение прав по ролям — в Фазе 1.
-- =====================================================================
alter table public.objects            enable row level security;
alter table public.departments        enable row level security;
alter table public.locations          enable row level security;
alter table public.assets             enable row level security;
alter table public.contractors        enable row level security;
alter table public.contractor_objects enable row level security;
alter table public.invites            enable row level security;
alter table public.executors          enable row level security;
alter table public.work_orders        enable row level security;
alter table public.checklist_items    enable row level security;
alter table public.work_logs          enable row level security;
alter table public.attachments        enable row level security;
alter table public.scan_tags          enable row level security;
alter table public.ar_anchors         enable row level security;

-- Прямой company_id
create policy objects_company on public.objects
  for all using (company_id = public.my_company_id())
  with check (company_id = public.my_company_id());

create policy contractors_company on public.contractors
  for all using (company_id = public.my_company_id())
  with check (company_id = public.my_company_id());

create policy work_orders_company on public.work_orders
  for all using (company_id = public.my_company_id())
  with check (company_id = public.my_company_id());

-- Через objects
create policy departments_company on public.departments
  for all using (exists (
    select 1 from public.objects o
    where o.id = departments.object_id and o.company_id = public.my_company_id()));

create policy locations_company on public.locations
  for all using (exists (
    select 1 from public.objects o
    where o.id = locations.object_id and o.company_id = public.my_company_id()));

-- Через locations -> objects
create policy assets_company on public.assets
  for all using (exists (
    select 1 from public.locations l
    join public.objects o on o.id = l.object_id
    where l.id = assets.location_id and o.company_id = public.my_company_id()));

-- Через contractors
create policy contractor_objects_company on public.contractor_objects
  for all using (exists (
    select 1 from public.contractors c
    where c.id = contractor_objects.contractor_id and c.company_id = public.my_company_id()));

create policy invites_company on public.invites
  for all using (exists (
    select 1 from public.contractors c
    where c.id = invites.contractor_id and c.company_id = public.my_company_id()));

create policy executors_company on public.executors
  for all using (exists (
    select 1 from public.contractors c
    where c.id = executors.contractor_id and c.company_id = public.my_company_id()));

-- Через work_orders
create policy checklist_company on public.checklist_items
  for all using (exists (
    select 1 from public.work_orders w
    where w.id = checklist_items.work_order_id and w.company_id = public.my_company_id()));

create policy work_logs_company on public.work_logs
  for all using (exists (
    select 1 from public.work_orders w
    where w.id = work_logs.work_order_id and w.company_id = public.my_company_id()));

create policy attachments_company on public.attachments
  for all using (exists (
    select 1 from public.work_orders w
    where w.id = attachments.work_order_id and w.company_id = public.my_company_id()));

-- scan_tags: через asset или location к объекту компании
create policy scan_tags_company on public.scan_tags
  for all using (
    exists (
      select 1 from public.assets a
      join public.locations l on l.id = a.location_id
      join public.objects o on o.id = l.object_id
      where a.id = scan_tags.asset_id and o.company_id = public.my_company_id())
    or exists (
      select 1 from public.locations l
      join public.objects o on o.id = l.object_id
      where l.id = scan_tags.location_id and o.company_id = public.my_company_id()));

-- ar_anchors: через asset
create policy ar_anchors_company on public.ar_anchors
  for all using (exists (
    select 1 from public.assets a
    join public.locations l on l.id = a.location_id
    join public.objects o on o.id = l.object_id
    where a.id = ar_anchors.asset_id and o.company_id = public.my_company_id()));
