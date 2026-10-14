// Шаг 27: чистые функции проверки отпечатков фото из очереди без сети.

/** Путь фото очереди: <компания>/<заявка>/off_<id действия>.jpg. */
export const OFFLINE_PATH =
  /^[0-9a-f-]{36}\/[0-9a-f-]{36}\/off_[0-9a-f-]{36}\.jpg$/;
const SHA = /^[0-9a-f]{64}$/;
export const MAX_PHOTOS = 50;

export type PhotoClaim = { path: string; sha256: string };

/** Вход {photos: [{path, sha256}]} → список или null (плохой вход). */
export function parseInput(body: unknown): PhotoClaim[] | null {
  if (!body || typeof body !== "object") return null;
  const photos = (body as { photos?: unknown }).photos;
  if (!Array.isArray(photos) || photos.length === 0 || photos.length > MAX_PHOTOS) return null;
  const out: PhotoClaim[] = [];
  for (const p of photos) {
    if (!p || typeof p !== "object") return null;
    const path = (p as { path?: unknown }).path;
    const sha = (p as { sha256?: unknown }).sha256;
    if (typeof path !== "string" || !OFFLINE_PATH.test(path)) return null;
    if (typeof sha !== "string" || !SHA.test(sha.toLowerCase())) return null;
    out.push({ path, sha256: sha.toLowerCase() });
  }
  return out;
}

/** SHA-256 байтов — строкой hex. */
export async function sha256Hex(bytes: Uint8Array<ArrayBuffer>): Promise<string> {
  const d = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
