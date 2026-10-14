import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/location.dart';
import '../../l10n/app_localizations.dart';
import '../camera/live_camera.dart';
import '../photo_identify/photo_compress.dart';
import '../photo_identify/photo_recompress.dart' deferred as recompress;
import 'photo_repository.dart';
import 'photo_stamp.dart';

/// Фото «после» — только живым снимком (шаг 26).
///
/// Полноэкранная камера (тот же [LiveCamera], что у «Камеры-помощника»:
/// CameraX на Android, `getUserMedia` в браузере), затвор → стоп-кадр →
/// «Переснять» / «Готово». На «Готово» в снимок вжигается штамп [stamp]
/// (дата, объект, помещение, геозона). Галереи нет. Только в браузере без
/// камеры (ПК без веб-камеры, отказ в доступе) можно выбрать файл — такое
/// фото помечается «из файла» и в акте не считается доказательством.
/// null — человек закрыл экран, ничего не сняв.
Future<CapturedPhoto?> captureLivePhoto(BuildContext context,
        {PhotoStamp? stamp, LiveCamera? camera}) =>
    Navigator.push<CapturedPhoto>(
        context, appRoute((_) => LiveShotScreen(stamp: stamp, camera: camera)));

enum _Shot { starting, live, frozen, error, saving }

class LiveShotScreen extends StatefulWidget {
  const LiveShotScreen({super.key, this.stamp, this.camera});
  final PhotoStamp? stamp;

  /// Для тестов; иначе — камера платформы (или заглушка с `VOICE_MOCK`).
  final LiveCamera? camera;

  @override
  State<LiveShotScreen> createState() => _LiveShotScreenState();
}

