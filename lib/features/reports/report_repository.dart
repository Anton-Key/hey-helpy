import 'package:supabase_flutter/supabase_flutter.dart';

/// Период и фильтры отчёта. [to] — не включительно.
class ReportQuery {
  final DateTime from;
  final DateTime to;
  final String? objectId;
  final String? contractorId;
  final String? layerId;
  const ReportQuery(
      {required this.from,
      required this.to,
      this.objectId,
      this.contractorId,
      this.layerId});
}

/// Заявка в отчёте: только то, что нужно для расчёта.
class ReportOrder {
  final String id;
  final String title;
  final String status;
  final String priority;
  final String? objectId;
  final String? layerId;
  final String? workType;
  final String? contractorId;
  final bool recurring;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final DateTime? acceptedAt;
  final DateTime? dueAt;

  /// Сколько раз работу возвращали на доработку.
  final int returnCount;
  final bool hasBeforePhoto;
  final bool hasAfterPhoto;

  const ReportOrder(
      {required this.id,
      this.title = '',
      required this.status,
      this.priority = 'normal',
      this.objectId,
      this.layerId,
      this.workType,
      this.contractorId,
      this.recurring = false,
      required this.createdAt,
      this.startedAt,
      this.submittedAt,
      this.acceptedAt,
      this.dueAt,
      this.returnCount = 0,
      this.hasBeforePhoto = false,
      this.hasAfterPhoto = false});

  /// Счётчик возвратов — из 0010 (`return_count`). До неё — по причине возврата,
  /// которая остаётся в заявке после возврата.
  factory ReportOrder.fromMap(Map<String, dynamic> m,
      {bool hasBefore = false, bool hasAfter = false}) {
    final reason = (m['return_reason'] as String?)?.trim() ?? '';
    final count = m.containsKey('return_count')
        ? (m['return_count'] as num?)?.toInt() ?? 0
        : (reason.isNotEmpty ? 1 : 0);
    return ReportOrder(
      id: m['id'] as String,
      title: (m['title'] ?? '') as String,
      status: (m['status'] ?? 'new') as String,
      priority: (m['priority'] ?? 'normal') as String,
      objectId: m['object_id'] as String?,
      layerId: m['layer_id'] as String?,
      workType: m['work_type'] as String?,
      contractorId: m['assigned_contractor_id'] as String?,
      recurring: m['recurrence'] != null,
      createdAt: DateTime.parse('${m['created_at']}'),
      startedAt: DateTime.tryParse('${m['started_at']}'),
      submittedAt: DateTime.tryParse('${m['submitted_at']}'),
      acceptedAt: DateTime.tryParse('${m['accepted_at']}'),
      dueAt: DateTime.tryParse('${m['due_at']}'),
      returnCount: count,
      hasBeforePhoto: hasBefore,
      hasAfterPhoto: hasAfter,
    );
  }

  bool get accepted => status == 'done';
  bool get cancelled => status == 'cancelled';
  bool get wasReturned => returnCount > 0 || status == 'returned';

  /// Работа сдана (на проверке или принята) — для доли с фото.
  bool get submitted => status == 'on_review' || status == 'done';

  /// Просрочена: принята позже дедлайна или не принята, а дедлайн прошёл.
  bool isOverdue(DateTime now) {
    if (cancelled) return false;
    if (status == 'overdue') return true;
    final due = dueAt;
    if (due == null) return false;
    if (accepted) return acceptedAt != null && acceptedAt!.isAfter(due);
    return now.isAfter(due);
  }
}

/// Посещение в отчёте.
class ReportVisit {
  final String? contractorId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool? inGeofence;
  final bool mockLocation;
  const ReportVisit(
      {this.contractorId,
      required this.startedAt,
      this.endedAt,
      this.inGeofence,
      this.mockLocation = false});

  factory ReportVisit.fromMap(Map<String, dynamic> m) => ReportVisit(
        contractorId: m['contractor_id'] as String?,
        startedAt: DateTime.parse('${m['started_at']}'),
        endedAt: DateTime.tryParse('${m['ended_at']}'),
        inGeofence: m['in_geofence'] as bool?,
        mockLocation: m['mock_location'] == true,
      );

  /// Вне геозоны или с подменой GPS.
  bool get suspicious => inGeofence == false || mockLocation;

  /// Время на объекте; у незакрытого визита не считается.
  Duration get onSite =>
      endedAt == null ? Duration.zero : endedAt!.difference(startedAt);
}

/// Норма визитов в месяц у закрепления подрядчика (0010).
class VisitNorm {
  final String contractorId;
  final String layerId;
  final String? objectId;
  final int visitsPerMonth;
  const VisitNorm(
      {required this.contractorId,
      required this.layerId,
      this.objectId,
      required this.visitsPerMonth});
}

