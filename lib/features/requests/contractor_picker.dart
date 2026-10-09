import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';

/// Поиск появляется, когда подрядчиков больше этого числа.
const _searchFrom = 6;

/// Окно выбора подрядчика для заявки. Сверху — закреплённые за видом работ
/// и объектом заявки (в том же порядке, в каком их выбирает база:
/// сначала за объектом, потом «на все объекты»), ниже — остальные.
/// Назначает не окно, а вызывающий экран; права проверяет база.
Future<Contractor?> pickContractor(
  BuildContext context, {
  required List<Contractor> contractors,
  String? layerId,
  String? layerLabel,
  String? objectId,
  String? currentId,
}) {
  final picker = _ContractorPicker(
      contractors: contractors,
      layerId: layerId,
      layerLabel: layerLabel,
      objectId: objectId,
      currentId: currentId);
  // Нижняя шторка (на широком окне — не шире колонки содержимого) на почти
  // всю высоту: список прокручивается внутри и не обрезается.
  return showAppSheet<Contractor>(
    context: context,
    builder: (ctx) =>
        SizedBox(height: MediaQuery.sizeOf(ctx).height * 0.9, child: picker),
  );
}

class _ContractorPicker extends StatefulWidget {
  const _ContractorPicker(
      {required this.contractors,
      this.layerId,
      this.layerLabel,
      this.objectId,
      this.currentId});
  final List<Contractor> contractors;
  final String? layerId;
  final String? layerLabel;
  final String? objectId;
  final String? currentId;

  @override
  State<_ContractorPicker> createState() => _ContractorPickerState();
}

class _ContractorPickerState extends State<_ContractorPicker> {
  final _repo = DirectoryRepo();
  final _search = TextEditingController();
  List<Binding> _bindings = const [];
  Map<String, int> _executors = const {};
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait<Object>(
          [_repo.allBindings(), _repo.executorCounts()]);
      if (!mounted) return;
      setState(() {
        _bindings = r[0] as List<Binding>;
        _executors = r[1] as Map<String, int>;
        _loading = false;
      });
    } catch (e) {
      // Без закреплений список всё равно рабочий — просто без подсказок.
      debugPrint('Picker: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// Закрепление подходит заявке: тот же вид работ и её объект или «все объекты».
  bool _fits(Binding b) =>
      widget.layerId != null &&
      b.layer?.id == widget.layerId &&
      (b.objectId == null || b.objectId == widget.objectId);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = _search.text.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.contractors
        : widget.contractors
            .where((c) => c.orgName.toLowerCase().contains(q))
            .toList();

    // Закреплённые: сначала за объектом, затем «на все объекты».
    final fitting = _bindings.where(_fits).toList()
      ..sort((a, b) =>
          (a.objectId == null ? 1 : 0).compareTo(b.objectId == null ? 1 : 0));
    final boundIds = <String>[];
    for (final b in fitting) {
      if (!boundIds.contains(b.contractorId)) boundIds.add(b.contractorId);
    }
    final bound = [
      for (final id in boundIds) ...shown.where((c) => c.id == id),
    ];
    final others = shown.where((c) => !boundIds.contains(c.id)).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetHeader(title: l.actionAssign, cancelLabel: l.commonCancel),
      if (widget.contractors.length > _searchFrom)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpace.screen, AppSpace.xs, AppSpace.screen, AppSpace.xs),
          child: AppSearchField(
              controller: _search, hint: l.assignSearch, onChanged: (_) {}),
        ),
      if (_loading)
        const Padding(
          padding: EdgeInsetsDirectional.only(top: AppSpace.s),
          child: AppLoader(),
        ),
      Expanded(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpace.screen, AppSpace.xs, AppSpace.screen, AppSpace.xl),
          children: [
            if (!_loading && !_failed && boundIds.isEmpty)
              Container(
                margin: const EdgeInsetsDirectional.only(
                    top: AppSpace.s, bottom: AppSpace.xs),
                padding: const EdgeInsets.all(AppSpace.m),
                decoration: BoxDecoration(
                    color: StatusColors.newOrder.background,
                    borderRadius: BorderRadius.circular(AppRadius.field)),
                child: Text(
                    widget.layerLabel == null
                        ? l.assignNoLayer
                        : l.assignNobodyBound(widget.layerLabel!),
                    style: AppText.footnote
                        .copyWith(color: StatusColors.newOrder.foreground)),
              ),
            if (bound.isNotEmpty)
              AppGroup(header: l.assignBound, children: [
                for (final c in bound)
                  _tile(l, c, fitting.where((b) => b.contractorId == c.id)),
              ]),
            if (others.isNotEmpty)
              AppGroup(
                  header: bound.isEmpty && boundIds.isEmpty
                      ? l.assignAll
                      : l.assignOthers,
                  children: [
                    for (final c in others)
                      _tile(
                          l, c, _bindings.where((b) => b.contractorId == c.id)),
                  ]),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
                child: Text(l.assignNothingFound,
                    textAlign: TextAlign.center,
                    style:
                        AppText.callout.copyWith(color: AppColors.secondary)),
              ),
            if (_failed)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: AppSpace.s),
                child: Text(l.assignBindingsFailed,
                    style: AppText.caption.copyWith(color: AppColors.danger)),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _tile(AppLocalizations l, Contractor c, Iterable<Binding> bindings) {
    final current = c.id == widget.currentId;
    final lines = [
      for (final b in bindings.take(3)) _bindingLine(l, b),
      l.assignExecutors(_executors[c.id] ?? 0),
    ];
    return AppRow(
      leading: InitialsTile(c.orgName),
      title: c.orgName,
      subtitle: lines.join('\n'),
      subtitleMaxLines: 4,
      chevron: false,
      trailing: current
          ? Icon(AppIcons.check,
              size: AppSizes.icon,
              color: AppColors.accentText,
              semanticLabel: l.assignCurrent)
          : null,
      onTap: () => Navigator.pop(context, c),
    );
  }

  /// «Климат · БЦ «Демо» · норма 4 визита в месяц».
  String _bindingLine(AppLocalizations l, Binding b) => [
        b.layer?.label(context.localeCode) ?? '—',
        b.objectLabel ?? l.assignAllObjects,
        if (b.visitsPerMonth != null) l.assignNorm(b.visitsPerMonth!),
      ].join(' · ');
}
