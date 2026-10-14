import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/design/design.dart';
import 'package:hey_helpy/features/camera/live_camera.dart';
import 'package:hey_helpy/features/photos/live_shot_screen.dart';
import 'package:hey_helpy/features/photos/photo_repository.dart';
import 'package:hey_helpy/features/photos/photo_section.dart';
import 'package:hey_helpy/features/photos/photo_stamp.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('ru'),
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
  testWidgets('фото «после»: затвор → стоп-кадр → «Готово» — снимок камеры',
      (t) async {
    final cam = MockLiveCamera();
    final l = await AppLocalizations.delegate.load(const Locale('ru'));
    CapturedPhoto? got;
    await t.pumpWidget(_app(Builder(
        builder: (context) => Center(
              child: TextButton(
                  onPressed: () async =>
                      got = await captureLivePhoto(context, camera: cam),
                  child: const Text('open')),
            ))));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(cam.running, isTrue);
    expect(find.text(l.shotHint), findsOneWidget);
    // Галереи нет: ни «Выбрать файл», ни «Выбрать фото».
    expect(find.text(l.shotPickFile), findsNothing);
    await t.runAsync(() async {
      await t.tap(find.bySemanticsLabel(l.shotTake));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await t.pumpAndSettle();
    expect(cam.running, isFalse, reason: 'на стоп-кадре камера выключена');
    expect(find.text(l.shotRetake), findsOneWidget);
    await t.runAsync(() async {
      await t.tap(find.text(l.shotDone));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await t.pumpAndSettle();
    expect(got, isNotNull);
    expect(got!.source, 'camera');
    expect(got!.bytes, isNotEmpty);
  });

  testWidgets('камеры нет — на телефоне только «Попробовать снова»', (t) async {
    final l = await AppLocalizations.delegate.load(const Locale('ru'));
    await t.pumpWidget(_app(
        LiveShotScreen(camera: MockLiveCamera(fail: CameraProblem.noCamera))));
    await t.pumpAndSettle();
    expect(find.text(l.shotFailed), findsOneWidget);
    expect(find.text(l.cameraRetryStart), findsOneWidget);
    expect(find.text(l.shotPickFile), findsNothing);
  });

  group('штамп фото «после»', () {
    late AppLocalizations l;
    setUpAll(() async {
      l = await AppLocalizations.delegate.load(const Locale('ru'));
    });
    final at = DateTime(2026, 10, 14, 14, 19);
    const zone = PhotoGeofence(lat: 44.80471, lng: 20.44942, radiusM: 150);
    test('дата · объект · помещение · в геозоне', () {
      expect(
          stampText(
              l,
              const PhotoStamp(
                  object: 'БЦ «Демо»',
                  place: '301 Переговорная',
                  geofence: zone),
              at: at,
              lat: 44.8048,
              lng: 20.4495),
          '14.10.2026 14:19 · БЦ «Демо» · 301 Переговорная · в геозоне');
    });
    test('вне геозоны', () {
      expect(
          stampText(l, const PhotoStamp(object: 'БЦ', geofence: zone),
              at: at, lat: 44.82, lng: 20.44942),
          '14.10.2026 14:19 · БЦ · вне геозоны');
    });
    test('без координат — без геозоны', () {
      expect(stampText(l, const PhotoStamp(geofence: zone), at: at),
          '14.10.2026 14:19');
    });
  });

  testWidgets('штамп вжигается: JPEG того же размера', (t) async {
    await t.runAsync(() async {
      final src = File('assets/demo_photos/ac_indoor.jpg').readAsBytesSync();
      final out = await stampJpeg(src, '14.10.2026 14:19 · БЦ «Демо»');
      expect(out, isNotNull);
      expect(out!.sublist(0, 3), [0xff, 0xd8, 0xff]);
      Future<(int, int)> size(List<int> b) async {
        final f = await (await ui.instantiateImageCodec(Uint8List.fromList(b)))
            .getNextFrame();
        return (f.image.width, f.image.height);
      }

      expect(await size(out), await size(src));
    });
  });
}
