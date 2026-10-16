import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'vps_logic.dart';

/// Шаг 28: канал к нативному экрану VPS (только VPS-вариант APK,
/// android/app/src/vps/…/VpsHook.kt). В обычной сборке канала нет —
/// [status] вернёт [VpsStatus.none], кнопок не будет.
class VpsChannel {
  VpsChannel._();
  static const _ch = MethodChannel('hey_helpy/vps');
  static VpsStatus? _cached;

  static Future<VpsStatus> status({bool refresh = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return VpsStatus.none;
    }
    if (!refresh && _cached != null) return _cached!;
    try {
      final m = await _ch.invokeMapMethod<Object?, Object?>('status');
      return _cached = VpsStatus.fromMap(m);
    } on MissingPluginException {
      return _cached = VpsStatus.none;
    } catch (e) {
      debugPrint('VPS status: ${e.runtimeType}');
      return VpsStatus.none;
    }
  }

  /// Открыть экран; ответ — id оборудования, если по метке нажали «Открыть».
  static Future<String?> open(Map<String, Object?> args) async {
    final m = await _ch.invokeMapMethod<String, Object?>('open', args);
    return m?['assetId'] as String?;
  }
}
