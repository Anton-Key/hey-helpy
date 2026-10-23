// Настройки сайта «Эй, Helpy» — одно место.
// После покупки своего домена: поменять SITE_URL (с «/» в конце) и пересобрать:
//   node tools/site/build.mjs
// (подробно — docs/site/README.md, «Свой домен»).

/** Адрес, по которому опубликован сайт (canonical, sitemap, hreflang, Open Graph, JSON-LD). */
export const SITE_URL = process.env.SITE_URL || 'https://anton-key.github.io/hey-helpy/site/';

/** Вход в приложение (веб-версия) — приложение живёт отдельно, сайт только ссылается на него. */
export const APP_URL = 'https://anton-key.github.io/hey-helpy/';

/** Дата последнего изменения содержания (sitemap lastmod, dateModified). Менять при правке текстов. */
export const UPDATED = '2026-10-23';

/**
 * Контакт для заявок на демо / пилот — Telegram-бот (решение владельца, шаг 29).
 * Бот по ?start=demo просит одно сообщение и сохраняет его (sales.site_leads, миграция 0026).
 * E-mail и телефон на сайте не указываются.
 */
export const CONTACT = {
  bot: 'HeyHelpy_bot',
  demoUrl: 'https://t.me/HeyHelpy_bot?start=demo',
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
