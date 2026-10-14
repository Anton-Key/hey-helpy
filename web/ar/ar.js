// Шаг 25 — WebXR-демо «AR-метки» (без сборщика; модули с jsDelivr, точные версии).
// Сценарий: «Начать AR» → прицел-кольцо на поверхности → касание ставит метку →
// выбрать оборудование → над меткой табличка «КД-301 · 1 открытая заявка · ТО 31.10».
// До 5 меток; живут, пока открыта страница. Данные — под RLS вошедшего
// пользователя (сессия приложения из localStorage того же сайта, anon-ключ).
const SUPABASE_JS = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/+esm';
const THREE_JS = 'https://cdn.jsdelivr.net/npm/three@0.169.0/build/three.module.js';
const MAX_MARKERS = 5;

// ---------------------------------------------------------------------------
// Язык — как у приложения (flutter.locale), иначе язык браузера.
// ---------------------------------------------------------------------------
const TEXT = {
  ru: {
    brand: 'Эй, Helpy · демо', title: 'AR-метки на оборудовании',
    intro: 'Поставьте метку над прибором — над ней появится табличка с открытыми заявками и плановым ТО.',
    loading: 'Проверяю вход и поддержку AR…',
    needLogin: 'Откройте сначала приложение и войдите — эта страница берёт вход оттуда.',
    expired: 'Вход устарел. Откройте приложение (оно обновит вход) и вернитесь сюда.',
    openApp: 'Открыть приложение',
    unsupported: 'AR работает в Chrome на Android с поддержкой ARCore.',
    unsupportedHint: 'На iPhone, в Firefox и на компьютере — «Камера-помощник»: навести камеру на прибор и нажать «Что это?».',
    openCamera: 'Открыть «Камеру-помощник»',
    startAr: 'Начать AR',
    howTo: 'Медленно поводите телефоном по стене или полу — появится кольцо. Коснитесь экрана, чтобы поставить метку, и выберите оборудование.',
    ephemeral: 'Метки живут, пока открыта страница: это демо, они нигде не сохраняются.',
    pickAsset: 'Что здесь стоит?',
    place: 'Оборудование: {place}', placeAll: 'всё оборудование объекта',
    noAssets: 'Здесь нет оборудования в реестре.',
    hintScan: 'Наведите на поверхность — появится кольцо',
    hintTap: 'Коснитесь, чтобы поставить метку ({n} из {max})',
    hintMax: 'Уже {max} меток — это предел демо',
    noOpen: 'нет открытых заявок', maint: 'ТО {date}', overdue: 'ТО просрочено',
    error: 'Не получилось: {e}',
  },
  en: {
    brand: 'Hey Helpy · demo', title: 'AR tags on equipment',
    intro: 'Place a tag over a unit — a label shows its open work orders and next maintenance.',
    loading: 'Checking sign-in and AR support…',
    needLogin: 'Open the app and sign in first — this page uses the app’s sign-in.',
    expired: 'Your sign-in has expired. Open the app (it will refresh it) and come back.',
    openApp: 'Open the app',
    unsupported: 'AR works in Chrome on Android with ARCore.',
    unsupportedHint: 'On iPhone, in Firefox and on a computer use the camera assistant: point the camera at the unit and tap “What is it?”.',
    openCamera: 'Open the camera assistant',
    startAr: 'Start AR',
    howTo: 'Slowly move the phone over a wall or floor until a ring appears. Tap the screen to place a tag and choose the equipment.',
    ephemeral: 'Tags live while this page is open: it’s a demo, nothing is saved.',
    pickAsset: 'What is here?',
    place: 'Equipment: {place}', placeAll: 'all equipment on site',
    noAssets: 'No registered equipment here.',
    hintScan: 'Point at a surface until a ring appears',
    hintTap: 'Tap to place a tag ({n} of {max})',
    hintMax: '{max} tags already — the demo limit',
    noOpen: 'no open work orders', maint: 'maintenance {date}', overdue: 'maintenance overdue',
    error: 'Something went wrong: {e}',
  },
};
function appLocale() {
  try {
    const v = JSON.parse(localStorage.getItem('flutter.locale') ?? 'null');
    if (v === 'ru' || v === 'en') return v;
  } catch {}
  return (navigator.language || 'en').toLowerCase().startsWith('ru') ? 'ru' : 'en';
}
const LANG = appLocale();
const t = (k, p = {}) => TEXT[LANG][k].replace(/\{(\w+)\}/g, (_, x) => p[x] ?? '');
function openOrdersText(n) {
  if (n === 0) return t('noOpen');
  if (LANG === 'en') return `${n} open work order${n === 1 ? '' : 's'}`;
  const m10 = n % 10, m100 = n % 100;
  const w = m10 === 1 && m100 !== 11 ? 'открытая заявка'
    : m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14) ? 'открытые заявки' : 'открытых заявок';
  return `${n} ${w}`;
}
document.documentElement.lang = LANG;
for (const el of document.querySelectorAll('[data-t]')) el.textContent = t(el.dataset.t);

