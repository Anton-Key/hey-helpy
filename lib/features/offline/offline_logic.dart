/// Работа без интернета (шаг 27): чистые функции очереди действий,
/// «честного» времени и наложения неотправленных действий на заявку.
/// Тесты — test/offline_logic_test.dart. Сеть, часы и файлы — в
/// offline_service.dart / device_clock.dart / offline_store.dart.
library;

/// Что исполнитель сделал без сети.
enum OfflineKind { start, visit, check, photo, submit }

/// Показания часов телефона в момент действия.
class ClockReading {
  const ClockReading(
      {required this.device, this.monoMs, this.bootId, this.gpsAt});

  /// Часы телефона (их можно перевести).
  final DateTime device;

  /// Монотонные часы — миллисекунды с загрузки телефона.
  final int? monoMs;

  /// Номер загрузки телефона: после перезагрузки монотонные часы
  /// начинаются заново, якорь прежней загрузки не годится.
  final String? bootId;

  /// Время по спутникам GPS, пересчитанное к моменту действия.
  final DateTime? gpsAt;
}

/// «Время сервера при последней связи ↔ монотонные часы телефона».
class ClockAnchor {
  const ClockAnchor(
      {required this.serverAt, required this.monoMs, required this.bootId});
  final DateTime serverAt;
  final int monoMs;
  final String bootId;

  Map<String, Object?> toJson() => {
        'server_at': serverAt.toUtc().toIso8601String(),
        'mono_ms': monoMs,
        'boot': bootId,
      };

  static ClockAnchor? fromJson(Object? j) {
    if (j is! Map) return null;
    final at = DateTime.tryParse('${j['server_at']}');
    final mono = j['mono_ms'];
    final boot = j['boot'];
    if (at == null || mono is! int || boot is! String) return null;
    return ClockAnchor(serverAt: at, monoMs: mono, bootId: boot);
  }
}

/// Насколько можно верить времени действия (как `time_trust` в базе).
enum TimeTrust { online, gps, monotonic, deviceOnly, unverified }

TimeTrust? timeTrustFromDb(Object? v) => switch (v) {
      'online' => TimeTrust.online,
      'gps' => TimeTrust.gps,
      'monotonic' => TimeTrust.monotonic,
      'device_only' => TimeTrust.deviceOnly,
      'unverified' => TimeTrust.unverified,
      _ => null,
    };

/// Время подтверждено автоматически (не нужно решение менеджера).
bool trustOk(TimeTrust? t) =>
    t == null ||
    t == TimeTrust.online ||
    t == TimeTrust.gps ||
    t == TimeTrust.monotonic;

/// Порог расхождения часов телефона с доверенным временем.
const kMaxDrift = Duration(minutes: 5);

/// Доверенное время на телефоне (для штампа фото и подписи): якорь этой
/// загрузки + прошедшее по монотонным часам, иначе GPS. null — нет ни того,
/// ни другого (остаются часы телефона). Та же логика, что `offline_time`
/// в базе (0024); окончательное решение — за базой.
({DateTime at, TimeTrust trust, Duration? drift})? trustedTime(
    ClockReading r, ClockAnchor? anchor) {
  DateTime? mono;
  if (anchor != null &&
      r.monoMs != null &&
      r.bootId == anchor.bootId &&
      r.monoMs! >= anchor.monoMs) {
    mono =
        anchor.serverAt.add(Duration(milliseconds: r.monoMs! - anchor.monoMs));
  }
  final gps = r.gpsAt;
  if (mono == null && gps == null) return null;
  final at = mono ?? gps!;
  var trust = mono != null ? TimeTrust.monotonic : TimeTrust.gps;
  if (mono != null && gps != null && gps.difference(mono).abs() > kMaxDrift) {
    trust = TimeTrust.unverified;
  }
  final drift = r.device.difference(at);
  if (drift.abs() > kMaxDrift) trust = TimeTrust.unverified;
  return (at: at, trust: trust, drift: drift);
}

