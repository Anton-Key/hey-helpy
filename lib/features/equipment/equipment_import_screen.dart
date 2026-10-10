import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/schema_compat.dart';
import '../../l10n/app_localizations.dart';
import '../directory/city.dart';
import '../directory/directory.dart';
import 'equipment_form.dart';
import 'equipment_import.dart';
import 'equipment_models.dart';
import 'equipment_repository.dart';

/// Подсказка ⓘ «Импорт оборудования».
AppInfoButton importInfo(AppLocalizations l) => AppInfoButton(
      title: l.importInfoTitle,
      lines: [l.importInfo1, l.importInfo2, l.importInfo3, l.importInfo4],
      closeLabel: l.commonGotIt,
      semanticLabel: l.infoShowHint(l.importInfoTitle),
    );

/// Импорт оборудования объекта из Excel / CSV (менеджер, шаг 16):
/// шаблон → файл → проверка по строкам → «Импортировать N строк».
/// Строки с ошибками не загружаются; недостающие помещения можно создать.
/// Всё загружается одним запросом (либо все строки, либо ни одной).
class EquipmentImportScreen extends StatefulWidget {
  const EquipmentImportScreen({
    super.key,
    required this.object,
    required this.places,
    required this.layers,
  });

  final Obj object;
  final List<Place> places;
  final List<Layer> layers;

  @override
  State<EquipmentImportScreen> createState() => _EquipmentImportScreenState();
}

class _EquipmentImportScreenState extends State<EquipmentImportScreen> {
  final _repo = EquipmentRepo();
  String? _fileName;
  ImportPreview? _preview;
  bool _createRooms = false;
  bool _busy = false;

  /// Сколько строк показывать в каждой группе (остальное — «И ещё N»).
  static const _shown = 50;

  Future<void> _saveTemplate(bool xlsx) async {
    final l = context.l10n;
    final locale = context.localeCode;
    try {
      final bytes = xlsx ? buildTemplateXlsx(locale) : buildTemplateCsv(locale);
      final name = locale == 'ru'
          ? 'HeyHelpy_Оборудование_шаблон'
          : 'HeyHelpy_Equipment_template';
      final uri = await FilePicker.saveFile(
        fileName: '$name.${xlsx ? 'xlsx' : 'csv'}',
        bytes: bytes,
        mimeType: xlsx
            ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            : 'text/csv',
        type: FileType.custom,
        allowedExtensions: [xlsx ? 'xlsx' : 'csv'],
      );
      if (uri != null && mounted) {
        showAppMessage(context, l.importTemplateSaved,
            type: AppMessageType.success);
      }
    } catch (e) {
      debugPrint('Template: $e');
      if (mounted) {
        showAppMessage(context, l.importTemplateFailed,
            type: AppMessageType.error);
      }
    }
  }

