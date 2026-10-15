import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/vps/vps_launch.dart';
import 'package:hey_helpy/features/vps/vps_logic.dart';
import 'package:hey_helpy/l10n/app_localizations_ru.dart';

void main() {
  group('VpsStatus', () {
    test('обычная сборка — нет канала', () {
      expect(VpsStatus.fromMap(null).available, isFalse);
      expect(VpsStatus.fromMap({'available': false}).available, isFalse);
    });

    test('разбор ответа канала', () {
      final s = VpsStatus.fromMap({
        'available': true,
        'token': 'ok',
        'arcore': 'supported',
        'tokenExpiresAt': DateTime(2026, 12, 1).millisecondsSinceEpoch,
      });
      expect(s.available, isTrue);
      expect(s.token, VpsToken.ok);
      expect(s.arcore, VpsArcore.supported);
      expect(s.tokenExpiresAt, DateTime(2026, 12, 1));
      expect(VpsStatus.fromMap({'available': true, 'token': '?'}).token,
          VpsToken.missing);
    });
  });

  group('vpsBlocker', () {
    final now = DateTime(2026, 10, 15);
    VpsStatus st(
            {VpsToken token = VpsToken.ok,
            VpsArcore arcore = VpsArcore.supported,
            DateTime? exp}) =>
        VpsStatus(
            available: true, token: token, arcore: arcore, tokenExpiresAt: exp);

    test('по порядку: токен → ARCore → скан', () {
      expect(vpsBlocker(st(token: VpsToken.missing), hasSite: false, now: now),
          VpsBlocker.tokenMissing);
      expect(vpsBlocker(st(token: VpsToken.expired), hasSite: true, now: now),
          VpsBlocker.tokenExpired);
      expect(
          vpsBlocker(st(arcore: VpsArcore.unsupported), hasSite: true, now: now),
          VpsBlocker.noArcore);
      expect(vpsBlocker(st(), hasSite: false, now: now), VpsBlocker.noSite);
      expect(vpsBlocker(st(), hasSite: true, now: now), isNull);
      // ARCore «неизвестно» не блокирует — решит сам экран
      expect(
          vpsBlocker(st(arcore: VpsArcore.unknown), hasSite: true, now: now),
          isNull);
    });

    test('срок токена истёк по дате, хотя при сборке был ok', () {
      expect(
          vpsBlocker(st(exp: DateTime(2026, 10, 14)), hasSite: true, now: now),
          VpsBlocker.tokenExpired);
      expect(vpsTokenDaysLeft(st(exp: DateTime(2026, 10, 20)), now), 5);
      expect(vpsTokenDaysLeft(st(), now), isNull);
    });
  });

  test('normalizePayload', () {
    expect(normalizePayload('  CjIKMAo  uQXJ\n0aWN=  '), 'CjIKMAouQXJ0aWN=');
    expect(normalizePayload('short'), isNull);
    expect(normalizePayload('привет мир это не payload'), isNull);
    expect(normalizePayload('a' * 20001), isNull);
    expect(payloadPreview('ABCDEFGHIJKLMNOPQRSTUVWXYZ'), 'ABCDEF…UVWXYZ');
    expect(payloadPreview('ABCDEF'), 'ABCDEF');
  });

  test('подпись метки', () {
    final l = AppLocalizationsRu();
    String line(int n, DateTime? d) => vpsMarkLine(
        openCount: n,
        nextDue: d,
        openOrders: l.vpsOpenOrders,
        noOpenOrders: l.vpsNoOpenOrders,
        maintenance: (d) => l.vpsMaintenance('${d.day}.${d.month}'));
    expect(line(1, DateTime(2026, 10, 31)), '1 открытая заявка · ТО 31.10');
    expect(line(0, null), 'Открытых заявок нет');
    expect(line(3, null), '3 открытые заявки');
  });

  test('сводка по оборудованию: заявки без ППР, ближайшее ТО', () {
    final f = vpsFactsByAsset([
      {'asset_id': 'a', 'status': 'new'},
      {'asset_id': 'a', 'status': 'in_progress'},
      {'asset_id': 'a', 'status': 'done'},
      {
        'asset_id': 'a',
        'status': 'assigned',
        'plan_id': 'p',
        'period_end': '2026-10-31'
      },
      {
        'asset_id': 'a',
        'status': 'assigned',
        'plan_id': 'p',
        'period_end': '2026-11-30'
      },
      {'asset_id': 'b', 'status': 'cancelled'},
      {'asset_id': null, 'status': 'new'},
    ]);
    expect(f['a']!.openCount, 2);
    expect(f['a']!.nextDue, DateTime(2026, 10, 31));
    expect(f.containsKey('b'), isFalse);
  });

  test('строки нативного экрана: каждый ключ из Kotlin передаётся из Flutter',
      () {
    final texts = vpsNativeTexts(AppLocalizationsRu());
    final dir = Directory('android/vps/src/main/kotlin');
    final used = <String>{};
    final re = RegExp(
        r'''(?:\bt|showMessage|blocked)\("([A-Za-z]+)"|->\s*"(vps[A-Za-z]+)"|to\s+"(vps[A-Za-z]+)"''');
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      for (final m in re.allMatches(f.readAsStringSync())) {
        used.add(m.group(1) ?? m.group(2) ?? m.group(3)!);
      }
    }
    expect(used, isNotEmpty);
    expect(used.difference(texts.keys.toSet()), isEmpty);
    expect(texts.values.every((v) => v.isNotEmpty), isTrue);
  });
}
