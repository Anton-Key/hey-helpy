/// Работа без интернета (шаг 27): чистые функции очереди действий,
/// «честного» времени и наложения неотправленных действий на заявку.
/// Тесты — test/offline_logic_test.dart. Сеть, часы и файлы — в
/// offline_service.dart / device_clock.dart / offline_store.dart.
library;

/// Что сделали без сети: create — новая заявка (шаг 32, любой вошедший),
/// остальное — действия исполнителя (шаг 27).
enum OfflineKind { create, start, visit, check, photo, submit }

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

  /// create: title, description, priority, input_channel, layer_id,
  /// work_type, object_id, location_id, asset_id (+ для показа на телефоне:
  /// created_by, location_name, location_code);
  /// visit: lat, lng, accuracy, mock; check: item_id, done;
  /// photo: path, sha256, lat, lng, mock, stage (before — шаг 32).
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
  badAction,
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
      'bad_action' => SyncReason.badAction,
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
      this.photoKept = false,
      this.before = false});
  final OfflineKind kind;

  /// Фото «до» (шаг 32), а не «после».
  final bool before;
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
        'before': before,
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
        photoKept: j['photo_kept'] == true,
        before: j['before'] == true);
  }
}

/// Заявка, какой её видит исполнитель с учётом неотправленных действий:
/// статус, отмеченные пункты, фото и визит «ждут отправки».
class PendingView {
  const PendingView(
      {required this.status,
      this.checked = const {},
      this.photos = const [],
      this.beforePhotos = const [],
      this.visit = false,
      this.count = 0});

  final String status;

  /// item_id → отмечен ли (последнее действие по пункту).
  final Map<String, bool> checked;

  /// Действия-фото «после» по порядку.
  final List<OfflineAction> photos;

  /// Фото «до» новой заявки без сети (шаг 32).
  final List<OfflineAction> beforePhotos;
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
  final before = <OfflineAction>[];
  var visit = false;
  var n = 0;
  for (final a in queue) {
    if (a.orderId != orderId) continue;
    n++;
    switch (a.kind) {
      case OfflineKind.create:
        break; // статус «Новая» — уже в строке заявки из очереди
      case OfflineKind.start:
        if (const {'new', 'assigned', 'returned'}.contains(s)) {
          s = 'in_progress';
        }
      case OfflineKind.visit:
        visit = true;
      case OfflineKind.check:
        final id = a.payload['item_id'];
        if (id is String) checked[id] = a.payload['done'] != false;
      case OfflineKind.photo:
        (a.payload['stage'] == 'before' ? before : photos).add(a);
      case OfflineKind.submit:
        if (s == 'in_progress') s = 'on_review';
    }
  }
  return PendingView(
      status: s,
      checked: checked,
      photos: photos,
      beforePhotos: before,
      visit: visit,
      count: n);
}

/// Строка заявки, созданной без сети и ещё не отправленной (шаг 32), — для
/// списка и карточки на телефоне. `offline_pending` — пометка «ждёт отправки».
Map<String, dynamic> pendingOrderRow(OfflineAction a) {
  final p = a.payload;
  final locName = p['location_name'];
  return {
    'id': a.orderId,
    'title': p['title'] ?? '',
    'description': p['description'],
    'priority': p['priority'] ?? 'normal',
    'status': 'new',
    'layer_id': p['layer_id'],
    'work_type': p['work_type'],
    'object_id': p['object_id'],
    'location_id': p['location_id'],
    'asset_id': p['asset_id'],
    'input_channel': p['input_channel'] ?? 'button',
    'created_by': p['created_by'],
    'created_at': a.clock.device.toUtc().toIso8601String(),
    'recurrence': null,
    'locations':
        locName == null ? null : {'name': locName, 'code': p['location_code']},
    'offline_pending': true,
  };
}

/// Неотправленные новые заявки — новые первыми.
List<Map<String, dynamic>> pendingCreates(List<OfflineAction> queue) => [
      for (final a in queue.reversed)
        if (a.kind == OfflineKind.create) pendingOrderRow(a),
    ];

