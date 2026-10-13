/// Адрес веб-версии (GitHub Pages, см. CLAUDE.md → «Веб-ссылка»).
const webAppUrl = 'https://anton-key.github.io/hey-helpy/';

/// Ссылка-приглашение: веб-версия сама подставит код на экране вступления.
String inviteLink(String code) =>
    Uri.parse(webAppUrl).replace(queryParameters: {'invite': code}).toString();

/// Telegram-бот (шаг 23) — одно место; в функции — BOT_USERNAME в
/// supabase/functions/telegram-bot/telegram.ts.
const kTelegramBot = 'HeyHelpy_bot';

/// Ссылка «открыть бота» с параметром /start: `link_<код>` — привязка
/// аккаунта, `obj_<токен>` — QR объекта, `co_<токен>` — ссылка компании.
String telegramStartLink(String param) =>
    'https://t.me/$kTelegramBot?start=$param';

/// Ссылка «добавить бота в группу» — сразу с кодом подключения к объекту.
String telegramGroupLink(String code) =>
    'https://t.me/$kTelegramBot?startgroup=grp_$code';
