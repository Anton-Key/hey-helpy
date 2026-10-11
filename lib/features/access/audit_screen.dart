import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/schema_compat.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_role.dart';
import '../floors/plan_sheets.dart' show SheetAction, showActionSheet;
import '../profile/profile_repository.dart';
import 'audit_logic.dart';
import 'zone_editor.dart';
import 'zone_logic.dart';

/// Журнал изменений доступа (шаг 18): «Моя компания» → «Журнал доступа».
/// Только чтение и только администратор (политика access_audit в 0016):
/// кто, когда и что изменил в зонах, бригадах и ролях. Фильтр — сотрудник.
class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key, required this.companyId});
  final String companyId;

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  List<AuditItem> _items = const [];
  Map<String, Member> _people = const {};
  Map<String, String> _crews = const {};
  ZoneRefs? _refs;
  String? _person;
  bool _loading = true;
  bool _failed = false;
  bool _noMigration = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final c = Supabase.instance.client;
    try {
      final rows = await SchemaCompat.run(
          '0016',
          () => c
              .from('access_audit')
              .select('id,actor,action,entity,target,details,created_at')
              .order('created_at', ascending: false)
              .limit(500));
      final entries = [
        for (final r in rows as List)
          AuditEntry.fromMap(r as Map<String, dynamic>)
      ];
      final items = groupAudit(entries);
      final r = await Future.wait<Object>([
        ProfileRepository().members(widget.companyId),
        c.from('crews').select('id,name'),
        ZoneRefs.load([
          for (final i in items) ...[...i.added, ...i.removed]
        ]),
      ]);
      if (!mounted) return;
      setState(() {
        _items = items;
        _people = {for (final m in r[0] as List<Member>) m.id: m};
        _crews = {
          for (final x in r[1] as List)
            (x as Map)['id'] as String: x['name'] as String? ?? ''
        };
        _refs = r[2] as ZoneRefs;
        _loading = false;
        _noMigration = false;
      });
    } on MigrationMissing {
      if (mounted) {
        setState(() {
          _loading = false;
          _noMigration = true;
        });
      }
    } catch (e) {
      debugPrint('Audit: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  String _name(AppLocalizations l, String? id) {
    if (id == null) return l.auditSystem;
    final m = _people[id];
    final n = m?.fullName;
    return (n != null && n.isNotEmpty) ? n : l.auditUnknownPerson;
  }

  String _zones(AppLocalizations l, List<ZoneRow> rows) {
    final refs = _refs;
    if (refs == null) return '';
    final n = refs.names(l);
    return groupRules(rows).map((r) => ruleSummary(r, n)).join('; ');
  }

  ({String title, String? detail}) _describe(AppLocalizations l, AuditItem i) {
    String role(String? code) => l.role(UserRole.fromString(code));
    final crew = _crews[i.targetId] ?? '';
    switch (i.kind) {
      case AuditKind.role:
        return (
          title: l.auditRole(_name(l, i.targetId)),
          detail: '${role(i.from)} → ${role(i.to)}'
        );
      case AuditKind.zone:
        return (
          title: l.auditZone(_name(l, i.targetId)),
          detail: [
            if (i.removed.isNotEmpty) l.auditWas(_zones(l, i.removed)),
            i.added.isEmpty
                ? l.auditNowWholeCompany
                : l.auditNow(_zones(l, i.added)),
          ].join('\n')
        );
      case AuditKind.crewCreated:
        return (title: l.auditCrewCreated(i.to ?? ''), detail: null);
      case AuditKind.crewRenamed:
        return (
          title: l.auditCrewRenamed(i.to ?? ''),
          detail: l.auditWas(i.from ?? '')
        );
      case AuditKind.crewDeleted:
        return (title: l.auditCrewDeleted(i.from ?? ''), detail: null);
      case AuditKind.crewMembers:
        return (
          title: l.auditCrewMembers(crew),
          detail: [
            if (i.membersAdded > 0) '+${i.membersAdded}',
            if (i.membersRemoved > 0) '−${i.membersRemoved}',
          ].join(' · ')
        );
      case AuditKind.crewZone:
        return (
          title: l.auditCrewZone(crew),
          detail: i.added.isEmpty
              ? l.auditCrewZoneNone
              : l.auditNow(_zones(l, i.added))
        );
      case AuditKind.other:
        return (title: l.auditOther(i.entity), detail: null);
    }
  }

  Future<void> _pickPerson() async {
    final l = context.l10n;
    final ids = auditPeople(_items).toList()
      ..sort((a, b) => _name(l, a).compareTo(_name(l, b)));
    final pick = await showActionSheet<String>(context,
        title: l.auditFilterPerson,
        actions: [
          SheetAction('', l.auditAllPeople, AppIcons.users),
          for (final id in ids) SheetAction(id, _name(l, id), AppIcons.user),
        ]);
    if (pick == null || !mounted) return;
    setState(() => _person = pick.isEmpty ? null : pick);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppScaffold(
      title: l.auditTitle,
      onRefresh: _load,
      slivers: [_body(l), const SliverBottomInset()],
    );
  }

  Widget _body(AppLocalizations l) {
    if (_loading && _items.isEmpty) {
      return const SliverFillRemaining(
          hasScrollBody: false, child: AppLoader());
    }
    if (_noMigration) {
      return SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
              icon: AppIcons.key, text: l.migrationNeeded('0016')));
    }
    if (_failed) {
      return SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
              text: l.auditLoadFailed,
              error: true,
              actionLabel: l.commonRetry,
              onAction: _load));
    }
    final shown = [
      for (final i in _items)
        if (_person == null || i.involves(_person!)) i
    ];
    return SliverContent(
      sliver: SliverList.list(children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpace.m),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppFilterChip(
              label: l.auditFilterPerson,
              activeLabel: _person == null ? null : _name(l, _person),
              icon: AppIcons.user,
              onTap: _pickPerson,
              onClear:
                  _person == null ? null : () => setState(() => _person = null),
            ),
          ),
        ),
        if (shown.isEmpty)
          AppEmptyState(icon: AppIcons.key, text: l.auditEmpty)
        else
          AppGroup(footer: l.auditFooter, children: [
            for (final i in shown) _row(l, i),
          ]),
      ]),
    );
  }

  Widget _row(AppLocalizations l, AuditItem i) {
    final d = _describe(l, i);
    final icon = switch (i.kind) {
      AuditKind.role => AppIcons.user,
      AuditKind.zone => AppIcons.key,
      AuditKind.other => AppIcons.info,
      _ => AppIcons.users,
    };
    return AppRow(
      leading: LeadingIcon(icon),
      title: d.title,
      subtitle: [
        if (d.detail != null && d.detail!.isNotEmpty) d.detail!,
        l.auditBy(_name(l, i.actorId), l.dateTime(i.at)),
      ].join('\n'),
      chevron: false,
    );
  }
}
