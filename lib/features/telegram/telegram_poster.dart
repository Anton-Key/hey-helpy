import 'package:barcode/barcode.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/app_links.dart';
import '../../l10n/app_localizations.dart';
import '../reports/report_pdf.dart';

/// Плакат A4 с QR-кодом ссылки объекта (шаг 23): «Что-то сломалось?»,
/// название объекта, QR, три шага, имя бота. Язык — интерфейса.
/// Загружается отложенно (`deferred as poster`), как PDF отчёта.

class _C {
  static const ink = PdfColor.fromInt(0xFF0F1A17);
  static const secondary = PdfColor.fromInt(0xFF5B6763);
  static const accent = PdfColor.fromInt(0xFF2DB89A);
  static const onAccent = PdfColor.fromInt(0xFF062B23);
  static const mint = PdfColor.fromInt(0xFFD8F0EA);
}

/// Сборка плаката — чистая функция (тест: test/telegram_test.dart).
Future<Uint8List> buildPosterPdf({
  required AppLocalizations l,
  required ReportPdfFonts fonts,
  required String objectName,
  required String url,
}) async {
  final doc = pw.Document(title: '${l.appName} · $objectName');
  final theme = pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold);
  pw.Widget step(int n, String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.Row(children: [
          pw.Container(
            width: 30,
            height: 30,
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(
                color: _C.accent, shape: pw.BoxShape.circle),
            child: pw.Text('$n',
                style: pw.TextStyle(
                    color: _C.onAccent,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 16)),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
              child: pw.Text(text,
                  style: const pw.TextStyle(fontSize: 17, color: _C.ink))),
        ]),
      );
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.all(48),
    build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(l.appName,
            style: pw.TextStyle(
                fontSize: 16,
                color: _C.accent,
                fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 18),
        pw.Text(l.tgPosterTitle,
            style: pw.TextStyle(
                fontSize: 44, fontWeight: pw.FontWeight.bold, color: _C.ink)),
        pw.SizedBox(height: 6),
        pw.Text(objectName,
            style: const pw.TextStyle(fontSize: 20, color: _C.secondary)),
        pw.SizedBox(height: 28),
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: _C.mint, width: 6),
                borderRadius: pw.BorderRadius.circular(18)),
            child: pw.BarcodeWidget(
                barcode: Barcode.qrCode(
                    errorCorrectLevel: BarcodeQRCorrectionLevel.medium),
                data: url,
                drawText: false,
                width: 260,
                height: 260,
                color: _C.ink),
          ),
        ),
        pw.SizedBox(height: 28),
        step(1, l.tgPosterStep1),
        step(2, l.tgPosterStep2),
        step(3, l.tgPosterStep3),
        pw.Spacer(),
        pw.Text(l.tgPosterFooter(kTelegramBot),
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 13, color: _C.secondary)),
      ],
    ),
  ));
  return doc.save();
}

/// Плакат → печать (веб) или «Поделиться» (Android).
Future<void> printPoster(
    AppLocalizations l, String objectName, String url) async {
  final fonts = await loadReportFonts();
  final bytes = await buildPosterPdf(
      l: l, fonts: fonts, objectName: objectName, url: url);
  await outputReportPdf(bytes, 'hey-helpy-qr.pdf');
}
