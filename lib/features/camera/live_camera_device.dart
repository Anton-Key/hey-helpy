import 'dart:async';

import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../photo_identify/photo_compress.dart';
import '../photo_identify/photo_recompress.dart' deferred as recompress;
import 'live_camera.dart';

LiveCamera createPlatformCamera() => DeviceLiveCamera();

/// На Android камера есть почти всегда; если нет — экран покажет ошибку и
/// «Выбрать фото». На других платформах (тесты, ПК) — нет.
Future<bool> platformCameraAvailable() async =>
    defaultTargetPlatform == TargetPlatform.android;

/// Android: пакет `camera` (CameraX), задняя камера, без звука.
class DeviceLiveCamera implements LiveCamera {
  cam.CameraController? _c;

  @override
  bool get running => _c?.value.isInitialized ?? false;

  @override
  Future<void> start() async {
    if (running) return;
    List<cam.CameraDescription> cams;
    try {
      cams = await cam.availableCameras();
    } on cam.CameraException catch (e) {
      throw _problem(e.code);
    } catch (_) {
      throw const LiveCameraException(CameraProblem.unsupported);
    }
    if (cams.isEmpty) throw const LiveCameraException(CameraProblem.noCamera);
    final back = cams
            .where((c) => c.lensDirection == cam.CameraLensDirection.back)
            .firstOrNull ??
        cams.first;
    final c = cam.CameraController(back, cam.ResolutionPreset.high,
        enableAudio: false, imageFormatGroup: cam.ImageFormatGroup.jpeg);
    try {
      await c.initialize();
      _c = c;
    } on cam.CameraException catch (e) {
      await c.dispose();
      throw _problem(e.code);
    } catch (_) {
      await c.dispose();
      throw const LiveCameraException(CameraProblem.failed);
    }
  }

  static LiveCameraException _problem(String code) =>
      LiveCameraException(code.contains('Denied') || code.contains('denied')
          ? CameraProblem.denied
          : CameraProblem.failed);

  @override
  Future<void> stop() async {
    final c = _c;
    _c = null;
    if (c != null) await c.dispose();
  }

  @override
  Widget preview() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return const SizedBox.expand();
    // Картинка на всю область без полей (как «cover»): лишнее обрезается.
    final ratio = c.value.aspectRatio; // ширина / высота сенсора
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
              width: 1000, height: 1000 * ratio, child: c.buildPreview()),
        ),
      ),
    );
  }

  @override
  Future<Uint8List> capture() async {
    final c = _c;
    if (c == null) throw const LiveCameraException(CameraProblem.failed);
    final file = await c.takePicture();
    var bytes = await file.readAsBytes();
    // Камера снимает крупнее 1280 px — уменьшаем (пакет image, отложенно).
    await recompress.loadLibrary();
    bytes = recompress.recompressJpeg(bytes) ?? bytes;
    if (bytes.length > kIdentifyMaxBytes) {
      throw const LiveCameraException(CameraProblem.failed);
    }
    return bytes;
  }
}
