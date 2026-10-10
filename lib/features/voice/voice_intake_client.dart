import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../directory/directory.dart';
import 'speech_input.dart';
import 'text_intake.dart';
import 'voice_draft.dart';

/// Справочники компании, по которым текст раскладывается в поля заявки.
class IntakeCatalog {
  const IntakeCatalog(
      {this.layers = const [],
      this.places = const [],
      this.objects = const []});
  final List<Layer> layers;
  final List<Place> places;
  final List<Obj> objects;
}

/// Превращает текст заявки (распознанный или набранный) в черновик:
/// заголовок, описание, слой, место, срочность. Заявку не создаёт —
/// её отправляет пользователь с экрана подтверждения.
abstract class VoiceIntakeClient {
  /// [locale] — язык интерфейса (ru / en).
  Future<VoiceDraft> process(String transcript,
      {required String locale, required IntakeCatalog catalog});
}

/// Снимки для питча (`/screens --pitch`): речь — заготовленная фраза
/// (VOICE_MOCK), разбор — настоящий ИИ на сервере. В рабочие сборки не
/// добавлять.
const voiceMockAi = bool.fromEnvironment('VOICE_MOCK_AI');

/// Обычно — ИИ на сервере с откатом на словарь. В режиме VOICE_MOCK
/// (скриншоты `/screens`, без сети) — только словарь, с VOICE_MOCK_AI — ИИ.
VoiceIntakeClient createVoiceIntakeClient() =>
    voiceMock && !voiceMockAi ? const LocalVoiceIntake() : ServerVoiceIntake();

/// Разбор на устройстве по словарю ([TextIntake]).
class LocalVoiceIntake implements VoiceIntakeClient {
  const LocalVoiceIntake();

  @override
  Future<VoiceDraft> process(String transcript,
      {required String locale, required IntakeCatalog catalog}) async {
    return TextIntake(
            layers: catalog.layers,
            places: catalog.places,
            objects: catalog.objects)
        .parse(transcript);
  }
}

/// Вызов функции: тело запроса → JSON ответа (ошибка — исключение).
typedef IntakeCall = Future<Object?> Function(Map<String, dynamic> body);

/// ИИ-разбор на сервере: Supabase Edge Function `voice-intake` (YandexGPT,
/// ключи — только на сервере). При любой ошибке — сеть, ответ 4xx/5xx,
/// таймаут [timeout], функция не настроена — молча разбор по словарю.
/// Чего ИИ не нашёл (слой, место), подставляется из словаря.
class ServerVoiceIntake implements VoiceIntakeClient {
  ServerVoiceIntake(
      {IntakeCall? call,
      this.fallback = const LocalVoiceIntake(),
      this.timeout = const Duration(seconds: 10)})
      : _call = call ?? _invoke;

  static const functionName = 'voice-intake';

  final IntakeCall _call;
  final VoiceIntakeClient fallback;
  final Duration timeout;

  static Future<Object?> _invoke(Map<String, dynamic> body) async {
    final res = await Supabase.instance.client.functions
        .invoke(functionName, body: body);
    return res.status == 200 ? res.data : null;
  }

  @override
  Future<VoiceDraft> process(String transcript,
      {required String locale, required IntakeCatalog catalog}) async {
    final local =
        await fallback.process(transcript, locale: locale, catalog: catalog);
    try {
      final data = await _call({
        'text': transcript.trim(),
        'locale': locale == 'ru' ? 'ru' : 'en',
        // Один объект у компании — помещения только его.
        if (catalog.objects.length == 1) 'objectId': catalog.objects.first.id,
      }).timeout(timeout);
      if (data is! Map || data['source'] != 'ai') return local;
      return merge(Map<String, dynamic>.from(data), local, catalog);
    } catch (_) {
      return local;
    }
  }

  /// Ответ ИИ + разбор по словарю: поля ИИ, а пустые — из словаря.
  static VoiceDraft merge(
      Map<String, dynamic> ai, VoiceDraft local, IntakeCatalog catalog) {
    String? str(String key) {
      final v = ai[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final aiLayerId = str('layer_id');
    final aiPlace = catalog.places
        .where((p) => p.id == str('location_id'))
        .cast<Place?>()
        .firstWhere((_) => true, orElse: () => null);
    final p = str('priority');
    return VoiceDraft(
      transcript: local.transcript,
      title: str('title') ?? local.title,
      description: str('description') ?? local.description,
      layerId: aiLayerId ?? local.layerId,
      layer: aiLayerId != null ? str('layer') : local.layer,
      locationId: aiPlace?.id ?? local.locationId,
      objectId: aiPlace?.objectId ?? local.objectId,
      locationHint: str('location_hint') ?? local.locationHint,
      priority: VoiceDraft.priorities.contains(p) ? p! : local.priority,
      source: DraftSource.ai,
    );
  }
}
