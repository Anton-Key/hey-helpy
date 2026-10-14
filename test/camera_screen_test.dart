import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/design/design.dart';
import 'package:hey_helpy/features/camera/camera_screen.dart';
import 'package:hey_helpy/features/camera/live_camera.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

Widget _app(Widget child, {String locale = 'ru'}) => MaterialApp(
      theme: AppTheme.light(),
      locale: Locale(locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

void main() {
  testWidgets('камера включается при открытии и выключается при уходе',
      (t) async {
    final cam = MockLiveCamera();
    await t.pumpWidget(_app(CameraScreen(camera: cam, offline: true)));
    await t.pump();
    final l = await AppLocalizations.delegate.load(const Locale('ru'));
    expect(cam.starts, 1);
    expect(cam.running, isTrue);
    expect(find.text(l.cameraWhatIsIt), findsOneWidget);

    // Ушли с экрана — камера выключена.
    await t.pumpWidget(_app(const SizedBox()));
    await t.pump();
    expect(cam.running, isFalse);
    expect(cam.stops, 1);
  });

  testWidgets('сворачивание приложения выключает камеру, возврат — включает',
      (t) async {
    final cam = MockLiveCamera();
    await t.pumpWidget(_app(CameraScreen(camera: cam, offline: true)));
    await t.pump();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await t.pump();
    expect(cam.running, isFalse);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(cam.running, isTrue);
    expect(cam.starts, 2);
    await t.pumpWidget(_app(const SizedBox()));
  });

  for (final locale in ['ru', 'en']) {
    testWidgets('камера недоступна → понятный текст и «Выбрать фото» ($locale)',
        (t) async {
      final cam = MockLiveCamera(fail: CameraProblem.denied);
      await t.pumpWidget(
          _app(CameraScreen(camera: cam, offline: true), locale: locale));
      await t.pump();
      final l = await AppLocalizations.delegate.load(Locale(locale));
      expect(find.text(l.cameraDenied), findsOneWidget);
      expect(find.text(l.cameraPickPhoto), findsOneWidget);
      expect(find.text(l.cameraWhatIsIt), findsNothing);
    });
  }

  testWidgets('«Что это?» → стоп-кадр (камера выключена) → «Не узнал»',
      (t) async {
    final cam = MockLiveCamera();
    await t.pumpWidget(_app(CameraScreen(camera: cam, offline: true)));
    await t.pump();
    final l = await AppLocalizations.delegate.load(const Locale('ru'));
    await t.tap(find.text(l.cameraWhatIsIt));
    // Без сервера разбор падает сразу → карточка «Не узнал».
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(cam.running, isFalse, reason: 'на стоп-кадре камера выключена');
    expect(find.text(l.cameraNotRecognized), findsOneWidget);
    expect(find.text(l.cameraAgain), findsOneWidget);

    await t.tap(find.text(l.cameraAgain));
    await t.pump();
    await t.pump();
    expect(cam.running, isTrue);
    expect(find.text(l.cameraNotRecognized), findsNothing);
    await t.pumpWidget(_app(const SizedBox()));
  });
}
