import 'package:flutter/material.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/schema_compat.dart';
import 'vps_logic.dart';
import 'vps_repository.dart';

/// Шаг 28: «VPS-скан помещения» — anchor payload из портала Niantic.
/// Работает во всех сборках (это просто хранение); сами метки — в VPS-APK.
class VpsSiteScreen extends StatefulWidget {
  const VpsSiteScreen(
      {super.key,
      required this.locationId,
      required this.placeName,
      required this.canEdit});
  final String locationId;
  final String placeName;
  final bool canEdit;

  @override
  State<VpsSiteScreen> createState() => _VpsSiteScreenState();
}

class _VpsSiteScreenState extends State<VpsSiteScreen> {
  final _repo = VpsRepo();
  final _payload = TextEditingController();
  final _name = TextEditingController();
  VpsSite? _site;
  bool _loading = true;
  bool _saving = false;
  bool _missing = false;
  String? _payloadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _payload.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await _repo.site(widget.locationId);
      if (!mounted) return;
      setState(() {
        _site = s;
        _missing = SchemaCompat.has('0025') == false;
        _payload.text = s?.payload ?? '';
        _name.text = s?.name ?? '';
      });
    } catch (e) {
      if (mounted) {
        showAppMessage(context, context.l10n.errorGeneric,
            type: AppMessageType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final l = context.l10n;
    final p = normalizePayload(_payload.text);
    if (p == null) {
      setState(() => _payloadError = l.vpsPayloadInvalid);
      return;
    }
    final changed = _site != null && _site!.payload != p && _site!.marks > 0;
    setState(() {
      _payloadError = null;
      _saving = true;
    });
    try {
      await _repo.save(
          locationId: widget.locationId,
          payload: p,
          name: _name.text,
          id: _site?.id);
      if (!mounted) return;
      showAppMessage(context, changed ? l.vpsSiteRescanHint : l.vpsSiteSaved,
          type: AppMessageType.success);
      await _load();
    } catch (e) {
      if (mounted) {
        showAppMessage(context, l.errorGeneric, type: AppMessageType.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final s = _site;
    if (s == null) return;
    final ok = await showAppDialog<bool>(
      context: context,
      title: l.vpsSiteDelete,
      message: l.vpsSiteDeleteConfirm,
      actions: [
        AppDialogAction(l.actionDelete, true, destructive: true),
        AppDialogAction(l.commonCancel, false),
      ],
    );
    if (ok != true) return;
    try {
      await _repo.delete(s.id);
      if (!mounted) return;
      showAppMessage(context, l.vpsSiteDeleted, type: AppMessageType.success);
      await _load();
    } catch (e) {
      if (mounted) {
        showAppMessage(context, l.errorGeneric, type: AppMessageType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = _site;
    return AppScaffold(
      title: l.vpsSiteTitle,
      eyebrow: widget.placeName,
      slivers: [
        SliverContent(
          sliver: SliverList.list(children: [
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(AppSpace.xl),
                  child: Center(child: CircularProgressIndicator()))
            else if (_missing)
              AppGroup(children: [
                AppRow(
                    title: l.migrationNeeded('0025'),
                    titleStyle: AppText.callout),
              ])
            else ...[
              AppGroup(footer: l.vpsSiteIntro, children: [
                AppRow(
                  leading: const LeadingIcon(AppIcons.scan),
                  title: l.vpsSiteState,
                  value: s == null ? l.vpsSiteNone : l.vpsSiteMarks(s.marks),
                  chevron: false,
                ),
                if (s != null)
                  AppRow(
                    leading: const LeadingIcon.neutral(AppIcons.key),
                    title: l.vpsPayload,
                    value: payloadPreview(s.payload),
                    chevron: false,
                  ),
                if (s?.updatedAt != null)
                  AppRow(
                    leading: const LeadingIcon.neutral(AppIcons.clock),
                    title: l.vpsSiteUpdated,
                    value: l.dateTime(s!.updatedAt!),
                    chevron: false,
                  ),
              ]),
              if (widget.canEdit) ...[
                AppGroup(
                    header: s == null ? l.vpsSiteAdd : l.vpsSiteEdit,
                    children: [
                      TextField(
                        controller: _name,
                        maxLength: 80,
                        decoration: InputDecoration(
                            labelText: l.vpsSiteName, counterText: ''),
                      ),
                      TextField(
                        controller: _payload,
                        minLines: 2,
                        maxLines: 5,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                            labelText: l.vpsPayload,
                            hintText: l.vpsPayloadHint,
                            errorText: _payloadError,
                            errorMaxLines: 3),
                      ),
                    ]),
                AppButton.primary(
                    label: l.commonSave, loading: _saving, onPressed: _save),
                if (s != null) ...[
                  const SizedBox(height: AppSpace.s),
                  AppButton.destructive(
                      label: l.vpsSiteDelete, onPressed: _delete),
                ],
              ] else
                AppGroup(children: [
                  AppRow(title: l.vpsReadOnly, titleStyle: AppText.callout),
                ]),
            ],
          ]),
        ),
      ],
    );
  }
}
