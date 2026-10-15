import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/offline/device_clock.dart';
import 'package:hey_helpy/features/offline/offline_logic.dart';

void main() {
  final server = DateTime.utc(2026, 10, 14, 12);
  const boot = 'b7';
  final anchor = ClockAnchor(serverAt: server, monoMs: 1000000, bootId: boot);

  group('trustedTime', () {
    test('монотонные часы: якорь + прошедшее', () {
      final r = ClockReading(
          device: server.add(const Duration(minutes: 30)),
          monoMs: 1000000 + 30 * 60000,
          bootId: boot);
      final t = trustedTime(r, anchor)!;
      expect(t.trust, TimeTrust.monotonic);
      expect(t.at, server.add(const Duration(minutes: 30)));
      expect(t.drift, Duration.zero);
    });

    test('часы телефона переведены на 2 ч — unverified, расхождение 2 ч', () {
      final r = ClockReading(
          device: server.add(const Duration(hours: 2, minutes: 30)),
          monoMs: 1000000 + 30 * 60000,
          bootId: boot);
      final t = trustedTime(r, anchor)!;
      expect(t.trust, TimeTrust.unverified);
      expect(t.at, server.add(const Duration(minutes: 30)));
      expect(t.drift, const Duration(hours: 2));
    });

    test('после перезагрузки якорь не годится — остаётся GPS', () {
      final gps = server.add(const Duration(hours: 1));
      final r = ClockReading(
          device: gps.add(const Duration(seconds: 20)),
          monoMs: 5000,
          bootId: 'b8',
          gpsAt: gps);
      final t = trustedTime(r, anchor)!;
      expect(t.trust, TimeTrust.gps);
      expect(t.at, gps);
    });

    test('расхождение до 5 минут — ещё подтверждено', () {
      final r = ClockReading(
          device: server.add(const Duration(minutes: 4)),
          monoMs: 1000000,
          bootId: boot);
      expect(trustedTime(r, anchor)!.trust, TimeTrust.monotonic);
    });

    test('GPS спорит с монотонными — unverified', () {
      final r = ClockReading(
          device: server,
          monoMs: 1000000,
          bootId: boot,
          gpsAt: server.subtract(const Duration(hours: 3)));
      expect(trustedTime(r, anchor)!.trust, TimeTrust.unverified);
    });

    test('нет ни якоря, ни GPS — null, штамп по часам телефона', () {
      final r = ClockReading(device: server);
      expect(trustedTime(r, null), isNull);
      expect(stampTime(r, null), server);
    });

    test('штамп — по доверенному времени, не по переведённым часам', () {
      final r = ClockReading(
          device: server.add(const Duration(hours: 5)),
          monoMs: 1000000 + 60000,
          bootId: boot);
      expect(stampTime(r, anchor), server.add(const Duration(minutes: 1)));
    });
  });

  test('gpsNow: время фикса + прошедшее; старый фикс не берём', () {
    final fix = DateTime.utc(2026, 10, 14, 12).millisecondsSinceEpoch;
    expect(gpsNow(gpsTime: fix, gpsElapsed: 1000, mono: 61000),
        DateTime.utc(2026, 10, 14, 12, 1));
    expect(gpsNow(gpsTime: fix, gpsElapsed: 1000, mono: 1000 + 31 * 60000),
        isNull);
    expect(gpsNow(gpsTime: null, gpsElapsed: 1, mono: 2), isNull);
  });

  group('очередь', () {
    OfflineAction a(String id, OfflineKind k, String order,
            [Map<String, Object?> p = const {}]) =>
        OfflineAction(
            id: id,
            kind: k,
            orderId: order,
            clock: ClockReading(device: server),
            payload: p);

    test('наложение: начать → чек-лист → фото → сдать', () {
      final q = [
        a('1', OfflineKind.start, 'w'),
        a('2', OfflineKind.visit, 'w'),
        a('3', OfflineKind.check, 'w', {'item_id': 'i1', 'done': true}),
        a('4', OfflineKind.check, 'w', {'item_id': 'i2', 'done': true}),
        a('5', OfflineKind.check, 'w', {'item_id': 'i2', 'done': false}),
        a('6', OfflineKind.photo, 'w'),
        a('7', OfflineKind.start, 'other'),
      ];
      var v = pendingView('assigned', q, 'w');
      expect(v.status, 'in_progress');
      expect(v.checked, {'i1': true, 'i2': false});
      expect(v.photos.length, 1);
      expect(v.visit, isTrue);
      expect(v.count, 6);
      v = pendingView('assigned', [...q, a('8', OfflineKind.submit, 'w')], 'w');
      expect(v.status, 'on_review');
      expect(pendingView('cancelled', q, 'w').status, 'cancelled');
    });

    test('в очередь — без сети или если по заявке уже есть неотправленное', () {
      final q = [a('1', OfflineKind.start, 'w')];
      expect(shouldQueue(online: false, queue: const [], orderId: 'w'), isTrue);
      expect(shouldQueue(online: true, queue: q, orderId: 'w'), isTrue);
      expect(shouldQueue(online: true, queue: q, orderId: 'x'), isFalse);
    });

    test('действие → JSON → действие; для сервера — без лишнего', () {
      final x = OfflineAction(
          id: 'id1',
          kind: OfflineKind.photo,
          orderId: 'w',
          clock: ClockReading(
              device: server, monoMs: 42, bootId: boot, gpsAt: server),
          payload: const {'path': 'c/w/off_id1.jpg', 'sha256': 'ab'},
          photoFile: 'id1.jpg');
      final y = OfflineAction.fromJson(x.toJson())!;
      expect(y.toJson(), x.toJson());
      final s = x.toServer();
      expect(s['kind'], 'photo');
      expect(s['mono_ms'], 42);
      expect(s['boot'], boot);
      expect(s['path'], 'c/w/off_id1.jpg');
      expect(s.containsKey('photo_file'), isFalse);
    });

    test('ответ сервера: применено / отклонено / сохранено после отмены', () {
      final r = SyncResult.parse([
        {'id': '1', 'result': 'applied', 'trust': 'monotonic'},
        {'id': '2', 'result': 'rejected', 'reason': 'cancelled'},
        {'id': '3', 'result': 'saved_late', 'reason': 'cancelled'},
        {'id': '4', 'result': 'rejected', 'reason': 'что-то новое'},
      ]);
      expect(r[0].outcome, SyncOutcome.applied);
      expect(r[0].trust, TimeTrust.monotonic);
      expect(r[1].reason, SyncReason.cancelled);
      expect(r[2].outcome, SyncOutcome.savedLate);
      expect(r[3].reason, SyncReason.other);
    });
  });

  test('ошибка сети отличается от отказа базы', () {
    expect(isNetworkError(Exception('SocketException: Failed host lookup')),
        isTrue);
    expect(isNetworkError(Exception('ClientException: XMLHttpRequest error.')),
        isTrue);
    expect(isNetworkError(Exception('new row violates row-level security')),
        isFalse);
  });

  test('доверие времени: что засчитывается автоматически', () {
    expect(trustOk(TimeTrust.online), isTrue);
    expect(trustOk(TimeTrust.gps), isTrue);
    expect(trustOk(TimeTrust.monotonic), isTrue);
    expect(trustOk(TimeTrust.deviceOnly), isFalse);
    expect(trustOk(TimeTrust.unverified), isFalse);
    expect(timeTrustFromDb('device_only'), TimeTrust.deviceOnly);
  });
}
