import 'package:flutter/material.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import 'name_match.dart';
import 'region.dart';

/// Подсказка ⓘ «Регионы».
Widget regionInfoButton(BuildContext context) {
  final l = context.l10n;
  return AppInfoButton(
    title: l.regionsTitle,
    lines: [l.regionInfo1, l.regionInfo2, l.regionInfo3, l.regionInfo4],
    closeLabel: l.commonGotIt,
  );
}

/// Шторка «Название региона». null — отменили.
Future<String?> askRegionName(BuildContext context,
    {required String title, String initial = ''}) {
  return showAppSheet<String>(
    context: context,
    builder: (ctx) => _NameSheet(title: title, initial: initial),
  );
}

class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.title, required this.initial});
  final String title;
  final String initial;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _c = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _done() {
    final l = context.l10n;
    final v = _c.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (v.isEmpty) {
      setState(() => _error = l.regionNameRequired);
      return;
    }
    if (v.length > 60) {
      setState(() => _error = l.regionNameTooLong);
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetHeader(
              title: widget.title, doneLabel: l.commonSave, onDone: _done),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.xl),
            child: TextField(
              controller: _c,
              autofocus: true,
              maxLength: 60,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _done(),
              decoration: InputDecoration(
                  labelText: l.regionNameLabel,
                  hintText: l.regionNameHint,
                  errorText: _error),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Выбор в шторке «Похоже, такой … уже есть»: true — использовать
/// существующий, false — всё равно своё, null — отменили.
Future<bool?> askUseSimilar(BuildContext context,
    {required String title,
    required String text,
    required String useLabel,
    required String anywayLabel}) {
  return showAppSheet<bool>(
    context: context,
    builder: (ctx) => SafeArea(
      top: false,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SheetHeader(title: title),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.xl),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(text, style: AppText.body),
            const SizedBox(height: AppSpace.l),
            AppButton.primary(
                label: useLabel, onPressed: () => Navigator.pop(ctx, true)),
            const SizedBox(height: AppSpace.s),
            AppButton.secondary(
                label: anywayLabel, onPressed: () => Navigator.pop(ctx, false)),
          ]),
        ),
      ]),
    ),
  );
}

/// Новый регион с проверкой похожих названий. Есть похожий — шторка
/// «Похоже, такой регион уже есть: «Европа» (7 объектов). Использовать его?»;
/// выбрали существующий — он и возвращается. Точный дубль база не
/// пропустит (23505) — понятное сообщение и существующий регион.
/// null — отменили или ошибка.
Future<Region?> createRegionChecked(
  BuildContext context, {
  required String name,
  required List<Region> regions,
  required Map<String, int> counts,
  required String companyId,
  RegionRepository? repo,
}) async {
  final l = context.l10n;
  final similar = findSimilar(name, regions, (Region r) => r.name);
  if (similar != null) {
    final use = await askUseSimilar(context,
        title: l.regionSimilarTitle,
        text: l.regionSimilarText(
            similar.name, l.objectsCount(counts[similar.id] ?? 0)),
        useLabel: l.regionUseExisting(similar.name),
        anywayLabel: l.regionCreateAnyway);
    if (use == null) return null;
    if (use) return similar;
  }
  final maxSort = regions.fold<int>(0, (m, r) => r.sort > m ? r.sort : m);
  try {
    return await (repo ?? RegionRepository())
        .create(name, companyId: companyId, sort: maxSort + 1);
  } on RegionDuplicate {
    if (context.mounted) {
      showAppMessage(context, l.regionDuplicate, type: AppMessageType.error);
    }
    for (final r in regions) {
      if (normalizeLikeDb(r.name) == normalizeLikeDb(name)) return r;
    }
    return null;
  } catch (e) {
    debugPrint('createRegion: $e');
    if (context.mounted) {
      showAppMessage(context, l.saveFailed, type: AppMessageType.error);
    }
    return null;
  }
}

/// Переименование с той же проверкой. true — переименован.
Future<bool> renameRegionChecked(
  BuildContext context, {
  required Region region,
  required String name,
  required List<Region> regions,
  required Map<String, int> counts,
  RegionRepository? repo,
}) async {
  final l = context.l10n;
  if (name == region.name) return false;
  final others = [
    for (final r in regions)
      if (r.id != region.id) r
  ];
  final similar = findSimilar(name, others, (Region r) => r.name);
  if (similar != null) {
    final use = await askUseSimilar(context,
        title: l.regionSimilarTitle,
        text: l.regionSimilarText(
            similar.name, l.objectsCount(counts[similar.id] ?? 0)),
        // «Использовать» при переименовании — не переименовывать (дальше
        // можно объединить регионы).
        useLabel: l.regionUseExisting(similar.name),
        anywayLabel: l.regionRenameAnyway);
    if (use != false) return false;
  }
  try {
    await (repo ?? RegionRepository()).rename(region.id, name);
    return true;
  } on RegionDuplicate {
    if (context.mounted) {
      showAppMessage(context, l.regionDuplicate, type: AppMessageType.error);
    }
  } catch (e) {
    debugPrint('renameRegion: $e');
    if (context.mounted) {
      showAppMessage(context, l.saveFailed, type: AppMessageType.error);
    }
  }
  return false;
}
