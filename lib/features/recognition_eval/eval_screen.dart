import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';
import '../equipment/equipment_kinds.dart';
import '../regions/geo_pickers.dart' show ListPickerSheet;
import 'eval_add_photo.dart';
import 'eval_models.dart';
import 'eval_photos_screen.dart';
import 'eval_report_screen.dart';
import 'eval_repository.dart';
import 'eval_runner.dart';

/// «Моя компания» → «Тест распознавания» (шаг 34, только администратор):
/// набор фото со своей разметкой → заморозка test → прогон тем же путём, что
/// у пользователей → отчёт с интервалами. Права проверяет база (0028).
class EvalScreen extends StatefulWidget {
  const EvalScreen({super.key, this.repo});
  final EvalRepository? repo;

  @override
  State<EvalScreen> createState() => _EvalScreenState();
}

class _EvalScreenState extends State<EvalScreen> {
  late final EvalRepository _repo = widget.repo ?? EvalRepository();
  String? _companyId;
  String _companyName = '';
  List<EvalSet> _sets = const [];
  List<EvalSample> _samples = const [];
  List<EvalRun> _runs = const [];
  List<EvalProvider> _providers = const [];
  bool _providersFailed = false;
  String _provider = 'default';
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;

  // Идущий прогон.
  EvalRunner? _runner;
  EvalRun? _activeRun;
  EvalRunTotals? _totals;
  final Map<String, int> _resultCounts = {};