// ---------------------------------------------------------------------------
// Вход: сессия приложения и адрес базы (lib/core/web_bridge.dart).
// ---------------------------------------------------------------------------
const $ = (id) => document.getElementById(id);
const params = new URLSearchParams(location.search);
const locationId = params.get('location');
const objectId = params.get('object');
const cameraLink = `../#/camera${locationId ? `?location=${encodeURIComponent(locationId)}`
  : objectId ? `?object=${encodeURIComponent(objectId)}` : ''}`;
$('to-camera').href = cameraLink;
$('to-camera2').href = cameraLink;

function show(id) {
  for (const s of ['state-loading', 'state-login', 'state-unsupported', 'state-ready']) $(s).hidden = s !== id;
}
function fail(e) {
  $('error').hidden = false;
  $('error').textContent = t('error', { e: String(e?.message ?? e).slice(0, 160) });
}

function readSession() {
  let cfg = null;
  try { cfg = JSON.parse(localStorage.getItem('hh.web.supabase') ?? 'null'); } catch {}
  let session = null;
  for (let i = 0; i < localStorage.length; i++) {
    const k = localStorage.key(i);
    if (!/^sb-.+-auth-token$/.test(k)) continue;
    try { session = JSON.parse(localStorage.getItem(k)); } catch {}
  }
  return { cfg, session };
}

let db = null;
let assets = [];

async function init() {
  const { cfg, session } = readSession();
  if (!cfg?.url || !cfg?.anonKey || !session?.access_token) {
    show('state-login');
    return;
  }
  if (session.expires_at && session.expires_at * 1000 < Date.now() + 30_000) {
    $('state-login').querySelector('p').textContent = t('expired');
    show('state-login');
    return;
  }
  const xrOk = !!navigator.xr && await navigator.xr.isSessionSupported('immersive-ar').catch(() => false);
  if (!xrOk) {
    show('state-unsupported');
    return;
  }
  const { createClient } = await import(SUPABASE_JS);
  // Только чтение под RLS пользователя: токен приложения в заголовке, своя
  // сессия supabase-js не хранится и не обновляется (вход ведёт приложение).
  db = createClient(cfg.url, cfg.anonKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false, storageKey: 'hh-ar' },
    global: { headers: { Authorization: `Bearer ${session.access_token}` } },
  });
  await loadAssets();
  show('state-ready');
}

async function loadAssets() {
  let placeName = t('placeAll');
  let q;
  if (locationId) {
    const { data: loc } = await db.from('locations').select('name,code').eq('id', locationId).maybeSingle();
    if (loc) placeName = [loc.code, loc.name].filter(Boolean).join(' · ');
    q = db.from('assets').select('id,name,meta,location_id').eq('location_id', locationId);
  } else if (objectId) {
    q = db.from('assets').select('id,name,meta,location_id,locations!inner(object_id)').eq('locations.object_id', objectId);
  } else {
    q = db.from('assets').select('id,name,meta,location_id');
  }
  const { data, error } = await q.order('name').limit(40);
  if (error) throw error;
  assets = data ?? [];
  $('place').textContent = t('place', { place: placeName });
  const list = $('assets');
  list.innerHTML = '';
  if (!assets.length) {
    list.innerHTML = `<p class="muted">${t('noAssets')}</p>`;
    $('start-ar').disabled = true;
  }
  for (const a of assets.slice(0, 8)) {
    const row = document.createElement('div');
    row.className = 'row';
    row.innerHTML = '<div class="t"></div>';
    row.querySelector('.t').textContent = a.name;
    list.append(row);
  }
}

