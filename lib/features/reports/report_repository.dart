import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/paging.dart';
import '../../core/schema_compat.dart';

/// Тип задачи в отчёте: разовая, повторяющаяся, ППР (задача периода плана).
enum ReportKind { once, recurring, ppr }

/// Период и фильтры отчёта. [to] — не включительно.
class ReportQuery {
  final DateTime from;
  final DateTime to;

  /// Объекты (несколько — например «весь город» или «весь регион»); пусто — все.
  final Set<String> objectIds;
  final String? contractorId;
  final String? layerId;

  /// Тип задачи; null — все.
  final ReportKind? kind;
  const ReportQuery(
      {required this.from,
      required this.to,
      this.objectIds = const {},
      this.contractorId,
      this.layerId,
      this.kind});
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

  /// Помещение — для списка заявок в PDF.
  final String? locationId;

  /// Задача периода плана ППР (0015); null — обычная заявка.
  final String? planId;
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
      this.locationId,
      this.planId,
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
      locationId: m['location_id'] as String?,
      planId: m['plan_id'] as String?,
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

  /// Задача ППР (план регламентных работ).
  bool get isPpr => planId != null;

  /// Тип задачи для фильтра «Тип».
  ReportKind get kind => isPpr
      ? ReportKind.ppr
      : (recurring ? ReportKind.recurring : ReportKind.once);
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

  /// Заявки с дедлайном, по которым уже ясно, в срок ли они: принятые и
  /// не закрытые с прошедшим дедлайном (отменённые не считаются).
  /// Из них в срок — принятые не позже дедлайна.
  int withDue = 0;
  int onTime = 0;
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

  /// Задачи ППР (не отменённые) и из них принятые.
  int pprTotal = 0;
  int pprDone = 0;

  /// Норма визитов за период (дробная: за неделю при норме 2 в месяц ≈ 0,5);
  /// null — нормы нет.
  double? visitNorm;

