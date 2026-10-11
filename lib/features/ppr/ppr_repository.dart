import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/paging.dart';
import '../../core/schema_compat.dart';
import 'ppr_logic.dart';

/// План ППР (maintenance_plans, 0015).
class MaintenancePlan {
  const MaintenancePlan({
    required this.id,
    required this.objectId,
    required this.layerId,
    required this.title,
    required this.kind,
    required this.startsOn,
    this.locationId,
    this.assetId,
    this.description,
    this.days,
    this.checklist = const [],
    this.requiresPhoto = true,
    this.priority = 'normal',
    this.active = true,
  });

  final String id;
  final String objectId;
  final String? locationId;
  final String? assetId;
  final String layerId;
  final String title;
  final String? description;
  final PeriodKind kind;

  /// Для [PeriodKind.days] — длина периода в днях.
  final int? days;
  final DateTime startsOn;
  final List<String> checklist;
  final bool requiresPhoto;
  final String priority;
  final bool active;

  factory MaintenancePlan.fromMap(Map<String, dynamic> m) => MaintenancePlan(
        id: m['id'] as String,
        objectId: m['object_id'] as String,
        locationId: m['location_id'] as String?,
        assetId: m['asset_id'] as String?,
        layerId: m['layer_id'] as String,
        title: (m['title'] ?? '') as String,
        description: m['description'] as String?,
        kind: PeriodKind.fromCode(m['period_kind'] as String?) ??
            PeriodKind.month,
        days: (m['period_days'] as num?)?.toInt(),
        startsOn: parseDate(m['starts_on']) ?? dateOnly(DateTime.now()),
        checklist: [
          for (final e in (m['checklist'] as List?) ?? const [])
            if (e is String && e.trim().isNotEmpty) e.trim()
        ],
        requiresPhoto: m['requires_photo'] != false,
        priority: (m['priority'] ?? 'normal') as String,
        active: m['active'] != false,
      );

  /// Текущий период (по сегодняшней дате).
  PeriodBounds currentPeriod([DateTime? now]) => periodBounds(kind,
      days: days, startsOn: startsOn, on: now ?? DateTime.now());

  Map<String, dynamic> toRow() => {
        'object_id': objectId,
        'location_id': locationId,
        'asset_id': assetId,
        'layer_id': layerId,
        'title': title.trim(),
        'description':
            (description?.trim().isEmpty ?? true) ? null : description!.trim(),
        'period_kind': kind.code,
        'period_days': kind == PeriodKind.days ? days : null,
        'starts_on': _date(startsOn),
        'checklist': checklist,
        'requires_photo': requiresPhoto,
        'priority': priority,
        'active': active,
      };
}

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Задача периода (заявка с plan_id).
class PlanTask {
  const PlanTask({
    required this.id,
    required this.planId,
    required this.status,
    required this.period,
    required this.row,
    this.acceptedAt,
    this.acceptedBy,
    this.contractorId,
  });

  final String id;
  final String planId;
  final String status;
  final PeriodBounds period;
  final DateTime? acceptedAt;
  final String? acceptedBy;
  final String? contractorId;

  /// Строка заявки целиком — открыть карточку.
  final Map<String, dynamic> row;

  static PlanTask? fromMap(Map<String, dynamic> m) {
    final s = parseDate(m['period_start']);
    final e = parseDate(m['period_end']);
    final plan = m['plan_id'] as String?;
    if (s == null || e == null || plan == null) return null;
    return PlanTask(
      id: m['id'] as String,
      planId: plan,
      status: (m['status'] ?? 'new') as String,
      period: PeriodBounds(s, e),
      acceptedAt: DateTime.tryParse('${m['accepted_at'] ?? ''}')?.toLocal(),
      acceptedBy:
          (m['acceptor'] as Map<String, dynamic>?)?['full_name'] as String?,
      contractorId: m['assigned_contractor_id'] as String?,
      row: m,
    );
  }
}

/// В плане есть задачи — удалить нельзя, только приостановить.
class PlanHasTasks implements Exception {
  const PlanHasTasks();
}

/// ППР: планы, задачи периодов, генерация. Права проверяет база (0015):
/// читает вся компания, меняет менеджер. Без 0015 — [MigrationMissing].
class PprRepository {
  PprRepository([SupabaseClient? client])
      : _c = client ?? Supabase.instance.client;
  final SupabaseClient _c;

  /// Когда последний раз вызывали генерацию (на это устройство и сессию).
  static DateTime? _lastGenerate;

  static const _taskColumns =
      'id,title,work_type,layer_id,priority,status,recurrence,object_id,'
      'location_id,asset_id,assigned_contractor_id,created_at,accepted_at,'
      'return_count,due_at,plan_id,period_start,period_end,locations(name),'
      'acceptor:profiles!work_orders_accepted_by_fkey(full_name)';