/** Короткое имя: «КД-301» из «Кондиционер КД-301». */
function shortName(name) {
  const w = name.trim().split(/\s+/).reverse().find((x) => /\d/.test(x) && x.length <= 16);
  return w ?? (name.length <= 22 ? name : name.slice(0, 21) + '…');
}

/** «1 открытая заявка · ТО 31.10» — под RLS пользователя. */
async function factsLine(assetId) {
  const today = new Date().toISOString().slice(0, 10);
  const [open, ppr] = await Promise.all([
    db.from('work_orders').select('id', { count: 'exact', head: true })
      .eq('asset_id', assetId).is('plan_id', null).not('status', 'in', '(done,cancelled)'),
    db.from('work_orders').select('period_end').eq('asset_id', assetId)
      .not('plan_id', 'is', null).not('status', 'in', '(done,cancelled)').order('period_end').limit(1),
  ]);
  const parts = [openOrdersText(open.count ?? 0)];
  const end = ppr.data?.[0]?.period_end;
  if (end) {
    const [, m, d] = end.split('-');
    parts.push(end < today ? t('overdue') : t('maint', { date: `${d}.${m}` }));
  }
  return parts.join(' · ');
}

// ---------------------------------------------------------------------------
// AR: three.js + WebXR (immersive-ar, hit-test; dom-overlay и anchors — если есть).
// ---------------------------------------------------------------------------
let THREE, renderer, scene, camera, reticle, hitSource, lastHit, session;
const markers = [];
let pickingFor = null;

function labelTexture(title, sub) {
  const c = document.createElement('canvas');
  c.width = 640; c.height = 200;
  const g = c.getContext('2d');
  g.fillStyle = 'rgba(255,255,255,0.96)';
  g.beginPath(); g.roundRect(8, 8, 624, 184, 36); g.fill();
  g.fillStyle = '#2DB89A';
  g.beginPath(); g.roundRect(8, 8, 18, 184, [36, 0, 0, 36]); g.fill();
  g.fillStyle = '#0F1A17';
  g.font = '600 64px Onest, sans-serif';
  g.fillText(title, 52, 88, 560);
  g.fillStyle = '#5B6763';
  g.font = '400 40px Onest, sans-serif';
  g.fillText(sub, 52, 152, 560);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

function makeMarker(matrix) {
  const group = new THREE.Group();
  group.matrixAutoUpdate = false;
  group.matrix.copy(matrix);
  const pin = new THREE.Mesh(new THREE.SphereGeometry(0.015, 16, 12),
    new THREE.MeshBasicMaterial({ color: 0x2DB89A }));
  group.add(pin);
  const sprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: labelTexture('…', ''), depthTest: false }));
  sprite.scale.set(0.32, 0.1, 1);
  sprite.position.set(0, 0.14, 0);
  group.add(sprite);
  scene.add(group);
  return { group, sprite, anchor: null, asset: null };
}

async function setMarkerAsset(m, asset) {
  m.asset = asset;
  const title = shortName(asset.name);
  m.sprite.material.map?.dispose();
  m.sprite.material.map = labelTexture(title, '…');
  m.sprite.material.needsUpdate = true;
  try {
    const sub = await factsLine(asset.id);
    m.sprite.material.map.dispose();
    m.sprite.material.map = labelTexture(title, sub);
    m.sprite.material.needsUpdate = true;
  } catch (e) {
    console.warn('facts', e?.message);
  }
}

function hint() {
  $('hint').textContent = markers.length >= MAX_MARKERS ? t('hintMax', { max: MAX_MARKERS })
    : reticle?.visible ? t('hintTap', { n: markers.length + 1, max: MAX_MARKERS }) : t('hintScan');
}

