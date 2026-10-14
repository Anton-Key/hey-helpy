/// «Оплата по доказательству» (шаг 24): чистые функции акта подрядчику.
/// Тесты — test/act_logic_test.dart.
///
/// К оплате — только заявки, которые приняты менеджером и доказаны:
///   📷 фото «после», если фото требовалось (`requires_photo`); снятое
///      живой камерой (шаг 26) — фото «из файла» доказательством не считается;
///   📍 визит в геозоне, если у объекта есть координаты (геозона, 0009);
///   ✓ все пункты чек-листа, если чек-лист был.
/// Остальные — «без доказательства, к оплате не принимается» с причинами.
library;

enum VisitProof { none, inZone, outOfZone }

/// Почему заявка не принимается к оплате.
enum ActReason {
  notAccepted,
  returned,
  noPhoto,
  photoFromFile,
  noVisit,
  visitOutOfZone,
  checklist
}

/// Заявка подрядчика за период — всё, что нужно для решения.
class ActOrder {
  const ActOrder({
    required this.id,
    required this.title,
    required this.status,
    required this.date,
    this.dueAt,
    this.objectId,
    this.locationId,
    this.layerId,
    this.requiresPhoto = false,
    this.hasAfterPhoto = false,
    this.hasFileAfterPhoto = false,
    this.visitRequired = false,
    this.visit = VisitProof.none,
    this.checklistTotal = 0,
    this.checklistDone = 0,
    this.isPpr = false,
  });
  final String id;
  final String title;

  /// done / on_review / returned.
  final String status;

  /// Дата работы: приёмка, иначе сдача на проверку.
  final DateTime date;
  final DateTime? dueAt;
  final String? objectId;
  final String? locationId;
  final String? layerId;
  final bool requiresPhoto;
  /// Фото «после», которое считается доказательством (не «из файла»).
  final bool hasAfterPhoto;

  /// Есть фото «после» только «из файла» (0023, `attachments.source`).
  final bool hasFileAfterPhoto;
  final bool visitRequired;
  final VisitProof visit;
  final int checklistTotal;
  final int checklistDone;

  /// Задача планового ТО — по ставке «за визит ТО».
  final bool isPpr;

  bool get overdue => dueAt != null && date.isAfter(dueAt!);
}

class ActLine {
  const ActLine(this.order, this.reasons, this.amount);
  final ActOrder order;
  final List<ActReason> reasons;

  /// Сумма к оплате; null — ставки нет (акт без сумм) или не к оплате.
  final double? amount;

  bool get payable => reasons.isEmpty;
  bool get photoProof => order.hasAfterPhoto;
  bool get geoProof => order.visit == VisitProof.inZone;
  bool get checklistProof =>
      order.checklistTotal > 0 && order.checklistDone >= order.checklistTotal;
}

class ActRates {
  const ActRates({this.perOrder, this.perVisit, this.currency = 'RUB'});
  final double? perOrder;
  final double? perVisit;
  final String currency;
  bool get any => perOrder != null || perVisit != null;
}

class ActResult {
  const ActResult(this.paid, this.rejected, this.rates);
  final List<ActLine> paid;
  final List<ActLine> rejected;
  final ActRates rates;

  int get total => paid.length + rejected.length;

  /// Доля доказанных; null — заявок нет.
  double? get provenShare => total == 0 ? null : paid.length / total;
  int get overdue =>
      [...paid, ...rejected].where((x) => x.order.overdue).length;

  /// Итого к оплате; null — ставок нет.
  double? get sum =>
      rates.any ? paid.fold<double>(0, (s, x) => s + (x.amount ?? 0)) : null;
}

/// Причины, по которым заявка не к оплате (пусто — к оплате).
List<ActReason> actReasons(ActOrder o) => [
      if (o.status == 'returned')
        ActReason.returned
      else if (o.status != 'done')
        ActReason.notAccepted,
      if (o.requiresPhoto && !o.hasAfterPhoto)
        o.hasFileAfterPhoto ? ActReason.photoFromFile : ActReason.noPhoto,
      if (o.visitRequired && o.visit == VisitProof.none) ActReason.noVisit,
      if (o.visitRequired && o.visit == VisitProof.outOfZone)
        ActReason.visitOutOfZone,
      if (o.checklistTotal > 0 && o.checklistDone < o.checklistTotal)
        ActReason.checklist,
    ];

/// Входит ли заявка в период [from, toExclusive).
bool inActPeriod(ActOrder o, DateTime from, DateTime toExclusive) =>
    !o.date.isBefore(from) && o.date.isBefore(toExclusive);

/// Разделить заявки на «к оплате» и «без доказательства»; по дате.
ActResult buildAct(List<ActOrder> orders, ActRates rates) {
  final sorted = [...orders]..sort((a, b) => a.date.compareTo(b.date));
  final paid = <ActLine>[];
  final rejected = <ActLine>[];
  for (final o in sorted) {
    final reasons = actReasons(o);
    if (reasons.isEmpty) {
      paid.add(ActLine(o, reasons,
          o.isPpr ? rates.perVisit ?? rates.perOrder : rates.perOrder));
    } else {
      rejected.add(ActLine(o, reasons, null));
    }
  }
  return ActResult(paid, rejected, rates);
}

/// Месяц периода: [первое число, первое число следующего).
(DateTime, DateTime) monthRange(DateTime month) {
  final from = DateTime(month.year, month.month);
  return (from, DateTime(month.year, month.month + 1));
}

/// Снимок для базы (contractor_acts.items / totals): без названий и денег
/// словами — только то, что нужно для истории.
List<Map<String, Object?>> actItemsJson(ActResult r) => [
      for (final x in [...r.paid, ...r.rejected])
        {
          'id': x.order.id,
          'paid': x.payable,
          'amount': x.amount,
          'reasons': [for (final y in x.reasons) y.name],
          'photo': x.photoProof,
          'geo': x.geoProof,
          'checklist': x.checklistProof,
          'overdue': x.order.overdue,
        }
    ];

Map<String, Object?> actTotalsJson(ActResult r) => {
      'paid': r.paid.length,
      'rejected': r.rejected.length,
      'proven_share': r.provenShare,
      'overdue': r.overdue,
      'sum': r.sum,
      'currency': r.rates.currency,
    };

/// Имя файла PDF / Excel: «АКТ-2026-003» → «AKT-2026-003».
String actFileBase(String number) =>
    number.replaceAll('АКТ', 'AKT').replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