/// Показатели по набору заявок и визитов.
class ReportStats {
  int total = 0;
  int accepted = 0;
  int returned = 0;
  int overdue = 0;

  /// Принятые с дедлайном и из них — принятые до дедлайна.
  int acceptedWithDue = 0;
  int acceptedOnTime = 0;
  int firstPass = 0;
  Duration _reaction = Duration.zero;
  int _reactionCount = 0;
  Duration _execution = Duration.zero;
  int _executionCount = 0;
  int visits = 0;
  int visitsInGeofence = 0;
  int visitsSuspicious = 0;
  Duration onSite = Duration.zero;
  int submitted = 0;
  int submittedWithPhotos = 0;

  /// Норма визитов за период; null — нормы нет.
  int? visitNorm;

  void addOrder(ReportOrder o, DateTime now) {
    total++;
    if (o.wasReturned) returned++;
    if (o.isOverdue(now)) overdue++;
    if (o.accepted) {
      accepted++;
      if (o.returnCount == 0) firstPass++;
      if (o.dueAt != null && o.acceptedAt != null) {
        acceptedWithDue++;
        if (!o.acceptedAt!.isAfter(o.dueAt!)) acceptedOnTime++;
      }
    }
    if (o.startedAt != null && !o.startedAt!.isBefore(o.createdAt)) {
      _reaction += o.startedAt!.difference(o.createdAt);
      _reactionCount++;
    }
    if (o.startedAt != null &&
        o.submittedAt != null &&
        !o.submittedAt!.isBefore(o.startedAt!)) {
      _execution += o.submittedAt!.difference(o.startedAt!);
      _executionCount++;
    }
    if (o.submitted) {
      submitted++;
      if (o.hasBeforePhoto && o.hasAfterPhoto) submittedWithPhotos++;
    }
  }

  void addVisit(ReportVisit v) {
    visits++;
    if (v.inGeofence == true && !v.mockLocation) visitsInGeofence++;
    if (v.suspicious) visitsSuspicious++;
    onSite += v.onSite;
  }

  static double? _share(int part, int whole) =>
      whole == 0 ? null : part / whole;

  /// Доли от 0 до 1; null — не из чего считать.
  double? get onTimeShare => _share(acceptedOnTime, acceptedWithDue);
  double? get firstPassShare => _share(firstPass, accepted);
  double? get photoShare => _share(submittedWithPhotos, submitted);
  double? get geofenceShare => _share(visitsInGeofence, visits);

  Duration? get avgReaction => _reactionCount == 0
      ? null
      : Duration(seconds: _reaction.inSeconds ~/ _reactionCount);
  Duration? get avgExecution => _executionCount == 0
      ? null
      : Duration(seconds: _execution.inSeconds ~/ _executionCount);
}

/// Строка отчёта: подрядчик (null — заявки без подрядчика) и его показатели.
class ContractorReport {
  final String? contractorId;
  final ReportStats stats;
  final List<ReportOrder> orders;
  const ContractorReport(
      {required this.contractorId, required this.stats, required this.orders});
}

class Report {
  final ReportStats company;
  final List<ContractorReport> contractors;

  /// false — миграция 0010 ещё не применена, норм визитов в базе нет.
  final bool normsAvailable;
  const Report(
      {required this.company,
      required this.contractors,
      this.normsAvailable = true});

  /// Сводит заявки, визиты и нормы в отчёт. Подрядчики — в порядке
  /// [contractorOrder], затем «без подрядчика».
  static Report build({
    required ReportQuery query,
    required List<ReportOrder> orders,
    required List<ReportVisit> visits,
    required List<VisitNorm> norms,
    required List<String> contractorOrder,
    bool normsAvailable = true,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final company = ReportStats();
    final byContractor = <String?, ReportStats>{};
    final ordersBy = <String?, List<ReportOrder>>{};
    for (final o in orders) {
      company.addOrder(o, at);
      byContractor.putIfAbsent(o.contractorId, ReportStats.new).addOrder(o, at);
      ordersBy.putIfAbsent(o.contractorId, () => []).add(o);
    }
    for (final v in visits) {
      company.addVisit(v);
      byContractor.putIfAbsent(v.contractorId, ReportStats.new).addVisit(v);
    }

    // Норма в месяц пересчитывается на длину периода (месяц ≈ 30,44 дня).
    final days = query.to.difference(query.from).inHours / 24;
    final perMonth = <String, int>{};
    for (final n in norms) {
      if (query.layerId != null && n.layerId != query.layerId) continue;
      // Норма «на все объекты» не делится по объектам — при фильтре по объекту
      // учитываются только нормы этого объекта.
      if (query.objectId != null && n.objectId != query.objectId) continue;
      if (query.contractorId != null && n.contractorId != query.contractorId) {
        continue;
      }
      perMonth.update(n.contractorId, (v) => v + n.visitsPerMonth,
          ifAbsent: () => n.visitsPerMonth);
    }
    var companyNorm = 0;
    for (final e in perMonth.entries) {
      final norm = (e.value * days / 30.44).round();
      byContractor.putIfAbsent(e.key, ReportStats.new).visitNorm = norm;
      companyNorm += norm;
    }
    if (perMonth.isNotEmpty) company.visitNorm = companyNorm;

    int rank(String? id) {
      if (id == null) return contractorOrder.length + 1;
      final i = contractorOrder.indexOf(id);
      return i < 0 ? contractorOrder.length : i;
    }

    final ids = byContractor.keys.toList()
      ..sort((a, b) => rank(a).compareTo(rank(b)));
    return Report(
      company: company,
      normsAvailable: normsAvailable,
      contractors: [
        for (final id in ids)
          ContractorReport(
            contractorId: id,
            stats: byContractor[id]!,
            orders: (ordersBy[id] ?? [])
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
          ),
      ],
    );
  }
}

/// Данные отчёта. Все запросы идут под RLS: менеджер видит всю компанию,
/// у остальных база отдаёт только их собственные заявки и визиты.
class ReportRepository {
  final SupabaseClient _c = Supabase.instance.client;

