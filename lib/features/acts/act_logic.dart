/// «Оплата по доказательству» (шаг 24): чистые функции акта подрядчику.
/// Тесты — test/act_logic_test.dart.
///
/// К оплате — только заявки, которые приняты менеджером и доказаны:
///   📷 фото «после», если фото требовалось (`requires_photo`); снятое
///      живой камерой (шаг 26) — фото «из файла» доказательством не считается;
///   📍 визит в геозоне, если у объекта есть координаты (геозона, 0009);
///   ✓ все пункты чек-листа, если чек-лист был.
/// Остальные — «без доказательства, к оплате не принимается» с причинами.
///
/// Шаг 27: система не отказывает в оплате сама — сомнительное
/// доказательство (время снимка без сети не подтверждено, фото «из
/// файла», прислано после закрытия, отпечаток не сверен) идёт в группу
/// «Требует решения менеджера». Менеджер «Подтверждает к оплате» (строка
/// уходит в «К оплате» с пометкой) или «Не принимает» (в «Без доказательства»).
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
  checklist,

  /// Менеджер нажал «Не принимать» (шаг 27).
  rejectedByManager
}

/// Почему доказательство под вопросом — решает менеджер (шаг 27).
enum ActDoubt {
  /// Фото «после» только «из файла» (шаг 26).
  photoFromFile,

  /// Снято без сети, часы телефона расходились с доверенным временем.
  timeUnverified,

  /// Снято без сети, ни GPS, ни монотонных часов — только часы телефона.
  timeDeviceOnly,

  /// Фото пришло, когда заявку уже отменили / приняли / передали.
  latePhoto,

  /// Отпечаток фото не сверен сервером (функция offline-sync не выложена).
  hashUnchecked,

  /// Визит в геозоне, но время визита без сети не подтверждено.
  visitTime,
}

/// Решение менеджера по сомнительному доказательству.
class ActDecision {
  const ActDecision(
      {required this.approve, required this.at, this.by, this.reason});
  final bool approve;
  final DateTime at;
  final String? by;
  final String? reason;
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
    this.doubts = const [],
    this.driftS,
    this.decision,
    this.offline = false,
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

  /// Есть фото «после», но не доказанное: «из файла» (0023) или снятое
  /// без сети с сомнениями (шаг 27, причины — в [doubts]).
  final bool hasFileAfterPhoto;
  final bool visitRequired;
  final VisitProof visit;
  final int checklistTotal;
  final int checklistDone;

  /// Задача планового ТО — по ставке «за визит ТО».
  final bool isPpr;

  /// Сомнения в доказательстве (шаг 27) — без фото «из файла»: его
  /// добавляет [allDoubts] сам.
  final List<ActDoubt> doubts;

  /// На сколько секунд расходились часы телефона (для подписи).
  final int? driftS;
  final ActDecision? decision;

  /// Что-то сдано без сети (фото или визит) — для «Отчётов».
  final bool offline;

  /// Все сомнения: фото «после» требовалось, доказанного нет, но есть
  /// «из файла» — тоже сомнение (раньше было отказом).
  List<ActDoubt> get allDoubts => [
        if (requiresPhoto &&
            !hasAfterPhoto &&
            hasFileAfterPhoto &&
            !doubts.any((d) => d != ActDoubt.visitTime))
          ActDoubt.photoFromFile,
        ...doubts,
      ];

  bool get overdue => dueAt != null && date.isAfter(dueAt!);
}

class ActLine {
  const ActLine(this.order, this.reasons, this.amount, {this.manual = false});
  final ActOrder order;
  final List<ActReason> reasons;

  /// К оплате по решению менеджера («✋ подтверждено менеджером»).
  final bool manual;
  List<ActDoubt> get doubts => order.allDoubts;
  ActDecision? get decision => order.decision;

  /// Сумма к оплате; null — ставки нет (акт без сумм) или не к оплате.
  final double? amount;

  bool get payable => reasons.isEmpty;
  bool get photoProof =>
      order.hasAfterPhoto || (manual && order.hasFileAfterPhoto);
  bool get geoProof => order.visit == VisitProof.inZone;
  bool get checklistProof =>
      order.checklistTotal > 0 && order.checklistDone >= order.checklistTotal;
}

class ActRates {
  const ActRates({this.perOrder, this.perVisit, this.currency = 'USD'});
  final double? perOrder;
  final double? perVisit;
  final String currency;
  bool get any => perOrder != null || perVisit != null;
}

class ActResult {
  const ActResult(this.paid, this.rejected, this.rates,
      {this.review = const []});
  final List<ActLine> paid;
  final List<ActLine> rejected;
  final ActRates rates;

  /// «Требует решения менеджера» — в акт не попадают, пока не решено.
  final List<ActLine> review;

  /// Из «К оплате» — подтверждено вручную.
  int get manual => paid.where((x) => x.manual).length;

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
      if (o.requiresPhoto && !o.hasAfterPhoto && !o.hasFileAfterPhoto)
        ActReason.noPhoto,
      if (o.visitRequired && o.visit == VisitProof.none) ActReason.noVisit,
      if (o.visitRequired && o.visit == VisitProof.outOfZone)
        ActReason.visitOutOfZone,
      if (o.checklistTotal > 0 && o.checklistDone < o.checklistTotal)
        ActReason.checklist,
    ];

/// Входит ли заявка в период [from, toExclusive).
bool inActPeriod(ActOrder o, DateTime from, DateTime toExclusive) =>
    !o.date.isBefore(from) && o.date.isBefore(toExclusive);

/// Разделить заявки на «к оплате», «требует решения менеджера» и «без
/// доказательства»; по дате.
ActResult buildAct(List<ActOrder> orders, ActRates rates) {
  final sorted = [...orders]..sort((a, b) => a.date.compareTo(b.date));
  final paid = <ActLine>[];
  final review = <ActLine>[];
  final rejected = <ActLine>[];
  double? amount(ActOrder o) =>
      o.isPpr ? rates.perVisit ?? rates.perOrder : rates.perOrder;
  for (final o in sorted) {
    final reasons = actReasons(o);
    if (reasons.isNotEmpty) {
      rejected.add(ActLine(o, reasons, null));
    } else if (o.allDoubts.isEmpty) {
      paid.add(ActLine(o, reasons, amount(o)));
    } else if (o.decision?.approve == true) {
      paid.add(ActLine(o, reasons, amount(o), manual: true));
    } else if (o.decision?.approve == false) {
      rejected.add(ActLine(o, const [ActReason.rejectedByManager], null));
    } else {
      review.add(ActLine(o, reasons, null));
    }
  }
  return ActResult(paid, rejected, rates, review: review);
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
          if (x.manual) 'manual': true,
          if (x.order.decision != null) ...{
            'decision': x.order.decision!.approve ? 'approve' : 'reject',
            'decision_reason': x.order.decision!.reason,
          },
          if (x.order.allDoubts.isNotEmpty)
            'doubts': [for (final d in x.order.allDoubts) d.name],
        }
    ];

Map<String, Object?> actTotalsJson(ActResult r) => {
      'paid': r.paid.length,
      'rejected': r.rejected.length,
      'proven_share': r.provenShare,
      'overdue': r.overdue,
      'manual': r.manual,
      'review': r.review.length,
      'sum': r.sum,
      'currency': r.rates.currency,
    };

/// Имя файла PDF / Excel: «АКТ-2026-003» → «AKT-2026-003».
String actFileBase(String number) =>
    number.replaceAll('АКТ', 'AKT').replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
