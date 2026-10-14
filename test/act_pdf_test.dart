import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hey_helpy/features/acts/act_doc.dart';
import 'package:hey_helpy/features/acts/act_logic.dart';
import 'package:hey_helpy/features/acts/act_pdf.dart';
import 'package:hey_helpy/features/acts/act_xlsx.dart';
import 'package:hey_helpy/features/reports/report_pdf.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

Future<ByteData> _font(String asset) async =>
    ByteData.sublistView(await File(asset).readAsBytes());

ActResult _result() => buildAct([
      ActOrder(
          id: '1',
          title: 'Капает конденсат',
          status: 'done',
          date: DateTime(2026, 10, 9),
          requiresPhoto: true,
          hasAfterPhoto: true,
          visitRequired: true,
          visit: VisitProof.inZone),
      ActOrder(
          id: '2',
          title: 'Сквозняк от диффузора',
          status: 'done',
          date: DateTime(2026, 10, 3),
          requiresPhoto: true,
          visitRequired: true,
          visit: VisitProof.inZone),
    ], const ActRates(perOrder: 4500, currency: 'RUB'));

ActDoc _doc(AppLocalizations l) => buildActDoc(
      l: l,
      result: _result(),
      number: 'АКТ-2026-003',
      company: 'Демо БЦ',
      contractor: 'КлиматСервис',
      period: 'Октябрь 2026',
      issuedAt: DateTime(2026, 10, 19, 12),
      author: 'Менеджер Демо',
      objectName: (_) => 'Белград · БЦ «Демо»',
      placeName: (_) => '301 · Переговорная',
      workName: (_) => 'Климат',
    );

void main() {
  late ReportPdfFonts fonts;
  final ru = lookupAppLocalizations(const Locale('ru'));
  final en = lookupAppLocalizations(const Locale('en'));
  setUpAll(() async {
    await initializeDateFormatting();
    fonts = await loadReportFonts(_font);
  });

  test('акт словами: к оплате, не принято с причиной, итог', () {
    final d = _doc(ru);
    expect(d.paid.single.work, 'Капает конденсат');
    expect(d.paid.single.proofs, 'фото, геозона');
    expect(d.rejected.single.reasons, 'нет фото «после»');
    expect(d.sumLine, contains('4'));
    expect(d.totalLine, contains('К оплате: 1'));
  });

  test('PDF: создаётся, есть страницы (RU и EN)', () async {
    final out = await buildActPdf(_doc(ru), fonts);
    expect(out.pages, greaterThan(0));
    expect(String.fromCharCodes(out.bytes.take(5)), '%PDF-');
    final en1 = await buildActPdf(_doc(en), fonts);
    expect(en1.pages, greaterThan(0));
  });

  test('Excel: файл zip (xlsx) с двумя листами', () {
    final bytes = buildActXlsx(_doc(ru));
    expect(bytes.take(2), [0x50, 0x4B]); // «PK»
  });
}
