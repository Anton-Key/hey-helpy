import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/design/design.dart';
import 'package:hey_helpy/features/readiness/readiness_logic.dart';
import 'package:hey_helpy/features/readiness/readiness_repository.dart';
import 'package:hey_helpy/features/readiness/readiness_screen.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

/// Подменённые ответы: без сети и без Supabase.
class _FakeRepo extends ReadinessRepository {
  _FakeRepo({this.webhook = 200, this.missing = const {}, this.demoAge});
  final int? webhook;
  final Set<String> missing;
  final Duration? demoAge;

  @override
  Future<({bool ok, int ms})> pingDb() async => (ok: true, ms: 120);
  @override
  Future<Map<String, bool?>> migrations() async =>
      {for (final k in readinessMigrations.keys) k: !missing.contains(k)};
  @override
  Future<Probe> voiceProbe(String locale) async =>
      (status: 200, ms: 2300, data: {'model': 'pro'});
  @override
  Future<Probe> photoProbe(String locale) async =>
      (status: 200, ms: 6100, data: {'model': 'main'});
  @override
  Future<Probe> botProbe() async => (status: 401, ms: 90, data: null);
  @override
  Future<Probe> offlineSyncProbe() async => (status: 400, ms: 80, data: null);
  @override
  Future<Probe> webhookProbe() async => (
        status: webhook,
        ms: 300,
        data: webhook == 200
            ? {
                'webhook': {
                  'configured': true,
                  'pending': 0,
                  'last_error_age_s': null
                }
              }
            : null
      );
  @override
  Future<DateTime?> newestDemoOrder() async =>
      DateTime.now().subtract(demoAge ?? const Duration(hours: 3));
  @override
  Future<({int count, int? avgMs})?> photoLog24h() async =>
      (count: 4, avgMs: 5200);
}