  void addOrder(ReportOrder o, DateTime now) {
    total++;
    if (o.isPpr && !o.cancelled) {
      pprTotal++;
      if (o.accepted) pprDone++;
    }
    if (o.wasReturned) returned++;
    if (o.isOverdue(now)) overdue++;
    if (o.accepted) {
      accepted++;
      if (o.returnCount == 0) firstPass++;
    }
    final due = o.dueAt;
    if (due != null && !o.cancelled) {
      if (o.accepted && o.acceptedAt != null) {
        withDue++;
        if (!o.acceptedAt!.isAfter(due)) onTime++;
      } else if (!o.accepted && now.isAfter(due)) {
        // не закрыта, а дедлайн прошёл — не в срок
        withDue++;
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
  double? get onTimeShare => _share(onTime, withDue);
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

  /// false — миграция 0015 ещё не применена: ППР нет (показывается «—»).
  final bool pprAvailable;
  const Report(
      {required this.company,
      required this.contractors,
      this.normsAvailable = true,
      this.pprAvailable = true});

  /// Все заявки отчёта, новые сверху.
  List<ReportOrder> get orders => [
        for (final c in contractors) ...c.orders,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Сводит заявки, визиты и нормы в отчёт. Подрядчики — в порядке
  /// [contractorOrder], затем «без подрядчика».
  static Report build({
    required ReportQuery query,
    required List<ReportOrder> orders,
    required List<ReportVisit> visits,
    required List<VisitNorm> norms,
    required List<String> contractorOrder,
    bool normsAvailable = true,
    bool pprAvailable = true,
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
      if (query.objectIds.isNotEmpty && !query.objectIds.contains(n.objectId)) {
        continue;
      }
      if (query.contractorId != null && n.contractorId != query.contractorId) {
        continue;
      }
      perMonth.update(n.contractorId, (v) => v + n.visitsPerMonth,
          ifAbsent: () => n.visitsPerMonth);
    }
    var companyNorm = 0.0;
    for (final e in perMonth.entries) {
      final norm = e.value * days / 30.44;
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
      pprAvailable: pprAvailable,
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

/// Регион компании (0015) — для блока «По регионам».
class ReportRegion {
  final String id;
  final String name;
  final int sort;
  const ReportRegion({required this.id, required this.name, this.sort = 0});
}

/// Строка блока «По регионам»: [key] — id региона (или город, если регионов
/// в компании нет); [label] — подпись; null-ключ — «Без региона» / «Без города».
class RegionReport {
  final String? key;
  final String? label;
  final ReportStats stats;
  const RegionReport(
      {required this.key, required this.label, required this.stats});
}

/// Сводка по регионам: заявки, в срок, просрочено, ППР. Если у компании
/// есть регионы ([regions] не пусто) — по региону объекта, иначе по городу
/// ([cityOf]). Порядок — как у регионов (sort, название), города — по
/// алфавиту; «без региона / города» — в конце. Пустые регионы не выводятся.
List<RegionReport> buildRegionReports({
  required List<ReportOrder> orders,
  required List<ReportRegion> regions,
  required String? Function(String objectId) regionOf,
  required String Function(String objectId) cityOf,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final byRegion = regions.isNotEmpty;
  final names = {for (final r in regions) r.id: r.name};
  final stats = <String?, ReportStats>{};
  for (final o in orders) {
    final oid = o.objectId;
    String? key;
    if (oid != null) {
      if (byRegion) {
        final r = regionOf(oid);
        key = r != null && names.containsKey(r) ? r : null;
      } else {
        final c = cityOf(oid).trim();
        key = c.isEmpty ? null : c;
      }
    }
    stats.putIfAbsent(key, ReportStats.new).addOrder(o, at);
  }
  int regionRank(String id) {
    final i = regions.indexWhere((r) => r.id == id);
    return i < 0 ? regions.length : i;
  }

  final keys = stats.keys.toList()
    ..sort((a, b) {
      if (a == null || b == null) return a == null ? (b == null ? 0 : 1) : -1;
      if (byRegion) return regionRank(a).compareTo(regionRank(b));
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
  return [
    for (final k in keys)
      RegionReport(
          key: k,
          label: k == null ? null : (byRegion ? names[k] : k),
          stats: stats[k]!),
  ];
}

/// Регионы в порядке показа (sort, затем название).
List<ReportRegion> sortRegions(List<ReportRegion> list) => [...list]
  ..sort((a, b) {
    final s = a.sort.compareTo(b.sort);
    return s != 0 ? s : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

/// Данные отчёта. Все запросы идут под RLS: менеджер видит всю компанию,
/// у остальных база отдаёт только их собственные заявки и визиты.
class ReportRepository {
  final SupabaseClient _c = Supabase.instance.client;

  /// Регионы компании (0015); до миграции — пусто.
  Future<List<ReportRegion>> regions() => SchemaCompat.run<List<ReportRegion>>(
        '0015',
        () async {
          final rows = await _c.from('regions').select('id,name,sort');
          return sortRegions([
            for (final r in rows)
              ReportRegion(
                  id: r['id'] as String,
                  name: (r['name'] ?? '') as String,
                  sort: (r['sort'] as num?)?.toInt() ?? 0),
          ]);
        },
        legacy: () async => const <ReportRegion>[],
      );

  /// Название компании и имя текущего пользователя — для шапки PDF.
  Future<({String? company, String? me})> header() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return (company: null, me: null);
    final p = await _c
        .from('profiles')
        .select('full_name,company_id')
        .eq('id', uid)
        .maybeSingle();
    final cid = p?['company_id'] as String?;
    final c = cid == null
        ? null
        : await _c.from('companies').select('name').eq('id', cid).maybeSingle();
    return (
      company: c?['name'] as String?,
      me: (p?['full_name'] as String?) ?? _c.auth.currentUser?.email
    );
  }

  Future<Report> load(ReportQuery q,
      {required List<String> contractorOrder}) async {
    final from = q.from.toUtc().toIso8601String();
    final to = q.to.toUtc().toIso8601String();

    // select() без списка полей: return_count появляется только после 0010.
    final orderRows = await fetchAll(() {
      var b = _c
          .from('work_orders')
          .select()
          .gte('created_at', from)
          .lt('created_at', to);
      if (q.objectIds.isNotEmpty) {
        b = b.inFilter('object_id', q.objectIds.toList());
      }
      if (q.contractorId != null) {
        b = b.eq('assigned_contractor_id', q.contractorId!);
      }
      if (q.layerId != null) b = b.eq('layer_id', q.layerId!);
      return b.order('created_at').order('id');
    });

    // Слой визита — из его заявки; связь нужна только при фильтре по слою.
    const visitFields =
        'id,contractor_id,started_at,ended_at,in_geofence,mock_location';
    final visitRows = await fetchAll(() {
      var b = _c
          .from('visits')
          .select(q.layerId == null
              ? visitFields
              : '$visitFields,work_orders!inner(layer_id)')
          .gte('started_at', from)
          .lt('started_at', to);
      if (q.objectIds.isNotEmpty) {
        b = b.inFilter('object_id', q.objectIds.toList());
      }
      if (q.contractorId != null) b = b.eq('contractor_id', q.contractorId!);
      if (q.layerId != null) b = b.eq('work_orders.layer_id', q.layerId!);
      return b.order('started_at').order('id');
    });

    // Фото «до/после» по заявкам периода.
    final ids = [for (final r in orderRows) r['id'] as String];
    final before = <String>{};
    final after = <String>{};
    for (final chunk in chunks(ids)) {
      final rows = await fetchAll(() => _c
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

    // select() без списка полей: plan_id есть только после 0015.
    final pprAvailable = orderRows.isEmpty
        ? SchemaCompat.has('0015') != false
        : orderRows.first.containsKey('plan_id');
    final orders = [
      for (final r in orderRows)
        ReportOrder.fromMap(r,
            hasBefore: before.contains(r['id']),
            hasAfter: after.contains(r['id'])),
    ];
    return Report.build(
      query: q,
      orders: [
        for (final o in orders)
          if (q.kind == null || o.kind == q.kind) o,
      ],
      pprAvailable: pprAvailable,
      visits: [for (final r in visitRows) ReportVisit.fromMap(r)],
      norms: norms,
      contractorOrder: contractorOrder,
      normsAvailable: normsAvailable,
    );
  }
}
