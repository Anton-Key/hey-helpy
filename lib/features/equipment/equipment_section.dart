import 'package:flutter/material.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/schema_compat.dart';
import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';
import 'asset_card.dart';
import 'equipment_form.dart';
import 'equipment_import_screen.dart';
import 'equipment_models.dart';
import 'equipment_repository.dart';

/// Раздел «Оборудование · N» карточки объекта (шаг 16): по системам
/// (слоям), поиск по названию, номеру и модели. Менеджеру — «Добавить
/// оборудование» и «Импорт из Excel / CSV». Данные читает сам; перечитывает,
/// когда карточка объекта перезагрузилась (новый список помещений).
class EquipmentSection extends StatefulWidget {
  const EquipmentSection({
    super.key,
    required this.object,
    required this.places,
    required this.isManager,
    this.onChanged,
  });

  final Obj object;
  final List<Place> places;
  final bool isManager;

  /// Что-то добавили (например, импорт создал помещения) — перечитать карточку.
  final VoidCallback? onChanged;

  @override
  State<EquipmentSection> createState() => _EquipmentSectionState();
}

class _EquipmentSectionState extends State<EquipmentSection> {
  final _repo = EquipmentRepo();
  List<Asset>? _assets;
  List<Layer> _layers = const [];
  bool _failed = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EquipmentSection old) {
    super.didUpdateWidget(old);
    if (!identical(old.places, widget.places)) _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait<Object>([
        _repo.assetsOf(widget.object.id),
        DirectoryRepo().layers(),
      ]);
      if (!mounted) return;
      setState(() {
        _assets = r[0] as List<Asset>;
        _layers = r[1] as List<Layer>;
        _failed = false;
      });
    } catch (e) {
      debugPrint('Equipment: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  Place? _place(String id) {
    for (final p in widget.places) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool _matches(Asset a, String q) {
    if (q.isEmpty) return true;
    final room = _place(a.locationId);
    return [
      a.name,
      a.inventoryNo,
      a.manufacturer,
      a.model,
      a.serialNo,
      room?.label,
    ].whereType<String>().any((v) => v.toLowerCase().contains(q));
  }

  Future<void> _add() async {
    final l = context.l10n;
    final ok = await showAssetForm(context,
        objectId: widget.object.id, places: widget.places, layers: _layers);
    if (ok) {
      await _load();
      if (mounted) {
        showAppMessage(context, l.assetSaved, type: AppMessageType.success);
      }
    }
  }

  Future<void> _import() async {
    final l = context.l10n;
    if (SchemaCompat.has('0015') == false) {
      showAppMessage(context, l.migrationNeeded('0015'));
      return;
    }
    final done = await Navigator.push<bool>(
        context,
        appRoute(
            (_) => EquipmentImportScreen(
                object: widget.object, places: widget.places, layers: _layers),
            title: widget.object.name));
    if (done == true) {
      await _load();
      widget.onChanged?.call();
    }
  }

  Future<void> _open(Asset a) async {
    final changed = await Navigator.push<bool>(
        context,
        appRoute(
            (_) => AssetCardScreen(
                asset: a,
                object: widget.object,
                places: widget.places,
                layers: _layers,
                isManager: widget.isManager),
            title: widget.object.name));
    if (changed == true && mounted) widget.onChanged?.call();
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = context.localeCode;
    final assets = _assets;
    if (assets == null && !_failed) return const SizedBox.shrink();
    final all = assets ?? const <Asset>[];
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final a in all)
        if (_matches(a, q)) a
    ];

    // По системам: порядок слоёв компании, «Без системы» — в конце.
    final groups = <String?, List<Asset>>{};
    for (final a in shown) {
      final known = _layers.any((y) => y.id == a.layerId);
      groups.putIfAbsent(known ? a.layerId : null, () => []).add(a);
    }
    final order = [
      for (final y in _layers)
        if (groups.containsKey(y.id)) y.id,
      if (groups.containsKey(null)) null,
    ];
    String systemName(String? id) {
      for (final y in _layers) {
        if (y.id == id) return y.label(locale);
      }
      return l.equipNoSystem;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppGroup(
          header: l.equipSectionTitle(all.length),
          children: [
            if (_failed)
              AppRow(
                  title: l.assetLoadFailed,
                  titleStyle: AppText.callout,
                  chevron: false,
                  onTap: _load)
            else if (all.isEmpty)
              AppRow(
                  title: l.equipEmpty,
                  titleStyle: AppText.callout,
                  chevron: false),
            if (widget.isManager) ...[
              AppRow(
                leading: const LeadingIcon(AppIcons.add),
                title: l.equipAdd,
                titleStyle:
                    AppText.rowTitle.copyWith(color: AppColors.accentText),
                chevron: false,
                onTap: _add,
              ),
              AppRow(
                leading: const LeadingIcon(AppIcons.fileSheet),
                title: l.equipImport,
                titleStyle:
                    AppText.rowTitle.copyWith(color: AppColors.accentText),
                onTap: _import,
              ),
            ],
          ],
        ),
        if (all.length > 5)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpace.group),
            child: AppSearchField(
                hint: l.equipSearchHint,
                onChanged: (v) => setState(() => _query = v)),
          ),
        if (all.isNotEmpty && shown.isEmpty)
          AppGroup(children: [
            AppRow(
                title: l.equipNothingFound,
                titleStyle: AppText.callout,
                chevron: false),
          ]),
        for (final id in order)
          AppGroup(
            header: l.equipGroupTitle(systemName(id), groups[id]!.length),
            compactHeader: true,
            children: [
              for (final a in groups[id]!) _row(l, a),
            ],
          ),
      ],
    );
  }

  Widget _row(AppLocalizations l, Asset a) {
    final room = _place(a.locationId);
    return AppRow(
      leading: LeadingIcon(assetIcon(a.kind, a.category)),
      title: a.name,
      subtitle: [
        if (room != null) room.label,
        if (a.inventoryNo != null) a.inventoryNo!,
        if (a.makeModel != null) a.makeModel!,
      ].join(' · '),
      onTap: () => _open(a),
    );
  }
}
