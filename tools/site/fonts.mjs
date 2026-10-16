// Шрифт Onest для сайта: только 2 начертания (400, 600), только латиница + кириллица + нужные знаки,
// WOFF2. Разовая подготовка: cd tools/site && npm install && node fonts.mjs → site/fonts/.
// Лицензия Onest — SIL OFL 1.1 (assets/fonts/OFL.txt), копия кладётся рядом.
import subsetFont from 'subset-font';
import { readFileSync, writeFileSync, mkdirSync, copyFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '../..');
const out = join(root, 'site/fonts');
mkdirSync(out, { recursive: true });

let chars = '';
for (let c = 0x20; c <= 0x7e; c++) chars += String.fromCharCode(c);
for (let c = 0x400; c <= 0x45f; c++) chars += String.fromCharCode(c);
chars += '«»—–…№₽€$·•’‘“”„×→←↑↓✓✔©®°±≤≥ ';

for (const [file, w] of [['Onest-Regular.ttf', 400], ['Onest-SemiBold.ttf', 600]]) {
  const buf = await subsetFont(readFileSync(join(root, 'assets/fonts', file)), chars, { targetFormat: 'woff2' });
  writeFileSync(join(out, `onest-${w}.woff2`), buf);
  console.log(`onest-${w}.woff2`, buf.length, 'байт');
}
copyFileSync(join(root, 'assets/fonts/OFL.txt'), join(out, 'OFL.txt'));
