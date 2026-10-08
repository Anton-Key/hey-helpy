import '../directory/directory.dart';
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

/// Текущая реализация — локальный разбор, без сети.
///
/// Шаг 12 (план): серверный ИИ-разбор — `ServerVoiceIntake implements
/// VoiceIntakeClient`. Вызывает Supabase Edge Function (например,
/// `voice-intake`): на вход `{text, locale}`, на выход те же поля, что
/// читает [VoiceDraft.fromJson] (`title`, `description`, `layer_id`,
/// `location_id`, `location_hint`, `priority`). Ключи YandexGPT — только в
/// функции на сервере. При ошибке сети — откат на [LocalVoiceIntake].
VoiceIntakeClient createVoiceIntakeClient() => const LocalVoiceIntake();

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
