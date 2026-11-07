// Шаг 34: тест распознавания — сводка набора, разбор отчёта функции, CSV,
// прогон пачками (лимит параллельности, повторы, остановка).
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hey_helpy/features/recognition_eval/eval_pdf.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';
import 'package:hey_helpy/features/recognition_eval/eval_models.dart';
import 'package:hey_helpy/features/recognition_eval/eval_runner.dart';

EvalSample _s(String id,
        {String? unit,
        String room = 'R1',
        String site = 'S1',
        String split = 'dev',
        String? kind = 'ac'}) =>
    EvalSample.fromJson({
      'id': id,
      'set_id': 'set',
      'photo_path': 'c/set/$id.jpg',
      'site_id': site,
      'room_id': room,
      'true_equipment_id': unit,
      'true_is_unregistered': unit == null,
      'true_kind': kind,
      'similar_in_room': 1,
      'light': 'good',
      'distance': 'close',
      'angle': 'front',
      'occlusion': false,
      'split': split,
      'created_at': '2026-11-03T10:00:00Z',
    });

Map<String, dynamic> _rate(int k, int n) => {
      'k': k,
      'n': n,
      'p': n == 0 ? null : k / n,
      'lo': n == 0 ? null : 0.5,
      'hi': n == 0 ? null : 0.99,
    };

Map<String, dynamic> _reportJson() => {
      'run': {
        'id': 'run1',
        'set_id': 'set',
        'split': 'test',
        'created_at': '2026-11-03T10:00:00Z',
        'provider_requested': 'default',
        'provider': 'yandex',
        'model_vision': 'qwen3.6-35b-a3b',
        'prompt_hash': 'a' * 64,
        'status': 'done',
        'sample_count': 2,
        'set_frozen_at': '2026-11-02T09:00:00Z',
      },
      'headline':
          'Top-1: 50.0% (95% CI 9.5–90.5%), n = 2 photos, 2 units, 1 rooms, 1 sites',
      'metrics': {
        'photos': 3,
        'registered': 2,
        'unregistered': 1,
        'units': 2,
        'rooms': 1,
        'sites': 1,
        'kinds': {'ac': 2, 'unknown': 1},
        'conditions': {
          'light': {'good': 3}
        },
        'missing': 0,
        'errors': 0,
        'top1': _rate(1, 2),
        'top3': _rate(2, 2),
        'kind': _rate(2, 2),
        'false_recognition': _rate(0, 1),
        'thresholds': [
          {
            'threshold': 0,
            'coverage': _rate(2, 2),
            'accuracy': _rate(1, 2),
            'false_recognition': _rate(0, 1),
          }
        ],
        'by_kind': [
          {'key': 'ac', 'top1': _rate(1, 2), 'top3': _rate(2, 2)}
        ],
        'latency_ms': {'median': 3100, 'p95': 5200, 'n': 3},
        'tokens_median': 1200,
        'cost_per_photo_usd': null,
      },
      'rows': [
        {
          'sample_id': 'p1',
          'photo_path': 'c/set/p1.jpg',
          'site_id': 'S1',
          'room_id': 'R1',
          'true_equipment_id': 'A',
          'true_kind': 'ac',
          'unregistered': false,
          'light': 'good',
          'distance': 'close',
          'angle': 'front',
          'occlusion': false,
          'predicted_equipment_id': 'A',
          'top3': ['A', 'B'],
          'predicted_kind': 'ac',
          'confidence': 0.75,
          'ms': 3100,
          'error': null,
        },
        {
          'sample_id': 'p2',
          'photo_path': 'c/set/p2.jpg',
          'site_id': 'S1',
          'room_id': 'R1',
          'true_equipment_id': 'B',
          'true_kind': 'ac',
          'unregistered': false,
          'light': 'good',
          'distance': 'far',
          'angle': 'side',
          'occlusion': true,
          'predicted_equipment_id': 'A',
          'top3': ['A', 'B'],
          'predicted_kind': 'ac',
          'confidence': 0.75,
          'ms': 5200,
          'error': null,
        },
      ],
      'examples': [
        {
          'sample_id': 'p2',
          'type': 'wrong_unit',
          'photo_path': 'c/set/p2.jpg',
          'true_equipment_id': 'B',
          'predicted_equipment_id': 'A',
        }
      ],
      'names': {
        'A': 'AC-301',
        'B': 'AC, "west"',
        'R1': '301 Meeting room',
        'S1': 'Demo Tower'
      },
    };

