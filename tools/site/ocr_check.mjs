// Проверка «в кадрах сайта и питча нет русского текста» (шаг 35b) и старого имени «Helpy» (шаг 36:
// продукт называется Dokazio). Запуск вручную:
//   node tools/site/ocr_check.mjs                 → таблица «файл → слов на кириллице → примеры», код 1, если есть
//   node tools/site/ocr_check.mjs --md out.md     → то же в Markdown-файл (для отчёта)
//   node tools/site/ocr_check.mjs a.png b.webp    → только эти файлы
// Что проверяет: все картинки assets/site/ (кроме QR и SVG), docs/screens/pitch/*.png, демо-ролик сайта
// (кадр в секунду). Нужны tesseract (+ языки rus, eng) и ffmpeg: sudo apt-get install -y tesseract-ocr tesseract-ocr-rus.
// OCR rus+eng читает английские буквы как русские (Cancel → «Сапсе»), поэтому «русским» считается слово
// из 4+ букв только кириллицей, в котором есть буква, не похожая на латинскую (Б, Д, Ж, З, Л, Ф, Ц, Ч, Ь, Ы, Э, Ю, Я…),
// и нет невозможного в русском письме («ыы» — шум значков). Порог проверен на кадрах «до» (шаг 35b).
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

/**
 * Буквы кириллицы, которые OCR не путает с латиницей. Остальные (а в е к м н о р с т у х п г и ш)
 * в английском тексте распознаются «по-русски»: Cancel → «Сапсе», company → «сотрапу».
 */
const STRONG = /[БбДдЖжЗзЙйЛлФфЦцЧчЩщЪъЫыЬьЭэЮюЯяЁё]/;
/** Невозможное в русском письме — шум распознавания значков («фнныы»). */
const IMPOSSIBLE = /ыы|ьь|ъъ|^[ЫыЬьЪъ]|[ЬьЪъ][ЬьЪъЫы]|[аеёиоуыэюя]ы/i;
/**
 * Проверенный глазами шум распознавания (шаг 35b): «Чопег» — наклонный текст кадров на OG-картинке;
 * «РНОТОЗ» — «PHOTOS», «нмде» — «✓ HVAC», «Чень», «мены» — мелкий английский текст в кадрах ролика
 * (6, 33–39, 95–97 с). Шаг 35c: «Баева», «Бекаа», «База» — «Belgrade» в плашке «Где я» камеры поверх
 * тёмного кадра (ролик, 43–60 с); «зате» — «same» в «same type · same room» (кадр 18, ×2).
 * Шаг 36 (кадры пересняты с именем Dokazio): «баню» — кнопка «Dokazio» в меню (act.webp), «огце» — «orders»
 * в наклонном кадре OG, «ОМЕВОЧЕ» — «OVERDUE» в шапке таблицы (reports.webp); ролик: «падег» — «manager» в подписи
 * (73 с), «ЗАНВАРЕТТЬИ» — наложение двух английских строк при переходе (85 с), «леск» — обрезанное «check» (86–89 с).
 * Новое слово сюда — только после просмотра кадра.
 */
const KNOWN_NOISE = new Set(['Чопег', 'РНОТОЗ', 'нмде', 'Чень', 'мены', 'Баева', 'Бекаа', 'База', 'зате',
  'баню', 'огце', 'ОМЕВОЧЕ', 'падег', 'ЗАНВАРЕТТЬИ', 'леск']);
/**
 * Исключения — файл, где кириллица есть, но это не интерфейс и не демо-данные (с причиной в отчёте).
 * 08 — подложка карты OpenStreetMap (без ключа CARTO) подписывает города на местном языке
 * («Москва», «Беларусь»); интерфейс на кадре английский. Переснять с ключом: MAP_TILE_KEY в env.json.
 */
const ALLOW = { 'docs/screens/pitch/08-world-map-desktop.png': 'подложка карты OSM: местные названия городов' };
/** Похожие кириллические буквы → латиница: OCR rus+eng читает «Helpy» как «Неlру». */
const LOOK = { А: 'A', В: 'B', Е: 'E', К: 'K', М: 'M', Н: 'H', О: 'O', Р: 'P', С: 'C', Т: 'T', У: 'Y', Х: 'X',
  а: 'a', е: 'e', о: 'o', р: 'p', с: 'c', у: 'y', х: 'x', І: 'l', і: 'i', '1': 'l', '|': 'l' };
