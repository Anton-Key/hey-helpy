// QR-коды сайта — разово, после смены адреса сайта или ссылки на бота (нужен npm install в tools/site):
//   node tools/site/qr.mjs
// → assets/site/qr-demo.svg  — ссылка «Запросить демо» (CONTACT.demoUrl), build.mjs встраивает её в «Контакты»;
// → docs/site/qr-site.svg и docs/screens/site/qr-site.png (1024 px) — адрес сайта (SITE_URL), для печати и слайдов.
// Код считается здесь же, без внешних сервисов. PNG лежит в docs/screens/site/: хук block_secrets
// пропускает картинки только из разрешённых папок.
import QRCode from 'qrcode';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { CONTACT, SITE_URL } from './config.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '../..');
const opts = { errorCorrectionLevel: 'M', margin: 2, color: { dark: '#0F1A17', light: '#FFFFFF' } };

/** SVG без размеров в пикселях — масштабируется по месту; заголовок для читалок экрана. */
async function svg(text, title) {
  const s = await QRCode.toString(text, { ...opts, type: 'svg' });
  return s.replace(/<svg ([^>]*)>/, `<svg $1 role="img" aria-label="${title}"><title>${title}</title>`).replace(/<\?xml[^>]*>\s*/, '').trim() + '\n';
}

mkdirSync(join(root, 'docs/site'), { recursive: true });
mkdirSync(join(root, 'docs/screens/site'), { recursive: true });
writeFileSync(join(root, 'assets/site/qr-demo.svg'), await svg(CONTACT.demoUrl, `QR: ${CONTACT.demoUrl}`));
writeFileSync(join(root, 'docs/site/qr-site.svg'), await svg(SITE_URL, `QR: ${SITE_URL}`));
await QRCode.toFile(join(root, 'docs/screens/site/qr-site.png'), SITE_URL, { ...opts, width: 1024 });
console.log('готово: assets/site/qr-demo.svg, docs/site/qr-site.svg, docs/screens/site/qr-site.png');
