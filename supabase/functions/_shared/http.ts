// Общее для HTTP-обёрток функций: CORS (сайт на GitHub Pages и localhost),
// JSON-ответ и служебный лог одной строкой JSON. Содержимое запроса (текст
// заявки, фото) сюда не попадает — только поля, переданные явно.

export const ALLOWED_ORIGIN = "https://anton-key.github.io";
const LOCALHOST = /^http:\/\/(localhost|127\.0\.0\.1)(:\d{1,5})?$/;

export function corsHeaders(origin: string | null): Record<string, string> {
  const h: Record<string, string> = {
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
  if (origin && (origin === ALLOWED_ORIGIN || LOCALHOST.test(origin))) {
    h["Access-Control-Allow-Origin"] = origin;
  }
  return h;
}

export function logFn(fn: string) {
  return (fields: Record<string, unknown>) =>
    console.log(JSON.stringify({ fn, ...fields }));
}
