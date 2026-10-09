import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/period.dart';
import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';
import '../home/home_chrome.dart';
import '../requests/requests.dart';
import 'report_repository.dart';

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

  Period _period = const Period(PeriodKind.last30);
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
    final chosen = await showAppSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SheetHeader(title: title),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.l),
                children: [
                  AppGroup(margin: EdgeInsets.zero, children: [
                    for (final (id, label) in [
                      ('', l.reportsFilterAll),
                      ...items
                    ])
                      AppRow(
                        title: label,
                        chevron: false,
                        trailing: (id.isEmpty ? current == null : id == current)
                            ? const Icon(AppIcons.check,
                                size: AppSizes.icon,
                                color: AppColors.accentText)
                            : null,
                        onTap: () => Navigator.pop(ctx, id),
                      ),
                  ]),
                ],
              ),
            ),
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
    final List<Widget> body;
    if (_role == null && _loading) {
      body = const [
        Padding(
            padding: EdgeInsetsDirectional.symmetric(vertical: 40),
            child: AppLoader())
      ];
    } else if (_role == null && _failed) {
      body = [_errorView(l)];
    } else if (!_isManager) {
      body = [AppEmptyState(text: l.reportsManagerOnly, icon: AppIcons.lock)];
    } else {
      body = [
        PeriodBar(period: _period, onChanged: _setPeriod),
        const SizedBox(height: AppSpace.xs),
        _filters(l),
        const SizedBox(height: AppSpace.l),
        ..._content(l),
      ];
    }
    // Отчёты — во всю ширину окна (таблица на широком экране).
    return CustomScrollView(
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        // Из карточки подрядчика — своя шапка с «назад» (без колокольчика).
        if (widget.initialContractorId == null)
          HomeHeader(title: l.navReports, maxWidth: double.infinity)
        else
          AppSliverHeader(title: l.navReports, maxWidth: double.infinity),
        if (_isManager) CupertinoSliverRefreshControl(onRefresh: _load),
        SliverContent(
            maxWidth: double.infinity, sliver: SliverList.list(children: body)),
        const SliverBottomInset(),
      ],
    );
  }

  Widget _filters(AppLocalizations l) {
    final locale = context.localeCode;
    Widget chip(String title, String? value, VoidCallback onTap) => AppChip(
          label: value != null ? '$title: $value' : title,
          selected: value != null,
          icon: AppIcons.filter,
          onTap: onTap,
        );

    return Wrap(spacing: AppSpace.s, runSpacing: AppSpace.s, children: [
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
            padding: EdgeInsetsDirectional.symmetric(vertical: 40),
            child: AppLoader())
      ];
    }
    final f = _Fmt(l);
    final c = report.company;
    return [
      if (_loading)
        const Padding(
          padding: EdgeInsetsDirectional.only(bottom: AppSpace.s),
          child: CupertinoActivityIndicator(),
        ),
      LayoutBuilder(builder: (context, box) {
        final kpis = [
          KpiTile(value: f.count(c.total), label: l.reportsKpiRequests),
          KpiTile(
              value: f.pct(c.onTimeShare),
              label: l.reportsKpiOnTime,
              hint: c.withDue == 0 ? null : l.reportsKpiOf(c.withDue)),
          KpiTile(
              value: f.pct(c.firstPassShare),
              label: l.reportsKpiFirstPass,
              hint: c.accepted == 0 ? null : l.reportsKpiOf(c.accepted)),
          KpiTile(
              value: f.pct(c.geofenceShare),
              label: l.reportsKpiGeofence,
              hint: c.visits == 0 ? null : l.reportsKpiOf(c.visits)),
        ];
        // Плитки в ряду — одной высоты.
        final perRow = box.maxWidth >= 600 ? 4 : 2;
        return Column(children: [
          for (var i = 0; i < kpis.length; i += perRow) ...[
            if (i > 0) const SizedBox(height: AppSpace.group),
            IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = i; j < i + perRow && j < kpis.length; j++) ...[
                      if (j > i) const SizedBox(width: AppSpace.group),
                      Expanded(child: kpis[j]),
                    ],
                  ]),
            ),
          ],
        ]);
      }),
      SectionHeader(l.reportsByContractor),
      if (report.contractors.isEmpty)
        AppEmptyState(text: l.reportsEmpty, icon: AppIcons.reports)
      else
        LayoutBuilder(
          builder: (context, box) => box.maxWidth >= AppSpace.wideFrom
              ? _ContractorTable(
                  rows: report.contractors,
                  name: (id) => _contractorName(l, id),
                  fmt: f,
                  onOpen: _openContractor)
              : AppGroup(
                  separatorInset: AppSpace.separatorInsetIcon,
                  children: [
                      for (final r in report.contractors)
                        _ContractorRow(
                            row: r,
                            name: _contractorName(l, r.contractorId),
                            fmt: f,
                            onOpen: () => _openContractor(r)),
                    ]),
        ),
      if (!report.normsAvailable)
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpace.rowH, vertical: AppSpace.xs),
          child: Text(l.reportsNormsMissing, style: AppText.footnote),
        ),
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpace.rowH, AppSpace.s, AppSpace.rowH, 0),
        child: Text(l.reportsHelp, style: AppText.footnote),
      ),
    ];
  }

  Widget _errorView(AppLocalizations l) => AppEmptyState(
      text: l.reportsLoadFailed,
      error: true,
      actionLabel: l.commonRetry,
      onAction: _report == null && _objects.isEmpty ? _init : _load);

  Future<void> _openContractor(ContractorReport row) async {
    final l = context.l10n;
    await Navigator.push(
      context,
      appRoute(
        title: l.navReports,
        (_) => ContractorOrdersScreen(
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

/// Норма визитов за период: от 1 визита — целым числом («15 / 4»); меньше 1 —
/// с одним знаком после запятой («1 / 0,5»), чтобы за короткий период она
/// не округлялась до 0. Меньше 0,05 визита — null (показывается «—»).
String? formatVisitNorm(double v, String locale) {
  if (v < 0.05) return null;
  if (v >= 1) return NumberFormat.decimalPattern(locale).format(v.round());
  return NumberFormat('#,##0.#', locale).format(v);
}

/// Недобор визитов — по тому же округлению, что видно в отчёте:
/// при норме 4,07 четыре визита — не недобор («4 / 4»).
bool visitsBelowNorm(int visits, double norm) =>
    norm >= 1 ? visits < norm.round() : visits < norm;

/// Форматирование чисел, долей и длительностей по языку интерфейса.
class _Fmt {
  _Fmt(this.l)
      : _num = NumberFormat.decimalPattern(l.localeName),
        _pct = NumberFormat.percentPattern(l.localeName);
  final AppLocalizations l;
  final NumberFormat _num;
  final NumberFormat _pct;

  String count(int n) => _num.format(n);
  String pct(double? v) => v == null ? l.reportsNoValue : _pct.format(v);

  String duration(Duration? d) => d == null ? l.reportsNoValue : l.duration(d);

  String norm(double v) => formatVisitNorm(v, l.localeName) ?? l.reportsNoValue;

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
          s.visitNorm != null && visitsBelowNorm(s.visits, s.visitNorm!)
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

/// Цвет доли «в срок»: от 90 % — акцентный, от 70 % — оранжевый, ниже —
/// красный; нет данных — вторичный.
Color _onTimeColor(double? share) {
  if (share == null) return AppColors.secondary;
  if (share >= 0.9) return AppColors.accentText;
  if (share >= 0.7) return StatusColors.returned.foreground;
  return AppColors.danger;
}

/// Тонкая полоска выполнения (доля принятых от всех заявок).
class _Progress extends StatelessWidget {
  const _Progress(this.value);
  final double value;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          height: 4,
          width: double.infinity,
          child: Stack(children: [
            const Positioned.fill(child: ColoredBox(color: AppColors.fill)),
            // heightFactor: 1 — иначе заливка получает высоту 0 и не видна.
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: value.clamp(0.0, 1.0),
              heightFactor: 1,
              child: const ColoredBox(color: AppColors.accent),
            ),
          ]),
        ),
      );
}

/// Подрядчик на узком экране: инициалы, «в срок», полоска выполнения,
/// ключевые счётчики и остальные показатели мелко.
class _ContractorRow extends StatelessWidget {
  const _ContractorRow(
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
    final s = row.stats;
    final metrics = fmt.metrics(s);
    // Первые четыре — заявки, принято, возвращено, просрочено.
    final key = metrics.take(4).toList();
    final rest = metrics.skip(4).toList();
    return AppRow(
      leading: InitialsTile(name),
      title: name,
      titleStyle: AppText.rowTitle.copyWith(fontWeight: FontWeight.w600),
      trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(fmt.pct(s.onTimeShare),
                style: AppText.headline
                    .copyWith(color: _onTimeColor(s.onTimeShare))),
            Text(fmt.l.reportsOnTime, style: AppText.caption),
          ]),
      onTap: onOpen,
      extra: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Progress(s.total == 0 ? 0 : s.accepted / s.total),
        const SizedBox(height: 6),
        Text.rich(
            TextSpan(children: [
              for (var i = 0; i < key.length; i++) ...[
                if (i > 0) const TextSpan(text: ' · '),
                TextSpan(
                    text: '${key[i].$1} ${key[i].$2}',
                    style: key[i].$3
                        ? const TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600)
                        : null),
              ]
            ]),
            style: AppText.footnote),
        const SizedBox(height: 4),
        Wrap(spacing: AppSpace.m, runSpacing: 2, children: [
          for (final (label, value, alert) in rest)
            Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$label '),
                  TextSpan(
                      text: value,
                      style: TextStyle(
                          color: alert ? AppColors.danger : AppColors.ink,
                          fontWeight: FontWeight.w600)),
                ]),
                style: AppText.caption),
        ]),
      ]),
    );
  }
}

