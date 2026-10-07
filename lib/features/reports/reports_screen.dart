import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n_ext.dart';
import '../../core/period.dart';
import '../../core/directional.dart';
import '../../core/ui.dart';
import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';
import '../requests/order_list.dart';
import '../requests/requests.dart';
import 'report_repository.dart';

const _ink = Color(0xFF1C1E22);
const _muted = Color(0xFF8A9098);
const _line = Color(0xFFE8EAED);
const _link = Color(0xFF177A65);
const _danger = Color(0xFFC24444);
const _onBrand = Color(0xFF06342A);

BoxDecoration _card() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: _line));

/// Вкладка «Отчёты» (только менеджер и администратор): период, фильтры,
/// четыре главные цифры по компании и показатели по каждому подрядчику.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.initialContractorId});

  /// Сразу включить фильтр по подрядчику (кнопка «Отчёт» в его карточке).
  final String? initialContractorId;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _repo = ReportRepository();
  final _requests = RequestsRepo();
  final _dir = DirectoryRepo();

  String? _role;
  String? _companyId;
  List<Obj> _objects = const [];
  List<Contractor> _contractors = const [];
  List<Layer> _layers = const [];

  Period _period = const Period(PeriodKind.month);
  String? _objectId;
  late String? _contractorId = widget.initialContractorId;
  String? _layerId;

  Report? _report;
  bool _loading = true;
  bool _failed = false;

  /// Номер последнего запроса: ответ на устаревший фильтр не показываем.
  int _seq = 0;

  bool get _isManager => _role == 'admin' || _role == 'manager';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      _role ??= await _requests.myRole();
      if (!_isManager) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      _companyId ??= await _dir.myCompanyId();
      final objects = await _dir.objects();
      final contractors = await _dir.contractors();
      final layers = await _dir.layers();
      if (!mounted) return;
      setState(() {
        _objects = objects;
        _contractors = contractors;
        _layers = layers;
      });
      await _load();
    } catch (e) {
      debugPrint('Reports init: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _load() async {
    final seq = ++_seq;
    final r = _period.range();
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final report = await _repo.load(
        ReportQuery(
            from: r.from,
            to: r.to,
            objectId: _objectId,
            contractorId: _contractorId,
            layerId: _layerId),
        contractorOrder: [for (final c in _contractors) c.id],
      );
      if (!mounted || seq != _seq) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Reports: $e');
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _setPeriod(Period p) async {
    setState(() => _period = p);
    await _load();
  }

  Future<void> _pickFilter({
    required String title,
    required List<(String id, String label)> items,
    required String? current,
    required void Function(String?) apply,
  }) async {
    final l = context.l10n;
    // Пустая строка — «Все»: null из шторки означает «закрыли без выбора».
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: _line, borderRadius: BorderRadius.circular(4))),
            Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 6),
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800))),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final (id, label) in [('', l.reportsFilterAll), ...items])
                  ListTile(
                    title: Text(label),
                    trailing: (id.isEmpty ? current == null : id == current)
                        ? Icon(Icons.check_rounded,
                            color: Theme.of(ctx).colorScheme.primary)
                        : null,
                    onTap: () => Navigator.pop(ctx, id),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
    if (chosen == null) return;
    final value = chosen.isEmpty ? null : chosen;
    if (value == current) return;
    setState(() => apply(value));
    await _load();
  }

  String _contractorName(AppLocalizations l, String? id) {
    if (id == null) return l.reportsNoContractor;
    for (final c in _contractors) {
      if (c.id == id) return c.orgName;
    }
    return l.contractorUnknown;
  }

  String? _labelOf<T>(List<T> list, String? id, String Function(T) idOf,
      String Function(T) labelOf) {
    if (id == null) return null;
    for (final x in list) {
      if (idOf(x) == id) return labelOf(x);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_role == null && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_role == null && _failed) return _errorView(l);
    if (!_isManager) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 48, color: _muted),
            const SizedBox(height: 12),
            Text(l.reportsManagerOnly,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted)),
          ]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 120),
        children: [
          PeriodBar(period: _period, onChanged: _setPeriod),
          const SizedBox(height: 10),
          _filters(l),
          const SizedBox(height: 14),
          ..._content(l),
        ],
      ),
    );
  }

  Widget _filters(AppLocalizations l) {
    final locale = context.localeCode;
    Widget chip(String title, String? value, VoidCallback onTap) {
      final active = value != null;
      return ActionChip(
        onPressed: onTap,
        avatar:
            Icon(Icons.filter_list, size: 18, color: active ? _link : _muted),
        label: Text(active ? '$title: $value' : title,
            overflow: TextOverflow.ellipsis),
        labelStyle: TextStyle(
            color: active ? _link : _ink, fontWeight: FontWeight.w600),
        side: BorderSide(color: active ? _link : _line),
        backgroundColor: Colors.white,
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: [
      chip(
          l.reportsFilterObject,
          _labelOf<Obj>(_objects, _objectId, (o) => o.id, (o) => o.name),
          () => _pickFilter(
              title: l.reportsFilterObject,
              items: [for (final o in _objects) (o.id, o.name)],
              current: _objectId,
              apply: (v) => _objectId = v)),
      chip(
          l.reportsFilterContractor,
          _labelOf<Contractor>(
              _contractors, _contractorId, (c) => c.id, (c) => c.orgName),
          () => _pickFilter(
              title: l.reportsFilterContractor,
              items: [for (final c in _contractors) (c.id, c.orgName)],
              current: _contractorId,
              apply: (v) => _contractorId = v)),
      chip(
          l.reportsFilterLayer,
          _labelOf<Layer>(
              _layers, _layerId, (x) => x.id, (x) => x.label(locale)),
          () => _pickFilter(
              title: l.reportsFilterLayer,
              items: [for (final x in _layers) (x.id, x.label(locale))],
              current: _layerId,
              apply: (v) => _layerId = v)),
    ]);
  }

  List<Widget> _content(AppLocalizations l) {
    final report = _report;
    if (_failed) return [_errorView(l)];
    if (report == null) {
      return const [
        Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()))
      ];
    }
    final f = _Fmt(l);
    final c = report.company;
    return [
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      if (_loading) const SizedBox(height: 8),
      LayoutBuilder(builder: (context, box) {
        final kpis = [
          _Kpi(value: f.count(c.total), title: l.reportsKpiRequests),
          _Kpi(
              value: f.pct(c.onTimeShare),
              title: l.reportsKpiOnTime,
              hint: c.acceptedWithDue == 0
                  ? null
                  : l.reportsKpiOf(c.acceptedWithDue)),
          _Kpi(
              value: f.pct(c.firstPassShare),
              title: l.reportsKpiFirstPass,
              hint: c.accepted == 0 ? null : l.reportsKpiOf(c.accepted)),
          _Kpi(
              value: f.pct(c.geofenceShare),
              title: l.reportsKpiGeofence,
              hint: c.visits == 0 ? null : l.reportsKpiOf(c.visits)),
        ];
        final perRow = box.maxWidth >= 600 ? 4 : 2;
        final w = (box.maxWidth - 10 * (perRow - 1)) / perRow;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final k in kpis) SizedBox(width: w, child: k),
        ]);
      }),
      const SizedBox(height: 20),
      Text(l.reportsByContractor,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(height: 10),
      if (report.contractors.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(l.reportsEmpty,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted)),
        )
      else
        LayoutBuilder(
          builder: (context, box) => box.maxWidth >= 900
              ? _ContractorTable(
                  rows: report.contractors,
                  name: (id) => _contractorName(l, id),
                  fmt: f,
                  onOpen: _openContractor)
              : Column(children: [
                  for (final r in report.contractors)
                    _ContractorCard(
                        row: r,
                        name: _contractorName(l, r.contractorId),
                        fmt: f,
                        onOpen: () => _openContractor(r)),
                ]),
        ),
      if (!report.normsAvailable) ...[
        const SizedBox(height: 4),
        Text(l.reportsNormsMissing,
            style: const TextStyle(color: _muted, fontSize: 12)),
      ],
      const SizedBox(height: 14),
      Text(l.reportsHelp, style: const TextStyle(color: _muted, fontSize: 12)),
    ];
  }

  Widget _errorView(AppLocalizations l) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.reportsLoadFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _danger)),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: _report == null && _objects.isEmpty ? _init : _load,
              child: Text(l.commonRetry)),
        ]),
      );

  Future<void> _openContractor(ContractorReport row) async {
    final l = context.l10n;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContractorOrdersScreen(
          title: _contractorName(l, row.contractorId),
          subtitle: _period.label(context),
          orders: row.orders,
          objects: _objects,
          contractors: _contractors,
          layers: _layers,
          role: _role,
          companyId: _companyId,
        ),
      ),
    );
    // В карточке заявки могли сменить статус — пересчитываем.
    if (mounted) await _load();
  }
}

