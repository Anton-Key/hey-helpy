import 'package:flutter/material.dart';

import '../../core/l10n_ext.dart';
import '../../core/status_style.dart';
import '../../core/ui.dart';
import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';
import 'requests.dart';

const _muted = Color(0xFF8A9098);
const _danger = Color(0xFFC24444);

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
      if (o.id == id) return o.name;
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
        MaterialPageRoute(
          builder: (_) => WorkOrderDetailScreen(
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

/// Строка заявки в списке: название, подписи, пометки, статус, стрелка.
class OrderTile extends StatelessWidget {
  const OrderTile(
      {super.key,
      required this.title,
      required this.status,
      required this.onTap,
      this.lines = const [],
      this.alerts = const []});

  final String title;
  final String status;
  final VoidCallback onTap;

  /// Серые строки под названием (место, дата, исполнитель…).
  final List<String> lines;

  /// Красные пометки («Просрочена», «возвращали 2 раза»…).
  final List<String> alerts;

  @override
  Widget build(BuildContext context) {
    return TapCard(
      onTap: onTap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            for (final line in lines)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 3),
                child: Text(line,
                    style: const TextStyle(color: _muted, fontSize: 13)),
              ),
            if (alerts.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 3),
                child: Text(alerts.join(' · '),
                    style: const TextStyle(
                        color: _danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        Padding(
            padding: const EdgeInsetsDirectional.only(top: 1),
            child: StatusPill(status)),
      ]),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(children: [
          Text(widget.title, overflow: TextOverflow.ellipsis),
          if (widget.subtitle != null)
            Text(widget.subtitle!,
                style: const TextStyle(fontSize: 12, color: _muted)),
        ]),
      ),
      body: _body(l),
    );
  }

  Widget _body(AppLocalizations l) {
    if (_loading && _ctx == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l.requestsLoadFailed,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _danger)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: Text(l.commonRetry)),
          ]),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Center(
          child:
              Text(l.cardOrdersEmpty, style: const TextStyle(color: _muted)));
    }
    final ctx = _ctx!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 40),
        children: [
          for (final r in _rows)
            OrderTile(
              title: (r['title'] ?? '') as String,
              status: (r['status'] ?? 'new') as String,
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
        ],
      ),
    );
  }
}
