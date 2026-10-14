import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../photo_identify/identify_client.dart' show photoIdentifyMock;
import 'live_camera_device.dart'
    if (dart.library.js_interop) 'live_camera_web.dart' as platform;

/// Почему живая камера не включилась — показываем простыми словами и
/// предлагаем «Выбрать фото» (прежний экран «Узнать по фото»).
enum CameraProblem {
  /// Браузер или устройство не умеет показывать камеру.
  unsupported,

  /// Камеры нет (ПК без веб-камеры).
  noCamera,

  /// Доступ к камере запрещён.
  denied,

  /// Прочая ошибка (камера занята другим приложением и т. п.).
  failed,
}

class LiveCameraException implements Exception {
  const LiveCameraException(this.problem);
  final CameraProblem problem;
  @override
  String toString() => 'LiveCameraException($problem)';
}

/// Живое изображение с камеры для «Камеры-помощника» (шаг 25).
///
/// Android — пакет `camera`, браузер — `<video>` с `getUserMedia` через
/// `HtmlElementView` (задняя камера телефона, на ПК — веб-камера).
/// С `VOICE_MOCK` (снимки `/screens`, сквозные тесты) — [MockLiveCamera]:
/// нарисованная картинка вместо видео.
///
/// После [stop] камера выключена (в браузере остановлены треки
/// `MediaStream`), [start] включает её снова.
abstract class LiveCamera {
  /// Включить камеру. Ошибка — [LiveCameraException].
  Future<void> start();

  /// Выключить камеру. Можно вызывать много раз.
  Future<void> stop();

  /// Камера включена и показывает картинку.
  bool get running;

  /// Живое изображение, растянутое на всю отведённую область (cover).
  Widget preview();

  /// Кадр сейчас: JPEG не больше 1280 px по длинной стороне, ~80 %.
  Future<Uint8List> capture();
}

/// Камера для этой платформы (или заглушка с `VOICE_MOCK`).
LiveCamera createLiveCamera() =>
    photoIdentifyMock ? MockLiveCamera() : platform.createPlatformCamera();

/// Есть ли смысл открывать «Камеру»: на Android — всегда (ошибку покажет
/// сам экран), в браузере — есть `getUserMedia` и хотя бы одна камера.
/// Не дольше [limit]; не знаем — false (откроется выбор файла).
Future<bool> liveCameraAvailable(
    {Duration limit = const Duration(milliseconds: 1500)}) async {
  if (photoIdentifyMock) return true;
  try {
    return await platform.platformCameraAvailable().timeout(limit);
  } catch (_) {
    return false;
  }
}

/// Нарисованный кадр вместо камеры (`VOICE_MOCK`, тесты). Не фото объекта.
const kMockCameraFrame = 'assets/demo_photos/ac_indoor.jpg';

/// Заглушка камеры: «видео» — нарисованная картинка, кадр — её байты.
class MockLiveCamera implements LiveCamera {
  MockLiveCamera({this.fail, AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  /// Чем «упасть» при [start] (тест экрана с ошибкой).
  final CameraProblem? fail;
  final AssetBundle _bundle;

  bool _running = false;

  /// Сколько раз включали и выключали — для тестов.
  int starts = 0;
  int stops = 0;

  @override
  bool get running => _running;

  @override
  Future<void> start() async {
    starts++;
    if (fail != null) throw LiveCameraException(fail!);
    _running = true;
  }

  @override
  Future<void> stop() async {
    if (_running) stops++;
    _running = false;
  }

  @override
  Widget preview() => Image.asset(kMockCameraFrame,
      bundle: _bundle, fit: BoxFit.cover, gaplessPlayback: true);

  @override
  Future<Uint8List> capture() async =>
      (await _bundle.load(kMockCameraFrame)).buffer.asUint8List();
}
