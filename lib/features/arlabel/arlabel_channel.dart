import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'arlabel_logic.dart';

/// Шаг 31: канал к нативному экрану «AR-метки» (android/app/…/ArLabelHook.kt,
/// во всех сборках Android). В браузере и без ARCore — [ArLabelStatus.none],
/// кнопок нет, работает обычная «Камера-помощник».
class ArLabelChannel {
  ArLabelChannel._();
  static const _ch = MethodChannel('hey_helpy/arlabel');
  static ArLabelStatus? _cached;

  static Future<ArLabelStatus> status({bool refresh = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return ArLabelStatus.none;
    }
    if (!refresh && _cached != null) return _cached!;
    try {
      final m = await _ch.invokeMapMethod<Object?, Object?>('status');
      return _cached = ArLabelStatus.fromMap(m);
    } on MissingPluginException {
      return _cached = ArLabelStatus.none;
    } catch (e) {
      debugPrint('AR labels status: ${e.runtimeType}');
      return ArLabelStatus.none;
    }
  }

  /// Открыть экран; ответ — что выбрал человек на табличке (или пусто).
  static Future<Map<Object?, Object?>?> open(Map<String, Object?> args) =>
      _ch.invokeMapMethod<Object?, Object?>('open', args);
}
