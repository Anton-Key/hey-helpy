// Кадр питча 22 (шаг 25): МАКЕТ чата с ботом @HeyHelpy_bot — гость по QR
// написал о поломке, бот принял заявку и потом прислал «выполнена ✅» с фото
// «после». Тексты — как у бота (supabase/functions/telegram-bot/texts.ts:
// created, notifyDone, bNotifyOff); фото — нарисованная картинка
// assets/demo_photos/ac_after.jpg. Это HTML-макет, не снимок настоящего
// Telegram: оформление общее «чатное», без логотипов и фирменных знаков.
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node tg_notify_mock.mjs
// → docs/screens/pitch/22-telegram-done-phone.png
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { chromium } from 'playwright';

const ROOT = join(import.meta.dirname, '../..');
const OUT = join(ROOT, 'docs/screens/pitch/22-telegram-done-phone.png');
const photo = readFileSync(join(ROOT, 'assets/demo_photos/ac_after.jpg')).toString('base64');
const font = (w) => readFileSync(join(ROOT, `assets/fonts/Onest-${w}.ttf`)).toString('base64');

const number = '7F3A2C';
const title = 'Капает вода с кондиционера';

const html = `<!doctype html><html lang="ru"><head><meta charset="utf-8">
<style>
@font-face{font-family:Onest;src:url(data:font/ttf;base64,${font('Regular')});font-weight:400}
@font-face{font-family:Onest;src:url(data:font/ttf;base64,${font('Medium')});font-weight:500}
@font-face{font-family:Onest;src:url(data:font/ttf;base64,${font('SemiBold')});font-weight:600}
*{box-sizing:border-box;margin:0}
body{width:412px;height:915px;font-family:Onest,sans-serif;background:#d9e4dc;color:#0f1a17;display:flex;flex-direction:column}
.top{background:#fff;padding:14px 16px;display:flex;align-items:center;gap:12px;border-bottom:1px solid #e6eae8}
.back{font-size:26px;color:#0b7a62;width:18px}
.ava{width:42px;height:42px;border-radius:50%;background:#2db89a;color:#062b23;display:flex;align-items:center;justify-content:center;font-weight:600;font-size:15px}
.name{font-weight:600;font-size:17px}.sub{font-size:13px;color:#5b6763}
.chat{flex:1;padding:14px 10px;display:flex;flex-direction:column;gap:8px;justify-content:flex-end;
  background-image:radial-gradient(rgba(255,255,255,.35) 1px,transparent 1px);background-size:18px 18px}
.day{align-self:center;background:rgba(15,26,23,.35);color:#fff;font-size:12.5px;padding:3px 10px;border-radius:12px;margin:4px 0}
.msg{max-width:84%;padding:8px 11px 6px;border-radius:16px;font-size:15.5px;line-height:1.35;position:relative;box-shadow:0 1px 1px rgba(0,0,0,.08)}
.in{align-self:flex-start;background:#fff;border-bottom-left-radius:6px}
.out{align-self:flex-end;background:#e2f4ef;border-bottom-right-radius:6px}
.t{font-size:11.5px;color:#7c8783;text-align:right;margin-top:2px}
.photo{padding:3px;overflow:hidden}
.photo img{display:block;width:100%;border-radius:13px 13px 4px 4px}
.photo .cap{padding:7px 8px 2px}
.btn{align-self:flex-start;width:84%;margin-top:-4px;background:rgba(255,255,255,.75);border-radius:10px;text-align:center;padding:9px;font-size:14.5px;font-weight:500;color:#0b7a62}
.bar{background:#fff;padding:10px 14px;display:flex;align-items:center;gap:10px;border-top:1px solid #e6eae8}
.field{flex:1;background:#f2f4f3;border-radius:20px;padding:10px 14px;color:#a3ada9;font-size:15px}
.mic{width:40px;height:40px;border-radius:50%;background:#2db89a}
b{font-weight:600}
</style></head><body>
<div class="top"><div class="back">‹</div><div class="ava">EH</div>
  <div><div class="name">Hey Helpy</div><div class="sub">бот · @HeyHelpy_bot</div></div></div>
<div class="chat">
  <div class="day">Сегодня</div>
  <div class="msg out">В переговорной 301 с кондиционера капает вода на ковёр<div class="t">09:12 ✓✓</div></div>
  <div class="msg in">Заявка № ${number} принята. Менеджер уже видит её.<div class="t">09:12</div></div>
  <div class="msg in">Заявка № ${number} «${title}»: взята в работу 🔧<div class="t">10:05</div></div>
  <div class="msg in photo"><img src="data:image/jpeg;base64,${photo}" alt="">
    <div class="cap">Заявка № ${number} «${title}»: <b>выполнена ✅</b><div class="t">11:40</div></div></div>
  <div class="btn">🔕 Не присылать уведомления</div>
</div>
<div class="bar"><div class="field">Сообщение</div><div class="mic"></div></div>
</body></html>`;

const browser = await chromium.launch({ args: ['--disable-dev-shm-usage'] });
const page = await browser.newPage({ viewport: { width: 412, height: 915 }, deviceScaleFactor: 2 });
await page.setContent(html, { waitUntil: 'load' });
await page.evaluate(() => document.fonts.ready);
await page.screenshot({ path: OUT });
await browser.close();
try { execFileSync('pngquant', ['--force', '--skip-if-larger', '--quality=70-95', '--ext', '.png', OUT]); } catch {}
console.log(`✅ ${OUT}`);
