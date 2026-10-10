import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import 'floor_models.dart';
import 'floor_repository.dart';
import 'plan_logic.dart';

/// Подсказка ⓘ «Этажи».
AppInfoButton floorsInfo(AppLocalizations l) => AppInfoButton(
      title: l.infoFloorsTitle,
      lines: [l.infoFloors1, l.infoFloors2, l.infoFloors3],
      closeLabel: l.commonGotIt,
      semanticLabel: l.infoShowHint(l.infoFloorsTitle),
    );

/// Подсказка ⓘ «Загрузка плана».
AppInfoButton uploadInfo(AppLocalizations l) => AppInfoButton(
      title: l.infoUploadTitle,
      lines: [l.infoUpload1, l.infoUpload2, l.infoUpload3],
      closeLabel: l.commonGotIt,
      semanticLabel: l.infoShowHint(l.infoUploadTitle),
    );

/// Понятный текст ошибки планов (без технических деталей).
String planErrorText(AppLocalizations l, Object e) {
  if (e is FloorDenied) return l.planNoRights;
  if (e is PostgrestException && (e.code == '42501' || e.code == '403')) {
    return l.planNoRights;
  }
  if (e is StorageException) {
    final code = '${e.statusCode}';
    if (code == '413') return l.planTooBig;
    if (code == '415') return l.planBadType;
    if (code == '403' || code == '401') return l.planNoRights;
    return l.planUploadFailed;
  }
  if (e is PostgrestException && e.code == '23505') return l.floorNameTaken;
  return l.saveFailed;
}

String planFileProblemText(AppLocalizations l, PlanFileProblem p) =>
    switch (p) {
      PlanFileProblem.tooBig => l.planTooBig,
      PlanFileProblem.pdf => l.planPdf,
      PlanFileProblem.badType => l.planBadType,
      PlanFileProblem.unreadable => l.planUnreadable,
    };

/// Выбранный и проверенный файл плана.
class PickedPlan {
  const PickedPlan(this.bytes, this.info, this.name);
  final Uint8List bytes;
  final PlanImageInfo info;
  final String name;
}

/// Выбор картинки плана (галерея / файл в браузере) и проверка: PNG, JPEG,
/// WebP до 15 МБ. Ошибка — сообщением; null — не выбрали или не подходит.
Future<PickedPlan?> pickPlanFile(BuildContext context) async {
  final l = context.l10n;
  XFile? file;
  try {
    file = await ImagePicker().pickImage(source: ImageSource.gallery);
  } catch (e) {
    debugPrint('pickPlanFile: ${e.runtimeType}');
  }
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final (info, problem) = checkPlanFile(bytes);
  if (problem != null || info == null) {
    if (context.mounted) {
      showAppMessage(context,
          planFileProblemText(l, problem ?? PlanFileProblem.unreadable),
          type: AppMessageType.error);
    }
    return null;
  }
  return PickedPlan(bytes, info, file.name);
}

/// Результат формы этажа.
class FloorFormResult {
  const FloorFormResult(this.name, this.level, this.plan);
  final String name;
  final int? level;
  final PickedPlan? plan;
}

/// Форма этажа: название (1–60, уникально в объекте), номер (может быть
/// отрицательным), картинка плана (только у нового этажа, необязательно).
Future<FloorFormResult?> showFloorForm(BuildContext context,
    {required List<Floor> floors, Floor? existing}) {
  return showAppSheet<FloorFormResult>(
    context: context,
    builder: (_) => _FloorForm(floors: floors, existing: existing),
  );
}

class _FloorForm extends StatefulWidget {
  const _FloorForm({required this.floors, this.existing});
  final List<Floor> floors;
  final Floor? existing;

  @override
  State<_FloorForm> createState() => _FloorFormState();
}

