import 'package:flutter/material.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/schema_compat.dart';
import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';
import '../requests/order_list.dart';
import 'ppr_form.dart';
import 'ppr_logic.dart';
import 'ppr_repository.dart';
import 'ppr_tab.dart';
import 'ppr_text.dart';
import 'ppr_view.dart';

/// Карточка плана ППР: что, где, как часто, кто; чек-лист; история
/// периодов (последние 12) с переходом в задачу. Менеджер — изменить,
/// приостановить / возобновить, удалить (только без задач).
class PprPlanCardScreen extends StatefulWidget {
  const PprPlanCardScreen(
      {super.key, required this.planId, required this.data});
  final String planId;
  final PprData data;

  @override
  State<PprPlanCardScreen> createState() => _PprPlanCardScreenState();
}

class _PprPlanCardScreenState extends State<PprPlanCardScreen> {
  final _repo = PprRepository();
  MaintenancePlan? _plan;
  List<PlanTask> _tasks = const [];
  String? _placeName;
  String? _assetName;
  bool _loading = true;
  bool _failed = false;

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
    try {
      final plan = await _repo.plan(widget.planId);
      if (plan == null) throw StateError('plan not found');
      final tasks = await _repo.tasks(planId: plan.id);
      String? place;
      if (plan.locationId != null) {
        final places = await DirectoryRepo().placesOf(plan.objectId);
        for (final p in places) {
          if (p.id == plan.locationId) place = p.label;
        }
      }
      final asset =
          plan.assetId == null ? null : await _repo.assetName(plan.assetId!);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _tasks = tasks;
        _placeName = place;
        _assetName = asset;
        _loading = false;
      });
    } catch (e) {
      debugPrint('PprCard: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  PlanView? _view() {
    final p = _plan;
    if (p == null) return null;
    final d = widget.data;
    final v = buildPlanViews(
        plans: [p],
        tasks: _tasks,
        objects: d.objects,
        layers: d.layers,
        contractors: d.contractors,
        bindings: d.bindings);
    return v.isEmpty ? null : v.first;
  }

  Future<void> _openTask(PlanTask t) async {
    final ctx = await OrderContext.load();
    if (!mounted) return;
    await ctx.open(context, t.row);
    if (mounted) await _load();
  }

  Future<void> _edit() async {
    final p = _plan;
    if (p == null) return;
    final saved = await Navigator.push<bool>(
        context,
        appRoute((_) => PprPlanFormScreen(data: widget.data, plan: p),
            title: p.title));
    if (saved == true && mounted) {
      showAppMessage(context, context.l10n.pprSaved,
          type: AppMessageType.success);
      await _load();
    }
  }

  Future<void> _toggleActive() async {
    final l = context.l10n;
    final p = _plan;
    if (p == null) return;
    try {
      await _repo.setActive(p.id, !p.active);
      if (!mounted) return;
      showAppMessage(context, p.active ? l.pprPaused : l.pprResumed,
          type: AppMessageType.success);
      await _load();
    } catch (e) {
      debugPrint('PprCard active: $e');
      if (mounted) {
        showAppMessage(context, l.saveFailed, type: AppMessageType.error);
      }
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final p = _plan;
    if (p == null) return;
    if (_tasks.isNotEmpty) {
      showAppMessage(context, l.pprDeleteHasTasks, type: AppMessageType.error);
      return;
    }
    final ok = await showAppDialog<bool>(
      context: context,
      title: l.pprDelete,
      message: l.pprDeleteConfirm(p.title),
      actions: [
        AppDialogAction(l.commonCancel, false),
        AppDialogAction(l.pprDelete, true, destructive: true),
      ],
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.delete(p.id);
      if (!mounted) return;
      showAppMessage(context, l.pprDeleted, type: AppMessageType.success);
      Navigator.pop(context);
    } on PlanHasTasks {
      if (mounted) {
        showAppMessage(context, l.pprDeleteHasTasks,
            type: AppMessageType.error);
      }
    } on MigrationMissing {
      if (mounted) {
        showAppMessage(context, l.migrationNeeded('0015'),
            type: AppMessageType.error);
      }
    } catch (e) {
      debugPrint('PprCard delete: $e');
      if (mounted) {
        showAppMessage(context, l.saveFailed, type: AppMessageType.error);
      }
    }
  }

  Future<void> _menu(BuildContext anchor) async {
    final l = context.l10n;
    final p = _plan;
    if (p == null) return;
    final a = await showFilterPicker<int>(
      context: anchor,
      builder: (ctx) => AppGroup(margin: EdgeInsets.zero, children: [
        AppRow(
            leading: const LeadingIcon(AppIcons.edit),
            title: l.pprEdit,
            chevron: false,
            onTap: () => Navigator.pop(ctx, 0)),
        AppRow(
            leading: LeadingIcon(p.active ? AppIcons.clock : AppIcons.play),
            title: p.active ? l.pprPause : l.pprResume,
            chevron: false,
            onTap: () => Navigator.pop(ctx, 1)),
        AppRow(
            leading: const LeadingIcon.danger(AppIcons.delete),
            title: l.pprDelete,
            destructive: true,
            chevron: false,
            onTap: () => Navigator.pop(ctx, 2)),
      ]),
    );
    switch (a) {
      case 0:
        await _edit();
      case 1:
        await _toggleActive();
      case 2:
        await _delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = _view();
    final List<Widget> slivers;
    if (_loading && _plan == null) {
      slivers = const [
        SliverFillRemaining(hasScrollBody: false, child: AppLoader())
      ];
    } else if (_failed || v == null) {
      slivers = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
              text: l.cardLoadFailed,
              error: true,
              actionLabel: l.commonRetry,
              onAction: _load),
        ),
      ];
    } else {
      slivers = [
        SliverContent(sliver: SliverList.list(children: _content(l, v))),
      ];
    }
    return AppScaffold(
      title: _plan?.title ?? l.tabPpr,
      eyebrow: v?.objectLabel,
      onRefresh: _load,
      actions: [
        AppIconButton(
            icon: AppIcons.info,
            label: l.pprInfoTitle,
            onPressed: () => showPprInfo(context)),
        if (widget.data.isManager && _plan != null)
          Builder(
            builder: (anchor) => AppIconButton(
                icon: AppIcons.more,
                label: l.pprEdit,
                onPressed: () => _menu(anchor)),
          ),
      ],
      slivers: slivers,
      bottomBar: widget.data.isManager && _plan != null
          ? BottomActionBar(
              child: AppButton.tinted(
                  icon: AppIcons.edit, label: l.pprEdit, onPressed: _edit))
          : null,
    );
  }

  List<Widget> _content(AppLocalizations l, PlanView v) {
    final p = v.plan;
    final layer = v.layer?.label(l.localeName);
    final cur = v.current;
    final history = [..._tasks]
      ..sort((a, b) => b.period.start.compareTo(a.period.start));
    return [
      Wrap(spacing: AppSpace.s, runSpacing: AppSpace.s, children: [
        StatusPill(periodStateStatus(v.state),
            label: pprStateLabel(l, v.state), large: true),
        PriorityPill(p.priority, large: true),
      ]),
      const SizedBox(height: AppSpace.m),
      if (p.description != null && p.description!.trim().isNotEmpty) ...[
        Text(p.description!, style: AppText.body),
        const SizedBox(height: AppSpace.m),
      ],
      AppGroup(children: [
        AppRow(
            leading: const LeadingIcon(AppIcons.building),
            title: l.fieldObject,
            value: v.objectLabel.isEmpty ? '—' : v.objectLabel),
        if (_placeName != null)
          AppRow(
              leading: const LeadingIcon(AppIcons.room),
              title: l.reqFieldPlace,
              value: _placeName),
        if (_assetName != null)
          AppRow(
              leading: const LeadingIcon(AppIcons.wrench),
              title: l.pprAsset,
              value: _assetName),
        AppRow(
            leading: const LeadingIcon(AppIcons.workType),
            title: l.pprFormSystem,
            value: layer ?? '—'),
        AppRow(
            leading: const LeadingIcon(AppIcons.repeat),
            title: l.pprCardPeriodicity,
            subtitle: l.pprCardStarts(l.date(p.startsOn)),
            value: pprEvery(l, p.kind, p.days)),
        AppRow(
            leading: const LeadingIcon(AppIcons.contractor),
            title: l.fieldContractor,
            subtitle: v.contractor?.orgName ?? l.pprNoContractor,
            subtitleMaxLines: 2),
      ]),
      AppGroup(header: l.pprCardCurrent, children: [
        AppRow(
          leading: const LeadingIcon(AppIcons.calendar),
          title: pprPeriodText(l, p.kind, v.period),
          subtitle: cur == null
              ? l.pprCardNoTask
              : l.pprTaskLine(pprPeriodText(l, p.kind, v.period),
                  shortDay(v.period.end, l.localeName)),
          trailing: StatusPill(periodStateStatus(v.state),
              label: pprStateLabel(l, v.state)),
          chevron: cur != null,
          onTap: cur == null ? null : () => _openTask(cur),
        ),
      ]),
      if (p.checklist.isNotEmpty)
        AppGroup(header: l.pprCardChecklist, children: [
          for (final item in p.checklist)
            AppRow(
                leading: const LeadingIcon(AppIcons.check),
                title: item,
                titleStyle: AppText.callout,
                chevron: false),
        ]),
      AppGroup(
        header: l.pprCardHistory,
        children: [
          if (history.isEmpty)
            AppRow(title: l.pprCardHistoryEmpty, chevron: false),
          for (final t in history.take(12)) _historyRow(l, p, t),
        ],
      ),
    ];
  }

  Widget _historyRow(AppLocalizations l, MaintenancePlan p, PlanTask t) {
    final state = periodState(active: true, task: t.status, period: t.period);
    final accepted = t.acceptedAt == null
        ? null
        : (t.acceptedBy == null || t.acceptedBy!.isEmpty
            ? l.pprAcceptedAt(l.dateTime(t.acceptedAt!))
            : l.pprAcceptedBy(l.dateTime(t.acceptedAt!), t.acceptedBy!));
    String? contractor;
    for (final c in widget.data.contractors) {
      if (c.id == t.contractorId) contractor = c.orgName;
    }
    return AppRow(
      title: pprPeriodText(l, p.kind, t.period),
      subtitle: [
        if (contractor != null) contractor,
        if (accepted != null) accepted,
      ].join('\n'),
      trailing: state == PeriodState.overdue || state == PeriodState.done
          ? StatusPill(periodStateStatus(state), label: pprStateLabel(l, state))
          : StatusPill(t.status),
      onTap: () => _openTask(t),
    );
  }
}
