import 'dart:async';
import 'dart:io';

import 'package:record/record.dart';

/// Запись голосовой заявки в формате для синхронного распознавания
/// Yandex SpeechKit: LPCM, 16 бит, 16 кГц, моно, без заголовка.
/// 16 000 × 2 байта = 32 КБ в секунду; 25 с ≈ 800 КБ — с запасом
/// укладывается в лимиты SpeechKit (30 с и 1 МБ).
class VoiceRecorder {
  static const sampleRate = 16000;
  static const maxDuration = Duration(seconds: 25);
  static const minDuration = Duration(milliseconds: 800);

  final _rec = AudioRecorder();
  String? _path;
  DateTime? _startedAt;

  /// Спрашивает разрешение на микрофон, если его ещё нет.
  Future<bool> ensurePermission() => _rec.hasPermission();

  Future<void> start() async {
    final path = '${Directory.systemTemp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.pcm';
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        autoGain: true,
        noiseSuppress: true,
      ),
      path: path,
    );
    _path = path;
    _startedAt = DateTime.now();
  }

  /// Громкость от 0 до 1 — для индикатора на экране.
  Stream<double> levels() => _rec
      .onAmplitudeChanged(const Duration(milliseconds: 120))
      .map((a) => ((a.current + 50) / 50).clamp(0.0, 1.0));

  /// Останавливает запись. Возвращает null, если записалось слишком мало.
  Future<File?> stop() async {
    final started = _startedAt;
    final path = await _rec.stop() ?? _path;
    _startedAt = null;
    if (path == null) return null;
    final file = File(path);
    final tooShort = started == null || DateTime.now().difference(started) < minDuration;
    if (tooShort || !await file.exists() || await file.length() == 0) {
      await _deleteQuietly(file);
      return null;
    }
    return file;
  }

  Future<void> cancel() async {
    await _rec.cancel();
    final path = _path;
    if (path != null) await _deleteQuietly(File(path));
    _startedAt = null;
  }

  Future<void> dispose() => _rec.dispose();

  static Future<void> _deleteQuietly(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
