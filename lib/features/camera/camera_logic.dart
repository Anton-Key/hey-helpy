import '../photo_identify/identify_client.dart';
import '../photo_identify/identify_models.dart';

/// Чистая логика «Камеры-помощника» (шаг 25): что показать в карточке
/// поверх кадра, «Не тот», сводка по оборудованию, автоскан. Тесты —
/// `test/camera_logic_test.dart`.

/// Статусы, при которых заявка уже не «открыта».
const kClosedStatuses = {'done', 'cancelled'};

/// Сколько открытых заявок показывать в карточке.
const kCardOpenOrders = 3;

/// Что сейчас в карточке поверх стоп-кадра.
enum CameraCardKind {
  /// Ждём ответ ИИ («Смотрю…»).
  looking,

  /// Узнали: показан кандидат [CameraCard.candidate].
  recognized,

  /// Не узнали (ошибка или нет кандидатов) — список оборудования помещения.
  notRecognized,

  /// «Не тот» пролистал всех кандидатов — выбор вручную.
  manual,

  /// В кадре не видно оборудования (шаг 26) — «наведите на него камеру».
  noEquipment,
}

class CameraCard {
  const CameraCard(this.kind, {this.candidate, this.index = 0, this.total = 0});
  final CameraCardKind kind;
  final IdentifyCandidate? candidate;

  /// Номер показанного кандидата (0 — первый) и сколько их всего.
  final int index;
  final int total;

  /// Ещё есть кандидаты после этого — «Не тот» покажет следующего.
  bool get hasNext => index + 1 < total;
}

/// Карточка по ответу ИИ: [busy] — ждём; ошибка или пусто — «Не узнал»;
/// иначе кандидат номер [index] (за последним — выбор вручную).
CameraCard cameraCard(
    {required bool busy,
    PhotoIdentification? result,
    IdentifyProblem? problem,
    int index = 0}) {
  if (busy) return const CameraCard(CameraCardKind.looking);
  final list = result?.candidates ?? const <IdentifyCandidate>[];
  if (problem == null && result != null && result.noEquipment) {
    return const CameraCard(CameraCardKind.noEquipment);
  }
  if (problem != null || result == null || list.isEmpty) {
    return const CameraCard(CameraCardKind.notRecognized);
  }
  if (index >= list.length) {
    return CameraCard(CameraCardKind.manual, index: index, total: list.length);
  }
  return CameraCard(CameraCardKind.recognized,
      candidate: list[index], index: index, total: list.length);
}

/// Короткая подпись над рамкой: «КД-301» из «Кондиционер КД-301»
/// (последнее слово с цифрой), иначе название целиком (≤ 24 знаков).
String shortAssetLabel(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  for (final w in words.reversed) {
    if (RegExp(r'\d').hasMatch(w) && w.length <= 16) return w;
  }
  final n = name.trim();
  return n.length <= 24 ? n : '${n.substring(0, 23).trimRight()}…';
}

/// «КД-301 · 95 %» — подпись зелёной рамки. Уверенность — у ИИ (вид), а
/// не у сопоставления; без неё — только название.
String frameLabel(String name, int? percent) => percent == null
    ? shortAssetLabel(name)
    : '${shortAssetLabel(name)} · $percent %';

/// Плановое ТО (задача ППР) в карточке.
class NextMaintenance {
  const NextMaintenance(
      {required this.row, required this.due, this.forAsset = true});

  /// Строка заявки-задачи — открыть карточку.
  final Map<String, dynamic> row;

  /// Срок: конец периода (или due_at).
  final DateTime due;

  /// true — план этой единицы, false — план её системы на объекте.
  final bool forAsset;

  bool overdue(DateTime now) => DateTime(due.year, due.month, due.day)
      .isBefore(DateTime(now.year, now.month, now.day));
}

/// Последняя выполненная работа по единице.
class LastDone {
  const LastDone({required this.row, required this.at, this.contractorId});
  final Map<String, dynamic> row;
  final DateTime at;
  final String? contractorId;
}

/// Сводка по оборудованию для карточки поверх кадра.
class AssetFacts {
  const AssetFacts(
      {this.openOrders = const [],
      this.openCount = 0,
      this.next,
      this.lastDone});

  /// До [kCardOpenOrders] открытых заявок (без задач ППР), новые — первыми.
  final List<Map<String, dynamic>> openOrders;

  /// Сколько открытых заявок всего.
  final int openCount;
  final NextMaintenance? next;
  final LastDone? lastDone;