class _LiveShotScreenState extends State<LiveShotScreen>
    with WidgetsBindingObserver {
  late final LiveCamera _camera = widget.camera ?? createLiveCamera();
  late final Future<Position?> _position = ensureLocationPermission()
      .then((ok) => ok ? currentPosition() : null)
      .catchError((_) => null);
  _Shot _state = _Shot.starting;
  CameraProblem? _problem;
  Uint8List? _frame;
  DateTime? _takenAt;
  bool _pausedByApp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_camera.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_pausedByApp && _state == _Shot.live) unawaited(_start());
      _pausedByApp = false;
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_camera.running) {
        _pausedByApp = true;
        unawaited(_camera.stop());
      }
    }
  }

  Future<void> _start() async {
    setState(() {
      _state = _Shot.starting;
      _problem = null;
    });
    try {
      await _camera.start();
      if (!mounted) {
        await _camera.stop();
        return;
      }
      setState(() => _state = _Shot.live);
    } on LiveCameraException catch (e) {
      if (mounted) {
        setState(() {
          _state = _Shot.error;
          _problem = e.problem;
        });
      }
    } catch (e) {
      debugPrint('LiveShot start: ${e.runtimeType}');
      if (mounted) {
        setState(() {
          _state = _Shot.error;
          _problem = CameraProblem.failed;
        });
      }
    }
  }

  Future<void> _shoot() async {
    try {
      final bytes = await _camera.capture();
      _takenAt = DateTime.now();
      await _camera.stop();
      if (!mounted) return;
      setState(() {
        _frame = bytes;
        _state = _Shot.frozen;
      });
    } catch (e) {
      debugPrint('LiveShot capture: ${e.runtimeType}');
      if (mounted) {
        showAppMessage(context, context.l10n.cameraFailed,
            type: AppMessageType.error);
      }
    }
  }

  Future<void> _retake() async {
    setState(() => _frame = null);
    await _start();
  }

  Future<void> _done() async {
    final l = context.l10n;
    final frame = _frame!;
    final at = _takenAt ?? DateTime.now();
    setState(() => _state = _Shot.saving);
    final pos = await _position.timeout(const Duration(seconds: 4),
        onTimeout: () => null);
    var bytes = frame;
    final stamp = widget.stamp;
    if (stamp != null) {
      final text =
          stampText(l, stamp, at: at, lat: pos?.latitude, lng: pos?.longitude);
      bytes = await stampJpeg(frame, text) ?? frame;
    }
    if (!mounted) return;
    Navigator.pop(
        context,
        CapturedPhoto(
            bytes: bytes,
            takenAt: at,
            lat: pos?.latitude,
            lng: pos?.longitude,
            mockLocation: pos?.isMocked ?? false,
            source: 'camera'));
  }

  /// Только браузер без камеры: файл с пометкой «из файла».
  Future<void> _pickFile() async {
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 82,
          requestFullMetadata: false);
    } catch (e) {
      debugPrint('LiveShot pick: ${e.runtimeType}');
      return;
    }
    if (file == null) return;
    var bytes = await file.readAsBytes();
    // Хранилище work-photos принимает только JPEG.
    if (needsRecompress(bytes, maxBytes: 8 * 1024 * 1024)) {
      await recompress.loadLibrary();
      final jpeg = recompress.recompressJpeg(bytes, maxSide: 1600);
      if (jpeg == null) {
        if (mounted) {
          showAppMessage(context, context.l10n.photoCameraFailed,
              type: AppMessageType.error);
        }
        return;
      }
      bytes = jpeg;
    }
    if (!mounted) return;
    Navigator.pop(context,
        CapturedPhoto(bytes: bytes, takenAt: DateTime.now(), source: 'file'));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.camera,
      body: Stack(fit: StackFit.expand, children: [
        if (_frame != null)
          Image.memory(_frame!, fit: BoxFit.contain, gaplessPlayback: true)
        else if (_state == _Shot.live)
          _camera.preview(),
        if (_state == _Shot.starting || _state == _Shot.saving)
          Center(
            child: _Bubble(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 20, height: 20, child: AppLoader()),
              const SizedBox(width: AppSpace.s),
              Text(_state == _Shot.saving ? l.shotPreparing : l.cameraStarting,
                  style: AppText.callout.copyWith(color: AppColors.onCamera)),
            ])),
          ),
        if (_state == _Shot.error) Center(child: _errorPanel(l)),
        _topBar(l),
        if (_state == _Shot.live) _shutter(l),
        if (_state == _Shot.frozen) _confirm(l),
      ]),
    );
  }

  Widget _topBar(AppLocalizations l) => PositionedDirectional(
        top: 0,
        start: 0,
        end: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.m),
            child: Row(children: [
              AppIconButton(
                  icon: AppIcons.close,
                  label: l.commonClose,
                  onPressed: () => Navigator.maybePop(context)),
              const SizedBox(width: AppSpace.s),
              Flexible(
                child: _Bubble(
                    child: Text(l.shotTitle,
                        style: AppText.headline
                            .copyWith(color: AppColors.onCamera))),
              ),
            ]),
          ),
        ),
      );

  Widget _shutter(AppLocalizations l) => PositionedDirectional(
        start: 0,
        end: 0,
        bottom: 0,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _Bubble(
                  child: Text(l.shotHint,
                      textAlign: TextAlign.center,
                      style: AppText.footnote
                          .copyWith(color: AppColors.onCamera))),
              const SizedBox(height: AppSpace.l),
              Pressable(
                onTap: _shoot,
                semanticLabel: l.shotTake,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.onCamera,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent, width: 4),
                    boxShadow: AppShadows.floating,
                  ),
                  child: const Icon(AppIcons.camera,
                      size: 32, color: AppColors.ink),
                ),
              ),
            ]),
          ),
        ),
      );

  Widget _confirm(AppLocalizations l) => PositionedDirectional(
        start: 0,
        end: 0,
        bottom: 0,
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.l),
                child: Row(children: [
                  Expanded(
                    child: AppButton.secondary(
                        label: l.shotRetake,
                        icon: AppIcons.refresh,
                        onPressed: _retake),
                  ),
                  const SizedBox(width: AppSpace.m),
                  Expanded(
                    child: AppButton.primary(
                        label: l.shotDone,
                        icon: AppIcons.check,
                        onPressed: _done),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );

  Widget _errorPanel(AppLocalizations l) {
    // Выбор файла — только в браузере; на телефоне — только камера.
    final text = switch (_problem) {
      CameraProblem.denied => l.shotDenied,
      CameraProblem.noCamera when kIsWeb => l.cameraNoCamera,
      CameraProblem.unsupported when kIsWeb => l.cameraUnsupported,
      _ => l.shotFailed,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        margin: const EdgeInsets.all(AppSpace.l),
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(AppRadius.group)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(AppIcons.camera,
              size: AppSizes.iconL, color: AppColors.secondary),
          const SizedBox(height: AppSpace.s),
          Text(text, textAlign: TextAlign.center, style: AppText.callout),
          const SizedBox(height: AppSpace.l),
          AppButton.primary(
              label: l.cameraRetryStart,
              icon: AppIcons.refresh,
              onPressed: _start),
          if (kIsWeb) ...[
            const SizedBox(height: AppSpace.m),
            Text(l.shotFileWarning,
                textAlign: TextAlign.center, style: AppText.footnote),
            const SizedBox(height: AppSpace.s),
            AppButton.secondary(
                label: l.shotPickFile,
                icon: AppIcons.image,
                onPressed: _pickFile),
          ],
        ]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpace.m, vertical: AppSpace.s),
        decoration: BoxDecoration(
            color: AppColors.cameraOverlay,
            borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: child,
      );
}