  Future<List<MaintenancePlan>> plans() => SchemaCompat.run('0015', () async {
        final rows = await _c.from('maintenance_plans').select().order('title');
        return [
          for (final r in rows) MaintenancePlan.fromMap(r),
        ];
      });

  Future<MaintenancePlan?> plan(String id) =>
      SchemaCompat.run('0015', () async {
        final r = await _c
            .from('maintenance_plans')
            .select()
            .eq('id', id)
            .maybeSingle();
        return r == null ? null : MaintenancePlan.fromMap(r);
      });

  /// Задачи периодов (всех планов или одного), новые периоды — первыми.
  /// Видно столько, сколько разрешает RLS заявок.
  Future<List<PlanTask>> tasks({String? planId, DateTime? since}) =>
      SchemaCompat.run('0015', () async {
        final rows = await fetchAll(() {
          var q = _c
              .from('work_orders')
              .select(_taskColumns)
              .not('plan_id', 'is', null);
          if (planId != null) q = q.eq('plan_id', planId);
          if (since != null) q = q.gte('period_end', _date(since));
          return q.order('period_start', ascending: false).order('id');
        });
        return [
          for (final r in rows)
            if (PlanTask.fromMap(r) case final t?) t,
        ];
      });

  /// Сколько задач у плана (удалить можно только без задач).
  Future<int> taskCount(String planId) => SchemaCompat.run(
      '0015',
      () => _c
          .from('work_orders')
          .count(CountOption.exact)
          .eq('plan_id', planId));

  Future<String> create(MaintenancePlan p, {required String companyId}) =>
      SchemaCompat.run('0015', () async {
        final r = await _c
            .from('maintenance_plans')
            .insert({...p.toRow(), 'company_id': companyId})
            .select('id')
            .single();
        return r['id'] as String;
      });

  Future<void> update(MaintenancePlan p) => SchemaCompat.run('0015', () async {
        final rows = await _c
            .from('maintenance_plans')
            .update(p.toRow())
            .eq('id', p.id)
            .select('id');
        if (rows.isEmpty) {
          throw const PostgrestException(message: 'not allowed');
        }
      });

  Future<void> setActive(String id, bool active) =>
      SchemaCompat.run('0015', () async {
        final rows = await _c
            .from('maintenance_plans')
            .update({'active': active})
            .eq('id', id)
            .select('id');
        if (rows.isEmpty) {
          throw const PostgrestException(message: 'not allowed');
        }
      });

  /// Удалить план — только без задач ([PlanHasTasks]), иначе приостановить.
  Future<void> delete(String id) => SchemaCompat.run('0015', () async {
        if (await taskCount(id) > 0) throw const PlanHasTasks();
        final rows = await _c
            .from('maintenance_plans')
            .delete()
            .eq('id', id)
            .select('id');
        if (rows.isEmpty) {
          throw const PostgrestException(message: 'not allowed');
        }
      });

  /// Создать задачи текущего периода (функция базы ppr_generate). Не чаще
  /// раза в 10 минут ([force] — всё равно не чаще). Без 0015 или без прав —
  /// молча 0. Возвращает, сколько задач создано.
  Future<int> generate({DateTime? now}) async {
    final t = now ?? DateTime.now();
    if (!pprGenerateDue(_lastGenerate, t)) return 0;
    if (SchemaCompat.has('0015') == false) return 0;
    _lastGenerate = t;
    try {
      final r = await _c.rpc('ppr_generate');
      SchemaCompat.mark('0015', true);
      return (r as num?)?.toInt() ?? 0;
    } catch (e) {
      if (SchemaCompat.isMissing(e)) {
        SchemaCompat.mark('0015', false);
      } else {
        debugPrint('ppr_generate: $e');
      }
      return 0;
    }
  }

  /// Оборудование объекта (для выбора в плане): id, название, помещение.
  Future<List<({String id, String name, String locationId})>> assetsOf(
      String objectId) async {
    final rows = await _c
        .from('assets')
        .select('id,name,location_id,locations!inner(object_id)')
        .eq('locations.object_id', objectId)
        .order('name');
    return [
      for (final r in rows)
        (
          id: r['id'] as String,
          name: (r['name'] ?? '') as String,
          locationId: r['location_id'] as String,
        ),
    ];
  }

  /// Название оборудования (карточка плана).
  Future<String?> assetName(String id) async {
    final r =
        await _c.from('assets').select('name').eq('id', id).maybeSingle();
    return r?['name'] as String?;
  }

  /// Для тестов: сбросить порог 10 минут.
  @visibleForTesting
  static void resetThrottle() => _lastGenerate = null;
}
