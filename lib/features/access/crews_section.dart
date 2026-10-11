import 'package:flutter/material.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/schema_compat.dart';
import '../directory/directory.dart';
import 'zone_editor.dart';
import 'zone_logic.dart';
import 'zone_repository.dart';

/// Карточка подрядчика → «Бригады» (шаг 17, необязательно). Без бригад —
/// свёрнутая группа с подсказкой ⓘ. Менеджер заводит бригады; права
/// проверяет база (0016). Без 0016 — пометка «Нужна миграция 0016».
class CrewsSection extends StatefulWidget {
  const CrewsSection({
    super.key,
    required this.contractorId,
    required this.executors,
    required this.isManager,
    this.companyId,
  });

  final String contractorId;
  final List<ExecutorPerson> executors;
  final bool isManager;
  final String? companyId;

  @override
  State<CrewsSection> createState() => _CrewsSectionState();
}

class _CrewsSectionState extends State<CrewsSection> {
  final _repo = ZoneRepository();
  List<Crew> _crews = const [];
  bool _missing = false;
  bool _loaded = false;
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _companyId = widget.companyId;
    _load();
  }

  Future<void> _load() async {
    try {
      final crews = await _repo.crewsOf(widget.contractorId);
      _companyId ??= await DirectoryRepo().myCompanyId();
      if (mounted) {
        setState(() {
          _crews = crews;
          _loaded = true;
        });
      }
    } on MigrationMissing {
      if (mounted) setState(() => _missing = true);
    } catch (e) {
      debugPrint('Crews: $e');
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _open(Crew? crew) async {
    final cid = _companyId;
    if (cid == null) return;
    final changed = await Navigator.push<bool>(
        context,
        appRoute(
            (_) => CrewScreen(
                crew: crew,
                contractorId: widget.contractorId,
                companyId: cid,
                executors: widget.executors,
                canEdit: widget.isManager),
            title: context.l10n.crewSection));
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final info = AppInfoButton(
        title: l.crewInfoTitle,
        lines: [l.crewInfo1, l.crewInfo2, l.crewInfo3],
        closeLabel: l.commonGotIt);
    if (_missing) {
      return AppGroup(
          header: l.crewSection,
          headerTrailing: info,
          footer: l.migrationNeeded('0016'),
          children: const []);
    }
    if (!_loaded) return const SizedBox.shrink();
    return AppGroup(
      header: l.crewSection,
      headerTrailing: info,
      footer: _crews.isEmpty ? l.crewEmpty : null,
      children: [
        for (final c in _crews)
          AppRow(
            leading: const LeadingIcon(AppIcons.users),
            title: c.name,
            subtitle: l.crewMembersCount(c.executorIds.length),
            onTap: () => _open(c),
          ),
        if (widget.isManager)
          AppRow(
            leading: const LeadingIcon(AppIcons.add),
            title: l.crewAdd,
            chevron: false,
            onTap: () => _open(null),
          ),
      ],
    );
  }
}

/// Бригада: название, исполнители подрядчика, зона бригады.
class CrewScreen extends StatefulWidget {
  const CrewScreen({
    super.key,
    required this.crew,
    required this.contractorId,
    required this.companyId,
    required this.executors,
    required this.canEdit,
  });

  final Crew? crew;
  final String contractorId;
  final String companyId;
  final List<ExecutorPerson> executors;
  final bool canEdit;

  @override
  State<CrewScreen> createState() => _CrewScreenState();
}

class _CrewScreenState extends State<CrewScreen> {
  final _repo = ZoneRepository();
  late final _name = TextEditingController(text: widget.crew?.name ?? '');
  late Set<String> _members = {...?widget.crew?.executorIds};
  late List<ZoneRule> _rules = groupRules(widget.crew?.zones ?? const []);
  ZoneRefs? _refs;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ZoneRefs.load(widget.crew?.zones ?? const [], repo: _repo).then((r) {
      if (mounted) setState(() => _refs = r);
    }, onError: (e) => debugPrint('Crew refs: $e'));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 60) {
      showAppMessage(context, l.crewNameRequired, type: AppMessageType.error);
      return;
    }
    setState(() => _busy = true);
    try {
      await _repo.saveCrew(
          id: widget.crew?.id,
          companyId: widget.companyId,
          contractorId: widget.contractorId,
          name: name,
          executorIds: _members,
          zones: rulesToRows(_rules));
      if (!mounted) return;
      showAppMessage(context, l.crewSaved, type: AppMessageType.success);
      Navigator.pop(context, true);
    } on CrewDuplicate {
      if (mounted) {
        showAppMessage(context, l.crewDuplicate, type: AppMessageType.error);
      }
    } on MigrationMissing {
      if (mounted) {
        showAppMessage(context, l.migrationNeeded('0016'),
            type: AppMessageType.error);
      }
    } catch (e) {
      debugPrint('Crew save: $e');
      if (mounted) {
        showAppMessage(context, l.zoneRefused, type: AppMessageType.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final c = widget.crew;
    if (c == null) return;
    final ok = await showAppDialog<bool>(
      context: context,
      title: l.crewDelete,
      message: l.crewDeleteConfirm(c.name),
      actions: [
        AppDialogAction(l.commonCancel, false),
        AppDialogAction(l.crewDelete, true, destructive: true),
      ],
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deleteCrew(c.id);
      if (!mounted) return;
      showAppMessage(context, l.crewDeleted, type: AppMessageType.success);
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Crew delete: $e');
      if (mounted) {
        showAppMessage(context, l.zoneRefused, type: AppMessageType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final refs = _refs;
    return AppScaffold(
      title: widget.crew?.name ?? l.crewAdd,
      large: false,
      actions: [
        AppIconButton(
            icon: AppIcons.info,
            label: l.crewInfoTitle,
            onPressed: () => showCrewInfo(context)),
      ],
      bottomBar: widget.canEdit
          ? BottomActionBar(
              child: AppButton.primary(
                  label: l.commonSave,
                  loading: _busy,
                  onPressed: _busy ? null : _save))
          : null,
      slivers: [
        SliverContent(
          sliver: SliverList.list(children: [
            SectionHeader(l.crewName),
            TextField(
              controller: _name,
              enabled: widget.canEdit,
              maxLength: 60,
              decoration:
                  InputDecoration(hintText: l.crewNameHint, counterText: ''),
            ),
            const SizedBox(height: AppSpace.group),
            AppGroup(header: l.crewMembers, children: [
              if (widget.executors.isEmpty)
                AppRow(
                    title: l.crewNoExecutors,
                    titleStyle: AppText.callout,
                    chevron: false),
              for (final e in widget.executors)
                AppCheckRow(
                  title: e.name?.isNotEmpty == true
                      ? e.name!
                      : l.profileDefaultName,
                  subtitle: e.phone,
                  selected: _members.contains(e.id),
                  onTap: widget.canEdit
                      ? () => setState(() => _members = _members.contains(e.id)
                          ? ({..._members}..remove(e.id))
                          : {..._members, e.id})
                      : () {},
                ),
            ]),
            if (refs == null)
              const AppLoader()
            else
              ZoneRulesGroup(
                header: l.crewZone,
                footer: l.crewZoneHint,
                rules: _rules,
                refs: refs,
                enabled: widget.canEdit,
                onChanged: (r) => setState(() => _rules = r),
              ),
            if (widget.canEdit && widget.crew != null)
              AppGroup(children: [
                AppRow(
                  leading: const LeadingIcon.danger(AppIcons.delete),
                  title: l.crewDelete,
                  destructive: true,
                  chevron: false,
                  onTap: _delete,
                ),
              ]),
          ]),
        ),
      ],
    );
  }
}