/// Форматирование чисел, долей и длительностей по языку интерфейса.
class _Fmt {
  _Fmt(this.l)
      : _num = NumberFormat.decimalPattern(l.localeName),
        _norm = NumberFormat('#,##0.#', l.localeName),
        _pct = NumberFormat.percentPattern(l.localeName);
  final AppLocalizations l;
  final NumberFormat _num;
  final NumberFormat _norm;
  final NumberFormat _pct;

  String count(int n) => _num.format(n);
  String pct(double? v) => v == null ? l.reportsNoValue : _pct.format(v);

  String duration(Duration? d) => d == null ? l.reportsNoValue : l.duration(d);

  /// Норма за период — с одним знаком после запятой («1 / 0,5»), чтобы за
  /// короткий период она не округлялась до 0; меньше 0,05 визита — «—».
  String norm(double v) => v < 0.05 ? l.reportsNoValue : _norm.format(v);

  String visits(ReportStats s) => s.visitNorm == null
      ? count(s.visits)
      : l.reportsFactNorm(count(s.visits), norm(s.visitNorm!));

  /// Пары «подпись — значение» для строки подрядчика.
  List<(String, String, bool)> metrics(ReportStats s) => [
        (l.reportsOrders, count(s.total), false),
        (l.reportsAccepted, count(s.accepted), false),
        (l.reportsReturned, count(s.returned), s.returned > 0),
        (l.reportsOverdue, count(s.overdue), s.overdue > 0),
        (l.reportsOnTime, pct(s.onTimeShare), false),
        (l.reportsFirstPass, pct(s.firstPassShare), false),
        (l.reportsReaction, duration(s.avgReaction), false),
        (l.reportsExecution, duration(s.avgExecution), false),
        (
          s.visitNorm == null ? l.reportsVisits : l.reportsVisitNorm,
          visits(s),
          s.visitNorm != null && s.visits < s.visitNorm!
        ),
        (l.reportsVisitsInZone, count(s.visitsInGeofence), false),
        (
          l.reportsVisitsSuspicious,
          count(s.visitsSuspicious),
          s.visitsSuspicious > 0
        ),
        (l.reportsOnSite, duration(s.visits == 0 ? null : s.onSite), false),
        (l.reportsPhotos, pct(s.photoShare), false),
      ];
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.value, required this.title, this.hint});
  final String value;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFD8F0EA),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, color: _onBrand)),
        const SizedBox(height: 2),
        Text(title,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _onBrand)),
        if (hint != null)
          Text(hint!, style: const TextStyle(fontSize: 12, color: _link)),
      ]),
    );
  }
}

