import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Разрешение на геолокацию: спрашивает, если ещё не спрашивали.
/// false — геолокация выключена или человек отказал.
Future<bool> ensureLocationPermission() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  } catch (_) {
    return false;
  }
}

/// Текущее местоположение или null (не успели за 10 секунд и нет
/// последнего известного). `isMocked` — признак подмены GPS на Android.
Future<Position?> currentPosition() async {
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
    );
  } catch (_) {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}

/// Быстрая геопозиция для формы новой заявки (шаг 24): последняя известная,
/// если она свежее 2 минут, иначе текущая — всё вместе не дольше 3 секунд.
/// Нет доступа, нет сигнала, не успели — null, без сообщений.
Future<({double lat, double lng})?> quickPosition(
    {Duration limit = const Duration(seconds: 3)}) async {
  Future<({double lat, double lng})?> find() async {
    if (!await ensureLocationPermission()) return null;
    if (!kIsWeb) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null &&
            DateTime.now().difference(last.timestamp) <
                const Duration(minutes: 2)) {
          return (lat: last.latitude, lng: last.longitude);
        }
      } catch (_) {}
    }
    final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
            accuracy: LocationAccuracy.medium, timeLimit: limit));
    return (lat: p.latitude, lng: p.longitude);
  }

  try {
    return await find().timeout(limit);
  } catch (_) {
    return null;
  }
}
