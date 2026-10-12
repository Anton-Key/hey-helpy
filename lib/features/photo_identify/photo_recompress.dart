import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'photo_compress.dart';

/// Пересжатие снимка в JPEG ≤ [maxSide] px (пакет image — тяжёлый, поэтому
/// этот файл подключается отложенно: `deferred as recompress`). Качество
/// снижается ступенями, пока файл не станет меньше [maxBytes]. null —
/// картинку не удалось прочитать.
Uint8List? recompressJpeg(Uint8List bytes,
    {int maxSide = kIdentifyMaxSide,
    int quality = kIdentifyQuality,
    int maxBytes = kIdentifyMaxBytes}) {
  img.Image? src;
  try {
    src = img.decodeImage(bytes);
  } catch (_) {
    src = null; // битый или неизвестный формат
  }
  if (src == null) return null;
  final oriented = img.bakeOrientation(src);
  final (w, h) = fitWithin(oriented.width, oriented.height, maxSide: maxSide);
  final scaled = (w == oriented.width && h == oriented.height)
      ? oriented
      : img.copyResize(oriented,
          width: w, height: h, interpolation: img.Interpolation.average);
  var q = quality;
  var out = img.encodeJpg(scaled, quality: q);
  while (out.length > maxBytes && q > 40) {
    q -= 15;
    out = img.encodeJpg(scaled, quality: q);
  }
  return Uint8List.fromList(out);
}
