import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import 'act_logic.dart';

/// Строка акта словами — одна и та же для PDF и Excel.
class ActDocRow {
  const ActDocRow(
      {required this.no,
      required this.date,
      required this.object,
      required this.place,
      required this.work,
      required this.proofs,
      required this.amount,
      required this.reasons,
      required this.overdue});
  final int no;
  final String date;
  final String object;
  final String place;
  final String work;
  final String proofs;
  final String amount;
  final String reasons;
  final bool overdue;
}

/// Акт словами: шапка, «К оплате», итог, «Не принято к оплате».
class ActDoc {
  const ActDoc({
    required this.l,
    required this.number,
    required this.company,
    required this.contractor,
    required this.period,
    required this.issuedAt,
    required this.author,
    required this.paid,
    required this.rejected,
    required this.totalLine,
    required this.sumLine,
    required this.hasSums,
  });
  final AppLocalizations l;
  final String number;
  final String company;
  final String contractor;
  final String period;
  final String issuedAt;
  final String author;
  final List<ActDocRow> paid;
  final List<ActDocRow> rejected;

  /// «К оплате: 5 · без доказательства: 4 · доказано 56 % · просрочено 1».
  final String totalLine;

  /// «Итого к оплате: 22 500 ₽» или «без сумм».
  final String sumLine;
  final bool hasSums;
}

String actReasonText(AppLocalizations l, ActReason r) => switch (r) {
      ActReason.notAccepted => l.actReasonNotAccepted,
      ActReason.returned => l.actReasonReturned,
      ActReason.noPhoto => l.actReasonNoPhoto,
      ActReason.photoFromFile => l.actReasonPhotoFromFile,
      ActReason.noVisit => l.actReasonNoVisit,
      ActReason.visitOutOfZone => l.actReasonOutOfZone,
      ActReason.checklist => l.actReasonChecklist,
    };

String actProofText(AppLocalizations l, ActLine x) => [
      if (x.photoProof) l.actProofPhoto,
      if (x.geoProof) l.actProofGeo,
      if (x.checklistProof) l.actProofChecklist,
    ].join(', ');

/// «4 500 ₽», «4 500,50 ₽» — копейки только если они есть.
String actMoney(String locale, double v, String currency) =>
    NumberFormat.simpleCurrency(
            locale: locale, name: currency, decimalDigits: v % 1 == 0 ? 0 : 2)
        .format(v);

ActDoc buildActDoc({
  required AppLocalizations l,
  required ActResult result,
  required String number,
  required String company,
  required String contractor,
  required String period,
  required DateTime issuedAt,
  required String author,
  required String Function(String? id) objectName,
  required String Function(String? id) placeName,
  required String Function(ActOrder o) workName,
}) {
  final date = DateFormat(l.localeName == 'en' ? 'MM/dd/yy' : 'dd.MM.yy');
  final pct = NumberFormat.percentPattern(l.localeName);
  final cur = result.rates.currency;
  ActDocRow row(int i, ActLine x) => ActDocRow(
        no: i + 1,
        date: date.format(x.order.date),
        object: objectName(x.order.objectId),
        place: placeName(x.order.locationId),
        work: x.order.title.isEmpty ? workName(x.order) : x.order.title,
        proofs: actProofText(l, x),
        amount: x.amount == null ? '—' : actMoney(l.localeName, x.amount!, cur),
        reasons: [for (final r in x.reasons) actReasonText(l, r)].join('; '),
        overdue: x.order.overdue,
      );
  final sum = result.sum;
  return ActDoc(
    l: l,
    number: number,
    company: company,
    contractor: contractor,
    period: period,
    issuedAt: DateFormat.yMMMd(l.localeName).add_Hm().format(issuedAt),
    author: author,
    paid: [for (var i = 0; i < result.paid.length; i++) row(i, result.paid[i])],
    rejected: [
      for (var i = 0; i < result.rejected.length; i++)
        row(i, result.rejected[i])
    ],
    totalLine: l.actTotalLine(
        result.paid.length,
        result.rejected.length,
        result.provenShare == null ? '—' : pct.format(result.provenShare),
        result.overdue),
    sumLine: sum == null
        ? l.actNoRates
        : l.actSumLine(actMoney(l.localeName, sum, cur)),
    hasSums: sum != null,
  );
}
