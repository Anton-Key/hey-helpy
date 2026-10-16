// Картинки сайта: кадры питча (docs/screens/pitch/) → WebP в assets/site/.
// Запуск один раз после пересъёмки кадров: node tools/site/images.mjs (нужен ffmpeg с libwebp).
// Картинки лежат в assets/site/, а не в site/: хук block_secrets пропускает картинки только
// из разрешённых папок; build.mjs копирует их в img/ при сборке сайта.
import { execFileSync } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '../..');
const pitch = join(root, 'docs/screens/pitch');
const out = join(root, 'assets/site');
mkdirSync(out, { recursive: true });

// [исходный кадр, имя на сайте, ширина, обрезка ffmpeg (необязательно)]
export const SHOTS = [
  ['04-voice-ai-check-phone.png', 'voice', 480],
  ['21-camera-card-phone.png', 'camera', 480],
  ['28-telegram-assign-phone.png', 'telegram', 480, 'crop=iw:ih*0.62:0:ih*0.38,'],
  ['24-order-photos-phone.png', 'photos', 480],
  ['20-act-proven-desktop.png', 'act', 1200],
  ['06-floor-plan-desktop.png', 'plan', 1200],
  ['10-reports-desktop.png', 'reports', 1200],
  ['13-ppr-desktop.png', 'ppr', 1200],
];

const ff = (args) => execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...args]);

for (const [src, name, w, pre = ''] of SHOTS) {
  ff(['-i', join(pitch, src), '-vf', `${pre}scale=${w}:-2:flags=lanczos`, '-c:v', 'libwebp', '-quality', '78',
    '-compression_level', '6', join(out, `${name}.webp`)]);
}
// Постер видео — кадр демо-ролика на 20-й секунде.
ff(['-ss', '20', '-i', join(root, 'docs/demo/hey-helpy-demo-v2.mp4'), '-frames:v', '1', '-vf', 'scale=1280:-2',
  '-c:v', 'libwebp', '-quality', '75', join(out, 'video-poster.webp')]);
console.log('готово:', out);

// Размеры — для width / height в <img> (без сдвига вёрстки, CLS).
import { readdirSync, writeFileSync } from 'node:fs';
const sizes = {};
for (const f of readdirSync(out).filter((f) => f.endsWith('.webp') || f.endsWith('.png'))) {
  const [w, h] = execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'stream=width,height', '-of', 'csv=p=0', join(out, f)])
    .toString().trim().split(',').map(Number);
  sizes[f] = [w, h];
}
writeFileSync(join(out, 'sizes.json'), JSON.stringify(sizes, null, 1) + '\n');