  static const empty = AssetFacts();
}

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse('$v')?.toLocal();

bool _open(Map<String, dynamic> r) => !kClosedStatuses.contains(r['status']);
bool _ppr(Map<String, dynamic> r) => r['plan_id'] != null;

/// Срок задачи ППР: конец периода, иначе due_at.
DateTime? _due(Map<String, dynamic> r) =>
    _date(r['period_end']) ?? _date(r['due_at']);

/// Сводка из заявок единицы [assetRows] и задач ППР её системы на объекте
/// [systemPprRows] (без привязки к оборудованию).
///
/// Следующее ТО — ближайшая открытая задача ППР: сначала своя (единицы),
/// затем системы; среди них — с ближайшим сроком (просроченная — раньше).
/// Последняя выполненная — заявка «принята» с самой поздней датой приёмки.
AssetFacts buildAssetFacts(List<Map<String, dynamic>> assetRows,
    {List<Map<String, dynamic>> systemPprRows = const []}) {
  final open = [
    for (final r in assetRows)
      if (_open(r) && !_ppr(r)) r
  ]..sort((a, b) =>
      '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}'));

  NextMaintenance? pick(List<Map<String, dynamic>> rows, bool forAsset) {
    NextMaintenance? best;
    for (final r in rows) {
      if (!_ppr(r) || !_open(r)) continue;
      final due = _due(r);
      if (due == null) continue;
      if (best == null || due.isBefore(best.due)) {
        best = NextMaintenance(row: r, due: due, forAsset: forAsset);
      }
    }
    return best;
  }

  final next = pick(assetRows, true) ??
      pick([
        for (final r in systemPprRows)
          if (r['asset_id'] == null) r
      ], false);

  LastDone? last;
  for (final r in assetRows) {
    if (r['status'] != 'done') continue;
    final at = _date(r['accepted_at']) ?? _date(r['created_at']);
    if (at == null) continue;
    if (last == null || at.isAfter(last.at)) {
      last = LastDone(
          row: r, at: at, contractorId: r['assigned_contractor_id'] as String?);
    }
  }

  return AssetFacts(
      openOrders: open.take(kCardOpenOrders).toList(),
      openCount: open.length,
      next: next,
      lastDone: last);
}

// ---------------------------------------------------------------------------
// Автоскан (блок 2): «телефон неподвижен ~1,5 с» → кадр в photo-identify, но
// не чаще раза в 6 с и не больше 20 раз за экран.
// ---------------------------------------------------------------------------

class AutoScanGate {
  AutoScanGate(
      {this.still = const Duration(milliseconds: 1500),
      this.minGap = const Duration(seconds: 6),
      this.maxPerScreen = 20,
      this.threshold = 0.06});

  /// Сколько кадр должен не меняться.
  final Duration still;

  /// Не чаще одного запроса за это время.
  final Duration minGap;

  /// Не больше запросов за открытие экрана.
  final int maxPerScreen;

  /// Разница соседних кадров 0..1, меньше которой «неподвижно».
  final double threshold;

  DateTime? _stillSince;
  DateTime? _lastSent;
  int sent = 0;

  /// Лимит исчерпан — автоскан больше ничего не отправит.
  bool get exhausted => sent >= maxPerScreen;

  /// Новый замер разницы кадров [diff] в момент [now]. true — пора
  /// отправить кадр (и отправка засчитана).
  bool onFrame(double diff, DateTime now) {
    if (diff > threshold) {
      _stillSince = null;
      return false;
    }
    final since = _stillSince ??= now;
    if (now.difference(since) < still) return false;
    if (exhausted) return false;
    final last = _lastSent;
    if (last != null && now.difference(last) < minGap) return false;
    _lastSent = now;
    _stillSince = null; // следующий раз — снова 1,5 с покоя
    sent++;
    return true;
  }

  /// Ручной «Что это?» тоже считается запросом для паузы в 6 с.
  void onManual(DateTime now) => _lastSent = now;
}

/// Средняя разница двух кадров одинакового размера (байты яркости), 0..1.
/// Разные размеры или пусто — 1 (считаем, что двигается).
double frameDiff(List<int> a, List<int> b) {
  if (a.isEmpty || a.length != b.length) return 1;
  var sum = 0;
  for (var i = 0; i < a.length; i++) {
    final d = a[i] - b[i];
    sum += d < 0 ? -d : d;
  }
  return sum / (a.length * 255);
}
