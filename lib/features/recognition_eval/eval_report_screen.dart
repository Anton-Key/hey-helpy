import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/file_share.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import '../equipment/equipment_kinds.dart';
import 'eval_labels.dart';
import 'eval_models.dart';
import 'eval_pdf.dart' deferred as pdf;
import 'eval_repository.dart';

/// Результаты прогона (шаг 34): Top-1 с интервалом и n, Top-3, вид, ложные
/// «узнавания», пороги уверенности, разбивки, время, примеры ошибок;
/// «Скачать отчёт (PDF)» и «Скачать данные (CSV)». Цифры считает функция
/// recognition-eval по записанным результатам — приложение их только
/// показывает.
class EvalReportScreen extends StatefulWidget {
  const EvalReportScreen(
      {super.key,
      required this.runId,
      required this.repo,
      required this.companyName});
  final String runId;
  final EvalRepository repo;
  final String companyName;

  @override
  State<EvalReportScreen> createState() => _EvalReportScreenState();
}

class _EvalReportScreenState extends State<EvalReportScreen> {
  EvalReport? _r;
  bool _failed = false;
  bool _pdfBusy = false;
  final Map<String, Future<Uint8List?>> _thumbs = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final r = await widget.repo.report(widget.runId);
      if (!mounted) return;
      setState(() {
        _r = r;
        _failed = r == null;
      });
    } catch (e) {
      debugPrint('eval report: ${e.runtimeType}');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<Uint8List?> _thumb(String path) =>
      _thumbs.putIfAbsent(path, () => widget.repo.photo(path));

  Future<void> _csv() async {
    final r = _r;
    if (r == null) return;
    final now = DateTime.now();
    try {
      await saveOrShareBytes(
        bytes: Uint8List.fromList(utf8.encode(evalCsv(r, generatedAt: now))),
        fileName: evalReportFileName(now, 'csv'),
        mime: 'text/csv',
      );
    } catch (e) {
      debugPrint('eval csv: ${e.runtimeType}');
      if (mounted) {
        showAppMessage(context, context.l10n.evalReportFailed,
            type: AppMessageType.error);
      }
    }
  }

  Future<void> _pdf() async {
    final r = _r;
    if (r == null) return;
    final l = context.l10n;
    setState(() => _pdfBusy = true);
    try {
      await pdf.loadLibrary();
      final fonts = await pdf.loadReportFonts();
      final thumbs = <String, Uint8List>{};
      for (final e in r.examples.take(6)) {
        final b = await _thumb(e.photoPath);
        if (b != null) thumbs[e.sampleId] = b;
      }
      final now = DateTime.now();
      final bytes = await pdf.buildEvalPdf(
          l: l,
          r: r,
          company: widget.companyName,
          generatedAt: now,
          fonts: fonts,
          thumbs: thumbs);
      await pdf.outputReportPdf(bytes, evalReportFileName(now, 'pdf'));
    } catch (e) {
      debugPrint('eval pdf: ${e.runtimeType}');
      if (mounted) {
        showAppMessage(context, l.evalReportFailed, type: AppMessageType.error);
      }
    }
    if (mounted) setState(() => _pdfBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = _r;
    return AppScaffold(
      title: l.evalReportTitle,
      onRefresh: _load,
      bottomBar: r == null
          ? null
          : BottomActionBar(
              child: Row(children: [
                Expanded(
                  child: AppButton.secondary(
                      icon: AppIcons.fileSheet,
                      label: l.evalDownloadCsv,
                      onPressed: _csv),
                ),
                const SizedBox(width: AppSpace.s),
                Expanded(
                  child: AppButton.primary(
                      icon: AppIcons.download,
                      label: l.evalDownloadPdf,
                      loading: _pdfBusy,
                      onPressed: _pdfBusy ? null : _pdf),
                ),
              ]),
            ),
      slivers: [
        if (r == null && !_failed)
          const SliverFillRemaining(hasScrollBody: false, child: AppLoader())
        else if (r == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
                text: l.evalReportFailed,
                error: true,
                actionLabel: l.commonRetry,
                onAction: _load),
          )
        else
          SliverContent(sliver: SliverList.list(children: _body(l, r))),
        const SliverBottomInset(),
      ],
    );
  }

  String _kind(AppLocalizations l, String k) =>
      k == 'unknown' ? l.evalUnknownKind : equipmentKindLabel(l, k);

  List<Widget> _body(AppLocalizations l, EvalReport r) {
    final frozen = r.run.setFrozenAt;
    final footnote = r.run.split == 'test' && frozen != null
        ? l.evalFootnote(l.date(frozen.toLocal()))
        : l.evalFootnoteDev;
    final hash = r.run.promptHash ?? '—';
    Widget rate(IconData icon, String title, EvalRate x, {String? hint}) =>
        AppRow(
          leading: LeadingIcon(icon),
          title: title,
          subtitle: [
            evalRateText(x),
            '${x.k} / ${x.n}',
            if (hint != null) hint,
          ].join(' · '),
          subtitleMaxLines: 3,
          chevron: false,
        );
    return [
      AppGroup(footer: footnote, children: [
        AppRow(
          leading: const LeadingIcon(AppIcons.verified),
          title: r.headline,
          titleStyle: AppText.headline,
          subtitle: [
            l.evalRunRow(r.run.split, l.dateTime(r.run.createdAt)),
            l.evalRunMeta(r.run.provider ?? '—', r.run.model ?? '—',
                hash.length > 12 ? hash.substring(0, 12) : hash),
          ].join('\n'),
          subtitleMaxLines: 4,
          chevron: false,
        ),
      ]),
      AppGroup(children: [
        rate(AppIcons.check, l.evalTop1, r.top1),
        rate(AppIcons.list, l.evalTop3, r.top3),
        rate(AppIcons.eqOther, l.evalKind, r.kind),
        rate(AppIcons.warning, l.evalFalse, r.falseRecognition,
            hint: l.evalFalseHint),
        AppRow(
          leading: const LeadingIcon(AppIcons.error),
          title: l.evalErrorsLine(r.errors, r.missing),
          chevron: false,
        ),
      ]),
      AppGroup(header: l.evalComposition, children: [
        AppRow(
          title: l.evalSampleLine(r.photos, r.units, r.rooms, r.sites),
          subtitle: '${l.evalNotInRegistry}: ${r.unregistered}',
          chevron: false,
        ),
        for (final e in r.kinds.entries)
          AppRow(
              leading: LeadingIcon(assetIcon(e.key, 'equipment')),
              title: _kind(l, e.key),
              value: '${e.value}',
              chevron: false),
      ]),
      AppGroup(
        header: l.evalThresholds,
        footer: l.evalThresholdHint,
        children: [
          for (final t in r.thresholds)
            AppRow(
              title: t.threshold == 0
                  ? l.evalThresholdAny
                  : l.evalThresholdRow(t.threshold.toStringAsFixed(2)),
              subtitle: l.evalThresholdLine(evalRateText(t.coverage),
                  evalRateText(t.accuracy), evalRateText(t.falseRecognition)),
              subtitleMaxLines: 4,
              chevron: false,
            ),
        ],
      ),
      for (final (key, header, group) in [
        ('by_kind', l.evalByKind, ''),
        ('by_similar', l.evalBySimilar, 'similar'),
        ('by_light', l.evalByLight, 'light'),
        ('by_distance', l.evalByDistance, 'distance'),
        ('by_angle', l.evalByAngle, 'angle'),
        ('by_occlusion', l.evalByOcclusion, 'occlusion'),
      ])
        if ((r.groups[key] ?? const []).isNotEmpty)
          AppGroup(header: header, children: [
            for (final g in r.groups[key]!)
              AppRow(
                title: key == 'by_kind'
                    ? _kind(l, g.key)
                    : evalConditionLabel(l, group, g.key),
                subtitle: l.evalGroupLine(
                    evalRateText(g.top1), evalPct(g.top3.p), g.top1.n),
                subtitleMaxLines: 3,
                chevron: false,
              ),
          ]),
      AppGroup(header: l.evalSpeed, children: [
        AppRow(
          leading: const LeadingIcon(AppIcons.clock),
          title: l.evalLatency(
              '${r.latencyMedian ?? '—'}', '${r.latencyP95 ?? '—'}'),
          subtitle:
              r.tokensMedian == null ? null : l.evalTokens('${r.tokensMedian}'),
          chevron: false,
        ),
        AppRow(
          leading: const LeadingIcon(AppIcons.money),
          title: r.costPerPhoto == null
              ? l.evalCostNone
              : l.evalCost(r.costPerPhoto!.toStringAsFixed(4)),
          chevron: false,
        ),
      ]),
      AppGroup(header: l.evalExamples, children: [
        if (r.examples.isEmpty)
          AppRow(title: l.evalNoExamples, chevron: false)
        else
          for (final e in r.examples)
            AppRow(
              leading: _Thumb(bytes: _thumb(e.photoPath)),
              title: switch (e.exampleType) {
                'false_recognition' =>
                  l.evalExampleFalse(r.name(e.predictedId)),
                'error' => l.evalExampleError,
                _ => l.evalExampleWrong(
                    r.name(e.trueEquipmentId),
                    e.predictedId == null
                        ? l.evalExampleNone
                        : r.name(e.predictedId)),
              },
              subtitle: [
                r.name(e.roomId),
                evalConditionLabel(l, 'light', e.light),
                evalConditionLabel(l, 'distance', e.distance),
                evalConditionLabel(l, 'angle', e.angle),
              ].join(' · '),
              subtitleMaxLines: 3,
              chevron: false,
            ),
      ]),
    ];
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.bytes});
  final Future<Uint8List?> bytes;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.iconTile),
        child: SizedBox(
          width: 64,
          height: 48,
          child: FutureBuilder(
            future: bytes,
            builder: (_, snap) => snap.data == null
                ? const ColoredBox(color: AppColors.fill)
                : Image.memory(snap.data!, fit: BoxFit.cover),
          ),
        ),
      );
}
