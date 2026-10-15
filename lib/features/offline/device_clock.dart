import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'offline_logic.dart';

/// Часы телефона для офлайн-действий (шаг 27): время устройства,
/// монотонные часы с номером загрузки и время последнего GPS-фикса.
/// На Android — канал `hey_helpy/clock` (MainActivity.kt); в браузере и
/// тестах — монотонные часы процесса (Stopwatch), номер «загрузки» —
/// случайный на запуск приложения.
abstract class DeviceClock {
  Future<ClockReading> read();
}

/// GPS-фикс старше этого — не используем (время спутников пересчитывается
/// монотонными часами точно, но «свежий фикс» честнее показать).
const kGpsFresh = Duration(minutes: 30);

/// Время по спутникам к моменту [mono]: время фикса + прошедшее.
DateTime? gpsNow(
    {required int? gpsTime, required int? gpsElapsed, required int mono}) {
  if (gpsTime == null || gpsElapsed == null || gpsElapsed > mono) return null;
  final age = mono - gpsElapsed;
  if (age > kGpsFresh.inMilliseconds) return null;
  return DateTime.fromMillisecondsSinceEpoch(gpsTime + age, isUtc: true);
}

class PlatformDeviceClock implements DeviceClock {
  PlatformDeviceClock({this.skew = Duration.zero});

  /// Только для сквозного теста (OFFLINE_TEST): «переведённые» часы.
  final Duration skew;

  static const _channel = MethodChannel('hey_helpy/clock');
  static final _process = Stopwatch()..start();
  static final _processBoot =
      'p-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';

  @override
  Future<ClockReading> read() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final m = await _channel.invokeMapMethod<String, Object?>('read');
        if (m != null && m['mono'] is int) {
          final mono = m['mono'] as int;
          final wall =
              (m['wall'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
          final boot = m['boot'];
          return ClockReading(
            device: DateTime.fromMillisecondsSinceEpoch(wall).add(skew),
            monoMs: mono,
            // Без номера загрузки (Android < 7) — момент загрузки по часам
            // телефона с точностью до 10 минут: перевели часы — якорь не
            // найдётся, останется GPS (честно, хоть и строже).
            bootId: boot is int
                ? 'b$boot'
                : 'w${(wall - mono) ~/ const Duration(minutes: 10).inMilliseconds}',
            gpsAt: gpsNow(
                gpsTime: m['gps_time'] as int?,
                gpsElapsed: m['gps_elapsed'] as int?,
                mono: mono),
          );
        }
      } catch (e) {
        debugPrint('clock: ${e.runtimeType}');
      }
    }
    return ClockReading(
        device: DateTime.now().add(skew),
        monoMs: _process.elapsedMilliseconds,
        bootId: _processBoot);
  }
}