class _FloorFormState extends State<_FloorForm> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _level =
      TextEditingController(text: widget.existing?.level?.toString() ?? '');
  PickedPlan? _plan;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _level.dispose();
    super.dispose();
  }

  /// «−1», «-1», «–2» — минус бывает разный.
  static int? _parseLevel(String s) =>
      int.tryParse(s.trim().replaceAll(RegExp('[−–—]'), '-'));

  void _save() {
    final l = context.l10n;
    final problem = checkFloorName(widget.floors, _name.text,
        exceptId: widget.existing?.id);
    final levelText = _level.text.trim();
    final level = levelText.isEmpty ? null : _parseLevel(levelText);
    String? error = switch (problem) {
      FloorNameProblem.empty => l.floorNameEmpty,
      FloorNameProblem.tooLong => l.floorNameTooLong,
      FloorNameProblem.taken => l.floorNameTaken,
      null => null,
    };
    if (error == null && levelText.isNotEmpty && level == null) {
      error = l.floorLevelInvalid;
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, FloorFormResult(_name.text.trim(), level, _plan));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isNew = widget.existing == null;
    return Padding(
      padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetHeader(
            title: isNew ? l.floorFormNew : l.floorRename,
            doneLabel: l.commonSave,
            onDone: _save,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    autofocus: true,
                    maxLength: 60,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                        labelText: l.floorName, hintText: l.floorNameHint),
                  ),
                  const SizedBox(height: AppSpace.s),
                  TextField(
                    controller: _level,
                    keyboardType:
                        const TextInputType.numberWithOptions(signed: true),
                    decoration: InputDecoration(
                        labelText: l.floorLevel, hintText: l.floorLevelHint),
                    onSubmitted: (_) => _save(),
                  ),
                  if (isNew) ...[
                    const SizedBox(height: AppSpace.l),
                    Row(children: [
                      Expanded(
                          child:
                              Text(l.floorPlanImage, style: AppText.headline)),
                      uploadInfo(l),
                    ]),
                    AppGroup(
                      footer: l.floorPlanOptional,
                      children: [
                        AppRow(
                          leading: const LeadingIcon(AppIcons.imageAdd),
                          title: _plan?.name ?? l.floorPlanPick,
                          subtitle: _plan == null
                              ? null
                              : '${_plan!.info.width} × ${_plan!.info.height}',
                          trailing: _plan == null
                              ? null
                              : AppIconButton(
                                  icon: AppIcons.close,
                                  label: l.floorRemovePlan,
                                  size: AppSizes.minTap,
                                  onPressed: () =>
                                      setState(() => _plan = null)),
                          onTap: () async {
                            final p = await pickPlanFile(context);
                            if (p != null && mounted) {
                              setState(() => _plan = p);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 10),
                      child: Text(_error!,
                          style: AppText.footnote
                              .copyWith(color: AppColors.danger)),
                    ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Шторка с одним полем (название помещения, переименование).
Future<String?> askText(BuildContext context,
    {required String title, String initial = '', String? label}) {
  return showAppSheet<String>(
    context: context,
    builder: (_) => _TextSheet(title: title, initial: initial, label: label),
  );
}

class _TextSheet extends StatefulWidget {
  const _TextSheet({required this.title, required this.initial, this.label});
  final String title;
  final String initial;
  final String? label;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final _c = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _done() {
    final t = _c.text.trim();
    if (t.isEmpty) {
      setState(() => _error = context.l10n.planNameRequired);
      return;
    }
    Navigator.pop(context, t);
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
              maxLength: 120,
              decoration: InputDecoration(
                  labelText: widget.label ?? l.planNameLabel,
                  errorText: _error),
              onSubmitted: (_) => _done(),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Пункт меню в шторке.
class SheetAction<T> {
  const SheetAction(this.value, this.label, this.icon,
      {this.destructive = false});
  final T value;
  final String label;
  final IconData icon;
  final bool destructive;
}

/// Меню действий шторкой (крупные строки — удобно пальцем).
Future<T?> showActionSheet<T>(BuildContext context,
    {required String title, required List<SheetAction<T>> actions}) {
  return showAppSheet<T>(
    context: context,
    builder: (ctx) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpace.screen, 0, AppSpace.screen, AppSpace.l),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
                child: Text(title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.headline),
              ),
              AppGroup(children: [
                for (final a in actions)
                  AppRow(
                    leading: a.destructive
                        ? LeadingIcon.danger(a.icon)
                        : LeadingIcon(a.icon),
                    title: a.label,
                    destructive: a.destructive,
                    chevron: false,
                    onTap: () => Navigator.pop(ctx, a.value),
                  ),
              ]),
            ]),
      ),
    ),
  );
}
