# Исправление опечатки на иллюстрации fridge.png: «Check thermostat seting» →
# «Check thermostat setting» (шаг 33). Исходник — assets/marketing/fridge_original.png.
# Запуск из корня репозитория: python3 tools/marketing/fix_fridge_typo.py
# Строка закрашивается вертикальным градиентом фона (цвета над и под строкой),
# затем пишется заново шрифтом приложения Onest. Координаты — для 1672×941,
# для другого размера пересчитываются пропорционально.
from PIL import Image, ImageDraw, ImageFont

SRC = 'assets/marketing/fridge_original.png'
OUT = 'assets/marketing/fridge.png'

im = Image.open(SRC).convert('RGB')
k = im.size[0] / 1672                       # масштаб относительно 1672×941
px = im.load()
x0, x1, y0, y1 = (round(v * k) for v in (350, 602, 376, 401))   # область строки
for x in range(x0, x1):
    a, b = px[x, round(372 * k)], px[x, round(405 * k)]
    for y in range(y0, y1):
        t = (y - y0) / (y1 - y0)
        px[x, y] = tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))
# Размер 17 подобран по ширине исходной строки (≈ 200 px), верх букв — y 382.
f = ImageFont.truetype('assets/fonts/Onest-Regular.ttf', round(17 * k))
ImageDraw.Draw(im).text((round(355 * k), round(378 * k)), 'Check thermostat setting', font=f, fill=(32, 60, 92))
im.save(OUT)
print('готово:', OUT)
