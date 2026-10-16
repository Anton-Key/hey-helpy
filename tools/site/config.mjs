// Настройки сайта «Эй, Helpy» — одно место.
// После покупки своего домена: поменять SITE_URL (с «/» в конце) и пересобрать:
//   node tools/site/build.mjs
// (подробно — docs/site/README.md, «Свой домен»).

/** Адрес, по которому опубликован сайт (canonical, sitemap, hreflang, Open Graph, JSON-LD). */
export const SITE_URL = process.env.SITE_URL || 'https://anton-key.github.io/hey-helpy/site/';

/** Вход в приложение (веб-версия) — приложение живёт отдельно, сайт только ссылается на него. */
export const APP_URL = 'https://anton-key.github.io/hey-helpy/';

/** Дата последнего изменения содержания (sitemap lastmod, dateModified). Менять при правке текстов. */
export const UPDATED = '2026-10-16';

/**
 * Контакты для заявок на демо / пилот.
 * TODO (владелец): вписать рабочий e-mail и, по желанию, Telegram для связи (ник без @).
 * Пока пусто — на сайте вместо формы честная строка «контакт появится здесь», без выдуманных данных.
 */
export const CONTACT = {
  email: '', // TODO: например 'pilot@ваш-домен.ru'
  telegram: '', // TODO: например 'heyhelpy_team' (не бот заявок)
};

/** Демо-ролик: файл в репозитории и данные для VideoObject. */
export const VIDEO = {
  src: 'docs/demo/hey-helpy-demo-v2.mp4',
  file: 'media/hey-helpy-demo.mp4',
  poster: 'img/video-poster.webp',
  uploadDate: '2026-10-14',
  duration: 'PT2M9S',
  width: 1920,
  height: 1080,
};

export const BRAND = { ru: 'Эй, Helpy', en: 'Hey Helpy' };
