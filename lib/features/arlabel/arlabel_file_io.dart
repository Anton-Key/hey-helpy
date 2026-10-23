import 'dart:io';

import 'package:flutter/foundation.dart';

/// Снимок «AR-меток» для фото «до»: прочитать временный файл и сразу удалить
/// (снимки с камеры на телефоне не храним).
Future<Uint8List?> takeArPhoto(String path) async {
  final f = File(path);
  try {
    return await f.readAsBytes();
  } catch (e) {
    debugPrint('AR photo: ${e.runtimeType}');
    return null;
  } finally {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
