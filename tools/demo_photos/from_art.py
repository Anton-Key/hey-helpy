#!/usr/bin/env python3
"""Демо-фото из иллюстраций художника (шаг 35c).

Из PNG художника в assets/marketing/ (исходники не меняются) вырезаются
фрагменты под сюжеты демо-фото и сохраняются в assets/demo_photos/ —
те же имена, тот же размер 1280×960 (4:3), JPEG. В кадре нет надписей и
интерфейсных плашек художника: карточки, подписи и стрелки остаются за
краем кадра, а светящийся контур, линия-выноска и точка, которые заходят
в кадр, стираются (заливка соседними пикселями стены и потолка, без
дорисовки текста).

  ac_indoor.jpg — «до»: внутренний блок кондиционера, подтёк и капли на
                  стене (hotel_ac). Он же фон «Камеры-помощника»
                  (VOICE_MOCK, /screens, --pitch), снимок «Узнать по фото»
                  и проверка «Готовность к показу».
  ac_after.jpg  — «после»: тот же блок и тот же кадр, подтёк и капли убраны.
  *_tall.jpg    — те же сюжеты кадром 1:2 для заглушки камеры на высоком
                  экране телефона (на ПК — кадры 4:3).

Угол каждого снимка — маленькая пометка «DEMO»: это нарисованная картинка,
а не фото объекта.

Запуск (нужен только Pillow): python3 tools/demo_photos/from_art.py
Проверка: каждый файл ≤ 300 КБ, 1280×960.
"""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageMath

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'assets/marketing'
OUT = ROOT / 'assets/demo_photos'
FONT = ROOT / 'assets/fonts'
SIZE = (1280, 960)
MAX_BYTES = 300 * 1024

# hotel_ac.png 1672×941: блок кондиционера ≈ x 415–720, y 30–170; карточка
# художника начинается с x 887, рамка с картиной — x 815+. Кадр 4:3 с блоком
# по центру по горизонтали и в верхней четверти, изголовье кровати (y ≥ 378)
# за краем — AC-301 в демо стоит в переговорной (там «Камера-помощник»
# поднимает зелёную рамку над карточкой).
AC_CROP = (322, 6, 810, 372)
# Вертикальный кадр 1:2 для «живой камеры» на телефоне.
TALL_CROP = (347, 6, 787, 886)
TALL_SIZE = (720, 1440)


def teal_masks(img):
    """Светящийся бирюзовый контур художника: (ядро — яркая линия, ореол)."""
    r, g, b = img.split()
    # бирюза: G и B выше R (стены, потолок и сам блок — R ≥ G ≥ B или серые)
    ex = ImageChops.darker(ImageChops.subtract(g, r), ImageChops.subtract(b, r))
    core = ex.point(lambda v: 255 if v > 45 else 0).filter(ImageFilter.MaxFilter(5))
    # свечение тянется ~30 px от линии; у стены свой оттенок (G < R), поэтому
    # ореол — вся полоса, кроме светлого корпуса блока (его свечение не задело)
    band = core.filter(ImageFilter.MaxFilter(61))
    body = ImageChops.multiply(r.point(lambda v: 255 if v > 175 else 0),
                               b.point(lambda v: 255 if v > 165 else 0))
    halo = ImageChops.lighter(ImageChops.subtract(band, body), core)
    return core, halo


# Оттенок свечения художника (доли R : G : B), замерен по контуру.
GLOW = (0.25, 1.0, 0.92)


def fix_chroma(img, halo):
    """Ореол — добавленный бирюзовый свет: obs = base + a·GLOW. Оттенок
    чистого пикселя (G/R, B/R) берётся у соседей вне ореола, из него
    находится доля свечения a, и она вычитается из всех трёх каналов."""
    r, g, b = [c.convert('F') for c in img.split()]
    valid = ImageChops.invert(halo)
    ratios = []
    for c in (g, b):
        ratio_l = ImageMath.eval('convert(min(c * 100.0 / max(r, 1.0), 255.0), "L")', c=c, r=r)
        num = ImageChops.multiply(ratio_l, valid)
        fill = None
        for rad in (30, 12, 5):
            wl = valid.filter(ImageFilter.GaussianBlur(rad))
            f = ImageMath.eval('min(n * 255.0 / max(w, 0.01), 255.0) / 100.0',
                               n=num.filter(ImageFilter.GaussianBlur(rad)).convert('F'), w=wl.convert('F'))
            enough = wl.point(lambda v: 255 if v > 60 else 0)
            fill = f if fill is None else Image.composite(f, fill, enough)
        # у края картинки соседей мало — оттенок не дальше, чем у стены и корпуса
        f = ImageMath.eval('convert(min(max(f, 0.6), 1.08) * 200.0, "L")', f=fill)
        ratios.append(f.filter(ImageFilter.GaussianBlur(3)).convert('F').point(lambda v: v / 200.0))
    tr, tg, tb = GLOW
    a = ImageMath.eval('max((g - kg * r) / max(tg - kg * tr, 0.05), 0.0)',
                       g=g, r=r, kg=ratios[0], tg=tg, tr=tr)
    r0 = ImageMath.eval('max(r - a * tr, 0.0)', r=r, a=a, tr=tr)
    chans = [ImageMath.eval('convert(min(r0, 255.0), "L")', r0=r0),
             ImageMath.eval('convert(min(r0 * k, 255.0), "L")', r0=r0, k=ratios[0]),
             ImageMath.eval('convert(min(r0 * k, 255.0), "L")', r0=r0, k=ratios[1])]
    fixed = Image.merge('RGB', chans)
    # в тёмной тени у потолка свечения почти нет, а оценка шумит — там
    # только оттенок соседей при той же яркости R
    tint = Image.merge('RGB', [img.split()[0],
                               ImageMath.eval('convert(min(r * k, 255.0), "L")', r=r, k=ratios[0]),
                               ImageMath.eval('convert(min(r * k, 255.0), "L")', r=r, k=ratios[1])])
    bright = img.split()[0].point(lambda v: max(0, min(255, (v - 90) * 6)))
    fixed = Image.composite(fixed, tint, bright.filter(ImageFilter.GaussianBlur(2)))
    return Image.composite(fixed, img, halo.filter(ImageFilter.GaussianBlur(1)))


