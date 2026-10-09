import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../l10n/app_localizations.dart';
import '../reports/reports_screen.dart';
import '../requests/order_list.dart';
import '../requests/requests.dart';
import 'directory.dart';
import '../../core/app_message.dart';

const _ink = Color(0xFF1C1E22);
const _muted = Color(0xFF8A9098);
const _danger = Color(0xFFC24444);

/// Карточка подрядчика: контакты (исполнители), виды работ и объекты с нормой
/// визитов, кнопки «Заявки подрядчика» и «Отчёт». Норму меняет только менеджер —
/// это проверяет база (политика contractor_layers_manage).
class ContractorCardScreen extends StatefulWidget {
  const ContractorCardScreen({super.key, required this.contractor});
  final Contractor contractor;

  @override
  State<ContractorCardScreen> createState() => _ContractorCardScreenState();
}

class _ContractorCardScreenState extends State<ContractorCardScreen> {
  final _dir = DirectoryRepo();
  String? _role;
  List<Binding> _bindings = const [];
  List<ExecutorPerson> _executors = const [];
  bool _loading = true;
  bool _failed = false;

  bool get _isManager => _role == 'admin' || _role == 'manager';

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
      final id = widget.contractor.id;
      final results = await Future.wait<Object?>([
        RequestsRepo().myRole(),
        _dir.bindingsOfContractor(id),
        _dir.executorsOf(id),
      ]);
      if (!mounted) return;
      setState(() {
        _role = results[0] as String?;
        _bindings = results[1] as List<Binding>;
        _executors = results[2] as List<ExecutorPerson>;
        _loading = false;
      });
    } catch (e) {
      debugPrint('ContractorCard: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _snack(String m, {AppMessageType type = AppMessageType.info}) {
    if (mounted) showAppMessage(context, m, type: type);
  }

  Future<void> _editNorm(Binding b) async {
    final l = context.l10n;
    // null — закрыли без сохранения (в том числе нажатием мимо окна);
    // (value: null) — убрать норму.
    final result = await showDialog<({int? value})>(
      context: context,
      builder: (_) => _NormDialog(initial: b.visitsPerMonth),
    );
    if (result == null || !mounted) return;
    try {
      await _dir.setVisitNorm(b.id, result.value);
      await _load();
      _snack(l.toastSaved, type: AppMessageType.success);
    } catch (e) {
      debugPrint('setVisitNorm: $e');
      _snack(l.saveFailed, type: AppMessageType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(widget.contractor.orgName)),
      body: _loading && _role == null
          ? const Center(child: CircularProgressIndicator())
          : _failed
              ? _error(l)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 40),
                    children: _content(l),
                  ),
                ),
    );
  }

  Widget _error(AppLocalizations l) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l.cardLoadFailed,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _danger)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: Text(l.commonRetry)),
          ]),
        ),
      );

  List<Widget> _content(AppLocalizations l) {
    final locale = context.localeCode;
    return [
      // Название и кнопки
      TapCard(
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: HeyHelpyTheme.mint,
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.business, color: HeyHelpyTheme.link),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(widget.contractor.orgName,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
      Wrap(spacing: 10, runSpacing: 10, children: [
        FilledButton.icon(
          style: brandButtonStyle()
              .copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 48))),
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => WorkOrderListScreen(
                      title: l.cardContractorOrders,
                      subtitle: widget.contractor.orgName,
                      contractorId: widget.contractor.id))),
          icon: const Icon(Icons.list_alt_rounded, size: 20),
          label: Text(l.cardContractorOrders,
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        if (_isManager)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => Scaffold(
                          backgroundColor: Colors.white,
                          appBar: AppBar(title: Text(l.navReports)),
                          body: ReportsScreen(
                              initialContractorId: widget.contractor.id),
                        ))),
            icon: const Icon(Icons.bar_chart_rounded, size: 20),
            label: Text(l.cardContractorReport),
          ),
      ]),

      // Виды работ и объекты
      SectionTitle(l.cardBindingsTitle),
      if (_bindings.isEmpty)
        Text(l.cardBindingsEmpty, style: const TextStyle(color: _muted))
      else ...[
        if (_isManager)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8),
            child: Text(l.cardNormHint,
                style: const TextStyle(color: _muted, fontSize: 12)),
          ),
        for (final b in _bindings)
          TapCard(
            onTap: _isManager ? () => _editNorm(b) : null,
            chevron: false,
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.layer?.label(locale) ?? l.commonNotSpecified,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(b.objectName ?? l.cardAllObjects,
                          style: const TextStyle(color: _muted, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(
                          b.visitsPerMonth == null
                              ? l.cardNormNotSet
                              : l.cardNormPerMonth(b.visitsPerMonth!),
                          style: TextStyle(
                              color: b.visitsPerMonth == null
                                  ? _muted
                                  : HeyHelpyTheme.link,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ]),
              ),
              if (_isManager)
                const Icon(Icons.edit_outlined,
                    color: HeyHelpyTheme.link, size: 20),
            ]),
          ),
      ],

      // Исполнители и контакты
      SectionTitle(l.cardExecutorsTitle),
      if (_executors.isEmpty)
        Text(l.cardExecutorsEmpty, style: const TextStyle(color: _muted))
      else
        for (final e in _executors)
          TapCard(
            child: Row(children: [
              const Icon(Icons.person_outline, color: _muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          e.name?.isNotEmpty == true
                              ? e.name!
                              : l.profileDefaultName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, color: _ink)),
                      if (e.phone?.isNotEmpty == true)
                        SelectableText(e.phone!,
                            style: const TextStyle(
                                color: HeyHelpyTheme.link, fontSize: 13)),
                    ]),
              ),
            ]),
          ),
    ];
  }
}

/// Ввод нормы визитов в месяц. Возвращает (value: число) или (value: null) —
/// «без нормы»; при отмене — null.
class _NormDialog extends StatefulWidget {
  const _NormDialog({this.initial});
  final int? initial;

  @override
  State<_NormDialog> createState() => _NormDialogState();
}

class _NormDialogState extends State<_NormDialog> {
  late final _c = TextEditingController(text: widget.initial?.toString() ?? '');
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final text = _c.text.trim();
    if (text.isEmpty) {
      Navigator.pop(context, (value: null));
      return;
    }
    final v = int.tryParse(text);
    if (v == null || v < 0 || v > 1000) {
      setState(() => _error = context.l10n.cardNormInvalid);
      return;
    }
    Navigator.pop(context, (value: v));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.cardNormDialogTitle),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration:
            InputDecoration(hintText: l.cardNormDialogHint, errorText: _error),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.commonCancel)),
        FilledButton(
            style: brandButtonStyle(),
            onPressed: _save,
            child: Text(l.commonSave)),
      ],
    );
  }
}
