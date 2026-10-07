/// Адрес веб-версии (GitHub Pages, см. CLAUDE.md → «Веб-ссылка»).
const webAppUrl = 'https://anton-key.github.io/hey-helpy/';

/// Ссылка-приглашение: веб-версия сама подставит код на экране вступления.
String inviteLink(String code) =>
    Uri.parse(webAppUrl).replace(queryParameters: {'invite': code}).toString();