/// Подрядчики на широком экране: таблица в белой группе, тонкие
/// разделители, строка открывает заявки. Колонка «Подрядчик» закреплена,
/// остальные прокручиваются вбок (полоса прокрутки видна всегда, если
/// столбцы не помещаются).
class _ContractorTable extends StatefulWidget {
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
  State<_ContractorTable> createState() => _ContractorTableState();
}

class _ContractorTableState extends State<_ContractorTable> {
  // Высоты строк одинаковые в обеих частях таблицы — строки совпадают.
  static const _headH = 60.0; // до трёх строк заголовка
  static const _rowH = 52.0;
  static const _nameW = 240.0;
  static const _colW =
      120.0; // «ВОЗВРАЩЕНО», «ВЫПОЛНЕНИЕ» — без переноса посреди слова

  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _cell(Widget child, {double? width, bool end = false}) => SizedBox(
        width: width,
        child: Padding(
          padding:
              const EdgeInsetsDirectional.symmetric(horizontal: AppSpace.s),
          child: Align(
              alignment: end
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: child),
        ),
      );

  // Ширина — явно: части таблицы стоят в Row, где «во всю ширину»
  // означает бесконечность (ошибка вёрстки и пустая таблица).
  Widget _line(double width) => SizedBox(
      height: 0.5,
      width: width,
      child: const ColoredBox(color: AppColors.separator));

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final header =
        rows.isEmpty ? const [] : widget.fmt.metrics(rows.first.stats);
    final metricsW = _colW * header.length + AppSpace.s * 2;

