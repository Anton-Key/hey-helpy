import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../reports/report_pdf.dart';
import 'act_doc.dart';

/// PDF акта подрядчику (шаг 24): A4, тем же механизмом и шрифтом Onest, что
/// PDF-отчёты. Загружается отложенно (`deferred as actpdf`) вместе с пакетами
/// pdf / printing. Сборка — чистая функция [buildActPdf] (тест
/// test/act_pdf_test.dart).

class _C {
  static const ink = PdfColor.fromInt(0xFF0F1A17);
  static const secondary = PdfColor.fromInt(0xFF5B6763);
  static const separator = PdfColor.fromInt(0xFFE6EAE8);
  static const accentText = PdfColor.fromInt(0xFF0B7A62);
  static const accentTint = PdfColor.fromInt(0xFFE2F4EF);
  static const danger = PdfColor.fromInt(0xFFB42318);
  static const dangerTint = PdfColor.fromInt(0xFFFDE8E6);
  static const headerFill = PdfColor.fromInt(0xFFF2F4F3);
}

Future<({Uint8List bytes, int pages})> buildActPdf(
    ActDoc d, ReportPdfFonts fonts) async {
  final l = d.l;
  final base = pw.TextStyle(
      font: fonts.regular, fontBold: fonts.bold, fontSize: 8.5, color: _C.ink);
  final small = base.copyWith(fontSize: 7.5, color: _C.secondary);
  final bold = base.copyWith(font: fonts.bold);
  final th = bold.copyWith(fontSize: 7.5, color: _C.secondary);

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
    title: '${l.actPdfTitle} ${d.number}',
    author: d.author,
    creator: l.appName,
  );

  pw.Widget table(List<String> head, List<List<String>> rows,
      Map<int, pw.TableColumnWidth> widths,
      {Set<int> right = const {}, Set<int> alertRows = const {}}) {
    pw.Widget cell(String t, pw.TextStyle s, int c) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: pw.Text(t,
            style: s,
            textAlign:
                right.contains(c) ? pw.TextAlign.right : pw.TextAlign.left));
    return pw.Table(
      columnWidths: widths,
      border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _C.separator, width: 0.5),
          bottom: pw.BorderSide(color: _C.separator, width: 0.5)),
      children: [
        pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: _C.headerFill),
            children: [
              for (var i = 0; i < head.length; i++)
                cell(head[i].toUpperCase(), th, i)
            ]),
        for (var r = 0; r < rows.length; r++)
          pw.TableRow(children: [
            for (var c = 0; c < rows[r].length; c++)
              cell(
                  rows[r][c],
                  alertRows.contains(r) && c == rows[r].length - 1
                      ? base.copyWith(color: _C.danger)
                      : base,
                  c),
          ]),
      ],
    );
  }

  pw.Widget field(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child:
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: 80, child: pw.Text(k, style: small)),
          pw.Expanded(child: pw.Text(v, style: bold)),
        ]),
      );

  String withOverdue(ActDocRow r, String s) =>
      r.overdue ? (s.isEmpty ? l.actOverdue : '$s · ${l.actOverdue}') : s;

  final paidRows = [
    for (final r in d.paid)
      [
        '${r.no}',
        r.date,
        r.object,
        r.place,
        r.work,
        withOverdue(r, r.proofs),
        if (d.hasSums) r.amount,
      ]
  ];
  final rejectedRows = [
    for (final r in d.rejected) ['${r.no}', r.date, r.object, r.work, r.reasons]
  ];

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 36),
    footer: (ctx) => pw.Row(children: [
      pw.Expanded(
          child: pw.Text('${l.appName} · ${l.actsSlogan}', style: small)),
      pw.Text(l.actPdfPage(ctx.pageNumber, ctx.pagesCount), style: small),
    ]),
    build: (ctx) => [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(l.actPdfTitle, style: bold.copyWith(fontSize: 16)),
                pw.SizedBox(height: 2),
                pw.Text(l.actPdfNumberDate(d.number, d.issuedAt),
                    style: bold.copyWith(fontSize: 11, color: _C.accentText)),
              ]),
        ),
        pw.Text(l.appName,
            style: bold.copyWith(fontSize: 12, color: _C.accentText)),
      ]),
      pw.SizedBox(height: 10),
      field(l.actPdfCustomer, d.company),
      field(l.actPdfContractor, d.contractor),
      field(l.actPdfPeriod, d.period),
      field(l.actPdfIssuedBy, d.author),
      pw.SizedBox(height: 8),
      pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: const pw.BoxDecoration(
            color: _C.accentTint,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(d.totalLine, style: base),
              pw.SizedBox(height: 2),
              pw.Text(d.sumLine,
                  style: bold.copyWith(fontSize: 11, color: _C.accentText)),
            ]),
      ),
      pw.SizedBox(height: 12),
      pw.Text(l.actSheetPaid, style: bold.copyWith(fontSize: 11)),
      pw.SizedBox(height: 4),
      if (paidRows.isEmpty)
        pw.Text('—', style: small)
      else
        table(
            [
              l.actColNo,
              l.actColDate,
              l.actColObject,
              l.actColPlace,
              l.actColWork,
              l.actColProofs,
              if (d.hasSums) l.actColSum,
            ],
            paidRows,
            {
              0: const pw.FixedColumnWidth(18),
              1: const pw.FixedColumnWidth(42),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.6),
              4: const pw.FlexColumnWidth(3),
              5: const pw.FlexColumnWidth(1.8),
              if (d.hasSums) 6: const pw.FixedColumnWidth(58),
            },
            right: d.hasSums ? {6} : const {}),
      pw.SizedBox(height: 4),
      pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(d.sumLine, style: bold)),
      pw.SizedBox(height: 14),
      pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: const pw.BoxDecoration(
            color: _C.dangerTint,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Text(l.actPdfNotAccepted,
            style: bold.copyWith(fontSize: 11, color: _C.danger)),
      ),
      pw.SizedBox(height: 4),
      if (rejectedRows.isEmpty)
        pw.Text('—', style: small)
      else
        table(
            [
              l.actColNo,
              l.actColDate,
              l.actColObject,
              l.actColWork,
              l.actColReasons
            ],
            rejectedRows,
            {
              0: const pw.FixedColumnWidth(18),
              1: const pw.FixedColumnWidth(42),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(3),
              4: const pw.FlexColumnWidth(2.6),
            },
            alertRows: {for (var i = 0; i < rejectedRows.length; i++) i}),
      pw.SizedBox(height: 28),
      pw.Text(l.actPdfSigns, style: bold.copyWith(fontSize: 11)),
      pw.SizedBox(height: 16),
      pw.Row(children: [
        pw.Expanded(
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
              pw.Text(l.actPdfCustomer, style: small),
              pw.SizedBox(height: 18),
              pw.Text(l.actPdfSignLine, style: base),
              pw.Text(d.company, style: small),
            ])),
        pw.SizedBox(width: 24),
        pw.Expanded(
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
              pw.Text(l.actPdfContractor, style: small),
              pw.SizedBox(height: 18),
              pw.Text(l.actPdfSignLine, style: base),
              pw.Text(d.contractor, style: small),
            ])),
      ]),
    ],
  ));
  final bytes = await doc.save();
  return (bytes: bytes, pages: doc.document.pdfPageList.pages.length);
}

/// Отдать PDF: Android — «Поделиться», веб — окно печати (как отчёты).
Future<void> outputActPdf(Uint8List bytes, String name) =>
    outputReportPdf(bytes, name);

Future<ReportPdfFonts> loadActFonts() => loadReportFonts();
