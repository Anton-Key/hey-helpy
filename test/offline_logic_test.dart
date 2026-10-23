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
    // Веб-сборка: имя типа сжато, остаётся текст (шаг 32).
    expect(isNetworkError(_Minified('TimeoutException: offline')), isTrue);
  });

  test('доверие времени: что засчитывается автоматически', () {
    expect(trustOk(TimeTrust.online), isTrue);
    expect(trustOk(TimeTrust.gps), isTrue);
    expect(trustOk(TimeTrust.monotonic), isTrue);
    expect(trustOk(TimeTrust.deviceOnly), isFalse);
    expect(trustOk(TimeTrust.unverified), isFalse);
    expect(timeTrustFromDb('device_only'), TimeTrust.deviceOnly);
  });

  group('новая заявка без сети (шаг 32)', () {
    OfflineAction act(String id, OfflineKind k, String order,
            [Map<String, Object?> p = const {}]) =>
        OfflineAction(
            id: id,
            kind: k,
            orderId: order,
            clock: ClockReading(device: server),
            payload: p);
    final create = act('a1', OfflineKind.create, 'w1', {
      'title': 'Капает вода',
      'priority': 'high',
      'layer_id': 'L1',
      'work_type': 'Климат',
      'object_id': 'o1',
      'location_id': 'l1',
      'location_name': 'Переговорная',
      'location_code': '301',
      'input_channel': 'text',
      'created_by': 'u1',
    });
    final before = act('a2', OfflineKind.photo, 'w1',
        {'stage': 'before', 'path': 'c/w1/off_a2.jpg', 'sha256': 'x'});

    test('строка заявки из очереди: «Новая», поля и помещение', () {
      final r = pendingOrderRow(create);
      expect(r['id'], 'w1');
      expect(r['status'], 'new');
      expect(r['priority'], 'high');
      expect(r['title'], 'Капает вода');
      expect(r['created_by'], 'u1');
      expect(r['created_at'], server.toIso8601String());
      expect(r['locations'], {'name': 'Переговорная', 'code': '301'});
      expect(r['offline_pending'], isTrue);
    });

    test('неотправленные новые заявки — новые первыми', () {
      final second = act('a3', OfflineKind.create, 'w2', {'title': 'Второе'});
      final q = [create, before, act('a4', OfflineKind.start, 'w9'), second];
      expect([for (final r in pendingCreates(q)) r['id']], ['w2', 'w1']);
    });

    test('отправка: сначала новые заявки, порядок остальных сохраняется', () {
      final start = act('a5', OfflineKind.start, 'w9');
      final p = splitForSync([start, before, create]);
      expect([for (final a in p.creates) a.id], ['a1']);
      expect([for (final a in p.rest) a.id], ['a5', 'a2']);
    });

    test('фото «до» не считается фото «после»', () {
      final v = pendingView('new', [create, before], 'w1');
      expect(v.photos, isEmpty);
      expect([for (final a in v.beforePhotos) a.id], ['a2']);
      expect(v.status, 'new');
      expect(v.count, 2);
    });

    test('create уходит на сервер со всеми полями и переживает перезапуск', () {
      final j = create.toServer();
      expect(j['kind'], 'create');
      expect(j['order_id'], 'w1');
      expect(j['title'], 'Капает вода');
      expect(j['layer_id'], 'L1');
      final back = OfflineAction.fromJson(create.toJson())!;
      expect(back.kind, OfflineKind.create);
      expect(back.payload['location_name'], 'Переговорная');
    });

    test('отказ: причина bad_action и пометка фото «до»', () {
      expect(syncReasonFromDb('bad_action'), SyncReason.badAction);
      const f = SyncFailure(
          kind: OfflineKind.photo,
          orderId: 'w1',
          reason: SyncReason.cancelled,
          before: true);
      expect(SyncFailure.fromJson(f.toJson())!.before, isTrue);
    });
  });
}

/// Ошибка, как её видит веб-сборка: тип с чужим именем, текст — исходный.
class _Minified {
  const _Minified(this.text);
  final String text;
  @override
  String toString() => text;
}
