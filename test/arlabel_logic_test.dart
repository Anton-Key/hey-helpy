import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/arlabel/arlabel_logic.dart';
import 'package:hey_helpy/l10n/app_localizations_en.dart';
import 'package:hey_helpy/l10n/app_localizations_ru.dart';

void main() {
  test('статус канала', () {
    expect(ArLabelStatus.fromMap(null).available, isFalse);
    expect(ArLabelStatus.fromMap({'available': false}).available, isFalse);
    final s = ArLabelStatus.fromMap(
        {'available': true, 'arcore': 'supported', 'camera': 'granted'});
    expect(s.available, isTrue);
    expect(s.arcore, 'supported');
    expect(s.camera, 'granted');
  });

  test('сводка: открытые заявки без ППР, своё ТО, затем ТО системы', () {
    final f = arFactsByAsset([
      {'id': 'a', 'layer_id': 'hvac'},
      {'id': 'b', 'layer_id': 'hvac'},
      {'id': 'c', 'layer_id': null},
    ], [
      {'asset_id': 'a', 'status': 'new'},
      {'asset_id': 'a', 'status': 'in_progress'},
      {'asset_id': 'a', 'status': 'done'},
      {
        'asset_id': 'a',
        'status': 'assigned',
        'plan_id': 'p',
        'period_end': '2026-11-30'
      },
      {
        'asset_id': 'a',
        'status': 'assigned',
        'plan_id': 'p',
        'period_end': '2026-10-31'
      },
      // ТО системы на объекте (без оборудования) — для b.
      {
        'asset_id': null,
        'layer_id': 'hvac',
        'status': 'assigned',
        'plan_id': 'q',
        'period_end': '2026-10-25'
      },
      {
        'asset_id': null,
        'layer_id': 'hvac',
        'status': 'cancelled',
        'plan_id': 'q',
        'period_end': '2026-10-01'
      },
    ]);
    expect(f['a']!.openCount, 2);
    expect(f['a']!.due, DateTime(2026, 10, 31));
    expect(f['b']!.openCount, 0);
    expect(f['b']!.due, DateTime(2026, 10, 25));
    expect(f['c']!.due, isNull);
  });

  test('ТО просрочено — по дате', () {
    final now = DateTime(2026, 10, 22, 9);
    expect(arOverdue(DateTime(2026, 10, 21), now), isTrue);
    expect(arOverdue(DateTime(2026, 10, 22), now), isFalse);
    expect(arOverdue(DateTime(2026, 10, 31), now), isFalse);
  });

  test('ответ экрана', () {
    expect(ArLabelResult.fromMap(null), isNull);
    expect(ArLabelResult.fromMap({}), isNull);
    expect(ArLabelResult.fromMap({'action': 'x', 'assetId': 'a'}), isNull);
    final a = ArLabelResult.fromMap({'action': 'asset', 'assetId': 'a'})!;
    expect(a.action, ArLabelAction.asset);
    expect(a.identification, isNull);
    final o = ArLabelResult.fromMap({
      'action': 'order',
      'assetId': 'a',
      'photoPath': '/cache/arlabel_1.jpg',
      'takenAt': 1792656000000,
    }, identify: {
      'source': 'ai',
      'kind': 'ac',
      'defect': 'Капает вода',
      'confidence': 0.9,
      'candidates': [],
    })!;
    expect(o.action, ArLabelAction.order);
    expect(o.photoPath, '/cache/arlabel_1.jpg');
    expect(o.takenAt, DateTime.fromMillisecondsSinceEpoch(1792656000000));
    expect(o.identification!.kind, 'ac');
    expect(o.identification!.defect, 'Капает вода');
  });

  test('шаблоны для Kotlin: {n} и {date} остаются как есть', () {
    for (final t in [
      arLabelNativeTexts(AppLocalizationsRu()),
      arLabelNativeTexts(AppLocalizationsEn()),
    ]) {
      for (final k in ['arOrdersOne', 'arOrdersFew', 'arOrdersMany']) {
        expect(t[k], contains('{n}'), reason: k);
      }
      expect(t['arMaintenanceDue'], contains('{date}'));
    }
    final ru = arLabelNativeTexts(AppLocalizationsRu());
    expect(ru['arOrdersMany'], '{n} открытых заявок');
    expect(ru['arMaintenanceDue'], 'ТО до {date}');
    expect(ru['arNoNetwork'], 'Нужен интернет для узнавания оборудования');
  });

  test('строки нативного экрана: каждый ключ из Kotlin передаётся из Flutter',
      () {
    final dir = Directory('android/arlabel/src/main/kotlin');
    final used = <String>{};
    final re = RegExp(r'"((?:ar[A-Z]|common[A-Z])[A-Za-z]+)"');
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      for (final m in re.allMatches(f.readAsStringSync())) {
        used.add(m.group(1)!);
      }
    }
    // Формы числа собираются в Kotlin из "arOrders" + One / Few / Many.
    used
      ..remove('arOrders')
      ..addAll(['arOrdersOne', 'arOrdersFew', 'arOrdersMany']);
    for (final texts in [
      arLabelNativeTexts(AppLocalizationsRu()),
      arLabelNativeTexts(AppLocalizationsEn()),
    ]) {
      expect(used, contains('arWhatIsIt'));
      expect(used.difference(texts.keys.toSet()), isEmpty);
      expect(texts.values.every((v) => v.isNotEmpty), isTrue);
    }
  });
}
