import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../photo_identify/identify_log.dart' show newUuid;
import 'eval_models.dart';
import 'eval_runner.dart';

/// Данные теста распознавания (шаг 34, 0028). Всё — под RLS: наборы, фото,
/// прогоны и результаты видит только администратор своей компании. Прогоны
/// создаются и закрываются функциями базы, результаты пишет только
/// Edge Function recognition-eval.
class EvalRepository {
  EvalRepository([SupabaseClient? client])
      : _c = client ?? Supabase.instance.client;
  final SupabaseClient _c;

  static const bucket = 'eval-photos';
  static const function = 'recognition-eval';

  /// Сколько ждём одно фото (≤ 14 с у модели + скачивание и запись).
  static const callTimeout = Duration(seconds: 40);

  Future<List<EvalSet>> sets() async {
    final rows = await _c
        .from('recognition_eval_sets')
        .select()
        .order('created_at', ascending: false);
    return [for (final r in rows) EvalSet.fromJson(r)];
  }

  Future<EvalSet> createSet(
      {required String companyId, required String name}) async {
    final r = await _c
        .from('recognition_eval_sets')
        .insert({
          'company_id': companyId,
          'name': name,
          'created_by': _c.auth.currentUser?.id,
        })
        .select()
        .single();
    return EvalSet.fromJson(r);
  }

  Future<List<EvalSample>> samples(String setId) async {
    final out = <EvalSample>[];
    // Страницами по 1000 строк (лимит PostgREST).
    for (var from = 0;; from += 1000) {
      final rows = await _c
          .from('recognition_eval_samples')
          .select()
          .eq('set_id', setId)
          .order('created_at')
          .range(from, from + 999);
      out.addAll(rows.map(EvalSample.fromJson));
      if (rows.length < 1000) break;
    }
    return out;
  }

  /// Загрузить фото и записать разметку. dev / test назначает база.
  /// Не записалось — файл удаляется.
  Future<EvalSample> addSample({
    required EvalSet set,
    required String companyId,
    required Uint8List jpeg,
    required String siteId,
    required String roomId,
    required String? equipmentId,
    required String? seriesId,
    required String light,
    required String distance,
    required String angle,
    required bool occlusion,
  }) async {
    final path = '$companyId/${set.id}/${newUuid()}.jpg';
    await _c.storage.from(bucket).uploadBinary(path, jpeg,
        fileOptions: const FileOptions(contentType: 'image/jpeg'));
    try {
      final r = await _c
          .from('recognition_eval_samples')
          .insert({
            'set_id': set.id,
            'company_id': companyId,
            'created_by': _c.auth.currentUser?.id,
            'photo_path': path,
            'site_id': siteId,
            'room_id': roomId,
            'true_equipment_id': equipmentId,
            'true_is_unregistered': equipmentId == null,
            'series_id': seriesId,
            'light': light,
            'distance': distance,
            'angle': angle,
            'occlusion': occlusion,
          })
          .select()
          .single();
      return EvalSample.fromJson(r);
    } catch (_) {
      unawaited(_c.storage.from(bucket).remove([path]).then((_) {},
          onError: (Object e) => debugPrint('eval remove: ${e.runtimeType}')));
      rethrow;
    }
  }

  Future<void> deleteSample(EvalSample s) async {
    await _c.from('recognition_eval_samples').delete().eq('id', s.id);
    try {
      await _c.storage.from(bucket).remove([s.photoPath]);
    } catch (e) {
      debugPrint('eval remove: ${e.runtimeType}');
    }
  }

  Future<void> freeze(String setId) =>
      _c.rpc('recognition_eval_freeze', params: {'p_set': setId});

  Future<List<EvalRun>> runs(String setId) async {
    final rows = await _c
        .from('recognition_eval_runs')
        .select()
        .eq('set_id', setId)
        .order('created_at', ascending: false);
    return [for (final r in rows) EvalRun.fromJson(r)];
  }

  Future<String> startRun(String setId, String split, String provider) async {
    final id = await _c.rpc('recognition_eval_run_start',
        params: {'p_set': setId, 'p_split': split, 'p_provider': provider});
    return '$id';
  }

  Future<String> finishRun(String runId, {bool cancel = false}) async {
    final r = await _c.rpc('recognition_eval_run_finish',
        params: {'p_run': runId, 'p_cancel': cancel});
    return '$r';
  }

  /// id фото прогона с ответом без ошибки — их не повторяем.
  Future<Set<String>> answeredSampleIds(String runId) async {
    final out = <String>{};
    for (var from = 0;; from += 1000) {
      final rows = await _c
          .from('recognition_eval_results')
          .select('sample_id')
          .eq('run_id', runId)
          .isFilter('error', null)
          .range(from, from + 999);
      out.addAll(rows.map((r) => r['sample_id'] as String));
      if (rows.length < 1000) break;
    }
    return out;
  }

  Future<int> resultCount(String runId) async {
    final r = await _c
        .from('recognition_eval_results')
        .select('id')
        .eq('run_id', runId)
        .count(CountOption.exact);
    return r.count;
  }

  Future<List<EvalProvider>> providers() async {
    final r = await _c.functions
        .invoke(function, body: {'action': 'providers'}).timeout(callTimeout);
    return EvalProvider.listFromJson(r.data);
  }

  /// Одно фото прогона. Сеть / таймаут — исключение (повторит [EvalRunner]).
  Future<EvalStep> runOne(String runId, String sampleId) async {
    try {
      final r = await _c.functions.invoke(function, body: {
        'action': 'run',
        'runId': runId,
        'sampleId': sampleId,
      }).timeout(callTimeout);
      final d = r.data;
      if (d is Map && d['skipped'] == true) return EvalStep.skipped;
      if (d is Map && d['ok'] == true) return EvalStep.ok;
      return EvalStep.aiError;
    } on FunctionException catch (e) {
      final d = e.details;
      final code = d is Map ? '${d['error'] ?? ''}' : '';
      if (e.status == 400 || e.status == 404 || e.status == 409) {
        throw EvalFatal(code.isEmpty ? 'http_${e.status}' : code);
      }
      rethrow;
    }
  }

  Future<EvalReport?> report(String runId) async {
    final r = await _c.functions.invoke(function,
        body: {'action': 'report', 'runId': runId}).timeout(callTimeout);
    return EvalReport.fromJson(r.data);
  }

  Future<Uint8List?> photo(String path) async {
    try {
      return await _c.storage.from(bucket).download(path);
    } catch (e) {
      debugPrint('eval photo: ${e.runtimeType}');
      return null;
    }
  }
}
