import 'dart:async';

import 'eval_models.dart';

/// Итог одного фото от функции recognition-eval.
enum EvalStep {
  /// Ответ ИИ записан.
  ok,

  /// ИИ не ответил (таймаут, 5xx) — ошибка записана, фото считается неверным,
  /// его можно повторить кнопкой «Повторить ошибки».
  aiError,

  /// Ответ уже был — пропущено.
  skipped,
}

/// Прогон набора пачками (шаг 34): не больше [concurrency] фото одновременно,
/// сетевые сбои — до [retries] повторов с паузой; прогресс — [onProgress].
/// [call] бросает исключение при сбое сети, [EvalFatal] — когда продолжать
/// бессмысленно (поставщик не настроен, прогон закрыт, сменились секреты).
class EvalRunner {
  EvalRunner({
    required this.call,
    this.concurrency = kEvalConcurrency,
    this.retries = 2,
    this.backoff = const Duration(seconds: 2),
  });

  final Future<EvalStep> Function(String sampleId) call;
  final int concurrency;
  final int retries;
  final Duration backoff;
  bool _stop = false;

  void stop() => _stop = true;
  bool get stopped => _stop;

  Future<EvalRunTotals> run(
    List<String> sampleIds, {
    void Function(EvalRunTotals t)? onProgress,
  }) async {
    final queue = [...sampleIds];
    var t = EvalRunTotals(total: sampleIds.length);
    Object? fatal;

    Future<void> worker() async {
      while (!_stop && fatal == null && queue.isNotEmpty) {
        final id = queue.removeAt(0);
        EvalStep? step;
        for (var attempt = 0; attempt <= retries && !_stop; attempt++) {
          try {
            step = await call(id);
            break;
          } on EvalFatal catch (e) {
            fatal = e;
            _stop = true;
            break;
          } catch (_) {
            if (attempt < retries) {
              await Future<void>.delayed(backoff * (attempt + 1));
            }
          }
        }
        if (fatal != null) break;
        t = switch (step) {
          EvalStep.ok => t.copy(ok: t.ok + 1),
          EvalStep.skipped => t.copy(ok: t.ok + 1),
          EvalStep.aiError => t.copy(aiErrors: t.aiErrors + 1),
          null => _stop ? t : t.copy(failed: t.failed + 1),
        };
        onProgress?.call(t);
      }
    }

    await Future.wait([
      for (var i = 0; i < concurrency && i < sampleIds.length; i++) worker()
    ]);
    if (fatal != null) throw fatal!;
    return t;
  }
}

class EvalFatal implements Exception {
  const EvalFatal(this.code);
  final String code;
  @override
  String toString() => 'EvalFatal($code)';
}

class EvalRunTotals {
  const EvalRunTotals(
      {required this.total, this.ok = 0, this.aiErrors = 0, this.failed = 0});
  final int total;
  final int ok;

  /// Ответ ИИ с ошибкой (записан в результаты).
  final int aiErrors;

  /// Не дошло до функции после повторов (сеть) — не записано.
  final int failed;

  int get done => ok + aiErrors + failed;
  double get progress => total == 0 ? 1 : done / total;

  EvalRunTotals copy({int? ok, int? aiErrors, int? failed}) => EvalRunTotals(
      total: total,
      ok: ok ?? this.ok,
      aiErrors: aiErrors ?? this.aiErrors,
      failed: failed ?? this.failed);
}