  Future<void> _pick() async {
    final l = context.l10n;
    try {
      final file = await FilePicker.pickFile(
          type: FileType.custom, allowedExtensions: const ['xlsx', 'csv']);
      if (file == null) return;
      setState(() => _busy = true);
      final bytes = await file.readAsBytes();
      final rows = _read(file.name, bytes);
      final taken = await _repo.inventoryNumbers();
      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _createRooms = false;
        _preview = validateImport(rows,
            places: widget.places,
            layers: widget.layers,
            existingInventory: taken);
      });
    } catch (e) {
      debugPrint('Import read: $e');
      if (mounted) {
        showAppMessage(context, l.importReadFailed, type: AppMessageType.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<List<String>> _read(String name, Uint8List bytes) {
    final n = name.toLowerCase();
    // .xlsx — это zip (начинается с «PK»), даже если расширение другое.
    final zip = bytes.length > 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    if (n.endsWith('.xlsx') || zip) return parseXlsxBytes(bytes);
    return parseCsvBytes(bytes);
  }

  Future<void> _import() async {
    final l = context.l10n;
    final p = _preview;
    if (p == null) return;
    final rows = [
      for (final r in p.rows)
        if (r.ok(createRooms: _createRooms)) r
    ];
    if (rows.isEmpty) return;
    setState(() => _busy = true);
    try {
      // Недостающие помещения — по одному на название.
      final created = <String, String>{};
      if (_createRooms) {
        for (final r in rows) {
          if (r.placeId != null) continue;
          final key = importRoomKey(r.roomText);
          if (created.containsKey(key)) continue;
          created[key] = await _repo.addPlace(widget.object.id, r.roomText);
        }
      }
      final drafts = <AssetDraft>[
        for (final r in rows)
          r.draft(r.placeId ?? created[importRoomKey(r.roomText)]!)
      ];
      final n = await _repo.addMany(drafts);
      if (!mounted) return;
      showAppMessage(context, l.importDone(n), type: AppMessageType.success);
      Navigator.pop(context, true);
    } on MigrationMissing {
      if (mounted) showAppMessage(context, l.migrationNeeded('0015'));
    } catch (e) {
      debugPrint('Import: $e');
      if (mounted) {
        showAppMessage(context, l.importFailed, type: AppMessageType.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = _preview;
    final ready = p?.okCount(createRooms: _createRooms) ?? 0;
    return AppScaffold(
      title: l.importTitle,
      bottomBar: p == null || p.rows.isEmpty
          ? null
          : BottomActionBar(
              child: AppButton.primary(
                  icon: AppIcons.fileSheet,
                  label: l.importButton(ready),
                  loading: _busy,
                  onPressed: ready == 0 || _busy ? null : _import)),
      slivers: [
        SliverContent(
          sliver: SliverList.list(children: [
            AppGroup(
              header: objectDisplayName(widget.object),
              headerTrailing: importInfo(l),
              footer: l.importFooter,
              children: [
                AppRow(
                    leading: const LeadingIcon(AppIcons.download),
                    title: l.importTemplateXlsx,
                    chevron: false,
                    onTap: () => _saveTemplate(true)),
                AppRow(
                    leading: const LeadingIcon(AppIcons.download),
                    title: l.importTemplateCsv,
                    chevron: false,
                    onTap: () => _saveTemplate(false)),
                AppRow(
                    leading: const LeadingIcon(AppIcons.fileSheet),
                    title: _fileName ?? l.importPickFile,
                    subtitle: _fileName == null ? null : l.importPickFile,
                    titleStyle:
                        AppText.rowTitle.copyWith(color: AppColors.accentText),
                    chevron: false,
                    onTap: _busy ? null : _pick),
              ],
            ),
            if (_busy && p == null) const AppLoader(),
            if (p != null) ..._result(l, p),
          ]),
        ),
        const SliverBottomInset(),
      ],
    );
  }

  List<Widget> _result(AppLocalizations l, ImportPreview p) {
    if (p.missingColumns.isNotEmpty) {
      final cols = [
        for (final c in p.missingColumns)
          c == ImportColumn.name ? l.importColName : l.importColRoom
      ].join(', ');
      return [
        AppEmptyState(text: l.importMissingColumns(cols), error: true),
      ];
    }
    if (p.rows.isEmpty) {
      return [AppEmptyState(icon: AppIcons.fileSheet, text: l.importEmpty)];
    }
    final good = [
      for (final r in p.rows)
        if (r.ok(createRooms: _createRooms)) r
    ];
    final bad = [
      for (final r in p.rows)
        if (!r.ok(createRooms: _createRooms)) r
    ];
    final missing = p.missingRooms;
    String title(ImportRow r) =>
        l.importRowTitle(r.line, r.name.isEmpty ? l.importNoRowName : r.name);
    return [
      AppGroup(
        footer: missing.isEmpty ? null : missing.join(', '),
        children: [
          AppRow(
              leading: LeadingIcon(
                  bad.isEmpty ? AppIcons.success : AppIcons.warning),
              title: l.importSummary(p.rows.length, good.length, bad.length),
              titleStyle: AppText.callout,
              chevron: false),
          if (missing.isNotEmpty)
            AppRow(
              leading: const LeadingIcon(AppIcons.room),
              title: l.importCreateRooms(missing.length),
              chevron: false,
              trailing: Switch(
                  value: _createRooms,
                  onChanged: (v) => setState(() => _createRooms = v)),
            ),
        ],
      ),
      if (bad.isNotEmpty)
        AppGroup(header: l.importErrorsTitle, children: [
          for (final r in bad.take(_shown))
            AppRow(
              leading: const LeadingIcon.danger(AppIcons.error),
              title: title(r),
              subtitle: importIssuesText(l, r),
              subtitleMaxLines: 3,
              chevron: false,
            ),
          if (bad.length > _shown)
            AppRow(
                title: l.importMore(bad.length - _shown),
                titleStyle: AppText.callout,
                chevron: false),
        ]),
      if (good.isNotEmpty)
        AppGroup(header: l.importReadyTitle, children: [
          for (final r in good.take(_shown))
            AppRow(
              leading: const LeadingIcon(AppIcons.check),
              title: title(r),
              subtitle: [
                r.roomText,
                if (r.inventoryNo != null) r.inventoryNo!,
                [r.manufacturer, r.model].whereType<String>().join(' '),
              ].where((s) => s.isNotEmpty).join(' · '),
              chevron: false,
            ),
          if (good.length > _shown)
            AppRow(
                title: l.importMore(good.length - _shown),
                titleStyle: AppText.callout,
                chevron: false),
        ]),
    ];
  }
}
