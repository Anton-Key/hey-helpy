import 'package:flutter/material.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../directory/directory.dart';
import 'systems_repository.dart';

/// Новая система или правка: название RU и EN, значок, цвет.
/// Сохраняет только администратор (база: layers_insert / layers_update).
Future<bool?> showSystemForm(BuildContext context,
    {required String companyId, Layer? existing, int? sort}) {
  return showAppSheet<bool>(
    context: context,
    builder: (ctx) => Padding(
      padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _SystemForm(companyId: companyId, existing: existing, sort: sort),
    ),
  );
}

class _SystemForm extends StatefulWidget {
  const _SystemForm({required this.companyId, this.existing, this.sort});
  final String companyId;
  final Layer? existing;
  final int? sort;

  @override
  State<_SystemForm> createState() => _SystemFormState();
}

class _SystemFormState extends State<_SystemForm> {
  late final _ru = TextEditingController(
      text: widget.existing?.names['ru'] ?? widget.existing?.name ?? '');
  late final _en =
      TextEditingController(text: widget.existing?.names['en'] ?? '');
  late String _icon = widget.existing == null
      ? 'other'
      : systemIconCode(widget.existing!.icon, widget.existing!.name);
  late String _color = widget.existing?.color != null &&
          SystemPalette.colors.contains(widget.existing!.color!.toUpperCase())
      ? widget.existing!.color!.toUpperCase()
      : (widget.existing?.color ?? SystemPalette.colors.first);
  bool _saving = false;

  @override
  void dispose() {
    _ru.dispose();
    _en.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final name = _ru.text.trim();
    if (name.isEmpty || name.length > 60) {
      showAppMessage(context, l.systemNameRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      await SystemsRepository().save(
          id: widget.existing?.id,
          companyId: widget.companyId,
          nameRu: name,
          nameEn: _en.text,
          color: _color,
          icon: _icon,
          sort: widget.existing == null ? widget.sort : null);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('system save: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      final dup = '$e'.contains('23505') || '$e'.contains('duplicate');
      showAppMessage(context, dup ? l.systemNameTaken : l.systemSaveFailed,
          type: AppMessageType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final color = SystemPalette.parse(_color);
    Widget field(TextEditingController c, String hint) => TextField(
        controller: c,
        maxLength: 60,
        style: AppText.body,
        decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SheetHeader(
          title: widget.existing == null ? l.systemNew : l.systemEdit,
          cancelLabel: l.commonCancel),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpace.screen, AppSpace.xs, AppSpace.screen, AppSpace.l),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppGroup(header: l.systemNameRu, children: [
                  field(_ru, l.systemNameRuHint),
                ]),
                AppGroup(header: l.systemNameEn, children: [
                  field(_en, l.systemNameEnHint),
                ]),
                SectionHeader(l.systemIcon),
                Wrap(spacing: AppSpace.s, runSpacing: AppSpace.s, children: [
                  for (final e in kSystemIcons.entries)
                    Pressable(
                      onTap: () => setState(() => _icon = e.key),
                      borderRadius: BorderRadius.circular(AppRadius.iconTile),
                      semanticLabel: e.key,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: _icon == e.key
                                ? color.withValues(alpha: 0.16)
                                : AppColors.surface,
                            border: Border.all(
                                color: _icon == e.key
                                    ? color
                                    : AppColors.separator,
                                width: _icon == e.key ? 2 : 1),
                            borderRadius:
                                BorderRadius.circular(AppRadius.iconTile)),
                        child: Icon(e.value,
                            size: AppSizes.icon,
                            color:
                                _icon == e.key ? color : AppColors.secondary),
                      ),
                    ),
                ]),
                SectionHeader(l.systemColor),
                Wrap(spacing: AppSpace.m, runSpacing: AppSpace.m, children: [
                  for (final c in SystemPalette.colors)
                    Pressable(
                      onTap: () => setState(() => _color = c),
                      borderRadius: BorderRadius.circular(22),
                      semanticLabel: c,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            color: SystemPalette.parse(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: _color == c
                                    ? AppColors.ink
                                    : AppColors.surface,
                                width: 3)),
                        child: _color == c
                            ? const Icon(AppIcons.check,
                                size: 18, color: AppColors.surface)
                            : null,
                      ),
                    ),
                ]),
                const SizedBox(height: AppSpace.l),
              ]),
        ),
      ),
      BottomActionBar(
          child: AppButton.primary(
              onPressed: _saving ? null : _save,
              loading: _saving,
              label: widget.existing == null ? l.systemCreate : l.commonSave)),
    ]);
  }
}