Widget _app(Widget child, {String locale = 'ru'}) => MaterialApp(
      theme: AppTheme.light(),
      locale: Locale(locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

void main() {
  group('логика статусов', () {
    test('worst: красное > жёлтое > серое > зелёное', () {
      expect(worst([CheckLevel.ok, CheckLevel.ok]), CheckLevel.ok);
      expect(worst([CheckLevel.ok, CheckLevel.unknown]), CheckLevel.unknown);
      expect(worst([CheckLevel.unknown, CheckLevel.warn]), CheckLevel.warn);
      expect(worst([CheckLevel.warn, CheckLevel.fail, CheckLevel.ok]),
          CheckLevel.fail);
      expect(worst(const []), CheckLevel.ok);
    });

    test('functionLevel: ответ функции — жива, 5xx и тишина — нет', () {
      for (final s in [200, 400, 401, 403, 404]) {
        expect(functionLevel(s), CheckLevel.ok, reason: '$s');
      }
      for (final s in [500, 502, 503, 546]) {
        expect(functionLevel(s), CheckLevel.fail, reason: '$s');
      }
      expect(functionLevel(null), CheckLevel.fail);
    });

    test('migrationsLevel: отсутствующие по порядку, неизвестное — серое', () {
      expect(
          migrationsLevel({'0017': true, '0025': true}).level, CheckLevel.ok);
      final r = migrationsLevel({'0025': false, '0017': true, '0023': false});
      expect(r.level, CheckLevel.fail);
      expect(r.missing, ['0023', '0025']);
      expect(migrationsLevel({'0017': true, '0018': null}).level,
          CheckLevel.unknown);
      expect(readinessMigrations.keys, isNot(contains('0022')));
    });

    test('demoLevel: до 2 суток / до 7 / старше / нет', () {
      final now = DateTime(2026, 10, 19, 9);
      expect(demoLevel(now.subtract(const Duration(hours: 30)), now),
          CheckLevel.ok);
      expect(demoLevel(now.subtract(const Duration(days: 4)), now),
          CheckLevel.warn);
      expect(demoLevel(now.subtract(const Duration(days: 9)), now),
          CheckLevel.fail);
      expect(demoLevel(null, now), CheckLevel.fail);
    });

    test('aiLevel и photoLogLevel', () {
      expect(aiLevel(2300), CheckLevel.ok);
      expect(aiLevel(8000), CheckLevel.ok);
      expect(aiLevel(12000), CheckLevel.warn);
      expect(aiLevel(17000), CheckLevel.fail);
      expect(aiLevel(null), CheckLevel.fail);
      expect(photoLogLevel(0, null), CheckLevel.unknown);
      expect(photoLogLevel(3, 5000), CheckLevel.ok);
    });

    test('webhookLevel: настроен / ошибка за час / очередь / старая функция',
        () {
      const ok = WebhookStatus(configured: true, pending: 0);
      expect(webhookLevel(200, ok), CheckLevel.ok);
      expect(
          webhookLevel(
              200,
              const WebhookStatus(
                  configured: true, pending: 0, lastErrorAgeS: 120)),
          CheckLevel.warn);
      expect(
          webhookLevel(
              200,
              const WebhookStatus(
                  configured: true, pending: 0, lastErrorAgeS: 7200)),
          CheckLevel.ok);
      expect(
          webhookLevel(200, const WebhookStatus(configured: true, pending: 25)),
          CheckLevel.warn);
      expect(
          webhookLevel(200, const WebhookStatus(configured: false, pending: 0)),
          CheckLevel.fail);
      expect(webhookLevel(400, null), CheckLevel.unknown);
      expect(webhookLevel(null, null), CheckLevel.fail);
      expect(webhookLevel(403, null), CheckLevel.fail);
    });

    test('WebhookStatus.fromJson — только поля проверки', () {
      final w = WebhookStatus.fromJson({
        'webhook': {'configured': true, 'pending': 3, 'last_error_age_s': 60}
      })!;
      expect(w.configured, isTrue);
      expect(w.pending, 3);
      expect(w.lastErrorAgeS, 60);
      expect(WebhookStatus.fromJson({'error': 'bad_request'}), isNull);
      expect(WebhookStatus.fromJson(null), isNull);
    });
  });

  group('экран', () {
    setUp(() {
      final v =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      v.physicalSize = const Size(900, 3000);
      v.devicePixelRatio = 1;
    });
    tearDown(() {
      final v =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      v.resetPhysicalSize();
      v.resetDevicePixelRatio();
    });
    testWidgets('всё зелёное — «Всё готово к показу»', (t) async {
      await t.pumpWidget(_app(ReadinessScreen(repo: _FakeRepo())));
      await t.pumpAndSettle();
      expect(find.text('Всё готово к показу'), findsOneWidget);
      expect(find.text('Все применены'), findsOneWidget);
      expect(find.text('Отвечает · 90 мс'), findsOneWidget);
      expect(find.text('Настроен · ждут доставки: 0'), findsOneWidget);
      expect(find.textContaining('модель pro'), findsOneWidget);
      expect(find.text('Проверить ещё раз'), findsOneWidget);
    });

    testWidgets('нет миграции и старая telegram-notify', (t) async {
      await t.pumpWidget(_app(
          ReadinessScreen(repo: _FakeRepo(webhook: 400, missing: {'0025'}))));
      await t.pumpAndSettle();
      expect(find.textContaining('Не применены: 0025'), findsOneWidget);
      expect(find.text('Проверка появится после Deploy functions (шаг 29)'),
          findsOneWidget);
      expect(find.text('Есть проблемы — посмотрите красные строки'),
          findsOneWidget);
    });

    testWidgets('старые демо-данные — по-английски', (t) async {
      await t.pumpWidget(_app(
          ReadinessScreen(repo: _FakeRepo(demoAge: const Duration(days: 10))),
          locale: 'en'));
      await t.pumpAndSettle();
      expect(find.textContaining('run Refresh demo'), findsOneWidget);
      expect(find.text('Problems found — see the red rows'), findsOneWidget);
    });
  });
}
