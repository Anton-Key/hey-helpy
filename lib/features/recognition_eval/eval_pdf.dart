import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../l10n/app_localizations.dart';
import '../equipment/equipment_kinds.dart';
import '../reports/report_pdf.dart';
import 'eval_labels.dart';
import 'eval_models.dart';

export '../reports/report_pdf.dart' show loadReportFonts, outputReportPdf;

/// PDF отчёта теста распознавания для инвестора (шаг 34): главная цифра
/// Top-1 с интервалом и размером выборки, дата, поставщик, модель, версия
/// подсказки, состав набора, таблица порогов, 6 примеров ошибок с
/// миниатюрами (только своей компании), строка о честном замере. Язык — язык
/// интерфейса (английский по умолчанию). Грузится отложенно (пакет pdf).
class _C {
  static const ink = PdfColor.fromInt(0xFF0F1A17);
  static const secondary = PdfColor.fromInt(0xFF5B6763);
  static const separator = PdfColor.fromInt(0xFFE6EAE8);
  static const accentText = PdfColor.fromInt(0xFF0B7A62);
  static const accentTint = PdfColor.fromInt(0xFFE2F4EF);
  static const headerFill = PdfColor.fromInt(0xFFF2F4F3);
}

Future<Uint8List> buildEvalPdf({
  required AppLocalizations l,
  required EvalReport r,
  required String company,
  required DateTime generatedAt,
  required ReportPdfFonts fonts,
  required Map<String, Uint8List> thumbs,
}) async {
  final when = DateFormat.yMMMd(l.localeName).add_Hm();
  final day = DateFormat.yMMMd(l.localeName);
  final base = pw.TextStyle(
      font: fonts.regular, fontBold: fonts.bold, fontSize: 9, color: _C.ink);
  final small = base.copyWith(fontSize: 7.5, color: _C.secondary);
  final bold = base.copyWith(font: fonts.bold);
  final h2 = bold.copyWith(fontSize: 11);

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
    title: l.evalPdfTitle,
    creator: l.appName,
  );

  pw.Widget table(List<String> head, List<List<String>> rows) => pw.Table(
        border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(color: _C.separator, width: 0.5),
            bottom: pw.BorderSide(color: _C.separator, width: 0.5)),
        children: [
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: _C.headerFill),
            children: [
              for (final h in head)
                pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text(h.toUpperCase(),
                        style: small.copyWith(font: fonts.bold))),
            ],
          ),
          for (final row in rows)
            pw.TableRow(children: [
              for (final c in row)
                pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text(c, style: base)),
            ]),
        ],
      );

  String counts(Map<String, int> m, String group) => m.entries
      .map((e) => '${evalConditionLabel(l, group, e.key)} ${e.value}')
      .join(' · ');
  String kindName(String k) => switch (k) {
        kEvalUnregisteredKey => l.evalNotInRegistry,
        'unknown' => l.evalUnknownKind,
        _ => equipmentKindLabel(l, k),
      };

  final thresholdRows = [
    for (final t in r.thresholds)
      [
        t.threshold == 0 ? '0' : t.threshold.toStringAsFixed(2),
        evalRateText(t.coverage),
        evalRateText(t.accuracy),
        evalRateText(t.falseRecognition),
      ]
  ];

  pw.Widget example(EvalRow e) {
    final img = thumbs[e.sampleId];
    final text = switch (e.exampleType) {
      'false_recognition' => l.evalExampleFalse(r.name(e.predictedId)),
      'error' => l.evalExampleError,
      _ => l.evalExampleWrong(r.name(e.trueEquipmentId),
          e.predictedId == null ? l.evalExampleNone : r.name(e.predictedId)),
    };
    return pw.Container(
      width: 165,
      margin: const pw.EdgeInsets.only(right: 6, bottom: 6),
      child:
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          height: 110,
          width: 165,
          color: _C.headerFill,
          child: img == null
              ? null
              : pw.Image(pw.MemoryImage(img), fit: pw.BoxFit.cover),
        ),
        pw.SizedBox(height: 3),
        pw.Text(text, style: base.copyWith(fontSize: 8)),
        pw.Text(
            [
              r.name(e.roomId),
              evalConditionLabel(l, 'light', e.light),
              evalConditionLabel(l, 'distance', e.distance),
              evalConditionLabel(l, 'angle', e.angle),
            ].join(' · '),
            style: small),
      ]),
    );
  }

  final footnote = r.run.split == 'test' && r.run.setFrozenAt != null
      ? l.evalFootnote(day.format(r.run.setFrozenAt!.toLocal()))
      : l.evalFootnoteDev;

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 36),
    footer: (ctx) =>
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Expanded(child: pw.Text(footnote, style: small)),
      pw.Text(l.evalPdfPage(ctx.pageNumber, ctx.pagesCount), style: small),
    ]),
    build: (ctx) => [
      pw.Text(l.appName, style: small.copyWith(color: _C.accentText)),
      pw.Text(l.evalPdfTitle, style: bold.copyWith(fontSize: 18)),
      pw.Text(l.evalPdfGenerated(company, when.format(generatedAt)),
          style: small),
      pw.SizedBox(height: 10),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: const pw.BoxDecoration(
            color: _C.accentTint,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(r.headline, style: bold.copyWith(fontSize: 13)),
              pw.SizedBox(height: 4),
              pw.Text('${l.evalTop3}: ${evalRateText(r.top3)}', style: base),
              pw.Text('${l.evalKind}: ${evalRateText(r.kind)}', style: base),
              pw.Text(
                  '${l.evalFalse}: ${evalRateText(r.falseRecognition)} — ${l.evalFalseHint}',
                  style: base),
              pw.Text(l.evalErrorsLine(r.errors, r.missing), style: small),
            ]),
      ),
      pw.SizedBox(height: 6),
      pw.Text(
          l.evalRunMeta(
              r.run.provider ?? '—',
              r.run.model ?? '—',
              (r.run.promptHash ?? '—')
                  .substring(0, (r.run.promptHash ?? '—').length.clamp(0, 12))),
          style: small),
      pw.Text(
          '${r.run.split} · ${when.format(r.run.createdAt.toLocal())}'
          '${r.run.setFrozenAt != null ? ' · ${l.evalSetFrozen(day.format(r.run.setFrozenAt!.toLocal()))}' : ''}',
          style: small),
      pw.SizedBox(height: 12),
      pw.Text(l.evalComposition, style: h2),
      pw.SizedBox(height: 4),
      pw.Text(
          '${l.evalSampleLine(r.photos, r.units, r.rooms, r.sites)}'
          ' · ${l.evalNotInRegistry}: ${r.unregistered}',
          style: base),
      pw.Text(
          r.kinds.entries
              .map((e) => '${kindName(e.key)} ${e.value}')
              .join(' · '),
          style: base),
      for (final g in ['light', 'distance', 'angle', 'occlusion'])
        if (r.conditions[g] case final m? when m.isNotEmpty)
          pw.Text(counts(m, g), style: small),
      pw.SizedBox(height: 12),
      pw.Text(l.evalThresholds, style: h2),
      pw.SizedBox(height: 4),
      table([
        l.evalPdfThreshold,
        l.evalPdfAnswers,
        l.evalPdfAccuracy,
        l.evalFalse,
      ], thresholdRows),
      pw.SizedBox(height: 3),
      pw.Text(l.evalThresholdHint, style: small),
      pw.SizedBox(height: 12),
      pw.Text(l.evalBreakdown, style: h2),
      pw.SizedBox(height: 4),
      table([
        l.evalBreakdown,
        'Top-1',
        'Top-3',
      ], [
        for (final key in EvalReport.groupKeys)
          for (final g in r.groups[key] ?? const <EvalGroup>[])
            [
              key == 'by_kind'
                  ? kindName(g.key)
                  : evalConditionLabel(
                      l,
                      switch (key) {
                        'by_similar' => 'similar',
                        'by_light' => 'light',
                        'by_distance' => 'distance',
                        'by_angle' => 'angle',
                        _ => 'occlusion',
                      },
                      g.key),
              '${evalPct(g.top1.p)} (${g.top1.k}/${g.top1.n})',
              '${evalPct(g.top3.p)} (${g.top3.k}/${g.top3.n})',
            ]
      ]),
      pw.SizedBox(height: 12),
      pw.Text(l.evalSpeed, style: h2),
      pw.Text(
          l.evalLatency('${r.latencyMedian ?? '—'}', '${r.latencyP95 ?? '—'}'),
          style: base),
      if (r.tokensMedian != null)
        pw.Text(l.evalTokens('${r.tokensMedian}'), style: base),
      pw.Text(
          r.costPerPhoto == null
              ? l.evalCostNone
              : l.evalCost(r.costPerPhoto!.toStringAsFixed(4)),
          style: base),
      pw.SizedBox(height: 12),
      pw.Text(l.evalExamples, style: h2),
      pw.SizedBox(height: 4),
      if (r.examples.isEmpty)
        pw.Text(l.evalNoExamples, style: base)
      else
        pw.Wrap(children: [for (final e in r.examples.take(6)) example(e)]),
      pw.SizedBox(height: 8),
      pw.Text(l.evalPdfDefinitions, style: small),
      pw.Text(footnote, style: small),
    ],
  ));
  return doc.save();
}