/// Время для штампа: доверенное, если есть, иначе часы телефона.
DateTime stampTime(ClockReading r, ClockAnchor? anchor) =>
    trustedTime(r, anchor)?.at ?? r.device;

/// Одно действие очереди. [id] — свой у каждого: повторная отправка не
/// создаёт дублей (база помнит id в `offline_actions`).
class OfflineAction {
  const OfflineAction({
    required this.id,
    required this.kind,
    required this.orderId,
    required this.clock,
    this.payload = const {},
    this.photoFile,
  });

  final String id;
  final OfflineKind kind;
  final String orderId;
  final ClockReading clock;

  /// visit: lat, lng, accuracy, mock; check: item_id, done;
  /// photo: path, sha256, lat, lng, mock.
  final Map<String, Object?> payload;

  /// Имя файла снимка в каталоге приложения (только у photo).
  final String? photoFile;

  /// Для `offline_sync` в базе.
  Map<String, Object?> toServer() => {
        'id': id,
        'kind': kind.name,
        'order_id': orderId,
        'device_at': clock.device.toUtc().toIso8601String(),
        if (clock.gpsAt != null)
          'gps_at': clock.gpsAt!.toUtc().toIso8601String(),
        if (clock.bootId != null && clock.monoMs != null) ...{
          'boot': clock.bootId,
          'mono_ms': clock.monoMs,
        },
        ...payload,
      };

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'order_id': orderId,
        'device_at': clock.device.toUtc().toIso8601String(),
        'gps_at': clock.gpsAt?.toUtc().toIso8601String(),
        'boot': clock.bootId,
        'mono_ms': clock.monoMs,
        'payload': payload,
        'photo_file': photoFile,
      };

  static OfflineAction? fromJson(Object? j) {
    if (j is! Map) return null;
    final kind = OfflineKind.values.where((k) => k.name == j['kind']);
    final device = DateTime.tryParse('${j['device_at']}');
    if (kind.isEmpty || device == null || j['id'] is! String) return null;
    return OfflineAction(
      id: j['id'] as String,
      kind: kind.first,
      orderId: '${j['order_id']}',
      clock: ClockReading(
          device: device,
          gpsAt: DateTime.tryParse('${j['gps_at'] ?? ''}'),
          bootId: j['boot'] as String?,
          monoMs: j['mono_ms'] as int?),
      payload: Map<String, Object?>.from((j['payload'] as Map?) ?? const {}),
      photoFile: j['photo_file'] as String?,
    );
  }
}

/// Ответ базы на одно действие.
enum SyncOutcome { applied, rejected, savedLate }

/// Почему действие не применилось (коды `offline_conflict` в базе).
enum SyncReason {
  cancelled,
  reassigned,
  accepted,
  onReview,
  photoRequired,
  photoMismatch,
  photoMissing,
  notFound,
  denied,
  other
}

SyncReason syncReasonFromDb(Object? v) => switch (v) {
      'cancelled' => SyncReason.cancelled,
      'reassigned' => SyncReason.reassigned,
      'accepted' => SyncReason.accepted,
      'on_review' => SyncReason.onReview,
      'photo_required' => SyncReason.photoRequired,
      'photo_hash_mismatch' => SyncReason.photoMismatch,
      'photo_missing' => SyncReason.photoMissing,
      'not_found' => SyncReason.notFound,
      'denied' => SyncReason.denied,
      _ => SyncReason.other,
    };

class SyncResult {
  const SyncResult(this.id, this.outcome, {this.reason, this.trust});
  final String id;
  final SyncOutcome outcome;
  final SyncReason? reason;
  final TimeTrust? trust;

