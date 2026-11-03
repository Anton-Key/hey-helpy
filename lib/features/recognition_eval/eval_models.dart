// Тест точности распознавания (шаг 34): модели и чистые функции — сводка
// набора, разбор отчёта функции recognition-eval, CSV, порядок прогона.
// Метрики считает функция (supabase/functions/_shared/eval_metrics.ts),
// здесь — только показ. Тесты: test/recognition_eval_test.dart.

/// Ключ «нет в реестре» в сводке по видам.
const kEvalUnregisteredKey = '_unregistered';

/// Цель набора — 300 фото (презентация: «тест из 300–500 фото»).
const kEvalTargetPhotos = 300;

/// Сколько фото распознаётся одновременно (лимит параллельности).
const kEvalConcurrency = 3;

/// Условия съёмки — коды как в базе (0028).
const kEvalLight = ['good', 'dim', 'backlight'];
const kEvalDistance = ['close', 'medium', 'far'];
const kEvalAngle = ['front', 'side'];

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
double? _num(Object? v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

class EvalSet {
  const EvalSet(
      {required this.id,
      required this.name,
      required this.createdAt,
      this.frozenAt});
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime? frozenAt;
  bool get frozen => frozenAt != null;

  static EvalSet fromJson(Map<String, dynamic> j) => EvalSet(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        createdAt: _date(j['created_at']) ?? DateTime.now(),
        frozenAt: _date(j['frozen_at']),
      );
}

class EvalSample {
  const EvalSample({
    required this.id,
    required this.setId,
    required this.photoPath,
    required this.siteId,
    required this.roomId,
    required this.equipmentId,
    required this.unregistered,
    required this.trueKind,
    required this.similarInRoom,
    required this.seriesId,
    required this.light,
    required this.distance,
    required this.angle,
    required this.occlusion,
    required this.split,
    required this.createdAt,
  });
  final String id;
  final String setId;
  final String photoPath;
  final String siteId;
  final String roomId;
  final String? equipmentId;
  final bool unregistered;
  final String? trueKind;
  final int similarInRoom;
  final String? seriesId;
  final String light;
  final String distance;
  final String angle;
  final bool occlusion;
  final String split;
  final DateTime createdAt;

  static EvalSample fromJson(Map<String, dynamic> j) => EvalSample(
        id: j['id'] as String,
        setId: j['set_id'] as String,
        photoPath: j['photo_path'] as String,
        siteId: j['site_id'] as String,
        roomId: j['room_id'] as String,
        equipmentId: j['true_equipment_id'] as String?,
        unregistered: j['true_is_unregistered'] == true,
        trueKind: j['true_kind'] as String?,
        similarInRoom: (j['similar_in_room'] as num?)?.toInt() ?? 0,
        seriesId: j['series_id'] as String?,
        light: (j['light'] as String?) ?? 'good',
        distance: (j['distance'] as String?) ?? 'medium',
        angle: (j['angle'] as String?) ?? 'front',
        occlusion: j['occlusion'] == true,
        split: (j['split'] as String?) ?? 'dev',
        createdAt: _date(j['created_at']) ?? DateTime.now(),
      );
}

class EvalRun {
  const EvalRun({
    required this.id,
    required this.setId,
    required this.split,
    required this.createdAt,
    required this.providerRequested,
    required this.provider,
    required this.model,
    required this.promptHash,
    required this.status,
    required this.sampleCount,
    required this.setFrozenAt,
    required this.finishedAt,
  });
  final String id;
  final String setId;
  final String split;
  final DateTime createdAt;
  final String providerRequested;
  final String? provider;
  final String? model;
  final String? promptHash;

  /// running | done | cancelled
  final String status;
  final int sampleCount;
  final DateTime? setFrozenAt;
  final DateTime? finishedAt;

  bool get running => status == 'running';

  static EvalRun fromJson(Map<String, dynamic> j) => EvalRun(
        id: j['id'] as String,
        setId: j['set_id'] as String,
        split: (j['split'] as String?) ?? 'dev',
        createdAt: _date(j['created_at']) ?? DateTime.now(),
        providerRequested: (j['provider_requested'] as String?) ?? 'default',
        provider: j['provider'] as String?,
        model: j['model_vision'] as String?,
        promptHash: j['prompt_hash'] as String?,
        status: (j['status'] as String?) ?? 'running',
        sampleCount: (j['sample_count'] as num?)?.toInt() ?? 0,
        setFrozenAt: _date(j['set_frozen_at']),
        finishedAt: _date(j['finished_at']),
      );
}

/// Поставщик ИИ из настроенных секретов (только имена, без ключей).
class EvalProvider {
  const EvalProvider(
      {required this.id, required this.provider, required this.model});

  /// default | yandex | openai
  final String id;
  final String provider;
  final String model;

  static List<EvalProvider> listFromJson(Object? data) {
    if (data is! Map || data['providers'] is! List) return const [];
    return [
      for (final p in data['providers'] as List)
        if (p is Map && p['id'] is String)
          EvalProvider(
              id: p['id'] as String,
              provider: '${p['provider'] ?? ''}',
              model: '${p['model'] ?? ''}'),
    ];
  }
}

/// Сводка набора: счётчики для экрана и «до цели осталось N».
class EvalSummary {
  const EvalSummary({
    required this.photos,
    required this.units,
    required this.rooms,
    required this.sites,
    required this.unregistered,
    required this.dev,
    required this.test,
    required this.byKind,
  });
  final int photos;
  final int units;
  final int rooms;
  final int sites;
  final int unregistered;
  final int dev;
  final int test;

  /// Вид → количество фото (самые частые первыми); без вида — 'unknown'.
  final List<MapEntry<String, int>> byKind;

  int get remaining =>
      photos >= kEvalTargetPhotos ? 0 : kEvalTargetPhotos - photos;

  static EvalSummary of(List<EvalSample> s) {
    final kinds = <String, int>{};
    for (final x in s) {
      final k =
          x.unregistered ? kEvalUnregisteredKey : (x.trueKind ?? 'unknown');
      kinds[k] = (kinds[k] ?? 0) + 1;
    }
    final byKind = kinds.entries.toList()
      ..sort((a, b) =>
          b.value != a.value ? b.value - a.value : a.key.compareTo(b.key));
    return EvalSummary(
      photos: s.length,
      units: {
        for (final x in s)
          if (x.equipmentId != null) x.equipmentId
      }.length,
      rooms: {for (final x in s) x.roomId}.length,
      sites: {for (final x in s) x.siteId}.length,
      unregistered: s.where((x) => x.unregistered).length,
      dev: s.where((x) => x.split == 'dev').length,
      test: s.where((x) => x.split == 'test').length,
      byKind: byKind,
    );
  }
}

/// Доля с 95 % доверительным интервалом (интервал Уилсона считает функция).
class EvalRate {
  const EvalRate({required this.k, required this.n, this.p, this.lo, this.hi});
  final int k;
  final int n;
  final double? p;
  final double? lo;
  final double? hi;

  static EvalRate fromJson(Object? j) {
    if (j is! Map) return const EvalRate(k: 0, n: 0);
    return EvalRate(
      k: (j['k'] as num?)?.toInt() ?? 0,
      n: (j['n'] as num?)?.toInt() ?? 0,
      p: _num(j['p']),
      lo: _num(j['lo']),
      hi: _num(j['hi']),
    );
  }
}

class EvalThreshold {
  const EvalThreshold(
      {required this.threshold,
      required this.coverage,
      required this.accuracy,
      required this.falseRecognition});
  final double threshold;
  final EvalRate coverage;
  final EvalRate accuracy;
  final EvalRate falseRecognition;
}

class EvalGroup {
  const EvalGroup({required this.key, required this.top1, required this.top3});
  final String key;
  final EvalRate top1;
  final EvalRate top3;
}

/// Строка по одному фото (для CSV и примеров ошибок).
class EvalRow {
  const EvalRow({
    required this.sampleId,
    required this.photoPath,
    required this.siteId,
    required this.roomId,
    required this.trueEquipmentId,
    required this.trueKind,
    required this.unregistered,
    required this.similarInRoom,
    required this.light,
    required this.distance,
    required this.angle,
    required this.occlusion,
    required this.predictedId,
    required this.top3,
    required this.predictedKind,
    required this.confidence,
    required this.ms,
    required this.error,
    this.exampleType,
  });
  final String sampleId;
  final String photoPath;
  final String siteId;
  final String roomId;
  final String? trueEquipmentId;
  final String? trueKind;
  final bool unregistered;
  final int similarInRoom;
  final String light;
  final String distance;
  final String angle;
  final bool occlusion;
  final String? predictedId;
  final List<String> top3;
  final String? predictedKind;
  final double? confidence;
  final int? ms;
  final String? error;

  /// Только у примеров ошибок: wrong_unit | false_recognition | error.
  final String? exampleType;

  bool get top1Correct =>
      trueEquipmentId != null && predictedId == trueEquipmentId;
  bool get top3Correct =>
      trueEquipmentId != null && top3.contains(trueEquipmentId);

  static EvalRow fromJson(Map j) => EvalRow(
        sampleId: '${j['sample_id']}',
        photoPath: '${j['photo_path'] ?? ''}',
        siteId: '${j['site_id'] ?? ''}',
        roomId: '${j['room_id'] ?? ''}',
        trueEquipmentId: j['true_equipment_id'] as String?,
        trueKind: j['true_kind'] as String?,
        unregistered: j['unregistered'] == true,
        similarInRoom: (j['similar_in_room'] as num?)?.toInt() ?? 0,
        light: '${j['light'] ?? ''}',
        distance: '${j['distance'] ?? ''}',
        angle: '${j['angle'] ?? ''}',
        occlusion: j['occlusion'] == true,
        predictedId: j['predicted_equipment_id'] as String?,
        top3: [
          for (final x in (j['top3'] as List?) ?? const [])
            if (x is String) x
        ],
        predictedKind: j['predicted_kind'] as String?,
        confidence: _num(j['confidence']),
        ms: (j['ms'] as num?)?.toInt(),
        error: j['error'] as String?,
        exampleType: j['type'] as String?,
      );
}

/// Ответ `recognition-eval {action: "report"}`.
class EvalReport {
  const EvalReport({
    required this.run,
    required this.headline,
    required this.photos,
    required this.registered,
    required this.unregistered,
    required this.units,
    required this.rooms,
    required this.sites,
    required this.kinds,
    required this.conditions,
    required this.missing,
    required this.errors,
    required this.top1,
    required this.top3,
    required this.kind,
    required this.falseRecognition,
    required this.thresholds,
    required this.groups,
    required this.latencyMedian,
    required this.latencyP95,
    required this.tokensMedian,
    required this.costPerPhoto,
    required this.rows,
    required this.examples,
    required this.names,
  });
  final EvalRun run;
  final String headline;
  final int photos;
  final int registered;
  final int unregistered;
  final int units;
  final int rooms;
  final int sites;
  final Map<String, int> kinds;
  final Map<String, Map<String, int>> conditions;
  final int missing;
  final int errors;
  final EvalRate top1;
  final EvalRate top3;
  final EvalRate kind;
  final EvalRate falseRecognition;
  final List<EvalThreshold> thresholds;

  /// by_kind, by_light, by_distance, by_angle, by_occlusion, by_similar.
  final Map<String, List<EvalGroup>> groups;
  final int? latencyMedian;
  final int? latencyP95;
  final int? tokensMedian;
  final double? costPerPhoto;
  final List<EvalRow> rows;
  final List<EvalRow> examples;
  final Map<String, String> names;

  String name(String? id) => id == null ? '' : (names[id] ?? id);

  static const groupKeys = [
    'by_kind',
    'by_similar',
    'by_light',
    'by_distance',
    'by_angle',
    'by_occlusion',
  ];

  static EvalReport? fromJson(Object? data) {
    if (data is! Map || data['metrics'] is! Map || data['run'] is! Map) {
      return null;
    }
    final m = data['metrics'] as Map;
    Map<String, int> ints(Object? v) => {
          if (v is Map)
            for (final e in v.entries)
              '${e.key}': (e.value as num?)?.toInt() ?? 0
        };
    List<EvalGroup> groups(Object? v) => [
          if (v is List)
            for (final g in v)
              if (g is Map)
                EvalGroup(
                    key: '${g['key']}',
                    top1: EvalRate.fromJson(g['top1']),
                    top3: EvalRate.fromJson(g['top3'])),
        ];
    final lat = m['latency_ms'] is Map ? m['latency_ms'] as Map : const {};
    return EvalReport(
      run: EvalRun.fromJson(Map<String, dynamic>.from(data['run'] as Map)),
      headline: '${data['headline'] ?? ''}',
      photos: (m['photos'] as num?)?.toInt() ?? 0,
      registered: (m['registered'] as num?)?.toInt() ?? 0,
      unregistered: (m['unregistered'] as num?)?.toInt() ?? 0,
      units: (m['units'] as num?)?.toInt() ?? 0,
      rooms: (m['rooms'] as num?)?.toInt() ?? 0,
      sites: (m['sites'] as num?)?.toInt() ?? 0,
      kinds: ints(m['kinds']),
      conditions: {
        if (m['conditions'] is Map)
          for (final e in (m['conditions'] as Map).entries)
            '${e.key}': ints(e.value)
      },
      missing: (m['missing'] as num?)?.toInt() ?? 0,
      errors: (m['errors'] as num?)?.toInt() ?? 0,
      top1: EvalRate.fromJson(m['top1']),
      top3: EvalRate.fromJson(m['top3']),
      kind: EvalRate.fromJson(m['kind']),
      falseRecognition: EvalRate.fromJson(m['false_recognition']),
      thresholds: [
        if (m['thresholds'] is List)
          for (final t in m['thresholds'] as List)
            if (t is Map)
              EvalThreshold(
                threshold: _num(t['threshold']) ?? 0,
                coverage: EvalRate.fromJson(t['coverage']),
                accuracy: EvalRate.fromJson(t['accuracy']),
                falseRecognition: EvalRate.fromJson(t['false_recognition']),
              ),
      ],
      groups: {for (final k in groupKeys) k: groups(m[k])},
      latencyMedian: (lat['median'] as num?)?.toInt(),
      latencyP95: (lat['p95'] as num?)?.toInt(),
      tokensMedian: (m['tokens_median'] as num?)?.toInt(),
      costPerPhoto: _num(m['cost_per_photo_usd']),
      rows: [
        if (data['rows'] is List)
          for (final r in data['rows'] as List)
            if (r is Map) EvalRow.fromJson(r)
      ],
      examples: [
        if (data['examples'] is List)
          for (final r in data['examples'] as List)
            if (r is Map && r['sample_id'] != null) EvalRow.fromJson(r)
      ],
      names: {
        if (data['names'] is Map)
          for (final e in (data['names'] as Map).entries)
            '${e.key}': '${e.value}'
      },
    );
  }
}

/// «93.4%» — доля в процентах с одним знаком; нет данных — «—».
String evalPct(double? v) =>
    v == null ? '—' : '${(v * 100).toStringAsFixed(1)}%';

/// «93.4% (95% CI 90.1–95.7%)».
String evalRateText(EvalRate r) => r.p == null
    ? '—'
    : '${evalPct(r.p)} (95% CI ${evalPct(r.lo).replaceAll('%', '')}–${evalPct(r.hi)})';

String _csvCell(Object? v) {
  final s = v == null ? '' : '$v';
  if (s.contains(RegExp('[",\n\r]')) || s.startsWith(RegExp(r'[=+\-@]'))) {
    // Кавычки и защита от формул в Excel.
    final safe = s.startsWith(RegExp(r'[=+\-@]')) ? "'$s" : s;
    return '"${safe.replaceAll('"', '""')}"';
  }
  return s;
}

/// CSV отчёта: строки «# …» — сводка (на английском, как PDF по умолчанию),
/// затем по строке на фото. Названия — из реестра компании.
String evalCsv(EvalReport r, {required DateTime generatedAt}) {
  final b = StringBuffer();
  void line(List<Object?> cells) => b.writeln(cells.map(_csvCell).join(','));
  b.writeln('# Equipment recognition test');
  b.writeln('# ${r.headline}');
  b.writeln('# Top-3: ${evalRateText(r.top3)}');
  b.writeln('# Equipment type: ${evalRateText(r.kind)}');
  b.writeln(
      '# False recognitions (unregistered equipment named as a registry unit): '
      '${evalRateText(r.falseRecognition)}');
  b.writeln('# Run: ${r.run.id}; split: ${r.run.split}; '
      'provider: ${r.run.provider ?? '—'}; model: ${r.run.model ?? '—'}; '
      'prompt version: ${r.run.promptHash ?? '—'}');
  b.writeln(
      '# Test set frozen: ${r.run.setFrozenAt?.toUtc().toIso8601String() ?? 'not frozen (dev)'}; '
      'generated: ${generatedAt.toUtc().toIso8601String()}');
  b.writeln(
      "# Measured on the company's own test set; no tuning on test photos.");
  line([
    'sample_id',
    'site',
    'room',
    'true_equipment',
    'true_equipment_id',
    'unregistered',
    'true_type',
    'similar_units_in_room',
    'light',
    'distance',
    'angle',
    'occlusion',
    'predicted_equipment',
    'predicted_equipment_id',
    'predicted_type',
    'confidence',
    'top1_correct',
    'top3_correct',
    'response_ms',
    'error',
  ]);
  for (final x in r.rows) {
    line([
      x.sampleId,
      r.name(x.siteId),
      r.name(x.roomId),
      r.name(x.trueEquipmentId),
      x.trueEquipmentId,
      x.unregistered,
      x.trueKind,
      x.similarInRoom,
      x.light,
      x.distance,
      x.angle,
      x.occlusion,
      r.name(x.predictedId),
      x.predictedId,
      x.predictedKind,
      x.confidence?.toStringAsFixed(2),
      x.unregistered ? '' : x.top1Correct,
      x.unregistered ? '' : x.top3Correct,
      x.ms,
      x.error,
    ]);
  }
  return b.toString();
}

/// Имя файла отчёта: hey-helpy-recognition-test-2026-11-03.csv / .pdf.
String evalReportFileName(DateTime at, String ext) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'hey-helpy-recognition-test-${at.year}-${two(at.month)}-${two(at.day)}.$ext';
}
