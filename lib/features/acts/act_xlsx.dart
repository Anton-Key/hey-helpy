import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'act_doc.dart';

/// Excel акта для бухгалтерии (шаг 24): листы «К оплате» и «Не принято»,
/// тот же состав, что в PDF. Тянет пакет excel — загружается отложенно
/// (`deferred as actxlsx`), как импорт оборудования.
Uint8List buildActXlsx(ActDoc d) {
  final l = d.l;
  final book = Excel.createExcel();
  final first = book.getDefaultSheet() ?? book.tables.keys.first;
  book.rename(first, l.actSheetPaid);
  final paid = book[l.actSheetPaid];
  TextCellValue t(String s) => TextCellValue(s);
  for (final line in [
    [l.actPdfTitle, d.number],
    [l.actPdfCustomer, d.company],
    [l.actPdfContractor, d.contractor],
    [l.actPdfPeriod, d.period],
    [l.actPdfIssuedBy, '${d.author} · ${d.issuedAt}'],
    [d.totalLine],
    [d.sumLine],
    <String>[],
  ]) {
    paid.appendRow([for (final s in line) t(s)]);
  }
  paid.appendRow([
    t(l.actColNo),
    t(l.actColDate),
    t(l.actColObject),
    t(l.actColPlace),
    t(l.actColWork),
    t(l.actColProofs),
    if (d.hasSums) t(l.actColSum),
  ]);
  for (final r in d.paid) {
    paid.appendRow([
      IntCellValue(r.no),
      t(r.date),
      t(r.object),
      t(r.place),
      t(r.work),
      t(r.overdue ? '${r.proofs} · ${l.actOverdue}' : r.proofs),
      if (d.hasSums) t(r.amount),
    ]);
  }
  final rej = book[l.actSheetRejected];
  rej.appendRow([
    t(l.actColNo),
    t(l.actColDate),
    t(l.actColObject),
    t(l.actColPlace),
    t(l.actColWork),
    t(l.actColReasons),
  ]);
  for (final r in d.rejected) {
    rej.appendRow([
      IntCellValue(r.no),
      t(r.date),
      t(r.object),
      t(r.place),
      t(r.work),
      t(r.reasons),
    ]);
  }
  // Шаг 27: «Ожидают решения» — отдельным блоком под отказами, без сумм.
  if (d.review.isNotEmpty) {
    rej.appendRow([t('')]);
    rej.appendRow([t(l.actPendingBlock)]);
    for (final r in d.review) {
      rej.appendRow([
        IntCellValue(r.no),
        t(r.date),
        t(r.object),
        t(r.place),
        t(r.work),
        t(r.reasons),
      ]);
    }
  }
  for (final s in [paid, rej]) {
    for (var i = 0; i < 7; i++) {
      s.setColumnWidth(i, i == 0 ? 6 : (i == 4 ? 40 : 22));
    }
  }
  return Uint8List.fromList(book.encode()!);
}
