import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/file_share.dart';
import '../../core/l10n_ext.dart';
import '../../core/schema_compat.dart';
import '../../l10n/app_localizations.dart';
import '../directory/city.dart';
import '../directory/directory.dart';
import '../requests/order_link_screen.dart';
import '../requests/order_list.dart';
import 'act_doc.dart';
import 'act_logic.dart';
import 'act_pdf.dart' deferred as actpdf;
import 'act_xlsx.dart' deferred as actxlsx;
import 'acts_repository.dart';

/// «Отчёты → Акты подрядчикам» (шаг 24): «Платим подрядчику только за
/// доказанную работу». Подрядчик и месяц → «К оплате» (принято менеджером
/// и доказано: фото «после», визит в геозоне, чек-лист) и «Без
/// доказательства — к оплате не принимается» с причинами; итоги;
/// «Сформировать акт» (PDF A4 + номер АКТ-<год>-<NNN> в базе), Excel для
/// бухгалтерии, список сформированных актов. Видит менеджер в пределах зоны.
class ContractorActsScreen extends StatefulWidget {
  const ContractorActsScreen({super.key, this.initialContractorId});
  final String? initialContractorId;

  @override
  State<ContractorActsScreen> createState() => _ContractorActsScreenState();
}

class _ContractorActsScreenState extends State<ContractorActsScreen> {
  final _repo = ActsRepository();
  OrderContext? _ctx;
  List<Place> _places = const [];
  String? _contractorId;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  ActRates _rates = const ActRates();
  ActResult? _result;
  List<SavedAct> _acts = const [];
  bool _loading = true;
  bool _failed = false;
  bool _issuing = false;
  ({String? company, String? me}) _header = (company: null, me: null);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ctx = await OrderContext.load();
      final r = await Future.wait<Object>([
        DirectoryRepo().places().catchError((_) => const <Place>[]),
        _repo.header().catchError((_) => (company: null, me: null)),
      ]);
      if (!mounted) return;
      final first = widget.initialContractorId ??
          ctx.contractors
              .where((c) => c.orgName == 'КлиматСервис')
              .firstOrNull
              ?.id ??
          ctx.contractors.firstOrNull?.id;
      setState(() {
        _ctx = ctx;
        _places = r[0] as List<Place>;
        _header = r[1] as ({String? company, String? me});
        _contractorId = first;
      });
      await _load();
    } catch (e) {
      debugPrint('acts init: ${e.runtimeType}');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _load() async {
    final id = _contractorId;
    final ctx = _ctx;
    if (id == null || ctx == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final (from, to) = monthRange(_month);
      final r = await Future.wait<Object>([
        _repo.orders(id, from, to, ctx.objects),
        _repo.rates(id),
        _repo.acts(id).catchError((_) => const <SavedAct>[]),
      ]);
      if (!mounted || id != _contractorId) return;
      setState(() {
        _rates = r[1] as ActRates;
        _result = buildAct(r[0] as List<ActOrder>, _rates);
        _acts = r[2] as List<SavedAct>;
        _loading = false;
      });
    } catch (e) {
      debugPrint('acts: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  String _contractorName(String? id) =>
      _ctx?.contractors.where((c) => c.id == id).firstOrNull?.orgName ?? '—';

  String _objectName(String? id) {
    final o = _ctx?.objects.where((o) => o.id == id).firstOrNull;
    return o == null ? '—' : objectDisplayName(o);
  }

  String _placeName(String? id) =>
      _places.where((p) => p.id == id).firstOrNull?.name ?? '—';

  String _monthLabel(AppLocalizations l, DateTime m) {
    final s = DateFormat.yMMMM(l.localeName).format(m);
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  String _work(ActOrder o) {
    final layers = _ctx?.layers ?? const <Layer>[];
    return Layer.find(layers, id: o.layerId)?.label(context.localeCode) ?? '—';
  }

  ActDoc _doc(AppLocalizations l, String number, DateTime issuedAt) =>
      buildActDoc(
        l: l,
        result: _result!,
        number: number,
        company: _header.company ?? '—',
        contractor: _contractorName(_contractorId),
        period: _monthLabel(l, _month),
        issuedAt: issuedAt,
        author: _header.me ?? '—',
        objectName: _objectName,
        placeName: _placeName,
        workName: _work,
      );

  Future<void> _pickContractor() async {
    final l = context.l10n;
    final list = _ctx?.contractors ?? const <Contractor>[];
    final picked = await showAppSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetHeader(title: l.actPickContractor, cancelLabel: l.commonCancel),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.l),
              children: [
                AppGroup(
                    separatorInset: AppSpace.separatorInsetIcon,
                    children: [
                      for (final c in [
                        ...list
                      ]..sort((a, b) => a.orgName.compareTo(b.orgName)))
                        AppRow(
                          leading: InitialsTile(c.orgName),
                          title: c.orgName,
                          trailing: c.id == _contractorId
                              ? const Icon(AppIcons.check,
                                  size: AppSizes.iconS,
                                  color: AppColors.accentText)
                              : null,
                          chevron: false,
                          onTap: () => Navigator.pop(ctx, c.id),
                        ),
                    ]),
              ],
            ),
          ),
        ]),
      ),
    );
    if (picked == null || picked == _contractorId) return;
    setState(() {
      _contractorId = picked;
      _result = null;
    });
    await _load();
  }

  Future<void> _shiftMonth(int delta) async {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    await _load();
  }

  Future<void> _editRates() async {
    final l = context.l10n;
    final ctx = _ctx;
    if (ctx == null || _contractorId == null) return;
    final orderC = TextEditingController(
        text:
            _rates.perOrder == null ? '' : _rates.perOrder!.toStringAsFixed(0));
    final visitC = TextEditingController(
        text:
            _rates.perVisit == null ? '' : _rates.perVisit!.toStringAsFixed(0));
    Widget field(TextEditingController c, String hint) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: AppText.body,
        decoration: InputDecoration(
            hintText: hint,
            suffixText: _rates.currency,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none));
    final ok = await showAppSheet<bool>(
      context: context,
      builder: (sheet) => Padding(
        padding: EdgeInsetsDirectional.only(
            bottom: MediaQuery.of(sheet).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetHeader(title: l.actRates, cancelLabel: l.commonCancel),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpace.screen, AppSpace.xs, AppSpace.screen, AppSpace.l),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AppGroup(
                  header: l.actRateOrder,
                  children: [field(orderC, l.actRateNone)]),
              AppGroup(
                  header: l.actRateVisit,
                  footer: l.actRatesHint,
                  children: [field(visitC, l.actRateNone)]),
            ]),
          ),
          BottomActionBar(
              child: AppButton.primary(
                  label: l.commonSave,
                  onPressed: () => Navigator.pop(sheet, true))),
        ]),
      ),
    );
    double? num(String s) =>
        double.tryParse(s.trim().replaceAll(' ', '').replaceAll(',', '.'));
    final perOrder = num(orderC.text);
    final perVisit = num(visitC.text);
    orderC.dispose();
    visitC.dispose();
    if (ok != true || !mounted) return;
    try {
      await _repo.saveRates(
          companyId: ctx.companyId!,
          contractorId: _contractorId!,
          perOrder: perOrder,
          perVisit: perVisit,
          currency: _rates.currency);
      if (mounted) showAppMessage(context, l.actRatesSaved);
      await _load();
    } catch (e) {
      debugPrint('rates: ${e.runtimeType}');
      if (mounted) {
        showAppMessage(context, l.actRatesFailed, type: AppMessageType.error);
      }
    }
  }

  Future<void> _issue() async {
    final l = context.l10n;
    final result = _result;
    final ctx = _ctx;
    if (result == null || ctx == null || _contractorId == null) return;
    setState(() => _issuing = true);
    try {
      final (from, to) = monthRange(_month);
      final act = await _repo.issue(
          contractorId: _contractorId!,
          from: from,
          toInclusive: to.subtract(const Duration(days: 1)),
          result: result);
      if (!mounted) return;
      await actpdf.loadLibrary();
      final fonts = await actpdf.loadActFonts();
      if (!mounted) return;
      final pdf =
          await actpdf.buildActPdf(_doc(l, act.number, DateTime.now()), fonts);
      final base = actFileBase(act.number);
      var archived = true;
      try {
        await _repo.uploadPdf(
            companyId: ctx.companyId!,
            actId: act.id,
            fileBase: base,
            bytes: pdf.bytes);
      } catch (e) {
        debugPrint('act pdf upload: ${e.runtimeType}');
        archived = false;
      }
      if (!mounted) return;
      showAppMessage(
          context, archived ? l.actIssued(act.number) : l.actPdfNotSaved,
          type: archived ? AppMessageType.success : AppMessageType.info);
      await actpdf.outputActPdf(pdf.bytes, '$base.pdf');
      await _load();
    } catch (e) {
      debugPrint('act issue: $e');
      if (mounted) {
        showAppMessage(context, l.actIssueFailed, type: AppMessageType.error);
      }
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
  }

  Future<void> _excel() async {
    final l = context.l10n;
    if (_result == null) return;
    try {
      await actxlsx.loadLibrary();
      final number = _acts.where((a) => !a.replaced).firstOrNull?.number ??
          '${l.actsTitle} ${_monthLabel(l, _month)}';
      final bytes = actxlsx.buildActXlsx(_doc(l, number, DateTime.now()));
      final name =
          '${actFileBase(number)}_${actFileBase(_contractorName(_contractorId))}.xlsx';
      final uri = await FilePicker.saveFile(
        fileName: name,
        bytes: bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );
      if (uri != null && mounted) showAppMessage(context, l.actExcelSaved);
    } catch (e) {
      debugPrint('act xlsx: $e');
      if (mounted) {
        showAppMessage(context, l.actExcelFailed, type: AppMessageType.error);
      }
    }
  }

  Future<void> _openPdf(SavedAct a) async {
    final l = context.l10n;
    if (a.pdfPath == null) return;
    try {
      final url = await _repo.signedUrl(a.pdfPath!);
      if (mounted) await openStorageUrl(context, url);
    } catch (_) {
      if (mounted) {
        showAppMessage(context, l.fileOpenFailed, type: AppMessageType.error);
      }
    }
  }

  void _openOrder(ActOrder o) => Navigator.push(
      context,
      appRoute((_) => OrderLinkScreen(orderId: o.id),
          title: context.l10n.actsTitle));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppScaffold(
      title: l.actsTitle,
      eyebrow: l.actsSlogan,
      onRefresh: _load,
      slivers: [_body(l), const SliverBottomInset()],
      bottomBar: _result == null || SchemaCompat.has('0021') == false
          ? null
          : BottomActionBar(
              child: Row(children: [
                Expanded(
                  child: AppButton.primary(
                      icon: AppIcons.fileCheck,
                      label: l.actIssue,
                      loading: _issuing,
                      onPressed:
                          _issuing || _result!.total == 0 ? null : _issue),
                ),
                const SizedBox(width: AppSpace.m),
                AppIconButton(
                    icon: AppIcons.fileSheet,
                    label: l.actExcel,
                    tooltip: true,
                    size: 52,
                    filled: true,
                    onPressed: _result!.total == 0 ? null : _excel),
              ]),
            ),
    );
  }

  Widget _body(AppLocalizations l) {
    if (_ctx == null && !_failed) {
      return const SliverFillRemaining(
          hasScrollBody: false, child: AppLoader());
    }
    if (_ctx != null && _ctx!.contractors.isEmpty) {
      return SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(icon: AppIcons.act, text: l.actNoContractors));
    }
    final r = _result;
    final cur = _rates.currency;
    final pct = NumberFormat.percentPattern(l.localeName);
    String money(double v) => actMoney(l.localeName, v, cur);
    final ratesLine = !_rates.any
        ? l.actNoRates
        : [
            '${l.actRateOrder}: ${_rates.perOrder == null ? l.actRateNone : money(_rates.perOrder!)}',
            '${l.actRateVisit}: ${_rates.perVisit == null ? l.actRateNone : money(_rates.perVisit!)}',
          ].join(' · ');
    return SliverContent(
      sliver: SliverList.list(children: [
        AppGroup(children: [
          AppRow(
            leading: InitialsTile(_contractorName(_contractorId)),
            title: _contractorName(_contractorId),
            subtitle: l.actContractor,
            onTap: _pickContractor,
          ),
          AppRow(
            leading: const LeadingIcon(AppIcons.calendar),
            title: _monthLabel(l, _month),
            chevron: false,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              AppIconButton(
                  icon: AppIcons.chevronLeft,
                  label: l.actPrevMonth,
                  size: 32,
                  onPressed: () => _shiftMonth(-1)),
              AppIconButton(
                  icon: AppIcons.chevronRight,
                  label: l.actNextMonth,
                  size: 32,
                  onPressed: () => _shiftMonth(1)),
            ]),
          ),
          if (SchemaCompat.has('0021') != false)
            AppRow(
              leading: const LeadingIcon(AppIcons.money),
              title: l.actRates,
              subtitle: ratesLine,
              subtitleMaxLines: 2,
              chevron: _ctx?.isManager == true,
              onTap: _ctx?.isManager == true ? _editRates : null,
            ),
        ]),
        if (SchemaCompat.has('0021') == false)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpace.group),
            child: AppCard(
                child: Text(l.migrationNeeded('0021'), style: AppText.callout)),
          ),
        if (_loading && r == null)
          const Padding(
              padding: EdgeInsets.all(AppSpace.xl), child: AppLoader())
        else if (_failed)
          AppEmptyState(
              text: l.actLoadFailed,
              error: true,
              actionLabel: l.commonRetry,
              onAction: _load)
        else if (r != null) ...[
          LayoutBuilder(builder: (context, box) {
            final tiles = [
              KpiTile(
                  value: '${r.paid.length}',
                  label: l.actKpiPaid,
                  valueColor: AppColors.accentText,
                  hint: r.sum == null ? null : money(r.sum!)),
              KpiTile(
                  value: '${r.rejected.length}',
                  label: l.actKpiRejected,
                  valueColor: r.rejected.isEmpty ? null : AppColors.danger),
              KpiTile(
                  value:
                      r.provenShare == null ? '—' : pct.format(r.provenShare),
                  label: l.actKpiShare),
              KpiTile(value: '${r.overdue}', label: l.actKpiOverdue),
            ];
            final perRow = box.maxWidth >= 600 ? 4 : 2;
            return Column(children: [
              for (var i = 0; i < tiles.length; i += perRow) ...[
                if (i > 0) const SizedBox(height: AppSpace.group),
                IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var j = i;
                            j < i + perRow && j < tiles.length;
                            j++) ...[
                          if (j > i) const SizedBox(width: AppSpace.group),
                          Expanded(child: tiles[j]),
                        ],
                      ]),
                ),
              ],
            ]);
          }),
          if (r.total == 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpace.l),
              child: AppEmptyState(icon: AppIcons.act, text: l.actNoOrders),
            )
          else ...[
            AppGroup(
              header: l.actPaidTitle(r.paid.length),
              footer:
                  r.sum == null ? l.actNoRates : l.actSumLine(money(r.sum!)),
              separatorInset: AppSpace.separatorInsetIcon,
              children: [for (final x in r.paid) _line(l, x)],
            ),
            if (r.rejected.isNotEmpty)
              AppGroup(
                header: l.actRejectedTitle(r.rejected.length),
                separatorInset: AppSpace.separatorInsetIcon,
                children: [for (final x in r.rejected) _line(l, x)],
              ),
          ],
          if (_acts.isNotEmpty)
            AppGroup(
              header: l.actHistory,
              separatorInset: AppSpace.separatorInsetIcon,
              children: [
                for (final a in _acts)
                  AppRow(
                    leading: a.replaced
                        ? const LeadingIcon.neutral(AppIcons.fileText)
                        : const LeadingIcon(AppIcons.fileCheck),
                    title: a.replaced
                        ? '${a.number} · ${l.actReplaced}'
                        : a.number,
                    subtitle: [
                      l.actHistoryRow(
                          _monthLabel(l, a.periodStart), a.paid, a.rejected),
                      if (a.sum != null)
                        actMoney(l.localeName, a.sum!, a.currency ?? cur),
                      l.dateTime(a.createdAt.toLocal()),
                      if (a.authorName != null) a.authorName!,
                    ].join(' · '),
                    subtitleMaxLines: 3,
                    onTap: a.pdfPath == null ? null : () => _openPdf(a),
                  ),
              ],
            ),
        ],
      ]),
    );
  }

  Widget _line(AppLocalizations l, ActLine x) {
    final o = x.order;
    final date = DateFormat.MMMd(l.localeName).format(o.date);
    final proofs = <Widget>[
      if (x.photoProof) const _Proof(AppIcons.camera),
      if (x.geoProof) const _Proof(AppIcons.place),
      if (x.checklistProof) const _Proof(AppIcons.check),
    ];
    final reasons = [for (final r in x.reasons) actReasonText(l, r)].join(', ');
    return AppRow(
      leading: x.payable
          ? const LeadingIcon(AppIcons.success)
          : const LeadingIcon.danger(AppIcons.warning),
      title: o.title,
      subtitle: [
        date,
        _objectName(o.objectId),
        if (o.overdue) l.actOverdue,
        if (!x.payable) reasons,
      ].join(' · '),
      subtitleMaxLines: 3,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        ...proofs,
        if (x.amount != null) ...[
          const SizedBox(width: AppSpace.s),
          Text(actMoney(l.localeName, x.amount!, _rates.currency),
              style: AppText.callout.copyWith(fontWeight: FontWeight.w600)),
        ],
      ]),
      onTap: () => _openOrder(o),
    );
  }
}

/// Значок доказательства: 📷 фото, 📍 геозона, ✓ чек-лист.
class _Proof extends StatelessWidget {
  const _Proof(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: AppSpace.xs),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
              color: AppColors.accentTint,
              borderRadius: BorderRadius.circular(AppRadius.iconTile)),
          child: Icon(icon, size: 14, color: AppColors.accentText),
        ),
      );
}
