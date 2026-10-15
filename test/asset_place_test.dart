import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/equipment/asset_place.dart';
import 'package:hey_helpy/features/equipment/equipment_models.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('подпись «где именно»', () {
    const full = MountInfo(
        mount: 'ceiling', heightM: 2.8, landmark: 'над дверью, слева');

    test('монтаж · высота · ориентир — одной строкой', () {
      expect(formatMountLine(ru, full), 'потолок · 2,8 м · над дверью, слева');
      expect(formatMountLine(en, const MountInfo(mount: 'wall', heightM: 1.5)),
          'wall · 1.5 m');
    });

    test('для маркера плана — без ориентира', () {
      expect(formatMountLine(ru, full, withLandmark: false), 'потолок · 2,8 м');
    });

    test('частично и пусто', () {
      expect(formatMountLine(ru, const MountInfo(heightM: 3)), '3 м');
      expect(formatMountLine(ru, const MountInfo(mount: 'above_ceiling')),
          'за подвесным потолком');
      expect(
          formatMountLine(ru, const MountInfo(landmark: 'у окна')), 'у окна');
      expect(formatMountLine(ru, MountInfo.empty), isNull);
    });

    test('все виды монтажа подписаны на обоих языках', () {
      for (final c in kMountCodes) {
        expect(mountLabel(ru, c), isNot(c));
        expect(mountLabel(en, c), isNot(c));
      }
    });
  });

  group('высота', () {
    test('запятая, точка, единицы', () {
      expect(parseHeight('2,8'), 2.8);
      expect(parseHeight(' 2.80 '), 2.8);
      expect(parseHeight('3 м'), 3.0);
      expect(parseHeight('3m'), 3.0);
      expect(parseHeight('0'), 0.0);
      expect(parseHeight('2.345'), 2.35);
    });

    test('неправильное — null', () {
      expect(parseHeight(''), isNull);
      expect(parseHeight('abc'), isNull);
      expect(parseHeight('-1'), isNull);
      expect(parseHeight('101'), isNull);
      expect(parseHeight('2,8,1'), isNull);
      expect(heightTextOk(''), isTrue);
      expect(heightTextOk('2,8'), isTrue);
      expect(heightTextOk('высоко'), isFalse);
    });
  });

  group('assets.meta', () {
    test('чтение: мусор — как «не указано»', () {
      final m = MountInfo.fromMeta({
        'mount': 'roof',
        'height_m': 'x',
        'landmark': '   ',
      });
      expect(m.isEmpty, isTrue);
      expect(
          MountInfo.fromMeta(
              {'mount': 'wall', 'height_m': 2, 'landmark': ' у  окна '}),
          const MountInfo(mount: 'wall', heightM: 2, landmark: 'у окна'));
    });

    test('запись: другие ключи сохраняются, пустые убираются', () {
      final base = {'kind': 'ac', 'mount': 'floor', 'height_m': 1, 'x': 1};
      final out = const MountInfo(mount: 'ceiling', landmark: 'над дверью')
          .applyTo(base);
      expect(out, {
        'kind': 'ac',
        'x': 1,
        'mount': 'ceiling',
        'landmark': 'над дверью',
      });
      expect(base['mount'], 'floor', reason: 'исходный meta не меняется');
    });

    test('AssetDraft: вид, монтаж и фото места в meta, точка в строке', () {
      const d = AssetDraft(
        name: 'КД-301',
        locationId: 'loc',
        kind: 'ac',
        baseMeta: {'kind': 'fancoil', 'serial_photo': 'p'},
        mount: MountInfo(mount: 'ceiling', heightM: 2.8),
        setPoint: true,
        point: PlanPoint('f1', 0.123456, 1.2),
        setPlacePhoto: true,
        placePhoto: 'c/o/f/asset-place-1.jpg',
      );
      final row = d.toRow();
      expect(row['meta'], {
        'kind': 'ac',
        'serial_photo': 'p',
        'mount': 'ceiling',
        'height_m': 2.8,
        'place_photo': 'c/o/f/asset-place-1.jpg',
      });
      expect(row['floor_id'], 'f1');
      expect(row['plan_x'], 0.1235);
      expect(row['plan_y'], 1.0);
    });

    test('AssetDraft: «убрать с плана» стирает точку, этаж не трогает', () {
      const d =
          AssetDraft(name: 'a', locationId: 'l', setPoint: true, point: null);
      final row = d.toRow();
      expect(row.containsKey('floor_id'), isFalse);
      expect(row['plan_x'], isNull);
      expect(row.containsKey('plan_x'), isTrue);
      const keep = AssetDraft(name: 'a', locationId: 'l');
      expect(keep.toRow().containsKey('plan_x'), isFalse);
    });

    test('путь фото места — только в папке этажа', () {
      const c = '11111111-1111-4111-8111-111111111111';
      const o = '22222222-2222-4222-8222-222222222222';
      const f = '33333333-3333-4333-8333-333333333333';
      final path = placePhotoPath(c, o, f, 'jpg', DateTime.utc(2026, 10, 14));
      expect(path, startsWith('$c/$o/$f/asset-place-'));
      expect(placePhotoOf({'place_photo': path}), path);
      expect(placePhotoOf({'place_photo': '../etc/passwd'}), isNull);
      expect(withPlacePhoto({'kind': 'ac', 'place_photo': path}, null),
          {'kind': 'ac'});
    });
  });
}