  /// Сервер отдаёт не больше 1000 строк за раз — читаем страницами.
  static const _page = 1000;

  Future<List<Map<String, dynamic>>> _all(
      PostgrestTransformBuilder<PostgrestList> Function() query) async {
    final out = <Map<String, dynamic>>[];
    for (var start = 0;; start += _page) {
      final rows = await query().range(start, start + _page - 1);
      out.addAll(rows);
      if (rows.length < _page) return out;
    }
  }

  Future<Report> load(ReportQuery q,
      {required List<String> contractorOrder}) async {
    final from = q.from.toUtc().toIso8601String();
    final to = q.to.toUtc().toIso8601String();

    // select() без списка полей: return_count появляется только после 0010.
    final orderRows = await _all(() {
      var b = _c
          .from('work_orders')
          .select()
          .gte('created_at', from)
          .lt('created_at', to);
      if (q.objectId != null) b = b.eq('object_id', q.objectId!);
      if (q.contractorId != null) {
        b = b.eq('assigned_contractor_id', q.contractorId!);
      }
      if (q.layerId != null) b = b.eq('layer_id', q.layerId!);
      return b.order('created_at').order('id');
    });

    // Слой визита — из его заявки; связь нужна только при фильтре по слою.
    const visitFields =
        'id,contractor_id,started_at,ended_at,in_geofence,mock_location';
    final visitRows = await _all(() {
      var b = _c
          .from('visits')
          .select(q.layerId == null
              ? visitFields
              : '$visitFields,work_orders!inner(layer_id)')
          .gte('started_at', from)
          .lt('started_at', to);
      if (q.objectId != null) b = b.eq('object_id', q.objectId!);
      if (q.contractorId != null) b = b.eq('contractor_id', q.contractorId!);
      if (q.layerId != null) b = b.eq('work_orders.layer_id', q.layerId!);
      return b.order('started_at').order('id');
    });

    // Фото «до/после» по заявкам периода. Список id — порциями,
    // чтобы адрес запроса не стал слишком длинным.
    final ids = [for (final r in orderRows) r['id'] as String];
    final before = <String>{};
    final after = <String>{};
    for (var i = 0; i < ids.length; i += 100) {
      final chunk = ids.sublist(i, i + 100 > ids.length ? ids.length : i + 100);
      final rows = await _all(() => _c
          .from('attachments')
          .select('id,work_order_id,stage')
          .eq('kind', 'photo')
          .inFilter('work_order_id', chunk)
          .order('id'));
      for (final r in rows) {
        final id = r['work_order_id'] as String;
        // До 0006 у фото не было этапа — такие считаются «после» (как в базе).
        (r['stage'] == 'before' ? before : after).add(id);
      }
    }

    // select() без списка полей: visits_per_month появляется только после 0010.
    final normRows = await _c.from('contractor_layers').select();
    final normsAvailable =
        normRows.isEmpty || normRows.first.containsKey('visits_per_month');
    final norms = [
      for (final r in normRows)
        if (r['visits_per_month'] != null)
          VisitNorm(
            contractorId: r['contractor_id'] as String,
            layerId: r['layer_id'] as String,
            objectId: r['object_id'] as String?,
            visitsPerMonth: (r['visits_per_month'] as num).toInt(),
          ),
    ];

    return Report.build(
      query: q,
      orders: [
        for (final r in orderRows)
          ReportOrder.fromMap(r,
              hasBefore: before.contains(r['id']),
              hasAfter: after.contains(r['id'])),
      ],
      visits: [for (final r in visitRows) ReportVisit.fromMap(r)],
      norms: norms,
      contractorOrder: contractorOrder,
      normsAvailable: normsAvailable,
    );
  }
}