    final fixed =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: _headH,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: AppSpace.s),
          child: _cell(
              Text(context.l10n.reportsFilterContractor.toUpperCase(),
                  style: AppText.section),
              width: _nameW - AppSpace.s),
        ),
      ),
      for (final r in rows) ...[
        _line(_nameW),
        Pressable(
          onTap: () => widget.onOpen(r),
          effect: PressEffect.highlight,
          child: SizedBox(
            height: _rowH,
            width: _nameW,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: AppSpace.s),
              child: Row(children: [
                _cell(InitialsTile(widget.name(r.contractorId))),
                Expanded(
                  child: Text(widget.name(r.contractorId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.rowTitle
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
        ),
      ],
    ]);

    final scrolling = SizedBox(
      width: metricsW,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: _headH,
          child: Row(children: [
            for (final (label, _, _) in header)
              _cell(
                  Text(label.toUpperCase(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: AppText.caption.copyWith(
                          fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                  width: _colW,
                  end: true),
          ]),
        ),
        for (final r in rows) ...[
          _line(metricsW),
          Pressable(
            onTap: () => widget.onOpen(r),
            effect: PressEffect.highlight,
            child: SizedBox(
              height: _rowH,
              child: Row(children: [
                for (final (_, value, alert) in widget.fmt.metrics(r.stats))
                  _cell(
                      Text(value,
                          maxLines: 1,
                          style: AppText.callout.copyWith(
                              color: alert ? AppColors.danger : AppColors.ink,
                              fontWeight: FontWeight.w500)),
                      width: _colW,
                      end: true),
              ]),
            ),
          ),
        ],
      ]),
    );

    return AppCard(
      padding: EdgeInsets.zero,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        fixed,
        const SizedBox(
            width: 0.5,
            height: _headH,
            child: ColoredBox(color: AppColors.separator)),
        // Высота задана явно: горизонтальной прокрутке внутри списка нужна
        // ограниченная высота (иначе ошибка вёрстки и пустая таблица).
        Expanded(
          child: SizedBox(
            height: _headH + rows.length * (_rowH + 0.5) + AppSpace.m,
            // Без нижнего отступа экрана (место под меню вкладок): иначе
            // полоса прокрутки поднимается на его высоту — на строки таблицы.
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                // Полоса прокрутки — только своя (под строками): общая полоса
                // приложения на ПК рисовалась поверх таблицы.
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    // Место под полосу прокрутки, чтобы она не закрывала строку.
                    padding:
                        const EdgeInsetsDirectional.only(bottom: AppSpace.m),
                    child: scrolling,
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
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
    return AppScaffold(
      title: title,
      eyebrow: subtitle,
      slivers: [
        SliverContent(
          sliver: SliverList.list(children: [
            if (orders.isEmpty)
              AppEmptyState(text: l.reportsOrdersEmpty)
            else
              AppGroup(children: [
                for (final o in orders) _row(context, l, locale, now, o),
              ]),
          ]),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, AppLocalizations l, String locale,
      DateTime now, ReportOrder o) {
    final layer = Layer.find(layers, id: o.layerId, name: o.workType);
    final workType = layer?.label(locale) ?? o.workType;
    final flags = [
      if (o.isOverdue(now)) l.statusOverdue,
      if (o.returnCount > 0) l.reportsReturnedTimes(o.returnCount),
    ];
    return AppRow(
      leading: PriorityDot(o.priority),
      title: o.title,
      subtitle: [
        _objectName(l, o.objectId),
        if (workType != null && workType.isNotEmpty) workType,
      ].join(' · '),
      trailing: StatusPill(o.status),
      extra: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.dateTime(o.createdAt), style: AppText.caption),
        if (flags.isNotEmpty)
          Text(flags.join(' · '),
              style: AppText.caption.copyWith(
                  color: AppColors.danger, fontWeight: FontWeight.w600)),
      ]),
      onTap: () => _open(context, o),
    );
  }

  Future<void> _open(BuildContext context, ReportOrder o) async {
    final repo = RequestsRepo();
    await Navigator.push(
      context,
      appRoute(
        title: title,
        (_) => WorkOrderDetailScreen(
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