def clone(img, mask, dx, dy):
    """«Штамп»: участок, сдвинутый на (dx, dy), — поверх маски с мягким краем."""
    src = ImageChops.offset(img, -dx, -dy)
    return Image.composite(src, img, mask.filter(ImageFilter.GaussianBlur(8)))


def inpaint(img, mask, radii=(3, 8, 20, 50)):
    """Заливка маски по соседям: нормированная свёртка от мелкого радиуса к
    крупному (где рядом мало «чистых» пикселей — берётся крупный радиус)."""
    valid = ImageChops.invert(mask)
    out = img.copy()
    todo = mask
    for r in reversed(radii):  # сначала крупный — покрывает всё
        wl = valid.filter(ImageFilter.GaussianBlur(r))
        w = wl.convert('F')
        bands = []
        for band in img.split():
            num = ImageChops.multiply(band, valid).filter(ImageFilter.GaussianBlur(r)).convert('F')
            bands.append(ImageMath.eval('convert(min(n * 255.0 / max(w, 0.01), 255.0), "L")',
                                        n=num, w=w))
        fill = Image.merge('RGB', bands)
        enough = wl.point(lambda v: 255 if v > 40 else 0)
        out = Image.composite(fill, out, ImageChops.multiply(todo, enough))
    # мягкий край, чтобы не было шва
    soft = mask.filter(ImageFilter.GaussianBlur(1.5))
    return Image.composite(out, img, soft)


def line_mask(size, p0, p1, width, dots=()):
    m = Image.new('L', size, 0)
    d = ImageDraw.Draw(m)
    d.line([p0, p1], fill=255, width=width)
    for (x, y, rad) in dots:
        d.ellipse((x - rad, y - rad, x + rad, y + rad), fill=255)
    return m


def demo_badge(img, size=SIZE):
    """Маленькая пометка «DEMO» в правом верхнем углу."""
    d = ImageDraw.Draw(img, 'RGBA')
    try:
        font = ImageFont.truetype(str(FONT / 'Onest-SemiBold.ttf'), 22)
    except OSError:
        font = ImageFont.load_default()
    text = 'DEMO'
    x0, y0, x1, y1 = d.textbbox((0, 0), text, font=font)
    w, h = x1 - x0, y1 - y0
    pad = 10
    X = size[0] - w - 2 * pad - 24
    Y = 24
    d.rounded_rectangle((X, Y, X + w + 2 * pad, Y + h + 2 * pad), radius=10, fill=(0, 0, 0, 110))
    d.text((X + pad - x0, Y + pad - y0), text, font=font, fill=(255, 255, 255, 230))
    return img


def finish(img, name, size=SIZE):
    img = img.resize(size, Image.LANCZOS)
    img = img.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
    img = demo_badge(img, size)
    path = OUT / name
    for q in (84, 80, 76, 72, 68):
        img.save(path, 'JPEG', quality=q, optimize=True, progressive=True)
        if path.stat().st_size <= MAX_BYTES:
            break
    nbytes = path.stat().st_size
    assert nbytes <= MAX_BYTES, f'{name}: {nbytes} байт > 300 КБ'
    print(f'{path.relative_to(ROOT)}  {size[0]}×{size[1]}  {nbytes // 1024} КБ  q={q}')


def hotel_ac():
    src = Image.open(ART / 'hotel_ac.png').convert('RGB')
    # 1) контур художника вокруг блока: ореол — вернуть оттенок, яркую
    #    линию — залить соседями
    box = (320, 0, 800, 270)
    part = src.crop(box)
    core, halo = teal_masks(part)
    part = fix_chroma(part, halo)
    part = inpaint(part, core, radii=(2, 4, 8))
    clean = src.copy()
    clean.paste(part, box[:2])
    # 2) линия-выноска от точки на блоке к карточке и сама точка
    line = line_mask(src.size, (706, 148), (900, 214), 13, dots=[(700, 146, 15)])
    clean = inpaint(clean, line, radii=(3, 7, 14))
    # «после»: подтёк и капли под блоком закрыть чистой стеной левее
    leak = Image.new('L', src.size, 0)
    ImageDraw.Draw(leak).polygon(
        [(540, 176), (660, 176), (662, 240), (648, 310), (626, 368), (584, 370),
         (556, 330), (538, 250)], fill=255)
    fixed = clone(clean, leak, -150, 0)
    finish(clean.crop(AC_CROP), 'ac_indoor.jpg')
    finish(fixed.crop(AC_CROP), 'ac_after.jpg')
    # Вертикальные кадры для заглушки камеры на телефоне (экран ~1:2): блок
    # целиком в середине по ширине; ниже подтёка — кровать, на кадре 21 её
    # закрывает карточка.
    finish(clean.crop(TALL_CROP), 'ac_indoor_tall.jpg', TALL_SIZE)
    finish(fixed.crop(TALL_CROP), 'ac_after_tall.jpg', TALL_SIZE)


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    hotel_ac()
