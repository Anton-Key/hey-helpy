import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hey_helpy/features/reports/report_pdf.dart';
import 'package:hey_helpy/features/reports/report_repository.dart';
import 'package:hey_helpy/features/reports/reports_screen.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

Future<ByteData> _fontFromFile(String asset) async =>
    ByteData.sublistView(Uint8List.fromList(await File(asset).readAsBytes()));

ReportOrder _order(int i,
        {String status = 'done',
        String? object,
        String? plan,
        String? contractor = 'c1',
        DateTime? due,
        DateTime? accepted}) =>
    ReportOrder(
      id: 'de300000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
      title: 'Заявка $i',
      status: status,
      objectId: object ?? 'o${i % 3}',
      contractorId: contractor,
      planId: plan,
      locationId: 'l${i % 2}',
      workType: 'Климат',
      createdAt: DateTime.utc(2026, 9, 1).add(Duration(hours: i)),
      acceptedAt: accepted,
      dueAt: due,
    );

Report _report(List<ReportOrder> orders) => Report.build(
      query: ReportQuery(
          from: DateTime.utc(2026, 9, 1), to: DateTime.utc(2026, 10, 1)),
      orders: orders,
      visits: const [],
      norms: const [],
      contractorOrder: const ['c1', 'c2'],
      now: DateTime.utc(2026, 10, 10),
    );

ReportPdfData _data(AppLocalizations l, Report r,
        {List<RegionReport> regions = const []}) =>
    ReportPdfData(
      l: l,
      report: r,
      company: 'Демо БЦ',
      author: 'Менеджер Демо',
      generatedAt: DateTime.utc(2026, 10, 10, 9, 30),
      periodLabel: '1 сент. 2026 – 30 сент. 2026',
      filters: const ['Тип: ППР'],
      regions: regions,
      byRegion: true,
      contractorName: (id) => id ?? l.reportsNoContractor,
      objectName: (id) => 'Москва · Офис $id',
      placeName: (id) => id == null ? '—' : '305 · Переговорная',
      layerName: (o) => o.workType ?? '',
      now: DateTime.utc(2026, 10, 10),
    );

