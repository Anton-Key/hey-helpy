import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../photo_identify/photo_compress.dart';
import 'live_camera.dart';

LiveCamera createPlatformCamera() => WebLiveCamera();

/// В браузере: есть `getUserMedia` и хотя бы одна камера (`enumerateDevices`
/// перечисляет устройства и без разрешения, только без названий).
Future<bool> platformCameraAvailable() async {
  final md = _mediaDevices;
  if (md == null) return false;
  final list = (await md.enumerateDevices().toDart).toDart;
  return list.any((d) => d.kind == 'videoinput');
}

web.MediaDevices? get _mediaDevices {
  final nav = web.window.navigator as JSObject;
  if (!nav.has('mediaDevices')) return null;
  return web.window.navigator.mediaDevices;
}

/// Браузер: `<video>` с потоком `getUserMedia` через `HtmlElementView`.
/// Задняя камера телефона (`facingMode: environment`), на ПК — веб-камера.
/// [stop] останавливает все треки потока — индикатор камеры гаснет.
class WebLiveCamera implements LiveCamera {
  static int _seq = 0;

  final String _viewType = 'hh-live-camera-${_seq++}';
  web.HTMLVideoElement? _video;
  web.MediaStream? _stream;
  bool _registered = false;

  @override
  bool get running => _stream != null;

  @override
  Future<void> start() async {
    if (running) return;
    final md = _mediaDevices;
    if (md == null) {
      throw const LiveCameraException(CameraProblem.unsupported);
    }
    final constraints = {
      'audio': false,
      'video': {
        'facingMode': {'ideal': 'environment'},
        'width': {'ideal': 1920},
        'height': {'ideal': 1080},
      },
    }.jsify()! as web.MediaStreamConstraints;
    web.MediaStream stream;
    try {
      stream = await md.getUserMedia(constraints).toDart;
    } catch (e) {
      throw LiveCameraException(_problem(e));
    }
    final video = _video ??= _makeVideo();
    video.srcObject = stream;
    _stream = stream;
    if (!_registered) {
      ui_web.platformViewRegistry
          .registerViewFactory(_viewType, (int _) => video);
      _registered = true;
    }
    try {
      await video.play().toDart;
    } catch (_) {
      // autoplay + muted: play() почти всегда проходит; если нет — видео
      // всё равно начнётся само.
    }
  }

  static web.HTMLVideoElement _makeVideo() {
    final v = web.document.createElement('video') as web.HTMLVideoElement
      ..autoplay = true
      ..muted = true
      ..playsInline = true;
    v.setAttribute('playsinline', 'true');
    v.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'cover'
      ..backgroundColor = 'black'
      ..pointerEvents = 'none';
    return v;
  }

  static CameraProblem _problem(Object e) {
    final name =
        e.isA<web.DOMException>() ? (e as web.DOMException).name : e.toString();
    if (name.contains('NotAllowed') || name.contains('Security')) {
      return CameraProblem.denied;
    }
    if (name.contains('NotFound') || name.contains('Overconstrained')) {
      return CameraProblem.noCamera;
    }
    debugPrint('camera: $name');
    return CameraProblem.failed;
  }

  @override
  Future<void> stop() async {
    final s = _stream;
    _stream = null;
    if (s != null) {
      for (final t in s.getTracks().toDart) {
        t.stop();
      }
    }
    final v = _video;
    if (v != null) {
      v.pause();
      v.srcObject = null;
    }
  }

  @override
  Widget preview() => HtmlElementView(viewType: _viewType);

  web.HTMLCanvasElement? _probe;

  @override
  bool get canSample => true;

  @override
  Future<List<int>?> sampleLuma() async {
    final v = _video;
    if (v == null || !running || v.videoWidth == 0) return null;
    const w = 32, h = 24;
    final c = _probe ??=
        (web.document.createElement('canvas') as web.HTMLCanvasElement)
          ..width = w
          ..height = h;
    final ctx = c.getContext('2d', {'willReadFrequently': true}.jsify())
        as web.CanvasRenderingContext2D;
    ctx.drawImage(v, 0, 0, w.toDouble(), h.toDouble());
    final px = ctx.getImageData(0, 0, w, h).data.toDart;
    return [
      for (var i = 0; i < px.length; i += 4)
        (px[i] * 3 + px[i + 1] * 6 + px[i + 2]) ~/ 10
    ];
  }

  @override
  Future<Uint8List> capture() async {
    final v = _video;
    if (v == null || !running || v.videoWidth == 0) {
      throw const LiveCameraException(CameraProblem.failed);
    }
    final (w, h) = fitWithin(v.videoWidth, v.videoHeight);
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = w
      ..height = h;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(v, 0, 0, w.toDouble(), h.toDouble());
    final url = canvas.toDataURL('image/jpeg', (kIdentifyQuality / 100).toJS);
    final comma = url.indexOf(',');
    if (comma < 0) throw const LiveCameraException(CameraProblem.failed);
    return base64Decode(url.substring(comma + 1));
  }
}