/// Подрядчик на узком экране: карточка с сеткой показателей.
class _ContractorCard extends StatelessWidget {
  const _ContractorCard(
      {required this.row,
      required this.name,
      required this.fmt,
      required this.onOpen});
  final ContractorReport row;
  final String name;
  final _Fmt fmt;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return TapCard(
      onTap: onOpen,
      chevron: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text(name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800))),
          const ChevronEnd(color: _muted, size: 20),
        ]),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - 8) / 2;
          return Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (label, value, alert) in fmt.metrics(row.stats))
              SizedBox(
                width: w,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(color: _muted, fontSize: 12)),
                      Text(value,
                          style: TextStyle(
                              color: alert ? _danger : _ink,
                              fontWeight: FontWeight.w700)),
                    ]),
              ),
          ]);
        }),
      ]),
    );
  }
}

/// Подрядчики на широком экране (веб): таблица, строка открывает заявки.
class _ContractorTable extends StatelessWidget {
  const _ContractorTable(
      {required this.rows,
      required this.name,
      required this.fmt,
      required this.onOpen});
  final List<ContractorReport> rows;
  final String Function(String?) name;
  final _Fmt fmt;
  final void Function(ContractorReport) onOpen;

  @override
  Widget build(BuildContext context) {
    final header = rows.isEmpty ? const [] : fmt.metrics(rows.first.stats);
    return Container(
      decoration: _card(),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          headingTextStyle: const TextStyle(
              color: _muted, fontSize: 12, fontWeight: FontWeight.w700),
          columnSpacing: 18,
          columns: [
            DataColumn(label: Text(context.l10n.reportsFilterContractor)),
            for (final (label, _, _) in header)
              DataColumn(
                  label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(label, softWrap: true))),
          ],
          rows: [
            for (final r in rows)
              DataRow(
                onSelectChanged: (_) => onOpen(r),
                cells: [
                  DataCell(Text(name(r.contractorId),
                      style: const TextStyle(fontWeight: FontWeight.w700))),
                  for (final (_, value, alert) in fmt.metrics(r.stats))
                    DataCell(Text(value,
                        style: TextStyle(
                            color: alert ? _danger : _ink,
                            fontWeight: FontWeight.w600))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Заявки подрядчика за период; нажатие открывает карточку заявки.
class ContractorOrdersScreen extends StatelessWidget {
  const ContractorOrdersScreen(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.orders,
      required this.objects,
      required this.contractors,
      required this.layers,
      required this.role,
      required this.companyId});
  final String title;
  final String subtitle;
  final List<ReportOrder> orders;
  final List<Obj> objects;
  final List<Contractor> contractors;
  final List<Layer> layers;
  final String? role;
  final String? companyId;

  String _objectName(AppLocalizations l, String? id) {
    if (id == null) return l.objectNone;
    for (final o in objects) {
      if (o.id == id) return o.name;
    }
    return l.objectUnknown;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = context.localeCode;
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, overflow: TextOverflow.ellipsis),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: _muted)),
        ]),
      ),
      body: orders.isEmpty
          ? Center(
              child: Text(l.reportsOrdersEmpty,
                  style: const TextStyle(color: _muted)))
          : ListView.builder(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 40),
              itemCount: orders.length,
              itemBuilder: (context, i) {
                final o = orders[i];
                final layer =
                    Layer.find(layers, id: o.layerId, name: o.workType);
                final workType = layer?.label(locale) ?? o.workType;
                final flags = [
                  if (o.isOverdue(now)) l.statusOverdue,
                  if (o.returnCount > 0) l.reportsReturnedTimes(o.returnCount),
                ];
                return OrderTile(
                  title: o.title,
                  status: o.status,
                  lines: [
                    [
                      _objectName(l, o.objectId),
                      if (workType != null && workType.isNotEmpty) workType,
                    ].join(' · '),
                    l.dateTime(o.createdAt),
                  ],
                  alerts: flags,
                  onTap: () => _open(context, o),
                );
              },
            ),
    );
  }

  Future<void> _open(BuildContext context, ReportOrder o) async {
    final repo = RequestsRepo();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkOrderDetailScreen(
          order: WorkOrder(
              id: o.id,
              title: o.title,
              workType: o.workType,
              layerId: o.layerId,
              priority: o.priority,
              status: o.status,
              objectId: o.objectId,
              recurring: o.recurring),
          objects: objects,
          contractors: contractors,
          layers: layers,
          uid: Supabase.instance.client.auth.currentUser?.id,
          role: role,
          repo: repo,
          companyId: companyId,
        ),
      ),
    );
  }
}