  /// Выбранный набор (по умолчанию — самый новый).
  String? _selectedId;
  EvalSet? get _set => _sets.isEmpty
      ? null
      : _sets.firstWhere((x) => x.id == _selectedId, orElse: () => _sets.first);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _runner?.stop();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      _companyId ??= await DirectoryRepo().myCompanyId();
      if (_companyId != null && _companyName.isEmpty) {
        final c = await Supabase.instance.client
            .from('companies')
            .select('name')
            .eq('id', _companyId!)
            .maybeSingle();
        _companyName = (c?['name'] as String?) ?? '';
      }
      final sets = await _repo.sets();
      final set = sets.isEmpty
          ? null
          : sets.firstWhere((x) => x.id == _selectedId,
              orElse: () => sets.first);
      final r = await Future.wait<Object>([
        if (set != null)
          _repo.samples(set.id)
        else
          Future.value(<EvalSample>[]),
        if (set != null) _repo.runs(set.id) else Future.value(<EvalRun>[]),
      ]);
      final runs = r[1] as List<EvalRun>;
      for (final run in runs.where((x) => x.running)) {
        _resultCounts[run.id] = await _repo.resultCount(run.id);
      }
      if (!mounted) return;
      setState(() {
        _sets = sets;
        _samples = r[0] as List<EvalSample>;
        _runs = runs;
        _loading = false;
      });
    } catch (e) {
      debugPrint('eval load: ${e.runtimeType}');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
    if (_providers.isEmpty && !_providersFailed) unawaited(_loadProviders());
  }

  Future<void> _loadProviders() async {
    try {
      final p = await _repo.providers();
      if (mounted) {
        setState(() {
          _providers = p;
          _providersFailed = p.isEmpty;
        });
      }
    } catch (e) {
      debugPrint('eval providers: ${e.runtimeType}');
      if (mounted) setState(() => _providersFailed = true);
    }
  }

  String _setName(AppLocalizations l, int n) =>
      l.evalSetName(n, l.date(DateTime.now()));

  /// Набор для новых фото: выбранный или самый новый незамороженный, иначе — новый.
  Future<EvalSet?> _writableSet() async {
    final set = _set;
    if (set != null && !set.frozen) return set;
    final open = _sets.where((x) => !x.frozen).firstOrNull;
    if (open != null) {
      _selectedId = open.id;
      return open;
    }
    final l = context.l10n;
    final companyId = _companyId;
    if (companyId == null) return null;
    final created = await _repo.createSet(
        companyId: companyId, name: _setName(l, _sets.length + 1));
    setState(() {
      _sets = [created, ..._sets];
      _selectedId = created.id;
      _samples = const [];
      _runs = const [];
    });
    return created;
  }

  Future<void> _addPhoto() async {
    final l = context.l10n;
    EvalSet? set;
    try {
      set = await _writableSet();
    } catch (e) {
      debugPrint('eval set: ${e.runtimeType}');
    }
    if (!mounted) return;
    if (set == null || _companyId == null) {
      showAppMessage(context, l.evalRunFailed, type: AppMessageType.error);
      return;
    }
    await Navigator.push(
        context,
        appRoute(
            (_) => EvalAddPhotoScreen(
                set: set!, companyId: _companyId!, repo: _repo),
            title: l.evalTitle));
    if (mounted) await _load();
  }

  Future<void> _openPhotos() async {
    final set = _set;
    if (set == null) return;
    await Navigator.push(
        context,
        appRoute(
            (_) => EvalPhotosScreen(set: set, samples: _samples, repo: _repo),
            title: context.l10n.evalTitle));
    if (mounted) await _load();
  }

  Future<void> _freeze() async {
    final l = context.l10n;
    final set = _set;
    if (set == null) return;
    final ok = await showAppDialog<bool>(
      context: context,
      title: l.evalFreezeTitle,
      message: l.evalFreezeText,
      actions: [
        AppDialogAction(l.commonCancel, false),
        AppDialogAction(l.evalFreezeConfirm, true, primary: true),
      ],
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.freeze(set.id);
      if (mounted) showAppMessage(context, l.evalFrozenDone);
    } catch (e) {
      debugPrint('eval freeze: $e');
      if (mounted) {
        showAppMessage(
            context,
            '$e'.contains('eval_empty_test')
                ? l.evalFreezeNoTest
                : l.evalRunFailed,
            type: AppMessageType.error);
      }
    }
    if (mounted) {
      setState(() => _busy = false);
      await _load();
    }
  }

  Future<void> _start(String split) async {
    final l = context.l10n;
    final set = _set;
    if (set == null) return;
    setState(() => _busy = true);
    try {
      final id = await _repo.startRun(set.id, split, _provider);
      final runs = await _repo.runs(set.id);
      if (!mounted) return;
      setState(() => _runs = runs);
      final run = runs.firstWhere((r) => r.id == id);
      await _execute(run);
    } catch (e) {
      debugPrint('eval start: $e');
      if (mounted) {
        showAppMessage(context, l.evalRunFailed, type: AppMessageType.error);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Распознать все фото прогона без ответа (и с ошибкой ИИ) пачками.
  Future<void> _execute(EvalRun run) async {
    final l = context.l10n;
    final answered = await _repo.answeredSampleIds(run.id);
    final ids = [
      for (final s in _samples)
        if (s.split == run.split && !answered.contains(s.id)) s.id
    ];
    final runner = EvalRunner(call: (id) => _repo.runOne(run.id, id));
    setState(() {
      _runner = runner;
      _activeRun = run;
      _totals = EvalRunTotals(total: ids.length);
    });
    String? fatal;
    EvalRunTotals? totals;
    try {
      totals = await runner.run(ids, onProgress: (t) {
        if (mounted) setState(() => _totals = t);
      });
    } on EvalFatal catch (e) {
      fatal = e.code;
    }
    final count = await _repo.resultCount(run.id).catchError((_) => 0);
    if (!mounted) return;
    setState(() {
      _runner = null;
      _activeRun = null;
      _resultCounts[run.id] = count;
    });
    if (fatal != null) {
      showAppMessage(
          context,
          switch (fatal) {
            'provider_not_configured' => l.evalProviderMissing,
            'eval_config_changed' => l.evalConfigChanged,
            _ => l.evalRunFailed,
          },
          type: AppMessageType.error);
      return;
    }
    if (totals == null || runner.stopped) return;
    showAppMessage(
        context, l.evalRunSummary(totals.ok, totals.aiErrors, totals.failed));
    // Всё распознано без ошибок — прогон закрывается сам и открывается отчёт.
    if (count >= run.sampleCount &&
        totals.aiErrors == 0 &&
        totals.failed == 0) {
      await _finish(run, open: true);
    }
  }

  Future<void> _finish(EvalRun run,
      {bool cancel = false, bool open = false}) async {
    try {
      await _repo.finishRun(run.id, cancel: cancel);
    } catch (e) {
      debugPrint('eval finish: $e');
      if (mounted) {
        showAppMessage(context, context.l10n.evalRunFailed,
            type: AppMessageType.error);
      }
      return;
    }
    if (!mounted) return;
    await _load();
    if (open && mounted) _openReport(run.id);
  }

  void _openReport(String runId) {
    Navigator.push(
        context,
        appRoute(
            (_) => EvalReportScreen(
                runId: runId, repo: _repo, companyName: _companyName),
            title: context.l10n.evalTitle));
  }

  Future<void> _onRunTap(EvalRun run) async {
    final l = context.l10n;
    if (!run.running) {
      _openReport(run.id);
      return;
    }
    if (_runner != null) return;
    final done = _resultCounts[run.id] ?? 0;
    final action = await showAppDialog<String>(
      context: context,
      title: l.evalRunRow(run.split, l.dateTime(run.createdAt)),
      message: l.evalRunRunning(done, run.sampleCount),
      actions: [
        AppDialogAction(l.evalCancelRun, 'cancel', destructive: true),
        if (done >= run.sampleCount) AppDialogAction(l.evalFinishRun, 'finish'),
        AppDialogAction(
            done >= run.sampleCount ? l.evalRetryErrors : l.evalContinue,
            'continue',
            primary: true),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'cancel':
        await _finish(run, cancel: true);
      case 'finish':
        await _finish(run, open: true);
      default:
        setState(() => _busy = true);
        await _execute(run);
        if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickSet() async {
    final l = context.l10n;
    final picked = await showAppSheet<String>(
      context: context,
      builder: (ctx) => ListPickerSheet(
        title: l.evalSets,
        search: null,
        children: [
          AppGroup(margin: EdgeInsets.zero, children: [
            for (final x in _sets)
              AppCheckRow(
                title: x.name,
                subtitle: x.frozen
                    ? l.evalSetFrozen(l.dateTime(x.frozenAt!))
                    : l.evalSetOpen,
                selected: x.id == _set?.id,
                onTap: () => Navigator.pop(ctx, x.id),
              ),
          ]),
        ],
      ),
    );
    if (picked == null || !mounted || picked == _set?.id) return;
    _selectedId = picked;
    await _load();
  }

  Future<void> _pickProvider() async {
    final l = context.l10n;
    final picked = await showAppSheet<String>(
      context: context,
      builder: (ctx) => ListPickerSheet(
        title: l.evalProvider,
        search: null,
        children: [
          AppGroup(margin: EdgeInsets.zero, children: [
            for (final p in _providers)
              AppCheckRow(
                title: _providerLabel(l, p),
                selected: p.id == _provider,
                onTap: () => Navigator.pop(ctx, p.id),
              ),
          ]),
        ],
      ),
    );
    if (picked != null && mounted) setState(() => _provider = picked);
  }

  String _providerLabel(AppLocalizations l, EvalProvider p) => p.id == 'default'
      ? l.evalProviderDefault(p.model)
      : l.evalProviderOther(p.provider, p.model);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final running = _runner != null;
    return AppScaffold(
      title: l.evalTitle,
      onRefresh: running ? null : _load,
      bottomBar: _loading || _failed
          ? null
          : BottomActionBar(
              child: running
                  ? AppButton.secondary(
                      icon: AppIcons.close,
                      label: l.evalStop,
                      onPressed: () => setState(() => _runner?.stop()),
                    )
                  : AppButton.primary(
                      icon: AppIcons.camera,
                      label: l.evalAddPhoto,
                      onPressed: _busy ? null : _addPhoto,
                    ),
            ),
      slivers: [
        if (_loading)
          const SliverFillRemaining(hasScrollBody: false, child: AppLoader())
        else if (_failed)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
                text: l.evalRunFailed,
                error: true,
                actionLabel: l.commonRetry,
                onAction: _load),
          )
        else
          SliverContent(
            sliver: SliverList.list(children: _body(l)),
          ),
        const SliverBottomInset(),
      ],
    );
  }

  List<Widget> _body(AppLocalizations l) {
    final set = _set;
    final sum = EvalSummary.of(_samples);
    final running = _runner != null;
    return [
      AppGroup(footer: l.evalIntro, children: [
        AppRow(
          leading: const LeadingIcon(AppIcons.checklist),
          title: set?.name ?? l.evalTitle,
          titleStyle: AppText.headline,
          subtitle: set == null
              ? l.evalEmpty
              : set.frozen
                  ? l.evalSetFrozen(l.dateTime(set.frozenAt!))
                  : l.evalSetOpen,
          subtitleMaxLines: 3,
          chevron: _sets.length > 1,
          onTap: _sets.length > 1 && !running ? _pickSet : null,
        ),
        if (set != null && set.frozen)
          AppRow(
            leading: const LeadingIcon(AppIcons.add),
            title: l.evalNewSet,
            subtitle: l.evalNewSetHint,
            onTap: _busy || running ? null : _addPhoto,
          ),
      ]),
      if (set != null && _samples.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpace.group),
          child: Row(children: [
            for (final (i, kpi) in [
              ('${sum.photos}', l.evalKpiPhotos),
              ('${sum.units}', l.evalKpiUnits),
              ('${sum.rooms}', l.evalKpiRooms),
              ('${sum.sites}', l.evalKpiSites),
            ].indexed) ...[
              if (i > 0) const SizedBox(width: AppSpace.s),
              Expanded(child: KpiTile(value: kpi.$1, label: kpi.$2)),
            ],
          ]),
        ),
        AppGroup(children: [
          AppRow(
            leading: const LeadingIcon(AppIcons.image),
            title: l.evalPhotos,
            subtitle: l.evalSplitLine(sum.dev, sum.test, sum.unregistered),
            value: '${sum.photos}',
            onTap: _openPhotos,
          ),
          AppRow(
            leading: const LeadingIcon(AppIcons.info),
            title: sum.remaining == 0
                ? l.evalTargetReached
                : l.evalToTarget(sum.remaining),
            chevron: false,
          ),
        ]),
        AppGroup(header: l.evalByKind, children: [
          for (final e in sum.byKind.take(12))
            AppRow(
              leading: LeadingIcon(e.key == kEvalUnregisteredKey
                  ? AppIcons.eqOther
                  : assetIcon(e.key, 'equipment')),
              title: switch (e.key) {
                kEvalUnregisteredKey => l.evalNotInRegistry,
                'unknown' => l.evalUnknownKind,
                _ => equipmentKindLabel(l, e.key),
              },
              value: '${e.value}',
              chevron: false,
            ),
        ]),
        if (!set.frozen)
          AppGroup(children: [
            AppRow(
              leading: const LeadingIcon(AppIcons.lock),
              title: l.evalFreeze,
              subtitle: l.evalFreezeText,
              subtitleMaxLines: 3,
              onTap: _busy || running || sum.test == 0 ? null : _freeze,
            ),
          ]),
        _runGroup(l, set, sum),
      ],
      if (_runs.isNotEmpty)
        AppGroup(header: l.evalRuns, children: [
          for (final r in _runs)
            AppRow(
              leading: LeadingIcon(r.running
                  ? AppIcons.clock
                  : r.status == 'done'
                      ? AppIcons.check
                      : AppIcons.close),
              title: l.evalRunRow(r.split, l.dateTime(r.createdAt)),
              subtitle: [
                if (r.running)
                  l.evalRunRunning(_resultCounts[r.id] ?? 0, r.sampleCount)
                else if (r.status == 'done')
                  l.evalRunDone(r.sampleCount)
                else
                  l.evalRunCancelled,
                if (r.model != null) '${r.provider} · ${r.model}',
              ].join(' · '),
              onTap: running ? null : () => _onRunTap(r),
            ),
        ]),
    ];
  }

  Widget _runGroup(AppLocalizations l, EvalSet set, EvalSummary sum) {
    final running = _runner != null;
    final t = _totals;
    final providerRow = _providers.isEmpty
        ? AppRow(
            leading: const LeadingIcon(AppIcons.sparkles),
            title: l.evalProvider,
            subtitle: _providersFailed ? l.evalProviderUnknown : null,
            subtitleMaxLines: 3,
            chevron: false,
          )
        : AppRow(
            leading: const LeadingIcon(AppIcons.sparkles),
            title: l.evalProvider,
            subtitle: _providerLabel(
                l,
                _providers.firstWhere((p) => p.id == _provider,
                    orElse: () => _providers.first)),
            onTap: running || _providers.length < 2 ? null : _pickProvider,
            chevron: _providers.length > 1,
          );
    return AppGroup(header: l.evalRunHeader, footer: l.evalRunRule, children: [
      providerRow,
      if (running && t != null)
        AppRow(
          leading: const LeadingIcon(AppIcons.refresh),
          title: l.evalRunning(t.done, t.total),
          subtitle: _activeRun == null
              ? null
              : l.evalRunRow(
                  _activeRun!.split, l.dateTime(_activeRun!.createdAt)),
          extra: Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpace.xs),
            child: LinearProgressIndicator(
                value: t.progress,
                color: AppColors.accent,
                backgroundColor: AppColors.fill),
          ),
          chevron: false,
        )
      else ...[
        AppRow(
          leading: const LeadingIcon(AppIcons.play),
          title: l.evalRunDev,
          value: '${sum.dev}',
          onTap: _busy || sum.dev == 0 ? null : () => _start('dev'),
        ),
        AppRow(
          leading: const LeadingIcon(AppIcons.verified),
          title: l.evalRunTest,
          subtitle: set.frozen ? null : l.evalRunNeedsFreeze,
          value: '${sum.test}',
          onTap: _busy || !set.frozen || sum.test == 0
              ? null
              : () => _start('test'),
        ),
      ],
    ]);
  }
}
