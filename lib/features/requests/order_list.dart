import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';
import 'requests.dart';
import '../directory/city.dart';

/// Справочники и роль, нужные карточке заявки. Загружаются один раз на экран.
class OrderContext {
  OrderContext(
      {required this.objects,
      required this.contractors,
      required this.layers,
      required this.role,
      required this.companyId,
      required this.uid});

  final List<Obj> objects;
  final List<Contractor> contractors;
  final List<Layer> layers;
  final String? role;
  final String? companyId;
  final String? uid;
  final repo = RequestsRepo();

  bool get isManager => role == 'admin' || role == 'manager';

  static Future<OrderContext> load() async {
    final dir = DirectoryRepo();
    final repo = RequestsRepo();
    final results = await Future.wait<Object?>([
      dir.objects(),
      dir.contractors(),
      dir.layers().catchError((_) => const <Layer>[]),
      repo.myRole(),
      dir.myCompanyId(),
    ]);
    return OrderContext(
      objects: results[0] as List<Obj>,
      contractors: results[1] as List<Contractor>,
      layers: results[2] as List<Layer>,
      role: results[3] as String?,
      companyId: results[4] as String?,
      uid: repo.uid,
    );
  }

  String objectName(AppLocalizations l, String? id) {
    if (id == null) return l.objectNone;
    for (final o in objects) {
      if (o.id == id) return objectDisplayName(o);
    }
    return l.objectUnknown;
  }

  String? contractorName(String? id) {
    if (id == null) return null;
    for (final c in contractors) {
      if (c.id == id) return c.orgName;
    }
    return null;
  }

  String? layerLabel(String locale, {String? layerId, String? workType}) {
    final layer = Layer.find(layers, id: layerId, name: workType);
    if (layer != null) return layer.label(locale);
    return (workType == null || workType.isEmpty) ? null : workType;
  }

  /// «Объект · помещение · вид работ» для строки списка.
  String placeLine(BuildContext context, Map<String, dynamic> row) {
    final l = context.l10n;
    final place =
        (row['locations'] as Map<String, dynamic>?)?['name'] as String?;
    final work = layerLabel(context.localeCode,
        layerId: row['layer_id'] as String?,
        workType: row['work_type'] as String?);
    return [
      objectName(l, row['object_id'] as String?),
      if (place != null && place.isNotEmpty) place,
      if (work != null) work,
    ].join(' · ');
  }

  /// Открывает обычную карточку заявки.
  Future<void> open(BuildContext context, Map<String, dynamic> row) =>
      Navigator.push(
        context,
        appRoute(
          (_) => WorkOrderDetailScreen(
            order: WorkOrder.fromMap(row),
            objects: objects,
            contractors: contractors,
            layers: layers,
            uid: uid,
            role: role,
            repo: repo,
            companyId: companyId,
          ),
        ),
      );
}

/// Строка заявки в списке (внутри [AppGroup]): точка приоритета, название,
/// серые подписи, красные пометки, статус и стрелка.
class OrderTile extends StatelessWidget {
  const OrderTile(
      {super.key,
      required this.title,
      required this.status,
      required this.onTap,
      this.priority = 'normal',
      this.lines = const [],
      this.alerts = const []});

  final String title;
  final String status;
  final String priority;
  final VoidCallback onTap;

  /// Серые строки под названием (место, дата, исполнитель…).
  final List<String> lines;

  /// Красные пометки («Просрочена», «возвращали 2 раза»…).
  final List<String> alerts;

  @override
  Widget build(BuildContext context) {
    return AppRow(
      leading: PriorityDot(priority),
      title: title,
      subtitle: lines.join('\n'),
      subtitleMaxLines: 3,
      extra: alerts.isEmpty
          ? null
          : Text(alerts.join(' · '),
              style: AppText.footnote.copyWith(
                  color: AppColors.danger, fontWeight: FontWeight.w600)),
      trailing: StatusPill(status),
      onTap: onTap,
    );
  }
}

/// Список заявок подрядчика, объекта или помещения. Нажатие — карточка заявки.
class WorkOrderListScreen extends StatefulWidget {
  const WorkOrderListScreen(
      {super.key,
      required this.title,
      this.subtitle,
      this.contractorId,
      this.objectId,
      this.locationId});

  final String title;
  final String? subtitle;
  final String? contractorId;
  final String? objectId;
  final String? locationId;

  @override
  State<WorkOrderListScreen> createState() => _WorkOrderListScreenState();
}

class _WorkOrderListScreenState extends State<WorkOrderListScreen> {
  OrderContext? _ctx;
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final ctx = _ctx ?? await OrderContext.load();
      final rows = await ctx.repo.listBy(
          contractorId: widget.contractorId,
          objectId: widget.objectId,
          locationId: widget.locationId);
      if (!mounted) return;
      setState(() {
        _ctx = ctx;
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      debugPrint('WorkOrderList: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppScaffold(
      title: widget.title,
      eyebrow: widget.subtitle,
      onRefresh: _ctx == null ? null : _load,
      slivers: [_body(l)],
    );
  }

  Widget _body(AppLocalizations l) {
    if (_loading && _ctx == null) {
      return const SliverFillRemaining(
          hasScrollBody: false, child: AppLoader());
    }
    if (_failed) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
            text: l.requestsLoadFailed,
            error: true,
            actionLabel: l.commonRetry,
            onAction: _load),
      );
    }
    if (_rows.isEmpty) {
      return SliverFillRemaining(
          hasScrollBody: false, child: AppEmptyState(text: l.cardOrdersEmpty));
    }
    final ctx = _ctx!;
    return SliverContent(
      sliver: SliverToBoxAdapter(
        child: AppGroup(children: [
          for (final r in _rows)
            OrderTile(
              title: (r['title'] ?? '') as String,
              status: (r['status'] ?? 'new') as String,
              priority: (r['priority'] ?? 'normal') as String,
              lines: [
                ctx.placeLine(context, r),
                l.dateTime(DateTime.parse('${r['created_at']}')),
              ],
              alerts: [
                if (((r['return_count'] as num?) ?? 0) > 0)
                  l.reportsReturnedTimes((r['return_count'] as num).toInt()),
              ],
              onTap: () async {
                await ctx.open(context, r);
                if (mounted) await _load();
              },
            ),
        ]),
      ),
    );
  }
}
