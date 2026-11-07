// Проверка «в кадрах сайта и питча нет русского текста» (шаг 35b). Запуск вручную:
//   node tools/site/ocr_check.mjs                 → таблица «файл → слов на кириллице → примеры», код 1, если есть
//   node tools/site/ocr_check.mjs --md out.md     → то же в Markdown-файл (для отчёта)
//   node tools/site/ocr_check.mjs a.png b.webp    → только эти файлы
// Что проверяет: все картинки assets/site/ (кроме QR и SVG), docs/screens/pitch/*.png, демо-ролик сайта
// (кадр в секунду). Нужны tesseract (+ языки rus, eng) и ffmpeg: sudo apt-get install -y tesseract-ocr tesseract-ocr-rus.
// OCR rus+eng иногда читает английские буквы как русские (Н, Е, Р, С…), поэтому «русским» считается слово
// из 3+ букв, в котором есть буква, не похожая на латинскую (Б, Г, Д, Ж, З, И, Л, П, Ф, Ц, Ч, Ш, Ы, Э, Ю, Я…).
// В «PR check» не входит: tesseract с русским языком ставится дольше всей остальной проверки (⚠️ шаг 35b).
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readdirSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { VIDEO } from './config.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '../..');
const args = process.argv.slice(2);
const mdAt = args.indexOf('--md');
const mdOut = mdAt >= 0 ? args.splice(mdAt, 2)[1] : null;

const list = (dir, re) => (existsSync(dir) ? readdirSync(dir).filter((f) => re.test(f)).sort().map((f) => join(dir, f)) : []);
const files = args.length ? args : [
  ...list(join(root, 'assets/site'), /\.(webp|png)$/),
  ...list(join(root, 'docs/screens/pitch'), /\.png$/),
  join(root, VIDEO.src),
];

/** Буквы кириллицы, которых нет среди похожих на латинские. */
const NOT_LATIN_LOOKING = /[БбГгДдЖжЗзИиЙйЛлПпФфЦцЧчШшЩщЪъЫыЬьЭэЮюЯяЁё]/;
export function cyrillicWords(text) {
  return (text.match(/[A-Za-zА-Яа-яЁё]{3,}/g) || []).filter((w) => /[А-Яа-яЁё]/.test(w) && NOT_LATIN_LOOKING.test(w));
}

const tmp = mkdtempSync(join(tmpdir(), 'ocr-'));
const run = (cmd, a) => execFileSync(cmd, a, { stdio: ['ignore', 'pipe', 'ignore'], maxBuffer: 64 << 20 }).toString();

/** Картинка → PNG ×2 (мелкий текст телефонных кадров OCR читает лучше крупным). */
function toPng(src, name) {
  const out = join(tmp, `${name}.png`);
  run('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', '-i', src, '-vf', 'scale=iw*2:-2:flags=lanczos', '-frames:v', '1', out]);
  return out;
}
const ocr = (png) => run('tesseract', [png, '-', '-l', 'rus+eng', '--psm', '11']);

const rows = [];
let n = 0;
for (const f of files) {
  const rel = relative(root, f);
  let words = [];
  if (/\.(mp4|webm)$/.test(f)) {
    const dir = join(tmp, `v${n++}`);
    run('mkdir', ['-p', dir]);
    run('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-i', f, '-vf', 'fps=1', join(dir, '%04d.png')]);
    const frames = readdirSync(dir).sort();
    const bad = [];
    for (const fr of frames) {
      const w = cyrillicWords(ocr(join(dir, fr)));
      if (w.length) bad.push(`${Number(fr.slice(0, 4)) - 1} с`);
      words.push(...w);
    }
    rows.push({ rel: `${rel} (${frames.length} кадров)`, words, note: bad.length ? `кадры: ${bad.slice(0, 6).join(', ')}${bad.length > 6 ? '…' : ''}` : '' });
  } else {
    words = cyrillicWords(ocr(toPng(f, `i${n++}`)));
    rows.push({ rel, words, note: '' });
  }
  const r = rows.at(-1);
  console.log(`${r.words.length ? '✗' : '✓'} ${r.rel}${r.words.length ? ` — ${r.words.length}: ${[...new Set(r.words)].slice(0, 6).join(', ')}` : ''}`);
}
rmSync(tmp, { recursive: true, force: true });

const bad = rows.filter((r) => r.words.length);
if (mdOut) {
  const md = ['| Файл | Кириллица | Примеры |', '|---|---|---|', ...rows.map((r) => `| \`${r.rel}\` | ${r.words.length ? `да (${r.words.length})` : 'нет'} | ${[...new Set(r.words)].slice(0, 5).join(', ')}${r.note ? ` (${r.note})` : ''} |`)].join('\n');
  writeFileSync(mdOut, md + '\n');
}
console.log(bad.length ? `\nС кириллицей: ${bad.length} из ${rows.length}` : `\n✓ кириллицы нет: ${rows.length} файлов`);
process.exit(bad.length ? 1 : 0);
export { basename };
