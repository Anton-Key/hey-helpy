// Чтение справочников для разбора — ОТ ИМЕНИ ПОЛЬЗОВАТЕЛЯ (клиент Supabase с
// его JWT), под RLS: каждый видит только своё (компания, зона доступа).
// service_role не используется. Ошибка чтения → пустой список и код в лог.

import type { LayerRef } from "./intake.ts";
import type { AssetRef, Here } from "./identify.ts";

/** Больше оборудования не читаем: на демо-компанию — 38 единиц. */
export const ASSETS_MAX = 1000;

// deno-lint-ignore no-explicit-any
type Db = any;
type Log = (fields: Record<string, unknown>) => void;

export async function loadLayers(db: Db, log: Log): Promise<LayerRef[]> {
  // «*», а не список столбцов: archived_at появляется только с 0020, а без
  // неё запрос со столбцом упал бы. Архивные системы модели не предлагаются.
  const r = await db.from("layers").select("*").order("sort").order("name");
  if (r.error) log({ code: "layers_failed" });
  return (r.data ?? []).filter((l: { archived_at?: string | null }) =>
    !l.archived_at
  ).map((l: LayerRef) => ({
    id: l.id,
    name: l.name ?? "",
    name_i18n: l.name_i18n ?? null,
  }));
}

/**
 * Где человек: из заявки (orderId) или помещения (locationId) достраиваются
 * этаж и объект. Чужой или невидимый id просто не находится (RLS).
 */
export async function resolveHere(
  db: Db,
  input: Here & { orderId?: string | null },
): Promise<Here> {
  const here: Here = {
    locationId: input.locationId ?? null,
    floorId: input.floorId ?? null,
    objectId: input.objectId ?? null,
  };
  if (input.orderId && !here.locationId) {
    const r = await db.from("work_orders").select("object_id,location_id")
      .eq("id", input.orderId).maybeSingle();
    if (r.data) {
      here.locationId = r.data.location_id ?? null;
      here.objectId = here.objectId ?? r.data.object_id ?? null;
    }
  }
  if (here.locationId && (!here.floorId || !here.objectId)) {
    const r = await db.from("locations").select("object_id,floor_id")
      .eq("id", here.locationId).maybeSingle();
    if (r.data) {
      here.floorId = here.floorId ?? r.data.floor_id ?? null;
      here.objectId = here.objectId ?? r.data.object_id ?? null;
    } else {
      here.locationId = null;
    }
  }
  if (here.floorId && !here.objectId) {
    const r = await db.from("floors").select("object_id").eq("id", here.floorId)
      .maybeSingle();
    here.objectId = r.data?.object_id ?? null;
  }
  return here;
}

interface AssetRow {
  id: string;
  name: string | null;
  location_id: string;
  floor_id: string | null;
  meta: Record<string, unknown> | null;
  layer_id?: string | null;
  manufacturer?: string | null;
  model?: string | null;
  serial_no?: string | null;
  inventory_no?: string | null;
  locations?: {
    name?: string | null;
    code?: string | null;
    object_id: string;
    floor_id?: string | null;
    objects?: { name?: string | null } | null;
  } | null;
}

/**
 * Оборудование для сопоставления: объекта человека, если он известен, иначе
 * всё видимое. Плюс названия этажей и отметка «есть открытая заявка».
 */
export async function loadAssets(
  db: Db,
  here: Here,
  log: Log,
): Promise<AssetRef[]> {
  const cols = (passport: boolean) =>
    "id,name,location_id,floor_id,meta,inventory_no," +
    (passport ? "layer_id,manufacturer,model,serial_no," : "") +
    `locations!inner(name,${
      passport ? "code," : ""
    }object_id,floor_id,objects(name))`;
  const query = (passport: boolean) => {
    let q = db.from("assets").select(cols(passport));
    if (here.objectId) q = q.eq("locations.object_id", here.objectId);
    return q.limit(ASSETS_MAX);
  };
  // Паспорт и номер помещения — с 0015; без неё — как раньше.
  let res = await query(true);
  if (res.error) res = await query(false);
  if (res.error) {
    log({ code: "assets_failed" });
    return [];
  }
  const rows = (res.data ?? []) as AssetRow[];

  let floors = db.from("floors").select("id,name");
  if (here.objectId) floors = floors.eq("object_id", here.objectId);
  let orders = db.from("work_orders").select("asset_id")
    .not("asset_id", "is", null)
    .not("status", "in", "(done,cancelled)");
  if (here.objectId) orders = orders.eq("object_id", here.objectId);
  const [floorsRes, ordersRes] = await Promise.all([
    floors.limit(500),
    orders.limit(2000),
  ]);
  if (floorsRes.error) log({ code: "floors_failed" });
  if (ordersRes.error) log({ code: "orders_failed" });
  const floorName = new Map<string, string>(
    (floorsRes.data ?? []).map((f: { id: string; name: string }) => [
      f.id,
      f.name,
    ]),
  );
  const open = new Set<string>(
    (ordersRes.data ?? []).map((o: { asset_id: string }) => o.asset_id),
  );

  return rows.map((r) => {
    const floorId = r.floor_id ?? r.locations?.floor_id ?? null;
    const kind = r.meta?.kind;
    return {
      id: r.id,
      name: r.name ?? "",
      location_id: r.location_id,
      location_name: r.locations?.name ?? "",
      location_code: r.locations?.code ?? null,
      object_id: r.locations?.object_id ?? "",
      object_name: r.locations?.objects?.name ?? null,
      floor_id: floorId,
      floor_name: floorId ? floorName.get(floorId) ?? null : null,
      kind: typeof kind === "string" ? kind : null,
      layer_id: r.layer_id ?? null,
      manufacturer: r.manufacturer ?? null,
      model: r.model ?? null,
      serial_no: r.serial_no ?? null,
      inventory_no: r.inventory_no ?? null,
      open_order: open.has(r.id),
    };
  });
}
