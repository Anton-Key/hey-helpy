import 'dart:typed_data';

/// Снимок для «Узнать по фото»: не больше 1280 px по длинной стороне, JPEG
/// ~80 % — так функция получает ≤ 1,5 МБ, а к заявке прикладывается JPEG
/// (хранилище work-photos принимает только его).
const kIdentifyMaxSide = 1280;
const kIdentifyQuality = 80;
const kIdentifyMaxBytes = 1536 * 1024;

/// Тип картинки по первым байтам: image/jpeg, image/png, image/webp; иначе null.
String? sniffImageMime(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff) {
    return 'image/jpeg';
  }
  if (b.length >= 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4e &&
      b[3] == 0x47) {
    return 'image/png';
  }
  if (b.length >= 12 &&
      String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}

/// Нужно ли пересжать снимок в приложении: не JPEG (PNG с ПК, HEIC…) или
/// больше [maxBytes]. Обычно камера (image_picker) уже отдаёт JPEG 1280 px.
bool needsRecompress(Uint8List b, {int maxBytes = kIdentifyMaxBytes}) =>
    sniffImageMime(b) != 'image/jpeg' || b.length > maxBytes;

/// Размер, вписанный в [maxSide] по длинной стороне (пропорции сохраняются,
/// меньше — не увеличиваем).
(int, int) fitWithin(int w, int h, {int maxSide = kIdentifyMaxSide}) {
  if (w <= 0 || h <= 0) return (w, h);
  final long = w > h ? w : h;
  if (long <= maxSide) return (w, h);
  final k = maxSide / long;
  int r(double v) => v.round() < 1 ? 1 : v.round();
  return (r(w * k), r(h * k));
}
