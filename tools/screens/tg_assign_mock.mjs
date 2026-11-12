// Кадр питча 28 (шаг 28, английский — шаг 35b): МАКЕТ чата исполнителя «ClimaService» с ботом
// @HeyHelpy_bot — бот присылает «New work order» с кнопкой «Open». Решение владельца (шаг 32):
// подрядчик получает и ведёт заявку в приложении, Telegram для него — только уведомления,
// поэтому в макете нет «▶️ Start work» (сам бот не менялся). Тексты — английские тексты бота
// (supabase/functions/telegram-bot/texts.ts, EN: assignNew, assignPriority, bOpen, bAssignOff).
// Это HTML-макет, не снимок настоящего Telegram: оформление общее «чатное», без логотипов.
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node tg_assign_mock.mjs
// → docs/screens/pitch/28-telegram-assign-phone.png
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { chromium } from 'playwright';

const ROOT = join(import.meta.dirname, '../..');
const OUT = join(ROOT, 'docs/screens/pitch/28-telegram-assign-phone.png');
const font = (w) => readFileSync(join(ROOT, `assets/fonts/Onest-${w}.ttf`)).toString('base64');

const html = `<!doctype html><html lang="en"><head><meta charset="utf-8">
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
.msg{max-width:88%;padding:8px 11px 6px;border-radius:16px;font-size:15.5px;line-height:1.38;position:relative;box-shadow:0 1px 1px rgba(0,0,0,.08)}
.in{align-self:flex-start;background:#fff;border-bottom-left-radius:6px}
.t{font-size:11.5px;color:#7c8783;text-align:right;margin-top:2px}
.kb{align-self:flex-start;width:88%;display:flex;flex-direction:column;gap:5px;margin-top:-3px}
.row{display:flex;gap:5px}
.btn{flex:1;background:rgba(255,255,255,.78);border-radius:10px;text-align:center;padding:10px 6px;font-size:14.5px;font-weight:500;color:#0b7a62}
.btn.main{background:#2db89a;color:#062b23;font-weight:600}
.where{color:#3a4642}
.bar{background:#fff;padding:10px 14px;display:flex;align-items:center;gap:10px;border-top:1px solid #e6eae8}
.field{flex:1;background:#f2f4f3;border-radius:20px;padding:10px 14px;color:#a3ada9;font-size:15px}
.mic{width:40px;height:40px;border-radius:50%;background:#2db89a}
b{font-weight:600}
</style></head><body>
<div class="top"><div class="back">‹</div><div class="ava">D</div>
  <div><div class="name">Dokazio</div><div class="sub">bot · @HeyHelpy_bot</div></div></div>
<div class="chat">
  <div class="day">Today</div>
  <div class="msg in"><b>🆕 New work order #5C81E0: Noisy fan in the meeting room</b><br>
    <span class="where">📍 Demo Tower · 301 Meeting room · priority: normal</span><div class="t">08:41</div></div>
  <div class="kb"><div class="row"><div class="btn">Open</div></div></div>
  <div class="msg in"><b>🆕 New work order #3F2A1C: Water dripping from the AC</b><br>
    <span class="where">📍 Demo Tower · 301 Meeting room · priority: high</span><div class="t">09:12</div></div>
  <div class="kb">
    <div class="row"><div class="btn main">Open</div></div>
    <div class="row"><div class="btn">🔕 Stop work order alerts</div></div>
  </div>
</div>
<div class="bar"><div class="field">Message</div><div class="mic"></div></div>
</body></html>`;

const browser = await chromium.launch({ args: ['--disable-dev-shm-usage'] });
const page = await browser.newPage({ viewport: { width: 412, height: 915 }, deviceScaleFactor: 2 });
await page.setContent(html, { waitUntil: 'load' });
await page.evaluate(() => document.fonts.ready);
await page.screenshot({ path: OUT });
await browser.close();
try { execFileSync('pngquant', ['--force', '--skip-if-larger', '--quality=70-95', '--ext', '.png', OUT]); } catch {}
console.log(`✅ ${OUT}`);
