/// Шаг 31: «AR-метки» (V0 своей технологии позиционирования) — чистые
/// функции Flutter-стороны. Сам экран — нативный (android/arlabel,
/// ArLabelActivity). Тесты — test/arlabel_logic_test.dart.
library;

import '../../l10n/app_localizations.dart';
import '../photo_identify/identify_models.dart';

/// Состояние нативного экрана (канал hey_helpy/arlabel → status).
class ArLabelStatus {
  const ArLabelStatus(
      {required this.available, this.arcore = 'unknown', this.camera = 'ask'});

  /// Браузер, не Android или старая сборка без канала.
  static const none = ArLabelStatus(available: false);

  /// Телефон с ARCore — только тогда кнопки «AR-метки».
  final bool available;

  /// supported | unsupported | unknown.
  final String arcore;

  /// granted | ask.
  final String camera;

  static ArLabelStatus fromMap(Map<Object?, Object?>? m) {
    if (m == null || m['available'] != true) return none;
    return ArLabelStatus(
        available: true,
        arcore: '${m['arcore'] ?? 'unknown'}',
        camera: '${m['camera'] ?? 'ask'}');
  }
}

/// Сводка для таблички: открытые заявки (без ППР) и ближайшее ТО.
class ArAssetFacts {
  const ArAssetFacts({this.openCount = 0, this.due});
  final int openCount;
  final DateTime? due;
}

const _closed = {'done', 'cancelled'};

DateTime? _dueOf(Map<String, dynamic> r) =>
    DateTime.tryParse('${r['period_end'] ?? r['due_at'] ?? ''}');

/// Заявки объекта (под RLS) → сводка по каждой единице [assets]
/// (`{id, layer_id}`): открытые заявки без задач ППР; ТО — своя ближайшая
/// задача ППР, иначе задача ППР её системы на объекте (как «Камера-помощник»,
/// buildAssetFacts).
Map<String, ArAssetFacts> arFactsByAsset(
    List<Map<String, dynamic>> assets, List<Map<String, dynamic>> rows) {
  final open = <String, int>{};
  final ownDue = <String, DateTime>{};
  final systemDue = <String, DateTime>{};
  void keepMin(Map<String, DateTime> m, String k, DateTime d) {
    if (m[k] == null || d.isBefore(m[k]!)) m[k] = d;
  }

  for (final r in rows) {
    if (_closed.contains(r['status'])) continue;
    final asset = r['asset_id'] as String?;
    final ppr = r['plan_id'] != null;
    if (asset != null && !ppr) {
      open[asset] = (open[asset] ?? 0) + 1;
    } else if (ppr) {
      final d = _dueOf(r);
      if (d == null) continue;
      if (asset != null) {
        keepMin(ownDue, asset, d);
      } else if (r['layer_id'] != null) {
        keepMin(systemDue, r['layer_id'] as String, d);
      }
    }
  }
  return {
    for (final a in assets)
      a['id'] as String: ArAssetFacts(
        openCount: open[a['id']] ?? 0,
        due: ownDue[a['id']] ??
            (a['layer_id'] == null ? null : systemDue[a['layer_id']]),
      ),
  };
}

/// Срок прошёл (по дате, без времени).
bool arOverdue(DateTime due, DateTime now) =>
    DateTime(due.year, due.month, due.day)
        .isBefore(DateTime(now.year, now.month, now.day));

/// Что выбрал человек на табличке.
enum ArLabelAction { asset, order }

class ArLabelResult {
  const ArLabelResult(
      {required this.action,
      required this.assetId,
      this.identification,
      this.photoPath,
      this.takenAt});
  final ArLabelAction action;
  final String assetId;

  /// Ответ photo-identify — заголовок и описание новой заявки.
  final PhotoIdentification? identification;

  /// Снимок для фото «до» (временный файл; прочитать и удалить).
  final String? photoPath;
  final DateTime? takenAt;

  static ArLabelResult? fromMap(Map<Object?, Object?>? m, {Object? identify}) {
    if (m == null) return null;
    final id = m['assetId'];
    final action = switch (m['action']) {
      'asset' => ArLabelAction.asset,
      'order' => ArLabelAction.order,
      _ => null,
    };
    if (id is! String || id.isEmpty || action == null) return null;
    final t = m['takenAt'];
    return ArLabelResult(
      action: action,
      assetId: id,
      identification: PhotoIdentification.fromJson(identify),
      photoPath: m['photoPath'] as String?,
      takenAt: t is num && t > 0
          ? DateTime.fromMillisecondsSinceEpoch(t.toInt())
          : null,
    );
  }
}

/// Все строки нативного экрана — из lib/l10n (ключи = имена в
/// ArLabelActivity / ArLabelLogic). Шаблоны «{n}», «{date}» Kotlin
/// подставляет сам (формы числа — ArLabelLogic.pluralKey).
Map<String, String> arLabelNativeTexts(AppLocalizations l) => {
      'arHint': l.arHint,
      'arWhatIsIt': l.arWhatIsIt,
      'arLooking': l.arLooking,
      'arClose': l.commonClose,
      'commonCancel': l.commonCancel,
      'arNoHit': l.arNoHit,
      'arNoEquipment': l.arNoEquipment,
      'arNotRecognized': l.arNotRecognized,
      'arFailed': l.arFailed,
      'arNoNetwork': l.arNoNetwork,
      'arSessionExpired': l.arSessionExpired,
      'arNoCamera': l.arNoCamera,
      'arNoArcore': l.arNoArcore,
      'arPickAsset': l.arPickAsset,
      'arOpenAsset': l.arOpenAsset,
      'arCreateOrder': l.arCreateOrder,
      'arRemoveMark': l.arRemoveMark,
      'arLimit': l.arLimit,
      'arOrdersOne': l.arOrdersOne('{n}'),
      'arOrdersFew': l.arOrdersFew('{n}'),
      'arOrdersMany': l.arOrdersMany('{n}'),
      'arNoOpenOrders': l.arNoOpenOrders,
      'arMaintenanceDue': l.arMaintenanceDue('{date}'),
      'arMaintenanceOverdue': l.arMaintenanceOverdue,
    };