  static List<SyncResult> parse(Object? body) => [
        if (body is List)
          for (final e in body)
            if (e is Map && e['id'] != null)
              SyncResult(
                '${e['id']}',
                switch (e['result']) {
                  'applied' => SyncOutcome.applied,
                  'saved_late' => SyncOutcome.savedLate,
                  _ => SyncOutcome.rejected,
                },
                reason:
                    e['reason'] == null ? null : syncReasonFromDb(e['reason']),
                trust: timeTrustFromDb(e['trust']),
              ),
      ];
}

/// Не отправленное и не принятое — для «Не удалось отправить N действий».
class SyncFailure {
  const SyncFailure(
      {required this.kind,
      required this.orderId,
      required this.reason,
      this.orderTitle,
      this.photoKept = false});
  final OfflineKind kind;
  final String orderId;
  final String? orderTitle;
  final SyncReason reason;

  /// Фото всё равно сохранено в заявке (пометка «прислано после отмены»).
  final bool photoKept;

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'order_id': orderId,
        'title': orderTitle,
        'reason': reason.name,
        'photo_kept': photoKept,
      };

  static SyncFailure? fromJson(Object? j) {
    if (j is! Map) return null;
    final kind = OfflineKind.values.where((k) => k.name == j['kind']);
    final reason = SyncReason.values.where((r) => r.name == j['reason']);
    if (kind.isEmpty || reason.isEmpty) return null;
    return SyncFailure(
        kind: kind.first,
        orderId: '${j['order_id']}',
        orderTitle: j['title'] as String?,
        reason: reason.first,
        photoKept: j['photo_kept'] == true);
  }
}

/// Заявка, какой её видит исполнитель с учётом неотправленных действий:
/// статус, отмеченные пункты, фото и визит «ждут отправки».
class PendingView {
  const PendingView(
      {required this.status,
      this.checked = const {},
      this.photos = const [],
      this.visit = false,
      this.count = 0});

  final String status;

  /// item_id → отмечен ли (последнее действие по пункту).
  final Map<String, bool> checked;

  /// Действия-фото по порядку.
  final List<OfflineAction> photos;
  final bool visit;

  /// Сколько действий по заявке ждёт отправки.
  final int count;

  bool get pending => count > 0;
}

PendingView pendingView(
    String status, List<OfflineAction> queue, String orderId) {
  var s = status;
  final checked = <String, bool>{};
  final photos = <OfflineAction>[];
  var visit = false;
  var n = 0;
  for (final a in queue) {
    if (a.orderId != orderId) continue;
    n++;
    switch (a.kind) {
      case OfflineKind.start:
        if (const {'new', 'assigned', 'returned'}.contains(s))
          s = 'in_progress';
      case OfflineKind.visit:
        visit = true;
      case OfflineKind.check:
        final id = a.payload['item_id'];
        if (id is String) checked[id] = a.payload['done'] != false;
      case OfflineKind.photo:
        photos.add(a);
      case OfflineKind.submit:
        if (s == 'in_progress') s = 'on_review';
    }
  }
  return PendingView(
      status: s, checked: checked, photos: photos, visit: visit, count: n);
}

/// Ставить ли действие в очередь, а не отправлять сразу: нет сети или по
/// этой заявке уже есть неотправленные действия (порядок важен).
bool shouldQueue(
        {required bool online,
        required List<OfflineAction> queue,
        required String orderId}) =>
    !online || queue.any((a) => a.orderId == orderId);

/// Ошибка сети (а не отказ базы): нет соединения, таймаут, DNS.
/// По тексту и типу — без dart:io, чтобы собиралось и в вебе.
bool isNetworkError(Object e) {
  final t = e.runtimeType.toString();
  if (t.contains('TimeoutException') ||
      t.contains('SocketException') ||
      t.contains('ClientException') ||
      t.contains('AuthRetryableFetchException') ||
      t.contains('HandshakeException')) {
    return true;
  }
  final s = '$e';
  return s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('XMLHttpRequest error') ||
      s.contains('Failed to fetch') ||
      s.contains('Connection refused') ||
      s.contains('Connection reset') ||
      s.contains('Network is unreachable') ||
      s.contains('ClientException');
}
