import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'identify_client.dart';
import 'identify_models.dart';

/// Итог узнавания — что выбрал человек (photo_identifications.outcome, 0017).
enum IdentifyOutcome { matchedTop, matchedOther, newAsset, dismissed }

String outcomeCode(IdentifyOutcome o) => switch (o) {
      IdentifyOutcome.matchedTop => 'matched_top',
      IdentifyOutcome.matchedOther => 'matched_other',
      IdentifyOutcome.newAsset => 'new_asset',
      IdentifyOutcome.dismissed => 'dismissed',
    };

/// Итог по выбранному оборудованию: первый кандидат — «угадал с первого раза».
IdentifyOutcome outcomeFor(PhotoIdentification r, String? chosenAssetId,
        {bool created = false}) =>
    created
        ? IdentifyOutcome.newAsset
        : chosenAssetId == null
            ? IdentifyOutcome.dismissed
            : chosenAssetId == r.top?.assetId
                ? IdentifyOutcome.matchedTop
                : IdentifyOutcome.matchedOther;

/// Журнал узнаваний (таблица photo_identifications, миграция 0017): одна
/// строка на узнавание, без фото и шильдика. Без 0017 (или при любой ошибке)
/// журнал молча пропускается — узнавание работает, пользователь ничего не
/// видит; причина — в лог отладки.
class IdentifyLog {
  IdentifyLog({SupabaseClient? client})
      : _c = client ?? Supabase.instance.client;
  final SupabaseClient _c;

  static final _uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

  /// Строка журнала (id создаёт приложение — дописать выбор можно без
  /// чтения строки после вставки).
  static Map<String, dynamic> row(
      {required String id,
      required String companyId,
      required String userId,
      required IdentifyPlace place,
      required PhotoIdentification r,
      required int ms}) {
    String? id_(String? v) => v != null && _uuid.hasMatch(v) ? v : null;
    return {
      'id': id,
      'company_id': companyId,
      'user_id': userId,
      'object_id': id_(place.objectId),
      'floor_id': id_(place.floorId),
      'location_id': id_(place.locationId),
      'kind': r.kind,
      'confidence': r.confidence,
      'top_asset_id': id_(r.top?.assetId),
      'model': r.model,
      'ms': ms.clamp(0, 600000),
    };
  }

  /// Записать узнавание; null — не записано (нет 0017, нет сети…).
  Future<String?> add(
      {required String companyId,
      required IdentifyPlace place,
      required PhotoIdentification r,
      required int ms}) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null || photoIdentifyMock) return null;
    final id = newUuid();
    try {
      await _c.from('photo_identifications').insert(row(
          id: id,
          companyId: companyId,
          userId: uid,
          place: place,
          r: r,
          ms: ms));
      return id;
    } catch (e) {
      debugPrint('photo_identifications: skipped (${_why(e)})');
      return null;
    }
  }

  /// Дописать выбор человека.
  Future<void> finish(String? id, IdentifyOutcome outcome,
      {String? chosenAssetId}) async {
    if (id == null) return;
    try {
      await _c.from('photo_identifications').update({
        'outcome': outcomeCode(outcome),
        'chosen_asset_id':
            outcome == IdentifyOutcome.dismissed ? null : chosenAssetId,
      }).eq('id', id);
    } catch (e) {
      debugPrint('photo_identifications: outcome not saved (${_why(e)})');
    }
  }

  static String _why(Object e) =>
      e is PostgrestException ? 'code ${e.code}' : '${e.runtimeType}';
}

/// UUID v4 из безопасного генератора случайных чисел.
String newUuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
