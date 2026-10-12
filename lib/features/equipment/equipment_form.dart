import 'package:flutter/material.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/schema_compat.dart';
import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';
import '../regions/geo_pickers.dart';
import 'equipment_import.dart';
import 'equipment_kinds.dart';
import 'equipment_models.dart';
import 'equipment_repository.dart';

/// «каждый месяц», «каждый квартал», «каждые 10 дн.».
String assetPeriodLabel(AppLocalizations l, String kind, int? days) =>
    switch (kind) {
      'quarter' => l.assetPeriodQuarter,
      'half_year' => l.assetPeriodHalfYear,
      'year' => l.assetPeriodYear,
      'days' => l.assetPeriodDays(days ?? 0),
      _ => l.assetPeriodMonth,
    };

/// Дата ввода: «1 мая 2024 г.» — по языку интерфейса.
String assetDate(BuildContext context, DateTime d) => context.l10n.date(d);

/// Форма «Новое оборудование» / правка. Нужна миграция 0015 (паспортные
/// поля) — без неё сообщение «Нужна миграция 0015». true — сохранено.
Future<bool> showAssetForm(
  BuildContext context, {
  required String objectId,
  required List<Place> places,
  required List<Layer> layers,
  Asset? existing,
}) async =>
    await showAssetFormForId(context,
        objectId: objectId,
        places: places,
        layers: layers,
        existing: existing) !=
    null;

/// То же, но возвращает id сохранённого оборудования (null — не сохранено).
/// [prefill] — поля новой единицы заранее («Нет в реестре — добавить» после
/// узнавания по фото: вид, система, шильдик, помещение).
Future<String?> showAssetFormForId(
  BuildContext context, {
  required String objectId,
  required List<Place> places,
  required List<Layer> layers,
  Asset? existing,
  AssetDraft? prefill,
}) async {
  final l = context.l10n;
  if (SchemaCompat.has('0015') == false) {
    showAppMessage(context, l.migrationNeeded('0015'));
    return null;
  }
  if (places.isEmpty) {
    showAppMessage(context, l.assetNoPlaces);
    return null;
  }
  return showAppSheet<String>(
    context: context,
    builder: (ctx) => Padding(
      padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _AssetForm(
          objectId: objectId,
          places: places,
          layers: layers,
          existing: existing,
          prefill: prefill),
    ),
  );
}

class _AssetForm extends StatefulWidget {
  const _AssetForm(
      {required this.objectId,
      required this.places,
      required this.layers,
      this.existing,
      this.prefill});
  final String objectId;
  final List<Place> places;
  final List<Layer> layers;
  final Asset? existing;
  final AssetDraft? prefill;

  @override
  State<_AssetForm> createState() => _AssetFormState();
}

