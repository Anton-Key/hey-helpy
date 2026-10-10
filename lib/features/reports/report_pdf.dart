import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import 'report_repository.dart';

/// PDF отчёта (шаг 16, блок E): A4 книжная, шапка «Эй, Helpy» с компанией,
/// периодом, фильтрами словами и «Сформирован: …», показатели, таблицы
/// «По регионам» и «По подрядчикам», список заявок. Номера страниц
/// «стр. 2 из 5», шапки таблиц повторяются на каждой новой странице.
/// Все строки — из переводов (английский интерфейс → английский PDF).
/// Сборка — чистая функция [buildReportPdf] (тесты: test/report_pdf_test.dart).

/// Цвета документа — в одном месте, как токены бренда (lib/core/design/tokens.dart).
class _Pdf {
  static const ink = PdfColor.fromInt(0xFF0F1A17);
  static const secondary = PdfColor.fromInt(0xFF5B6763);
  static const separator = PdfColor.fromInt(0xFFE6EAE8);
  static const accent = PdfColor.fromInt(0xFF2DB89A);
  static const accentText = PdfColor.fromInt(0xFF0B7A62);
  static const accentTint = PdfColor.fromInt(0xFFE2F4EF);
  static const danger = PdfColor.fromInt(0xFFB42318);
  static const headerFill = PdfColor.fromInt(0xFFF2F4F3);
}

/// Шрифты PDF: Onest из assets/fonts (кириллица; обычный и полужирный).
class ReportPdfFonts {
  const ReportPdfFonts({required this.regular, required this.bold});
  final pw.Font regular;
  final pw.Font bold;
}

/// Загрузка файла шрифта по пути ассета. В приложении — rootBundle,
/// в тестах — чтение файла с диска.
typedef FontBytesLoader = Future<ByteData> Function(String asset);

Future<ReportPdfFonts> loadReportFonts([FontBytesLoader? load]) async {
  final l = load ?? rootBundle.load;
  final regular = await l('assets/fonts/Onest-Regular.ttf');
  final bold = await l('assets/fonts/Onest-SemiBold.ttf');
  return ReportPdfFonts(regular: pw.Font.ttf(regular), bold: pw.Font.ttf(bold));
}

/// Всё, что нужно документу; подписи уже переведены ([l] — язык интерфейса).
class ReportPdfData {
  const ReportPdfData({
    required this.l,
    required this.report,
    required this.company,
    required this.author,
    required this.generatedAt,
    required this.periodLabel,
    required this.filters,
    required this.regions,
    required this.byRegion,
    required this.contractorName,
    required this.objectName,
    required this.placeName,
    required this.layerName,
    this.now,
  });

  final AppLocalizations l;
  final Report report;
  final String? company;
  final String? author;
  final DateTime generatedAt;
  final String periodLabel;

  /// Фильтры словами: «Объект: Москва · Офис 1», «Тип: ППР». Пусто — без фильтров.
  final List<String> filters;

  /// Строки «По регионам» (или по городам — если регионов нет, [byRegion] = false).
  final List<RegionReport> regions;
  final bool byRegion;

  final String Function(String? contractorId) contractorName;
  final String Function(String? objectId) objectName;
  final String Function(String? locationId) placeName;
  final String Function(ReportOrder order) layerName;

  /// «Сейчас» для просрочки (тесты); по умолчанию — время формирования.
  final DateTime? now;
}

/// Короткий номер заявки для таблицы: последние 6 знаков id («#00A1B2»).
/// Последние, а не первые: у случайных id они так же различаются, а у
/// заявок с постоянными id (демо: de300000-…-000000000101) первые совпадают.
String reportOrderNumber(String id) {
  final hex = id.replaceAll('-', '');
  final n = hex.length < 6 ? hex.length : 6;
  return '#${hex.substring(hex.length - n).toUpperCase()}';
}

/// Имя файла: «HeyHelpy_Отчёт_2026-09-10_2026-10-09.pdf».
String reportPdfFileName(
    AppLocalizations l, DateTime from, DateTime toExclusive) {
  final f = DateFormat('yyyy-MM-dd');
  final last = toExclusive.subtract(const Duration(days: 1));
  return l.pdfFileName('${f.format(from)}_${f.format(last)}');
}

