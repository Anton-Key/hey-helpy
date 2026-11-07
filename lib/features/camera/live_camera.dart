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

  /// Яркость уменьшенного кадра (32 × 24, байты 0…255) — для «Авто»:
  /// телефон неподвижен, если соседние замеры почти не отличаются.
  /// null — платформа так не умеет (APK: «Авто» не показывается).
  Future<List<int>?> sampleLuma();

  /// Умеет ли [sampleLuma] (без включения камеры).
  bool get canSample;
}

/// Камера для этой платформы (или заглушка с `VOICE_MOCK`).
///
/// [mockFrame] — кадр заглушки (фото «после» — чистый блок, шаг 35c).
LiveCamera createLiveCamera({String mockFrame = kMockCameraFrame}) =>
    photoIdentifyMock
        ? MockLiveCamera(frame: mockFrame)
        : platform.createPlatformCamera();

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

/// Кадр-картинка вместо камеры (`VOICE_MOCK`, тесты) — фрагмент иллюстрации
/// художника (`tools/demo_photos/from_art.py`, шаг 35c). Не фото объекта.
const kMockCameraFrame = 'assets/demo_photos/ac_indoor.jpg';

/// Кадр заглушки для фото «после»: тот же блок, подтёка нет (шаг 35c).
const kMockAfterFrame = 'assets/demo_photos/ac_after.jpg';

/// Тот же сюжет кадром 1:2 — для высокого экрана телефона: при заполнении
/// экрана картинкой 4:3 видна только треть ширины (середина блока).
String mockTallFrame(String frame) => frame.replaceFirst('.jpg', '_tall.jpg');

/// Заглушка камеры: «видео» — нарисованная картинка, кадр — её байты.
class MockLiveCamera implements LiveCamera {
  MockLiveCamera(
      {this.fail, AssetBundle? bundle, this.frame = kMockCameraFrame})
      : _bundle = bundle ?? rootBundle;

  /// Картинка, которую «видит» камера.
  final String frame;

  /// Последний экран был выше, чем шире, — снимок тоже вертикальный.
  bool _tall = false;

  /// Картинка под форму экрана: высокий — вертикальный кадр.
  String get shownFrame => _tall ? mockTallFrame(frame) : frame;

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
  Widget preview() => LayoutBuilder(builder: (context, c) {
        _tall = c.hasBoundedHeight &&
            c.hasBoundedWidth &&
            c.maxHeight > c.maxWidth * 1.5;
        return Image.asset(shownFrame,
            bundle: _bundle, fit: BoxFit.cover, gaplessPlayback: true);
      });

  @override
  Future<Uint8List> capture() async =>
      (await _bundle.load(shownFrame)).buffer.asUint8List();

  /// Нарисованный кадр неподвижен — «телефон не двигается».
  @override
  Future<List<int>?> sampleLuma() async =>
      _running ? List<int>.filled(32 * 24, 128) : null;

  @override
  bool get canSample => true;
}