class _AssetFormState extends State<_AssetForm> {
  late final _name = TextEditingController(
      text: widget.existing?.name ?? widget.prefill?.name);
  late final _inv = TextEditingController(
      text: widget.existing?.inventoryNo ?? widget.prefill?.inventoryNo);
  late final _mf = TextEditingController(
      text: widget.existing?.manufacturer ?? widget.prefill?.manufacturer);
  late final _model = TextEditingController(
      text: widget.existing?.model ?? widget.prefill?.model);
  late final _serial = TextEditingController(
      text: widget.existing?.serialNo ?? widget.prefill?.serialNo);
  late String? _layerId = widget.existing?.layerId ?? widget.prefill?.layerId;
  late String? _kind = equipmentKind(widget.existing != null
          ? widget.existing!.kind
          : widget.prefill?.kind)
      ?.code;
  late String? _placeId = widget.existing?.locationId ??
      (widget.places.any((p) => p.id == widget.prefill?.locationId)
          ? widget.prefill!.locationId
          : null) ??
      (widget.places.length == 1 ? widget.places.first.id : null);
  late DateTime? _installed = widget.existing?.installedAt;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _inv, _mf, _model, _serial]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _t(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _save() async {
    final l = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppMessage(context, l.assetNameRequired);
      return;
    }
    if (_placeId == null) {
      showAppMessage(context, l.assetRoomRequired);
      return;
    }
    setState(() => _busy = true);
    final draft = AssetDraft(
      name: name,
      locationId: _placeId!,
      layerId: _layerId,
      inventoryNo: _t(_inv),
      manufacturer: _t(_mf),
      model: _t(_model),
      serialNo: _t(_serial),
      installedAt: _installed,
      kind: _kind,
      baseMeta: widget.existing?.meta,
    );
    try {
      final repo = EquipmentRepo();
      final String id;
      if (widget.existing == null) {
        id = await repo.add(draft);
      } else {
        id = widget.existing!.id;
        await repo.update(id, draft);
      }
      if (mounted) Navigator.pop(context, id);
    } on MigrationMissing {
      if (mounted) showAppMessage(context, l.migrationNeeded('0015'));
    } catch (e) {
      debugPrint('Asset save: $e');
      if (mounted) {
        showAppMessage(context, l.assetSaveFailed, type: AppMessageType.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickKind() async {
    final picked = await showAppSheet<String>(
      context: context,
      builder: (_) => KindPickerSheet(selected: _kind),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _kind = picked.isEmpty ? null : picked;
      // Система не выбрана — по умолчанию для вида.
      _layerId ??= defaultLayerForKind(_kind, widget.layers)?.id;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _installed ?? now,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _installed = picked);
  }

  Widget _field(TextEditingController c, String hint) => TextField(
        controller: c,
        style: AppText.body,
        decoration: InputDecoration(
          hintText: hint,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = context.localeCode;

    return SafeArea(
      top: false,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SheetHeader(
          title: widget.existing == null
              ? l.assetFormNewTitle
              : l.assetFormEditTitle,
          doneLabel: l.commonSave,
          doneLoading: _busy,
          onDone: _save,
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpace.screen, AppSpace.xs, AppSpace.screen, AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppGroup(header: l.assetFieldName, children: [
                  _field(_name, l.assetFieldNameHint),
                ]),
                AppGroup(header: l.assetFieldRoom, children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpace.rowH, vertical: AppSpace.xxs),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _placeId,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.field),
                        icon: const Icon(AppIcons.chevronDown,
                            size: AppSizes.iconS, color: AppColors.secondary),
                        hint: Text(l.assetChooseRoom,
                            style: AppText.body
                                .copyWith(color: AppColors.secondary)),
                        items: [
                          for (final p in widget.places)
                            DropdownMenuItem(
                                value: p.id,
                                child: Text(p.label, style: AppText.body)),
                        ],
                        onChanged: (v) => setState(() => _placeId = v),
                      ),
                    ),
                  ),
                ]),
                AppGroup(header: l.assetFieldKind, children: [
                  AppRow(
                    leading: Icon(
                        equipmentKind(_kind)?.icon ?? AppIcons.eqOther,
                        size: AppSizes.icon,
                        color: AppColors.accentText),
                    title: _kind == null
                        ? l.assetKindNone
                        : equipmentKindLabel(l, _kind!),
                    titleStyle: _kind == null
                        ? AppText.body.copyWith(color: AppColors.secondary)
                        : null,
                    onTap: _pickKind,
                  ),
                ]),
                SectionHeader(l.assetFieldSystem),
                Wrap(spacing: AppSpace.s, runSpacing: AppSpace.s, children: [
                  for (final y in widget.layers)
                    AppChip(
                        label: y.label(locale),
                        selected: _layerId == y.id,
                        onTap: () => setState(
                            () => _layerId = _layerId == y.id ? null : y.id)),
                ]),
                const SizedBox(height: AppSpace.group),
                AppGroup(header: l.assetFieldInventory, children: [
                  _field(_inv, l.assetFieldInventoryHint),
                ]),
                AppGroup(children: [
                  _field(_mf, l.assetFieldManufacturer),
                  _field(_model, l.assetFieldModel),
                  _field(_serial, l.assetFieldSerial),
                ]),
                AppGroup(children: [
                  AppRow(
                    leading: const LeadingIcon(AppIcons.calendar),
                    title: l.assetFieldInstalled,
                    value: _installed == null
                        ? l.commonNotSpecified
                        : assetDate(context, _installed!),
                    onTap: _pickDate,
                  ),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

/// Текст ошибок строки импорта: «нет помещения «Склад» · дата не распознана».
String importIssuesText(AppLocalizations l, ImportRow r) => [
      for (final i in r.issues)
        switch (i) {
          ImportIssue.noName => l.importIssueNoName,
          ImportIssue.noRoom => l.importIssueNoRoom,
          ImportIssue.roomNotFound => l.importIssueRoomNotFound(r.roomText),
          ImportIssue.unknownSystem => l.importIssueUnknownSystem(r.systemText),
          ImportIssue.duplicateInFile => l.importIssueDupFile,
          ImportIssue.duplicateInDb => l.importIssueDupDb,
          ImportIssue.badDate => l.importIssueBadDate,
          ImportIssue.tooLong => l.importIssueTooLong,
          ImportIssue.unknownKind => l.importIssueUnknownKind(r.kindText),
        }
    ].join(' · ');

/// Окно выбора вида оборудования: «Не указан» и каталог со значками.
/// Возвращает код; '' — не указан; null — закрыли.
class KindPickerSheet extends StatelessWidget {
  const KindPickerSheet({super.key, required this.selected});
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListPickerSheet(
      title: l.assetFieldKind,
      search: null,
      children: [
        AppGroup(margin: EdgeInsets.zero, children: [
          AppCheckRow(
              title: l.assetKindNone,
              selected: selected == null,
              onTap: () => Navigator.pop(context, '')),
          for (final k in kEquipmentKinds)
            AppCheckRow(
              leading: Icon(k.icon,
                  size: AppSizes.icon, color: AppColors.accentText),
              title: equipmentKindLabel(l, k.code),
              selected: k.code == selected,
              onTap: () => Navigator.pop(context, k.code),
            ),
        ]),
      ],
    );
  }
}
