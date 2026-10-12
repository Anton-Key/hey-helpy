import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/floors/floor_models.dart';
import 'package:hey_helpy/features/photo_identify/identify_client.dart';
import 'package:hey_helpy/features/photo_identify/identify_log.dart';
import 'package:hey_helpy/features/photo_identify/identify_models.dart';
import 'package:hey_helpy/features/photo_identify/photo_compress.dart';
import 'package:hey_helpy/features/photo_identify/photo_recompress.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';
import 'package:image/image.dart' as img;

/// Ответ функции photo-identify, как в сценарии демо.
Map<String, dynamic> _reply({String? defect}) => {
      'source': 'ai',
      'kind': 'ac',
      'kind_label': 'Кондиционер, внутренний блок',
      'layer_id': 'l-hvac',
      'layer': 'Климат',
      'nameplate': {
        'manufacturer': 'Daikin',
        'model': 'FTXM35R',
        'serial': null
      },
      'defect': defect,
      'confidence': 0.91,
      'candidates': [
        {
          'asset_id': 'a-301',
          'name': 'Кондиционер КД-301',
          'location_id': 'loc-301',
          'location_label': '301 Переговорная',
          'floor_label': '3 этаж',
          'score': 0.75,
          'reasons': ['kind', 'layer', 'same_room'],
          'reason_text': 'тот же вид · та же система · то же помещение',
        },
        {
          'asset_id': 'a-302',
          'name': 'Кондиционер КД-302',
          'location_id': 'loc-302',
          'location_label': '302 Кабинет',
          'floor_label': '3 этаж',
          'score': 0.57,
          'reasons': ['kind', 'layer', 'same_floor'],
        },
        {'asset_id': null, 'name': 'битый'},
      ],
      'model': 'main',
      'ms': 4210,
    };

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('ответ функции', () {
    test('разбирается; битый кандидат пропускается', () {
      final r = PhotoIdentification.fromJson(_reply())!;
      expect(r.kind, 'ac');
      expect(r.percent, 91);
      expect(r.layerId, 'l-hvac');
      expect(r.nameplate!.text, 'Daikin FTXM35R');
      expect(r.candidates.map((c) => c.assetId), ['a-301', 'a-302']);
      expect(r.top!.placeText, '301 Переговорная · 3 этаж');
      expect(r.model, 'main');
      expect(r.ms, 4210);
    });

    test('не ответ ИИ, неизвестный вид, уверенность вне 0..1', () {
      expect(PhotoIdentification.fromJson({'error': 'ai_unavailable'}), isNull);
      expect(PhotoIdentification.fromJson('текст'), isNull);
      final r = PhotoIdentification.fromJson(
          {'source': 'ai', 'kind': 'flux', 'confidence': 7, 'model': 'x'})!;
      expect(r.kind, 'other');
      expect(r.confidence, 1);
      expect(r.model, isNull);
      expect(r.candidates, isEmpty);
      expect(r.top, isNull);
    });

    test(
        'причины словами; «та же система» рядом с «тем же видом» не дублируется',
        () {
      expect(reasonsText(ru, ['kind', 'layer', 'same_room']),
          'тот же вид · то же помещение');
      expect(
          reasonsText(en, ['layer', 'same_floor']), 'same system · same floor');
      expect(reasonsText(ru, ['serial', 'model']),
          'серийный номер с шильдика · модель с шильдика');
    });
  });

  group('заявка по фото', () {
    test('заголовок — неисправность, иначе «{вид}: проверить»', () {
      final withDefect = PhotoIdentification.fromJson(
          _reply(defect: 'Подтёк воды под блоком'))!;
      expect(photoOrderTitle(ru, withDefect), 'Подтёк воды под блоком');
      final plain = PhotoIdentification.fromJson(_reply())!;
      expect(photoOrderTitle(ru, plain),
          'Кондиционер, внутренний блок: проверить');
      expect(photoOrderTitle(en, plain), 'Air conditioner, indoor unit: check');
      final long = PhotoIdentification.fromJson(_reply(defect: 'а' * 90))!;
      expect(photoOrderTitle(ru, long).length, lessThanOrEqualTo(60));
    });

    test('описание: вид, шильдик, неисправность', () {
      final r = PhotoIdentification.fromJson(
          _reply(defect: 'Подтёк воды под блоком'))!;
      expect(
          photoOrderDescription(ru, r),
          'По фото: Кондиционер, внутренний блок.\n'
          'Шильдик: Daikin FTXM35R.\n'
          'Видно: Подтёк воды под блоком.');
    });
  });

  group('журнал узнаваний', () {
    final r = PhotoIdentification.fromJson(_reply())!;

    test('итог по выбору человека', () {
      expect(outcomeFor(r, 'a-301'), IdentifyOutcome.matchedTop);
      expect(outcomeFor(r, 'a-302'), IdentifyOutcome.matchedOther);
      expect(outcomeFor(r, null), IdentifyOutcome.dismissed);
      expect(outcomeFor(r, 'new', created: true), IdentifyOutcome.newAsset);
      expect(IdentifyOutcome.values.map(outcomeCode),
          ['matched_top', 'matched_other', 'new_asset', 'dismissed']);
    });

    test('строка журнала: без фото и шильдика, чужие id — null', () {
      final id = newUuid();
      final row = IdentifyLog.row(
          id: id,
          companyId: 'c',
          userId: 'u',
          place: const IdentifyPlace(
              objectId: 'de300000-0000-4000-8000-000000000010',
              locationId: 'не-uuid'),
          r: r,
          ms: 4210);
      expect(row['id'], id);
      expect(row['object_id'], 'de300000-0000-4000-8000-000000000010');
      expect(row['location_id'], isNull);
      expect(row['top_asset_id'], isNull, reason: 'a-301 — не uuid');
      expect(row['kind'], 'ac');
      expect(row['ms'], 4210);
      expect(row.keys, isNot(contains('nameplate')));
      expect(row.keys, isNot(contains('image')));
    });

    test('newUuid — UUID v4, разные', () {
      final re = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      final a = newUuid(), b = newUuid();
      expect(re.hasMatch(a), isTrue, reason: a);
      expect(a, isNot(b));
    });
  });

  group('запрос к функции', () {
    test('тело: base64, язык, только известные места', () {
      final b = PhotoIdentifyClient.body(Uint8List.fromList([1, 2, 3]), 'ru',
          const IdentifyPlace(objectId: 'o', locationId: 'l'));
      expect(b, {
        'image': 'AQID',
        'locale': 'ru',
        'objectId': 'o',
        'locationId': 'l'
      });
      expect(
          PhotoIdentifyClient.body(
              Uint8List(0), 'de', const IdentifyPlace())['locale'],
          'en');
    });

    test('ответ → результат; не ответ ИИ, таймаут, сеть → понятная ошибка',
        () async {
      final jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]);
      Future<PhotoIdentification> run(IdentifyCall call,
              {Duration t = const Duration(seconds: 1)}) =>
          PhotoIdentifyClient(call: call, timeout: t)
              .identify(jpeg, locale: 'ru', place: const IdentifyPlace());
      final ok = await run((body) async {
        expect(body['image'], base64Encode(jpeg));
        return _reply();
      });
      expect(ok.top!.assetId, 'a-301');
      await expectLater(
          run((_) async => {'error': 'x'}),
          throwsA(isA<IdentifyException>()
              .having((e) => e.problem, 'problem', IdentifyProblem.failed)));
      await expectLater(
          run((_) => Completer<Object?>().future,
              t: const Duration(milliseconds: 10)),
          throwsA(isA<IdentifyException>()
              .having((e) => e.problem, 'problem', IdentifyProblem.failed)));
      await expectLater(
          run((_) async => throw Exception('нет сети')),
          throwsA(isA<IdentifyException>()
              .having((e) => e.problem, 'problem', IdentifyProblem.offline)));
      final big = Uint8List(kIdentifyMaxBytes + 1);
      await expectLater(
          PhotoIdentifyClient(call: (_) async => _reply())
              .identify(big, locale: 'ru', place: const IdentifyPlace()),
          throwsA(isA<IdentifyException>()
              .having((e) => e.problem, 'problem', IdentifyProblem.tooLarge)));
    });
  });

  test('заглушка: помещение решает, какой из одинаковых', () {
    PlanItem place(String id, String code, String floor) => PlanItem(
        kind: PlanKind.place,
        id: id,
        name: 'Комната $code',
        code: code,
        floorId: floor);
    PlanItem asset(String id, String loc, String kind, String floor) =>
        PlanItem(
            kind: PlanKind.asset,
            id: id,
            name: id,
            locationId: loc,
            equipmentKind: kind,
            floorId: floor);
    final items = [
      place('r301', '301', 'f3'),
      place('r302', '302', 'f3'),
      place('r101', '101', 'f1'),
      asset('КД-302', 'r302', 'ac', 'f3'),
      asset('КД-301', 'r301', 'ac', 'f3'),
      asset('Дым-301', 'r301', 'smoke', 'f3'),
      asset('КД-101', 'r101', 'ac', 'f1'),
    ];
    final c = mockCandidates('ac', items, {'f3': '3 этаж', 'f1': '1 этаж'},
        const IdentifyPlace(objectId: 'o', floorId: 'f3', locationId: 'r301'));
    expect(c.map((x) => x.assetId), ['КД-301', 'КД-302', 'КД-101']);
    expect(c.first.reasons, ['kind', 'same_room']);
    expect(c.first.placeText, '301 Комната 301 · 3 этаж');
    expect(c[1].reasons, ['kind', 'same_floor']);
  });

  group('сжатие снимка', () {
    test('тип по первым байтам', () {
      expect(sniffImageMime(Uint8List.fromList([0xff, 0xd8, 0xff, 0])),
          'image/jpeg');
      expect(
          sniffImageMime(Uint8List.fromList(
              [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])),
          'image/png');
      expect(
          sniffImageMime(Uint8List.fromList(utf8.encode('RIFF1234WEBPVP8 '))),
          'image/webp');
      expect(sniffImageMime(Uint8List.fromList(utf8.encode('GIF89a'))), isNull);
    });

    test('вписать в 1280 по длинной стороне, меньше — не трогать', () {
      expect(fitWithin(4000, 3000), (1280, 960));
      expect(fitWithin(3000, 4000), (960, 1280));
      expect(fitWithin(800, 600), (800, 600));
      expect(fitWithin(10000, 5), (1280, 1));
    });

    test('PNG 3000×2000 → JPEG ≤ 1280 px и ≤ 1,5 МБ', () {
      final src = img.Image(width: 3000, height: 2000);
      for (var y = 0; y < src.height; y += 1) {
        for (var x = 0; x < src.width; x += 1) {
          src.setPixelRgb(
              x, y, (x * 7 + y) & 255, (y * 3) & 255, (x ^ y) & 255);
        }
      }
      final png = Uint8List.fromList(img.encodePng(src, level: 1));
      expect(needsRecompress(png), isTrue);
      final out = recompressJpeg(png)!;
      expect(sniffImageMime(out), 'image/jpeg');
      expect(out.length, lessThanOrEqualTo(kIdentifyMaxBytes));
      final back = img.decodeJpg(out)!;
      expect((back.width, back.height), (1280, 853));
      expect(needsRecompress(out), isFalse);
      expect(recompressJpeg(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });
}
