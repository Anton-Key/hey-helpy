import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_message.dart';
import '../../core/l10n_ext.dart';
import '../../core/supabase_config.dart';
import '../directory/directory.dart';
import '../equipment/equipment_repository.dart';
import '../photo_identify/identify_models.dart';
import '../photos/photo_repository.dart';
import '../requests/order_form_place.dart';
import '../requests/requests.dart';
import 'arlabel_channel.dart';
import 'arlabel_file_stub.dart' if (dart.library.io) 'arlabel_file_io.dart';
import 'arlabel_logic.dart';

/// Шаг 31: открыть «AR-метки» с контекстом «Где я» (объект обязателен,
/// этаж и помещение — если известны). Только Android с ARCore (иначе кнопки
/// не видно — [ArLabelChannel.status]). Возвращает, что выбрал человек на
/// табличке: карточку оборудования или новую заявку.
Future<ArLabelResult?> openArLabels(BuildContext context,
    {required String? objectId,
    String? floorId,
    String? locationId,
    String? companyId}) async {
  final l = context.l10n;
  void fail(String text) =>
      showAppMessage(context, text, type: AppMessageType.error);

  if (objectId == null) {
    fail(l.arNoPlace);
    return null;
  }
  final status = await ArLabelChannel.status(refresh: true);
  if (!context.mounted) return null;
  if (!status.available) {
    fail(l.arNoArcore);
    return null;
  }
  final client = Supabase.instance.client;
  final session = client.auth.currentSession;
  if (session == null) return null;

  // Подписи табличек под RLS: оборудование объекта, его открытые заявки и ТО.
  final labels = <Map<String, Object?>>[];
  String? role;
  try {
    final r = await Future.wait<Object?>([
      client
          .from('assets')
          .select('id,name,layer_id,location_id,layers(color),'
              'locations!inner(object_id)')
          .eq('locations.object_id', objectId)
          .limit(1000),
      client
          .from('work_orders')
          .select('asset_id,layer_id,status,plan_id,period_end,due_at')
          .eq('object_id', objectId)
          .not('status', 'in', '(done,cancelled)')
          .limit(1000),
      companyId == null
          ? DirectoryRepo().myCompanyId()
          : Future.value(companyId),
      RequestsRepo().myRole(),
    ]);
    final assets = (r[0] as List).cast<Map<String, dynamic>>();
    final facts =
        arFactsByAsset(assets, (r[1] as List).cast<Map<String, dynamic>>());
    companyId = r[2] as String?;
    role = r[3] as String?;
    final fmt = DateFormat('dd.MM', l.localeName);
    final now = DateTime.now();
    for (final a in assets) {
      final f = facts[a['id']] ?? const ArAssetFacts();
      final layer = a['layers'];
      labels.add({
        'id': a['id'],
        'name': a['name'] ?? '',
        'openCount': f.openCount,
        'due': f.due == null ? null : fmt.format(f.due!),
        'overdue': f.due != null && arOverdue(f.due!, now),
        'color': layer is Map ? '${layer['color'] ?? ''}' : '',
        'layerId': a['layer_id'],
        'locationId': a['location_id'],
      });
    }
  } catch (e) {
    debugPrint('AR labels data: ${e.runtimeType}');
    if (context.mounted) fail(l.errorGeneric);
    return null;
  }
  if (!context.mounted) return null;

  try {
    final m = await ArLabelChannel.open({
      'url': SupabaseConfig.url,
      'anonKey': SupabaseConfig.anonKey,
      'jwt': session.accessToken,
      'companyId': companyId,
      'userId': client.auth.currentUser?.id,
      'objectId': objectId,
      'floorId': floorId,
      'locationId': locationId,
      'locale': l.localeName,
      'role': role,
      'assets': jsonEncode(labels),
      'texts': jsonEncode(arLabelNativeTexts(l)),
    });
    Object? identify;
    final raw = m?['identify'];
    if (raw is String) {
      try {
        identify = jsonDecode(raw);
      } catch (_) {}
    }
    return ArLabelResult.fromMap(m, identify: identify);
  } catch (e) {
    debugPrint('AR labels open: ${e.runtimeType}');
    if (context.mounted) fail(l.arFailed);
    return null;
  }
}

/// «Создать заявку» с таблички: объект, помещение, оборудование, система,
/// заголовок и описание от ИИ, снимок — фото «до», канал camera (как у
/// «Камеры-помощника»). true — заявка создана.
Future<bool> createOrderFromArLabel(BuildContext context, ArLabelResult r,
    {required List<Obj> objects, required String companyId}) async {
  final l = context.l10n;
  final photo = r.photoPath == null ? null : await takeArPhoto(r.photoPath!);
  final asset = await EquipmentRepo().asset(r.assetId);
  String? objectId;
  if (asset != null) {
    final row = await Supabase.instance.client
        .from('locations')
        .select('object_id')
        .eq('id', asset.locationId)
        .maybeSingle();
    objectId = row?['object_id'] as String?;
  }
  if (!context.mounted) return false;
  final id = r.identification;
  final name = asset?.name ?? '';
  final ok = await showOrderForm(
    context: context,
    repo: RequestsRepo(),
    objects: objects,
    companyId: companyId,
    initialObjectId: objectId,
    origin: PlaceOrigin.camera,
    initialLocationId: asset?.locationId,
    initialAssetId: r.assetId,
    initialAssetName: name,
    initialLayerId: id?.layerId ?? asset?.layerId,
    initialTitle:
        id == null ? l.photoOrderTitleCheck(name) : photoOrderTitle(l, id),
    initialDescription: id == null ? null : photoOrderDescription(l, id),
    photo: photo == null
        ? null
        : CapturedPhoto(
            bytes: photo,
            takenAt: r.takenAt ?? DateTime.now(),
            source: 'camera'),
  );
  return ok == true;
}