/// Собирает PDF. Возвращает байты и число страниц.
Future<({Uint8List bytes, int pages})> buildReportPdf(
    ReportPdfData d, ReportPdfFonts fonts) async {
  final l = d.l;
  final now = d.now ?? d.generatedAt;
  final num = NumberFormat.decimalPattern(l.localeName);
  final pct = NumberFormat.percentPattern(l.localeName);
  // Короткая дата («21.09.26») — чтобы столбцы даты и срока не переносились.
  final date = DateFormat(l.localeName == 'en' ? 'MM/dd/yy' : 'dd.MM.yy');
  final dateTime = DateFormat.yMMMd(l.localeName).add_Hm();
  String share(double? v) => v == null ? l.reportsNoValue : pct.format(v);
  String count(int n) => num.format(n);

  final base = pw.TextStyle(
      font: fonts.regular,
      fontBold: fonts.bold,
      fontSize: 8.5,
      color: _Pdf.ink);
  final small = base.copyWith(fontSize: 7.5, color: _Pdf.secondary);
  final bold = base.copyWith(font: fonts.bold);
  final h1 = bold.copyWith(fontSize: 16);
  final h2 = bold.copyWith(fontSize: 11);
  final th = bold.copyWith(fontSize: 7.5, color: _Pdf.secondary);

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
    title: l.pdfTitle,
    author: d.author ?? '',
    creator: l.appName,
  );

  // Таблица: первая строка — шапка, повторяется на каждой новой странице.
  pw.Widget table(List<String> head, List<List<String>> rows,
      {Map<int, pw.TableColumnWidth>? widths,
      Set<int> numeric = const {},
      bool Function(int row, int col)? alert}) {
    pw.Widget cell(String text, pw.TextStyle style, int col) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Text(text,
              style: style,
              textAlign: numeric.contains(col)
                  ? pw.TextAlign.right
                  : pw.TextAlign.left),
        );
    return pw.Table(
      columnWidths: widths,
      border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _Pdf.separator, width: 0.5),
          bottom: pw.BorderSide(color: _Pdf.separator, width: 0.5)),
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: _Pdf.headerFill),
          children: [
            for (var i = 0; i < head.length; i++)
              cell(head[i].toUpperCase(), th, i)
          ],
        ),
        for (var r = 0; r < rows.length; r++)
          pw.TableRow(children: [
            for (var c = 0; c < rows[r].length; c++)
              cell(
                  rows[r][c],
                  alert != null && alert(r, c)
                      ? base.copyWith(color: _Pdf.danger, font: fonts.bold)
                      : base,
                  c),
          ]),
      ],
    );
  }

  final c = d.report.company;
  final ppr = d.report.pprAvailable && c.pprTotal > 0
      ? l.reportPprOf(count(c.pprDone), count(c.pprTotal))
      : l.reportsNoValue;
  final kpis = <(String, String)>[
    (count(c.total), l.reportsKpiRequests),
    (share(c.onTimeShare), l.reportsKpiOnTime),
    (share(c.firstPassShare), l.reportsKpiFirstPass),
    (share(c.geofenceShare), l.reportsKpiGeofence),
    (ppr, l.reportPprDone),
  ];

  pw.Widget kpiTile((String, String) k) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.symmetric(horizontal: 2),
          padding: const pw.EdgeInsets.all(6),
          decoration: const pw.BoxDecoration(
              color: _Pdf.accentTint,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(k.$1,
                    style: bold.copyWith(fontSize: 14, color: _Pdf.accentText)),
                pw.SizedBox(height: 2),
                pw.Text(k.$2, style: small),
              ]),
        ),
      );

  // По регионам: заявки, в срок, просрочено, ППР.
  final regionRows = [
    for (final r in d.regions)
      [
        r.label ?? (d.byRegion ? l.reportNoRegion : l.reportNoCity),
        count(r.stats.total),
        share(r.stats.onTimeShare),
        count(r.stats.overdue),
        d.report.pprAvailable && r.stats.pprTotal > 0
            ? l.reportPprOf(count(r.stats.pprDone), count(r.stats.pprTotal))
            : l.reportsNoValue,
      ],
  ];

  final contractorRows = [
    for (final r in d.report.contractors)
      [
        d.contractorName(r.contractorId),
        count(r.stats.total),
        count(r.stats.accepted),
        count(r.stats.returned),
        count(r.stats.overdue),
        share(r.stats.onTimeShare),
        share(r.stats.firstPassShare),
        count(r.stats.visits),
      ],
  ];

  final orders = d.report.orders;
  final orderRows = [
    for (final o in orders)
      [
        reportOrderNumber(o.id),
        date.format(o.createdAt.toLocal()),
        d.objectName(o.objectId),
        d.placeName(o.locationId),
        d.layerName(o),
        d.contractorName(o.contractorId),
        o.isOverdue(now)
            ? '${l.status(o.status)} · ${l.statusOverdue}'
            : l.status(o.status),
        o.dueAt == null ? l.reportsNoValue : date.format(o.dueAt!.toLocal()),
      ],
  ];

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 36),
    header: (ctx) => ctx.pageNumber == 1
        ? pw.SizedBox()
        : pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 6),
            margin: const pw.EdgeInsets.only(bottom: 6),
            decoration: const pw.BoxDecoration(
                border: pw.Border(
                    bottom: pw.BorderSide(color: _Pdf.separator, width: 0.5))),
            child: pw.Row(children: [
              pw.Text(l.appName, style: bold.copyWith(color: _Pdf.accentText)),
              pw.Text('  ·  ${l.pdfTitle}  ·  ${d.periodLabel}', style: small),
            ]),
          ),
    footer: (ctx) =>
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(d.company ?? '', style: small),
      pw.Text(l.pdfPageOf('${ctx.pageNumber}', '${ctx.pagesCount}'),
          style: small),
    ]),
    build: (ctx) => [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(width: 6, height: 28, color: _Pdf.accent),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(l.appName,
                    style: bold.copyWith(color: _Pdf.accentText, fontSize: 10)),
                pw.Text(l.pdfTitle, style: h1),
              ]),
        ),
      ]),
      pw.SizedBox(height: 8),
      if ((d.company ?? '').isNotEmpty)
        pw.Text(l.pdfCompany(d.company!), style: base),
      pw.Text(l.pdfPeriod(d.periodLabel), style: base),
      pw.Text(
          l.pdfFilters(
              d.filters.isEmpty ? l.pdfNoFilters : d.filters.join('; ')),
          style: base),
      pw.Text(
          l.pdfGenerated(dateTime.format(d.generatedAt.toLocal()),
              d.author ?? l.reportsNoValue),
          style: small),
      pw.SizedBox(height: 12),
      pw.Row(children: [for (final k in kpis) kpiTile(k)]),
      if (regionRows.isNotEmpty) ...[
        pw.SizedBox(height: 14),
        pw.Text(d.byRegion ? l.reportByRegion : l.reportByCity, style: h2),
        pw.SizedBox(height: 4),
        table(
          [
            d.byRegion ? l.pdfColRegion : l.pdfColCity,
            l.reportsOrders,
            l.reportsOnTime,
            l.reportsOverdue,
            l.reportPprDone
          ],
          regionRows,
          widths: const {0: pw.FlexColumnWidth(3)},
          numeric: const {1, 2, 3, 4},
          alert: (r, col) => col == 3 && d.regions[r].stats.overdue > 0,
        ),
      ],
      pw.SizedBox(height: 14),
      pw.Text(l.reportsByContractor, style: h2),
      pw.SizedBox(height: 4),
      if (contractorRows.isEmpty)
        pw.Text(l.reportsEmpty, style: small)
      else
        table(
          [
            l.pdfColContractor,
            l.reportsOrders,
            l.reportsAccepted,
            l.reportsReturned,
            l.reportsOverdue,
            l.reportsOnTime,
            l.reportsFirstPass,
            l.reportsVisits
          ],
          contractorRows,
          widths: const {0: pw.FlexColumnWidth(3)},
          numeric: const {1, 2, 3, 4, 5, 6, 7},
          alert: (r, col) =>
              (col == 3 && d.report.contractors[r].stats.returned > 0) ||
              (col == 4 && d.report.contractors[r].stats.overdue > 0),
        ),
      pw.SizedBox(height: 14),
      pw.Text(l.pdfOrders, style: h2),
      pw.SizedBox(height: 4),
      if (orderRows.isEmpty)
        pw.Text(l.pdfOrdersEmpty, style: small)
      else
        table(
          [
            l.pdfColNumber,
            l.pdfColDate,
            l.pdfColObject,
            l.pdfColPlace,
            l.pdfColLayer,
            l.pdfColContractor,
            l.pdfColStatus,
            l.pdfColDue
          ],
          orderRows,
          widths: const {
            0: pw.FixedColumnWidth(44),
            1: pw.FixedColumnWidth(46),
            2: pw.FlexColumnWidth(2.2),
            3: pw.FlexColumnWidth(1.8),
            4: pw.FlexColumnWidth(1.2),
            5: pw.FlexColumnWidth(1.6),
            6: pw.FlexColumnWidth(1.5),
            7: pw.FixedColumnWidth(46),
          },
          alert: (r, col) => col == 6 && orders[r].isOverdue(now),
        ),
    ],
  ));

  final bytes = await doc.save();
  return (bytes: bytes, pages: doc.document.pdfPageList.pages.length);
}
