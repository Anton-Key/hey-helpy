import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import '../reports/reports_screen.dart';
import '../requests/order_list.dart';
import '../requests/requests.dart';
import 'directory.dart';
import '../../core/app_message.dart';

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
      barrierColor: AppColors.scrim,
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

  void _openOrders(AppLocalizations l) => Navigator.push(
      context,
      appRoute(
          (_) => WorkOrderListScreen(
              title: l.cardContractorOrders,
              subtitle: widget.contractor.orgName,
              contractorId: widget.contractor.id),
          title: widget.contractor.orgName));

  void _openReport(AppLocalizations l) => Navigator.push(
      context,
      appRoute(
          (_) => Scaffold(
                backgroundColor: AppColors.bg,
                body: Column(children: [
                  // Только «назад»: заголовок «Отчёты» — в шапке самого
                  // ReportsScreen.
                  const AppNavBar(border: false),
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: ReportsScreen(
                          initialContractorId: widget.contractor.id),
                    ),
                  ),
                ]),
              ),
          title: widget.contractor.orgName));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final List<Widget> slivers;
    if (_loading && _role == null) {
      slivers = const [
        SliverFillRemaining(hasScrollBody: false, child: AppLoader())
      ];
    } else if (_failed) {
      slivers = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
              text: l.cardLoadFailed,
              error: true,
              actionLabel: l.commonRetry,
              onAction: _load),
        )
      ];
    } else {
      slivers = [
        SliverContent(sliver: SliverList.list(children: _content(l))),
      ];
    }
    return AppScaffold(
      title: widget.contractor.orgName,
      onRefresh: _load,
      slivers: slivers,
      bottomBar: _failed || (_loading && _role == null)
          ? null
          : BottomActionBar(
              child: Row(children: [
                Expanded(
                  child: AppButton.primary(
                      icon: AppIcons.list,
                      label: l.cardContractorOrders,
                      onPressed: () => _openOrders(l)),
                ),
                if (_isManager) ...[
                  const SizedBox(width: AppSpace.m),
                  AppIconButton(
                      icon: AppIcons.reports,
                      label: l.cardContractorReport,
                      size: 52,
                      filled: true,
                      onPressed: () => _openReport(l)),
                ],
              ]),
            ),
    );
  }

  List<Widget> _content(AppLocalizations l) {
    final locale = context.localeCode;
    return [
      // Виды работ и объекты
      if (_bindings.isEmpty)
        AppGroup(header: l.cardBindingsTitle, children: [
          AppRow(title: l.cardBindingsEmpty, titleStyle: AppText.callout),
        ])
      else
        AppGroup(
          header: l.cardBindingsTitle,
          footer: _isManager ? l.cardNormHint : null,
          children: [
            for (final b in _bindings)
              AppRow(
                leading: const LeadingIcon(AppIcons.workType),
                title: b.layer?.label(locale) ?? l.commonNotSpecified,
                subtitle: b.objectName ?? l.cardAllObjects,
                extra: Text(
                    b.visitsPerMonth == null
                        ? l.cardNormNotSet
                        : l.cardNormPerMonth(b.visitsPerMonth!),
                    style: AppText.footnote.copyWith(
                        color: b.visitsPerMonth == null
                            ? AppColors.secondary
                            : AppColors.accentText,
                        fontWeight: FontWeight.w600)),
                trailing: _isManager
                    ? const Icon(AppIcons.edit,
                        size: AppSizes.iconS, color: AppColors.accentText)
                    : null,
                chevron: false,
                onTap: _isManager ? () => _editNorm(b) : null,
              ),
          ],
        ),

      // Исполнители и контакты
      AppGroup(header: l.cardExecutorsTitle, children: [
        if (_executors.isEmpty)
          AppRow(title: l.cardExecutorsEmpty, titleStyle: AppText.callout)
        else
          for (final e in _executors)
            AppRow(
              leading: const LeadingIcon.neutral(AppIcons.executor),
              title:
                  e.name?.isNotEmpty == true ? e.name! : l.profileDefaultName,
              extra: e.phone?.isNotEmpty == true
                  ? SelectableText(e.phone!,
                      style: AppText.footnote
                          .copyWith(color: AppColors.accentText))
                  : null,
            ),
      ]),
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
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpace.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 22, 20, 16),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.cardNormDialogTitle,
                    textAlign: TextAlign.center, style: AppText.headline),
                const SizedBox(height: AppSpace.m),
                TextField(
                  controller: _c,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                      hintText: l.cardNormDialogHint,
                      errorText: _error,
                      fillColor: AppColors.fill),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 18),
                AppButton.primary(label: l.commonSave, onPressed: _save),
                const SizedBox(height: AppSpace.s),
                AppButton.secondary(
                    label: l.commonCancel,
                    onPressed: () => Navigator.pop(context)),
              ]),
        ),
      ),
    );
  }
}