void main() {
  late ReportPdfFonts fonts;
  final ru = lookupAppLocalizations(const Locale('ru'));
  final en = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    await initializeDateFormatting();
    fonts = await loadReportFonts(_fontFromFile);
  });

  group('PDF отчёта', () {
    test('собирается из тестовых данных, страниц > 0, это PDF', () async {
      final r = _report([
        _order(1),
        _order(2, status: 'in_progress', due: DateTime.utc(2026, 9, 5)),
        _order(3, plan: 'p1'),
        _order(4, plan: 'p1', status: 'assigned', contractor: null),
      ]);
      final out = await buildReportPdf(_data(ru, r), fonts);
      expect(out.pages, greaterThan(0));
      expect(String.fromCharCodes(out.bytes.take(5)), '%PDF-');
    });

    test('500 заявок разбиваются на несколько страниц', () async {
      final r = _report([
        for (var i = 0; i < 500; i++)
          _order(i,
              plan: i % 7 == 0 ? 'p' : null,
              status: i % 5 == 0 ? 'in_progress' : 'done',
              due: DateTime.utc(2026, 9, 20))
      ]);
      final out = await buildReportPdf(
          _data(ru, r, regions: [
            RegionReport(key: 'eu', label: 'Европа', stats: r.company),
          ]),
          fonts);
      expect(out.pages, greaterThan(5));
      // Посмотреть глазами: REPORT_PDF_OUT=/tmp/report.pdf flutter test …
      final path = Platform.environment['REPORT_PDF_OUT'];
      if (path != null) File(path).writeAsBytesSync(out.bytes);
    });

    test('страна: флаг и название, неизвестный код — как есть', () {
      expect(reportCountryLabel('rs', 'ru'), '🇷🇸 Сербия');
      expect(reportCountryLabel('AE', 'en'), '🇦🇪 UAE');
      expect(reportCountryName('ZZ', 'ru'), 'ZZ');
    });

    test('английский интерфейс — английский PDF без ошибок', () async {
      final r = _report([_order(1), _order(2, plan: 'p')]);
      final out = await buildReportPdf(_data(en, r), fonts);
      expect(out.pages, 1);
    });

    test('пустой отчёт — одна страница', () async {
      final out = await buildReportPdf(_data(ru, _report(const [])), fonts);
      expect(out.pages, 1);
    });

    test('номер заявки и имя файла', () {
      expect(
          reportOrderNumber('de300000-0000-4000-8000-000000000101'), '#DE3000');
      expect(
          reportPdfFileName(ru, DateTime(2026, 9, 10), DateTime(2026, 10, 10)),
          'HeyHelpy_Отчёт_2026-09-10_2026-10-09.pdf');
      expect(reportPdfFileName(en, DateTime(2026, 9, 1), DateTime(2026, 10, 1)),
          'HeyHelpy_Report_2026-09-01_2026-09-30.pdf');
    });
  });

  group('По регионам', () {
    const regions = [
      ReportRegion(id: 'eu', name: 'Европа', sort: 1),
      ReportRegion(id: 'asia', name: 'Азия', sort: 2),
    ];
    final regionOf = {'o0': 'eu', 'o1': 'asia', 'o2': null};
    final cityOf = {'o0': 'Белград', 'o1': 'Пекин', 'o2': ''};

    test('заявки, просрочено и ППР — по региону объекта, без региона — в конце',
        () {
      final now = DateTime.utc(2026, 10, 10);
      final orders = [
        _order(0, object: 'o0'),
        _order(1,
            object: 'o0',
            status: 'in_progress',
            due: DateTime.utc(2026, 9, 2)), // просрочена
        _order(2, object: 'o1', plan: 'p'),
        _order(3, object: 'o1', plan: 'p', status: 'assigned'),
        _order(4, object: 'o1', plan: 'p', status: 'cancelled'),
        _order(5, object: 'o2'),
      ];
      final rows = buildRegionReports(
          orders: orders,
          regions: regions,
          regionOf: (id) => regionOf[id],
          cityOf: (id) => cityOf[id] ?? '',
          now: now);
      expect([for (final r in rows) r.label], ['Европа', 'Азия', null]);
      expect(rows[0].stats.total, 2);
      expect(rows[0].stats.overdue, 1);
      expect(rows[1].stats.total, 3);
      expect(rows[1].stats.pprTotal, 2, reason: 'отменённая ППР не считается');
      expect(rows[1].stats.pprDone, 1);
      expect(rows[2].key, isNull);
    });

    test('регионов нет — по городам, по алфавиту', () {
      final rows = buildRegionReports(
          orders: [
            _order(0, object: 'o1'),
            _order(1, object: 'o0'),
            _order(2, object: 'o2'),
          ],
          regions: const [],
          regionOf: (id) => regionOf[id],
          cityOf: (id) => cityOf[id] ?? '');
      expect([for (final r in rows) r.label], ['Белград', 'Пекин', null]);
    });

    test('регион, которого нет в списке, — «без региона»', () {
      final rows = buildRegionReports(
          orders: [_order(0, object: 'x')],
          regions: regions,
          regionOf: (_) => 'deleted',
          cityOf: (_) => '');
      expect(rows.single.key, isNull);
    });

    test('тип задачи: ППР, повторяющаяся, разовая', () {
      expect(_order(1, plan: 'p').kind, ReportKind.ppr);
      expect(_order(1).kind, ReportKind.once);
      final rec = ReportOrder.fromMap({
        'id': 'x',
        'status': 'new',
        'created_at': '2026-09-01T00:00:00Z',
        'recurrence': {'kind': 'regular'},
      });
      expect(rec.kind, ReportKind.recurring);
      expect(
          sortRegions(const [
            ReportRegion(id: 'b', name: 'Б', sort: 2),
            ReportRegion(id: 'a', name: 'А', sort: 1),
          ]).first.id,
          'a');
    });
  });
}
