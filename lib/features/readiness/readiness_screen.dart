import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import 'readiness_logic.dart';
import 'readiness_repository.dart';

/// «Моя компания» → «Готовность к показу» (шаг 29, только администратор):
/// за минуту утром перед показом — база, миграции 0017–0025, пять функций,
/// вебхук бота, ответ ИИ (голос и «По фото»), свежесть демо-данных.
/// Дополняет `docs/DEMO_DAY_CHECKLIST.md`. Ничего не меняет в базе.
class ReadinessScreen extends StatefulWidget {
  const ReadinessScreen({super.key, this.repo});
  final ReadinessRepository? repo;

  @override
  State<ReadinessScreen> createState() => _ReadinessScreenState();
}

/// Строка проверки: цвет и подпись (null — ещё проверяется).
typedef _Row = ({CheckLevel level, String text});

class _ReadinessScreenState extends State<ReadinessScreen> {
  late final ReadinessRepository _repo = widget.repo ?? ReadinessRepository();
  final Map<String, _Row> _rows = {};
  int _run = 0;

  static const _keys = [
    'db', 'migrations', //
    'fnVoice', 'fnPhoto', 'fnBot', 'fnNotify', 'fnOffline', 'webhook', //
    'aiVoice', 'aiPhoto', 'photoLog', 'demo',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_run == 0) _check();
  }

  bool get _running => _rows.length < _keys.length;

  void _set(int run, String key, CheckLevel level, String text) {
    if (!mounted || run != _run) return;
    setState(() => _rows[key] = (level: level, text: text));
  }

  Future<void> _check() async {
    final l = context.l10n;
    final run = ++_run;
    setState(_rows.clear);
    final locale = l.localeName.startsWith('ru') ? 'ru' : 'en';
    String sec(int ms) => NumberFormat('0.0', l.localeName).format(ms / 1000);
    String fn(Probe p) => p.status == null
        ? l.readyNoAnswer
        : functionLevel(p.status) == CheckLevel.ok
            ? l.readyFnOk(p.ms)
            : l.readyFnFail(p.status!);

    await Future.wait([
      _repo.pingDb().then((r) => _set(
          run,
          'db',
          r.ok ? CheckLevel.ok : CheckLevel.fail,
          r.ok ? l.readyMs(r.ms) : l.readyNoAnswer)),
      _repo.migrations().then((m) {
        final r = migrationsLevel(m);
        _set(
            run,
            'migrations',
            r.level,
            switch (r.level) {
              CheckLevel.ok => l.readyMigrationsOk,
              CheckLevel.fail => l.readyMigrationsMissing(r.missing.join(', ')),
              _ => l.readyUnknown,
            });
      }),
      _repo.voiceProbe(locale).then((p) {
        _set(run, 'fnVoice', functionLevel(p.status), fn(p));
        final ok = p.status == 200;
        final model =
            p.data is Map ? '${(p.data as Map)['model'] ?? '—'}' : '—';
        _set(run, 'aiVoice', ok ? aiLevel(p.ms) : CheckLevel.fail,
            ok ? l.readyAiTime(sec(p.ms), model) : l.readyAiVoiceFail);
      }),
      _repo.photoProbe(locale).then((p) {
        _set(run, 'fnPhoto', functionLevel(p.status), fn(p));
        final ok = p.status == 200;
        final model =
            p.data is Map ? '${(p.data as Map)['model'] ?? '—'}' : '—';
        _set(run, 'aiPhoto', ok ? aiLevel(p.ms) : CheckLevel.fail,
            ok ? l.readyAiTime(sec(p.ms), model) : l.readyAiPhotoFail);
      }),
      _repo
          .botProbe()
          .then((p) => _set(run, 'fnBot', functionLevel(p.status), fn(p))),
      _repo
          .offlineSyncProbe()
          .then((p) => _set(run, 'fnOffline', functionLevel(p.status), fn(p))),
      _repo.webhookProbe().then((p) {
        _set(run, 'fnNotify', functionLevel(p.status), fn(p));
        final w = WebhookStatus.fromJson(p.data);
        final level = webhookLevel(p.status, w);
        _set(
            run,
            'webhook',
            level,
            p.status == 400
                ? l.readyWebhookOld
                : w == null
                    ? (p.status == null ? l.readyNoAnswer : l.readyUnknown)
                    : !w.configured
                        ? l.readyWebhookNot
                        : level == CheckLevel.warn && w.lastErrorAgeS != null
                            ? l.readyWebhookError(w.lastErrorAgeS! ~/ 60)
                            : l.readyWebhookOk(w.pending));
      }),
      _repo.photoLog24h().then((r) => _set(
          run,
          'photoLog',
          r == null ? CheckLevel.unknown : photoLogLevel(r.count, r.avgMs),
          r == null
              ? l.readyUnknown
              : r.count == 0
                  ? l.readyPhotoLogEmpty
                  : l.readyPhotoLogValue(
                      r.count, r.avgMs == null ? '—' : sec(r.avgMs!)))),
      _repo.newestDemoOrder().then((d) {
        final level = demoLevel(d, DateTime.now());
        _set(
            run,
            'demo',
            level,
            d == null
                ? l.readyDemoNone
                : level == CheckLevel.ok
                    ? l.readyDemoValue(l.dateTime(d))
                    : l.readyDemoOld(l.dateTime(d)));
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppScaffold(
      title: l.readyTitle,
      onRefresh: _check,
      bottomBar: BottomActionBar(
        child: AppButton.primary(
          icon: AppIcons.refresh,
          label: l.readyRecheck,
          loading: _running,
          onPressed: _running ? null : _check,
        ),
      ),
      slivers: [
        SliverContent(
          sliver: SliverList.list(children: [
            AppGroup(footer: l.readyIntro, children: [_summary(l)]),
            AppGroup(header: l.readyGroupBase, children: [
              _row(l, 'db', AppIcons.check, l.readyDb),
              _row(l, 'migrations', AppIcons.list, l.readyMigrations),
            ]),
            AppGroup(header: l.readyGroupFunctions, children: [
              _row(l, 'fnVoice', AppIcons.mic, l.readyFnVoice),
              _row(l, 'fnPhoto', AppIcons.camera, l.readyFnPhoto),
              _row(l, 'fnBot', AppIcons.telegram, l.readyFnBot),
              _row(l, 'fnNotify', AppIcons.bell, l.readyFnNotify),
              _row(l, 'fnOffline', AppIcons.refresh, l.readyFnOffline),
              _row(l, 'webhook', AppIcons.link, l.readyWebhook),
            ]),
            AppGroup(header: l.readyGroupAi, children: [
              _row(l, 'aiVoice', AppIcons.sparkles, l.readyAiVoice),
              _row(l, 'aiPhoto', AppIcons.sparkles, l.readyAiPhoto),
              _row(l, 'photoLog', AppIcons.clock, l.readyPhotoLog),
            ]),
            AppGroup(header: l.readyGroupData, children: [
              _row(l, 'demo', AppIcons.clock, l.readyDemo),
            ]),
          ]),
        ),
        const SliverBottomInset(),
      ],
    );
  }

  Widget _summary(AppLocalizations l) {
    final level = _running ? null : worst(_rows.values.map((r) => r.level));
    return AppRow(
      leading: _badge(level),
      title: switch (level) {
        null => l.readyRunning,
        CheckLevel.ok => l.readyAllOk,
        CheckLevel.warn => l.readySomeWarn,
        CheckLevel.fail => l.readySomeFail,
        CheckLevel.unknown => l.readySomeUnknown,
      },
      titleStyle: AppText.headline,
      chevron: false,
    );
  }

  Widget _row(AppLocalizations l, String key, IconData icon, String title) {
    final r = _rows[key];
    return AppRow(
      leading: _badge(r?.level, icon: icon),
      title: title,
      subtitle: r?.text ?? l.readyRunning,
      subtitleMaxLines: 3,
      chevron: false,
    );
  }

  /// Цвет строки: зелёный / жёлтый / красный / серый; пока проверяется — серый
  /// значок самой проверки.
  Widget _badge(CheckLevel? level, {IconData? icon}) {
    final (colors, glyph) = switch (level) {
      null => (StatusColors.cancelled, icon ?? AppIcons.clock),
      CheckLevel.ok => (StatusColors.done, AppIcons.check),
      CheckLevel.warn => (StatusColors.newOrder, AppIcons.warning),
      CheckLevel.fail => (StatusColors.overdue, AppIcons.close),
      CheckLevel.unknown => (StatusColors.cancelled, AppIcons.info),
    };
    return LeadingIcon(glyph,
        color: colors.foreground, background: colors.background);
  }
}
