import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/design/design.dart';
import '../../l10n/app_localizations.dart';
import 'photo_section.dart' show PhotoGeofence;
import 'photo_stamp_encode.dart' deferred as stamp_encode;

/// Что вжечь в фото «после» (шаг 26): объект и помещение заявки, геозона.
class PhotoStamp {
  const PhotoStamp({this.object, this.place, this.geofence});
  final String? object;
  final String? place;
  final PhotoGeofence? geofence;
}

/// Строка штампа: «14.10.2026 14:19 · БЦ «Демо» · 301 Переговорная · в
/// геозоне». Геозона — только если есть и координаты снимка, и объекта.
String stampText(AppLocalizations l, PhotoStamp s,
    {required DateTime at, double? lat, double? lng}) {
  String? zone;
  final g = s.geofence;
  if (g != null && lat != null && lng != null) {
    final d = const Distance()
        .as(LengthUnit.Meter, LatLng(lat, lng), LatLng(g.lat, g.lng));
    zone = d <= g.radiusM ? l.stampInZone : l.stampOutOfZone;
  }
  return [
    DateFormat('dd.MM.yyyy HH:mm').format(at.toLocal()),
    if (s.object?.isNotEmpty == true) s.object!,
    if (s.place?.isNotEmpty == true) s.place!,
    if (zone != null) zone,
  ].join(' · ');
}

/// Вжигает [text] полупрозрачной полосой внизу снимка и возвращает JPEG.
/// Рисует Flutter (шрифт Onest — кириллица), кодирует пакет image
/// (отложенно). Не получилось — null: загружается снимок без штампа.
Future<Uint8List?> stampJpeg(Uint8List jpeg, String text) async {
  try {
    final codec = await ui.instantiateImageCodec(jpeg);
    final src = (await codec.getNextFrame()).image;
    final w = src.width, h = src.height;
    final font = (w / 42).clamp(12.0, 40.0);
    final pad = font * 0.7;
    final painter = TextPainter(
      text: TextSpan(
          text: text,
          style: AppText.callout.copyWith(
              fontSize: font,
              height: 1.25,
              color: AppColors.onCamera,
              fontWeight: FontWeight.w600)),
      textDirection: ui.TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: w - pad * 2);
    final bar = painter.height + pad * 2;

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawImage(src, Offset.zero, Paint());
    canvas.drawRect(Rect.fromLTWH(0, h - bar, w.toDouble(), bar),
        Paint()..color = AppColors.cameraOverlay);
    painter.paint(canvas, Offset(pad, h - bar + pad));
    final out = await rec.endRecording().toImage(w, h);
    final rgba = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
    src.dispose();
    out.dispose();
    if (rgba == null) return null;
    await stamp_encode.loadLibrary();
    return stamp_encode.rgbaToJpeg(rgba.buffer.asUint8List(), w, h);
  } catch (_) {
    return null;
  }
}
