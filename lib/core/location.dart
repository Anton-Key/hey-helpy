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