void main() {
  test('сводка набора и «до цели 300 фото»', () {
    final s = EvalSummary.of([
      _s('1', unit: 'A'),
      _s('2', unit: 'A'),
      _s('3', unit: 'B', room: 'R2', split: 'test'),
      _s('4', site: 'S2', room: 'R3', split: 'test', kind: null),
    ]);
    expect(s.photos, 4);
    expect(s.units, 2);
    expect(s.rooms, 3);
    expect(s.sites, 2);
    expect(s.unregistered, 1);
    expect(s.dev, 2);
    expect(s.test, 2);
    expect(s.byKind.first.key, 'ac');
    expect(s.byKind.first.value, 3);
    expect(s.byKind.last.key, kEvalUnregisteredKey);
    expect(s.remaining, 296);
    expect(
        EvalSummary.of(List.generate(301, (i) => _s('$i', unit: 'A')))
            .remaining,
        0);
  });

  test('отчёт функции разбирается', () {
    final r = EvalReport.fromJson(_reportJson())!;
    expect(r.run.split, 'test');
    expect(r.run.setFrozenAt, isNotNull);
    expect(r.top1.k, 1);
    expect(r.top1.n, 2);
    expect(r.top3.p, 1.0);
    expect(r.thresholds.single.coverage.k, 2);
    expect(r.groups['by_kind']!.single.key, 'ac');
    expect(r.groups['by_light'], isEmpty);
    expect(r.latencyMedian, 3100);
    expect(r.costPerPhoto, isNull);
    expect(r.rows, hasLength(2));
    expect(r.rows.first.top1Correct, isTrue);
    expect(r.rows.last.top1Correct, isFalse);
    expect(r.rows.last.top3Correct, isTrue);
    expect(r.examples.single.exampleType, 'wrong_unit');
    expect(r.name('A'), 'AC-301');
    expect(EvalReport.fromJson({'run': {}}), isNull);
    expect(EvalReport.fromJson(null), isNull);
  });

  test('подписи долей: проценты и интервал', () {
    expect(evalPct(0.934), '93.4%');
    expect(evalPct(null), '—');
    expect(
        evalRateText(
            const EvalRate(k: 329, n: 352, p: 0.9347, lo: 0.9013, hi: 0.9572)),
        '93.5% (95% CI 90.1–95.7%)');
    expect(evalRateText(const EvalRate(k: 0, n: 0)), '—');
  });

  test('CSV: сводка, строка на фото, кавычки', () {
    final r = EvalReport.fromJson(_reportJson())!;
    final csv = evalCsv(r, generatedAt: DateTime.utc(2026, 11, 3, 12));
    final lines = csv.trim().split('\n');
    expect(lines.first, startsWith('# '));
    expect(csv, contains(r.headline));
    expect(csv, contains('no tuning on test photos'));
    expect(
        csv,
        contains('test set frozen: 2026-11-02T09:00:00.000Z'
            .replaceFirst('test set', 'Test set')));
    final header = lines.firstWhere((x) => x.startsWith('sample_id'));
    expect(header.split(',').length, 20);
    final rows = lines.where((x) => x.startsWith('p')).toList();
    expect(rows, hasLength(2));
    expect(rows.last, contains('"AC, ""west"""'));
    expect(rows.first, contains(',true,true,'));
    expect(evalReportFileName(DateTime(2026, 11, 3), 'pdf'),
        'hey-helpy-recognition-test-2026-11-03.pdf');
  });

  test('провайдеры из ответа функции', () {
    final p = EvalProvider.listFromJson({
      'providers': [
        {'id': 'default', 'provider': 'yandex', 'model': 'qwen'},
        {'id': 'openai', 'provider': 'openai', 'model': 'm'},
        'junk',
      ]
    });
    expect(p.map((x) => x.id), ['default', 'openai']);
    expect(EvalProvider.listFromJson(null), isEmpty);
  });

  test('прогон: не больше N одновременно, все фото по разу', () async {
    var active = 0;
    var peak = 0;
    final seen = <String>[];
    final runner = EvalRunner(
      concurrency: 3,
      call: (id) async {
        active++;
        peak = peak < active ? active : peak;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        active--;
        seen.add(id);
        return id == 'p5' ? EvalStep.aiError : EvalStep.ok;
      },
    );
    final progress = <int>[];
    final t = await runner.run([for (var i = 0; i < 10; i++) 'p$i'],
        onProgress: (t) => progress.add(t.done));
    expect(peak, 3);
    expect(seen.toSet(), hasLength(10));
    expect(t.ok, 9);
    expect(t.aiErrors, 1);
    expect(t.failed, 0);
    expect(progress.last, 10);
  });

  test('прогон: сбой сети — повтор, потом «не отправлено»', () async {
    final tries = <String, int>{};
    final runner = EvalRunner(
      concurrency: 2,
      retries: 2,
      backoff: Duration.zero,
      call: (id) async {
        tries[id] = (tries[id] ?? 0) + 1;
        if (id == 'flaky' && tries[id]! < 2) throw TimeoutException('x');
        if (id == 'dead') throw TimeoutException('x');
        return EvalStep.ok;
      },
    );
    final t = await runner.run(['flaky', 'dead', 'ok']);
    expect(tries['flaky'], 2);
    expect(tries['dead'], 3);
    expect(t.ok, 2);
    expect(t.failed, 1);
  });

  test('прогон: EvalFatal останавливает всё', () async {
    var calls = 0;
    final runner = EvalRunner(
      concurrency: 1,
      call: (id) async {
        calls++;
        if (id == 'p1') throw const EvalFatal('eval_config_changed');
        return EvalStep.ok;
      },
    );
    await expectLater(
        runner.run(['p0', 'p1', 'p2', 'p3']), throwsA(isA<EvalFatal>()));
    expect(calls, 2);
  });

  test('прогон: «Остановить» — новые фото не берутся', () async {
    late EvalRunner runner;
    var calls = 0;
    runner = EvalRunner(
      concurrency: 1,
      call: (id) async {
        calls++;
        if (calls == 2) runner.stop();
        return EvalStep.ok;
      },
    );
    final t = await runner.run(['a', 'b', 'c', 'd']);
    expect(calls, 2);
    expect(t.ok, 2);
    expect(runner.stopped, isTrue);
  });

  test('PDF для инвестора собирается (EN и RU)', () async {
    await initializeDateFormatting();
    final fonts = await loadReportFonts((a) async =>
        ByteData.sublistView(Uint8List.fromList(await File(a).readAsBytes())));
    final r = EvalReport.fromJson(_reportJson())!;
    for (final lang in ['en', 'ru']) {
      final l = lookupAppLocalizations(Locale(lang));
      final bytes = await buildEvalPdf(
          l: l,
          r: r,
          company: 'Demo Properties',
          generatedAt: DateTime(2026, 11, 3, 12),
          fonts: fonts,
          thumbs: const {});
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      final out = Platform.environment['EVAL_PDF_OUT'];
      if (out != null) File('$out-$lang.pdf').writeAsBytesSync(bytes);
      expect(bytes.length, greaterThan(2000));
    }
  });
}