function showPicker(m) {
  pickingFor = m;
  const list = $('picker-list');
  list.innerHTML = '';
  const used = new Set(markers.map((x) => x.asset?.id).filter(Boolean));
  for (const a of assets) {
    const b = document.createElement('button');
    b.className = 'asset';
    b.textContent = a.name + (used.has(a.id) ? ' ✓' : '');
    b.addEventListener('click', () => {
      $('picker').hidden = true;
      pickingFor = null;
      setMarkerAsset(m, a);
    });
    list.append(b);
  }
  $('picker').hidden = false;
}

function onSelect() {
  if (pickingFor || !reticle.visible || markers.length >= MAX_MARKERS) return;
  const m = makeMarker(reticle.matrix);
  markers.push(m);
  const hit = lastHit;
  if (hit?.createAnchor) hit.createAnchor().then((a) => { m.anchor = a; }).catch(() => {});
  if (session.domOverlayState) {
    showPicker(m);
  } else {
    // Без dom-overlay списка поверх AR нет — по очереди из списка помещения.
    const used = new Set(markers.map((x) => x.asset?.id).filter(Boolean));
    const next = assets.find((a) => !used.has(a.id)) ?? assets[0];
    if (next) setMarkerAsset(m, next);
  }
  hint();
}

async function startAr() {
  $('start-ar').disabled = true;
  try {
    THREE ??= await import(THREE_JS);
    const overlay = $('overlay');
    session = await navigator.xr.requestSession('immersive-ar', {
      requiredFeatures: ['hit-test'],
      optionalFeatures: ['dom-overlay', 'anchors'],
      domOverlay: { root: overlay },
    });
    overlay.hidden = false;
    // Касание списка поверх AR не ставит метку.
    $('picker').addEventListener('beforexrselect', (e) => e.preventDefault());
    $('end-ar').addEventListener('beforexrselect', (e) => e.preventDefault());

    renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setPixelRatio(window.devicePixelRatio);
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.xr.enabled = true;
    renderer.xr.setReferenceSpaceType('local');
    document.body.append(renderer.domElement);
    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(70, window.innerWidth / window.innerHeight, 0.01, 20);

    reticle = new THREE.Mesh(new THREE.RingGeometry(0.05, 0.065, 32).rotateX(-Math.PI / 2),
      new THREE.MeshBasicMaterial({ color: 0x2DB89A }));
    reticle.matrixAutoUpdate = false;
    reticle.visible = false;
    scene.add(reticle);

    await renderer.xr.setSession(session);
    const viewer = await session.requestReferenceSpace('viewer');
    hitSource = await session.requestHitTestSource({ space: viewer });
    renderer.xr.getController(0).addEventListener('select', onSelect);
    session.addEventListener('end', onEnd);
    hint();

    renderer.setAnimationLoop((_, frame) => {
      if (!frame) return;
      const ref = renderer.xr.getReferenceSpace();
      const hits = frame.getHitTestResults(hitSource);
      const was = reticle.visible;
      if (hits.length) {
        lastHit = hits[0];
        const pose = hits[0].getPose(ref);
        reticle.visible = !!pose;
        if (pose) reticle.matrix.fromArray(pose.transform.matrix);
      } else {
        lastHit = null;
        reticle.visible = false;
      }
      if (was !== reticle.visible) hint();
      for (const m of markers) {
        if (!m.anchor) continue;
        const p = frame.getPose(m.anchor.anchorSpace, ref);
        if (p) m.group.matrix.fromArray(p.transform.matrix);
      }
      renderer.render(scene, camera);
    });
  } catch (e) {
    fail(e);
    $('start-ar').disabled = false;
  }
}

function onEnd() {
  renderer?.setAnimationLoop(null);
  hitSource?.cancel?.();
  hitSource = null;
  renderer?.domElement.remove();
  renderer?.dispose();
  for (const m of markers) m.anchor?.delete?.();
  markers.length = 0;
  pickingFor = null;
  $('picker').hidden = true;
  $('overlay').hidden = true;
  $('start-ar').disabled = false;
}

$('start-ar').addEventListener('click', startAr);
$('end-ar').addEventListener('click', () => session?.end());
init().catch((e) => { show('state-ready'); fail(e); });