/**
 * Старое имя продукта в кадре (шаг 36). Можно: адрес …/hey-helpy/ и бот @HeyHelpy_bot — их не меняют.
 * Возвращает найденные слова (пусто — всё в порядке).
 */
export function oldNameWords(text) {
  const t = text.replace(/[А-Яа-яІі1|]/g, (c) => LOOK[c] ?? c)
    .replace(/hey-helpy/gi, '').replace(/heyhelpy[\s_.]*bot/gi, '');
  return t.match(/\b\S*h[e3]lp[yv]\S*|\bhey\W+h[e3]l?p[yv]\b|ctrl\s*site/gi) || [];
}
export function cyrillicWords(text) {
  return (text.match(/[A-Za-zА-Яа-яЁё]{4,}/g) || [])
    .filter((w) => !/[A-Za-z]/.test(w) && STRONG.test(w) && !IMPOSSIBLE.test(w) && !KNOWN_NOISE.has(w));
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
/** Шаг 36: имя ищем отдельным проходом только с английским — rus+eng читает «Hey Helpy» как «Hey Неру». */
const ocrEn = (png) => run('tesseract', [png, '-', '-l', 'eng', '--psm', '11']);

const rows = [];
let n = 0;
for (const f of files) {
  const rel = relative(root, f);
  let words = [];
  let old = [];
  if (/\.(mp4|webm)$/.test(f)) {
    const dir = join(tmp, `v${n++}`);
    run('mkdir', ['-p', dir]);
    run('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-i', f, '-vf', 'fps=1', join(dir, '%04d.png')]);
    const frames = readdirSync(dir).sort();
    const bad = [];
    for (const fr of frames) {
      const png = join(dir, fr);
      const w = cyrillicWords(ocr(png));
      const o = oldNameWords(ocrEn(png));
      if (w.length || o.length) bad.push(`${Number(fr.slice(0, 4)) - 1} с`);
      words.push(...w);
      old.push(...o);
    }
    rows.push({ rel: `${rel} (${frames.length} кадров)`, words, old, note: bad.length ? `кадры: ${bad.slice(0, 6).join(', ')}${bad.length > 6 ? '…' : ''}` : '' });
  } else {
    const png = toPng(f, `i${n++}`);
    words = cyrillicWords(ocr(png));
    old = oldNameWords(ocrEn(png));
    rows.push({ rel, words, old, note: '' });
  }
  const r = rows.at(-1);
  const all = [...r.words, ...r.old];
  console.log(`${all.length ? '✗' : '✓'} ${r.rel}${all.length ? ` — ${all.length}: ${[...new Set(all)].slice(0, 6).join(', ')}` : ''}`);
}
rmSync(tmp, { recursive: true, force: true });

// Исключение снимает только кириллицу; старое имя продукта не прощается никогда (шаг 36).
for (const r of rows) if (r.words.length && ALLOW[r.rel]) { r.note = `исключение: ${ALLOW[r.rel]}`; r.allowed = true; }
const bad = rows.filter((r) => (r.words.length && !r.allowed) || r.old.length);
if (mdOut) {
  const md = ['| Файл | Кириллица / «Helpy» | Примеры |', '|---|---|---|', ...rows.map((r) => `| \`${r.rel}\` | ${r.words.length ? (r.allowed ? `исключение (${r.words.length})` : `да (${r.words.length})`) : 'нет'}${r.old.length ? ` · **старое имя (${r.old.length})**` : ''} | ${[...new Set([...r.old, ...r.words])].slice(0, 5).join(', ')}${r.note ? ` (${r.note})` : ''} |`)].join('\n');
  writeFileSync(mdOut, md + '\n');
}
console.log(bad.length ? `\nС кириллицей или «Helpy»: ${bad.length} из ${rows.length}` : `\n✓ кириллицы и «Helpy» нет: ${rows.length} файлов`);
process.exit(bad.length ? 1 : 0);
export { basename };
