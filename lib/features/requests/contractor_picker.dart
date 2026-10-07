import 'package:flutter/material.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';

const _muted = Color(0xFF8A9098);
const _danger = Color(0xFFC24444);

/// Поиск появляется, когда подрядчиков больше этого числа.
const _searchFrom = 6;

/// С какой ширины окно — диалог по центру, а не нижняя шторка.
const _wideFrom = 600.0;

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
  final size = MediaQuery.sizeOf(context);
  if (size.width >= _wideFrom) {
    return showDialog<Contractor>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: 520, maxHeight: size.height * 0.8),
          child: picker,
        ),
      ),
    );
  }
  return showModalBottomSheet<Contractor>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    // Вся доступная высота: список прокручивается внутри и не обрезается.
    builder: (ctx) =>
        SizedBox(height: MediaQuery.sizeOf(ctx).height, child: picker),
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
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 8, 4),
        child: Row(children: [
          Expanded(
            child: Text(l.actionAssign,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close, semanticLabel: l.commonCancel)),
        ]),
      ),
      if (widget.contractors.length > _searchFrom)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l.assignSearch,
                isDense: true,
                border: const OutlineInputBorder()),
          ),
        ),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      Expanded(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 24),
          children: [
            if (!_loading && !_failed && boundIds.isEmpty)
              Container(
                margin: const EdgeInsetsDirectional.only(top: 8, bottom: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFFBF0D9),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(
                    widget.layerLabel == null
                        ? l.assignNoLayer
                        : l.assignNobodyBound(widget.layerLabel!),
                    style: const TextStyle(
                        color: Color(0xFF7A5300), fontSize: 13)),
              ),
            if (bound.isNotEmpty) ...[
              SectionTitle(l.assignBound),
              for (final c in bound)
                _tile(l, c, fitting.where((b) => b.contractorId == c.id)),
            ],
            if (others.isNotEmpty) ...[
              SectionTitle(bound.isEmpty && boundIds.isEmpty
                  ? l.assignAll
                  : l.assignOthers),
              for (final c in others)
                _tile(l, c, _bindings.where((b) => b.contractorId == c.id)),
            ],
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l.assignNothingFound,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted)),
              ),
            if (_failed)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: Text(l.assignBindingsFailed,
                    style: const TextStyle(color: _danger, fontSize: 12)),
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
    return TapCard(
      onTap: () => Navigator.pop(context, c),
      chevron: false,
      child: Row(children: [
        const Icon(Icons.business, color: HeyHelpyTheme.link),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.orgName,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            for (final line in lines)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 2),
                child: Text(line,
                    style: const TextStyle(color: _muted, fontSize: 12)),
              ),
          ]),
        ),
        if (current)
          Icon(Icons.check_rounded,
              color: HeyHelpyTheme.link, semanticLabel: l.assignCurrent),
      ]),
    );
  }

  /// «Климат · БЦ «Демо» · норма 4 визита в месяц».
  String _bindingLine(AppLocalizations l, Binding b) => [
        b.layer?.label(context.localeCode) ?? '—',
        b.objectName ?? l.assignAllObjects,
        if (b.visitsPerMonth != null) l.assignNorm(b.visitsPerMonth!),
      ].join(' · ');
}
