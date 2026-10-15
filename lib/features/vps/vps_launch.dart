import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_message.dart';
import '../../core/l10n_ext.dart';
import '../../core/supabase_config.dart';
import '../../l10n/app_localizations.dart';
import 'vps_channel.dart';
import 'vps_logic.dart';
import 'vps_repository.dart';

/// Шаг 28: открыть «Метки VPS (эксперимент)» для помещения [locationId].
/// Только VPS-вариант APK (иначе кнопки не видно — [VpsChannel.status]).
/// Возвращает id оборудования, если на метке нажали «Карточка оборудования».
Future<String?> openVpsMarks(BuildContext context,
    {required String locationId,
    required String placeName,
    required bool canEdit}) async {
  final l = context.l10n;
  void fail(String text) =>
      showAppMessage(context, text, type: AppMessageType.error);

  final status = await VpsChannel.status(refresh: true);
  if (!status.available || !context.mounted) return null;
  final repo = VpsRepo();
  VpsSite? site;
  try {
    site = await repo.site(locationId);
  } catch (_) {
    if (context.mounted) fail(l.errorGeneric);
    return null;
  }
  if (!context.mounted) return null;
  final blocker = vpsBlocker(status, hasSite: site != null);
  if (blocker != null) {
    fail(switch (blocker) {
      VpsBlocker.tokenMissing => l.vpsTokenMissing,
      VpsBlocker.tokenExpired => l.vpsTokenExpired,
      VpsBlocker.noArcore => l.vpsNoArcore,
      VpsBlocker.noSite => l.vpsNoSite,
    });
    return null;
  }
  final days = vpsTokenDaysLeft(status, DateTime.now());
  if (days != null && days <= 7) {
    showAppMessage(context, l.vpsTokenSoon(days));
  }

  // Подписи меток: название, открытые заявки, ближайшее ТО, цвет системы.
  final labels = <VpsMarkLabel>[];
  try {
    final rows = await Supabase.instance.client
        .from('assets')
        .select('id,name,layers(color)')
        .eq('location_id', locationId)
        .order('name');
    final ids = [for (final r in rows) r['id'] as String];
    final facts = vpsFactsByAsset(await repo.ordersOfAssets(ids));
    if (!context.mounted) return null;
    final fmt = DateFormat('dd.MM', l.localeName);
    for (final r in rows) {
      final f = facts[r['id']] ?? const VpsAssetFacts();
      final layer = r['layers'];
      labels.add(VpsMarkLabel(
        id: r['id'] as String,
        name: (r['name'] as String?) ?? '',
        line: vpsMarkLine(
            openCount: f.openCount,
            nextDue: f.nextDue,
            openOrders: l.vpsOpenOrders,
            noOpenOrders: l.vpsNoOpenOrders,
            maintenance: (d) => l.vpsMaintenance(fmt.format(d))),
        color: layer is Map ? '${layer['color'] ?? ''}' : '',
      ));
    }
  } catch (_) {
    if (context.mounted) fail(l.errorGeneric);
    return null;
  }

  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return null;
  try {
    return await VpsChannel.open({
      'url': SupabaseConfig.url,
      'anonKey': SupabaseConfig.anonKey,
      'jwt': session.accessToken,
      'locationId': locationId,
      'locationName': placeName,
      'locale': l.localeName,
      'canEdit': canEdit,
      'assets': jsonEncode([for (final a in labels) a.toJson()]),
      'texts': jsonEncode(vpsNativeTexts(l)),
    });
  } catch (_) {
    if (context.mounted) fail(l.vpsFailed);
    return null;
  }
}

/// Все строки нативного экрана — из lib/l10n (ключи = имена в VpsActivity).
Map<String, String> vpsNativeTexts(AppLocalizations l) => {
      'vpsFindPlace': l.vpsFindPlace,
      'vpsSearching': l.vpsSearching,
      'vpsCoarse': l.vpsCoarse,
      'vpsPrecise': l.vpsPrecise,
      'vpsPlaceMark': l.vpsPlaceMark,
      'vpsPlaceHint': l.vpsPlaceHint,
      'vpsPickAsset': l.vpsPickAsset,
      'vpsMarkSaved': l.vpsMarkSaved,
      'vpsMarkDeleted': l.vpsMarkDeleted,
      'vpsDeleteMark': l.vpsDeleteMark,
      'vpsOpenAsset': l.vpsOpenAsset,
      'vpsClose': l.commonClose,
      'commonCancel': l.commonCancel,
      'vpsNoCamera': l.vpsNoCamera,
      'vpsNoNetwork': l.vpsNoNetwork,
      'vpsAuthFailed': l.vpsAuthFailed,
      'vpsNoMap': l.vpsNoMap,
      'vpsQuota': l.vpsQuota,
      'vpsSessionExpired': l.vpsSessionExpired,
      'vpsFailed': l.vpsFailed,
      'vpsNoHit': l.vpsNoHit,
      'vpsNoAssets': l.vpsNoAssets,
      'vpsNeedPrecise': l.vpsNeedPrecise,
      'vpsMoveSlowly': l.vpsMoveSlowly,
      'vpsTokenMissing': l.vpsTokenMissing,
      'vpsTokenExpired': l.vpsTokenExpired,
      'vpsNoArcore': l.vpsNoArcore,
      'vpsNoSite': l.vpsNoSite,
    };
