import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../directory/city.dart';
import '../directory/directory.dart';
import '../equipment/equipment_kinds.dart';
import '../floors/floor_models.dart';
import '../regions/geo_pickers.dart';

/// «Где я» — общее для «Узнать по фото» и «Камеры» (шаги 22, 25): последнее
/// выбранное место хранится на устройстве для каждого пользователя.
String _hereKey(String uid) => 'photo_here_v1_$uid';

/// Последнее выбранное место: (объект, помещение); нет — (null, null).
Future<(String?, String?)> loadPhotoHere() async {
  try {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return (null, null);
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_hereKey(uid))?.split('|');
    if (v == null || v.isEmpty || v[0].isEmpty) return (null, null);
    return (v[0], v.length > 1 && v[1].isNotEmpty ? v[1] : null);
  } catch (_) {
    return (null, null);
  }
}

Future<void> savePhotoHere(String? objectId, String? locationId) async {
  try {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_hereKey(uid), '${objectId ?? ''}|${locationId ?? ''}');
  } catch (_) {}
}

/// Выбор объекта для «Где я»: «Без объекта — искать везде» и объекты по
/// городам, поиск. '' — без объекта, null — закрыли.
class HereObjectPickerSheet extends StatefulWidget {
  const HereObjectPickerSheet(
      {super.key, required this.objects, required this.selected});
  final List<Obj> objects;
  final String? selected;

  @override
  State<HereObjectPickerSheet> createState() => _HereObjectPickerSheetState();
}

class _HereObjectPickerSheetState extends State<HereObjectPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = _q.trim().toLowerCase();
    final list = [
      for (final g in groupObjectsByCity(widget.objects))
        for (final o in g.items)
          if (q.isEmpty || objectDisplayName(o).toLowerCase().contains(q)) o
    ];
    return ListPickerSheet(
      title: l.photoWhereChooseObject,
      search: widget.objects.length < 6
          ? null
          : AppSearchField(
              hint: l.formChooseObject,
              onChanged: (v) => setState(() => _q = v)),
      children: [
        AppGroup(margin: EdgeInsets.zero, children: [
          if (q.isEmpty)
            AppCheckRow(
                title: l.photoWhereNoObject,
                selected: widget.selected == null,
                onTap: () => Navigator.pop(context, '')),
          for (final o in list)
            AppCheckRow(
              title: objectDisplayName(o),
              selected: o.id == widget.selected,
              onTap: () => Navigator.pop(context, o.id),
            ),
        ]),
      ],
    );
  }
}

/// «Другое оборудование…»: оборудование объекта, сначала — в помещении
/// [here], поиск по названию и инвентарному номеру.
class HereAssetPickerSheet extends StatefulWidget {
  const HereAssetPickerSheet(
      {super.key,
      required this.assets,
      required this.places,
      required this.here});
  final List<PlanItem> assets;
  final Map<String, PlanItem> places;
  final String? here;

  @override
  State<HereAssetPickerSheet> createState() => _HereAssetPickerSheetState();
}

class _HereAssetPickerSheetState extends State<HereAssetPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = _q.trim().toLowerCase();
    final list = [
      for (final a in widget.assets)
        if (q.isEmpty ||
            a.name.toLowerCase().contains(q) ||
            (a.inventoryNo ?? '').toLowerCase().contains(q))
          a
    ]..sort((x, y) {
        final hx = x.locationId == widget.here ? 0 : 1;
        final hy = y.locationId == widget.here ? 0 : 1;
        return hx != hy ? hx - hy : naturalCompare(x.name, y.name);
      });
    return ListPickerSheet(
      title: l.photoPickAsset,
      search: AppSearchField(
          hint: l.photoAssetSearchHint,
          onChanged: (v) => setState(() => _q = v)),
      children: [
        AppGroup(margin: EdgeInsets.zero, children: [
          for (final a in list)
            AppRow(
              leading:
                  LeadingIcon(assetIcon(a.equipmentKind, a.category ?? '')),
              title: a.name,
              subtitle: [
                if (widget.places[a.locationId] case final p?) p.label,
                if (a.inventoryNo != null) a.inventoryNo!,
              ].join(' · '),
              onTap: () => Navigator.pop(context, a),
            ),
        ]),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Text(l.equipNothingFound,
                textAlign: TextAlign.center, style: AppText.footnote),
          ),
      ],
    );
  }
}
