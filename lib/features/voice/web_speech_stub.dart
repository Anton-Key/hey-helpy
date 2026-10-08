import 'speech_input.dart';

/// Не в браузере Web Speech API нет — сюда не попадаем
/// ([createSpeechInput] выбирает его только при `kIsWeb`).
SpeechInput createWebSpeechInput() => DeviceSpeechInput();