/// Порядок отправки: сначала новые заявки — снимки «до» кладутся в папку
/// заявки, а хранилище пускает только в папку уже существующей заявки.
({List<OfflineAction> creates, List<OfflineAction> rest}) splitForSync(
        List<OfflineAction> batch) =>
    (
      creates: [
        for (final a in batch)
          if (a.kind == OfflineKind.create) a
      ],
      rest: [
        for (final a in batch)
          if (a.kind != OfflineKind.create) a
      ],
    );

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
  // В веб-сборке имена типов сжаты — узнаём и по тексту (шаг 32).
  return s.startsWith('TimeoutException') ||
      s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('XMLHttpRequest error') ||
      s.contains('Failed to fetch') ||
      s.contains('Connection refused') ||
      s.contains('Connection reset') ||
      s.contains('Network is unreachable') ||
      s.contains('ClientException');
}

// ---------------------------------------------------------------------------
// Шаг 28: фото «до» и планы этажей на телефоне (предзагрузка)
// ---------------------------------------------------------------------------

/// ⚠️ Решение: фото «до» своих заявок — всего до 30 МБ, одно — до 4 МБ;
/// планы этажей — всего до 20 МБ, один — до 8 МБ (демо-схемы ~0,3 МБ,
/// реальные планы в PNG бывают 5–10 МБ; больше — не держим на телефоне).
const kOfflinePhotoBudget = 30 * 1024 * 1024;
const kOfflinePhotoMax = 4 * 1024 * 1024;
const kOfflinePlanBudget = 20 * 1024 * 1024;
const kOfflinePlanMax = 8 * 1024 * 1024;

/// Имя файла на телефоне: фото «до» — по id вложения; план — по этажу и
/// имени файла на сервере (заменили план — имя другое, старый удалится).
String offlinePhotoName(String attachmentId) => 'pre_$attachmentId.jpg';
String offlinePlanName(String floorId, String path) {
  final file = path.split('/').last.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  return 'plan_${floorId}_$file';
}

bool isOfflinePhotoName(String n) => n.startsWith('pre_');
bool isOfflinePlanName(String n) => n.startsWith('plan_');

/// Что из сохранённого больше не нужно ([drop]: заявку закрыли, передали
/// другому, этаж больше не нужен) и сколько займёт оставшееся ([used]) —
/// по видам ([isKind]: фото или планы).
({List<String> drop, int used}) mediaCleanup(Iterable<String> wanted,
    Map<String, int> stored, bool Function(String) isKind) {
  final want = wanted.toSet();
  final drop = <String>[];
  var used = 0;
  for (final e in stored.entries) {
    if (!isKind(e.key)) continue;
    if (want.contains(e.key)) {
      used += e.value;
    } else {
      drop.add(e.key);
    }
  }
  return (drop: drop, used: used);
}

/// Влезает ли ещё один файл размера [size] в бюджет.
bool mediaFits(int used, int size, int budget, int max) =>
    size > 0 && size <= max && used + size <= budget;

/// Фото «до», которые нужны на телефоне: заявки по порядку (новые первыми),
/// внутри заявки — по времени снимка; демо-картинки (путь `demo/`) — в
/// сборке, качать не нужно.
List<Map<String, dynamic>> beforePhotosToKeep(
    List<String> orderIds, List<Map<String, dynamic>> rows) {
  final byOrder = <String, List<Map<String, dynamic>>>{};
  for (final r in rows) {
    if (r['stage'] != 'before') continue;
    final p = '${r['storage_path'] ?? ''}';
    if (p.isEmpty || p.startsWith('demo/')) continue;
    byOrder.putIfAbsent('${r['work_order_id']}', () => []).add(r);
  }
  return [
    for (final id in orderIds)
      ...(byOrder[id] ?? const <Map<String, dynamic>>[])
        ..sort((a, b) =>
            '${a['created_at'] ?? ''}'.compareTo('${b['created_at'] ?? ''}')),
  ];
}
