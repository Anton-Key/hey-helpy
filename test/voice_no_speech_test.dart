import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/design/design.dart';
import 'package:hey_helpy/features/voice/speech_input.dart';
import 'package:hey_helpy/features/voice/voice_draft.dart';
import 'package:hey_helpy/features/voice/voice_intake_client.dart';
import 'package:hey_helpy/features/voice/voice_record_screen.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

/// Распознаватель браузера: [unavailable] — как Firefox / Яндекс Браузер.
class _FakeSpeech implements SpeechInput {
  _FakeSpeech({required this.unavailable});
  final bool unavailable;
  int inits = 0;

  @override
  bool get voiceUnavailable => unavailable;
  @override
  bool get weakBrowser => unavailable;
  @override
  Future<SpeechProblem?> init() async {
    inits++;
    return null;
  }

  @override
  Future<void> start({
    required String localeId,
    required Duration listenFor,
    required Duration pauseFor,
    required void Function(String text) onText,
    required void Function() onDone,
    required void Function(SpeechProblem problem, String code) onError,
    void Function(double level)? onLevel,
    void Function(bool silent)? onMicSilent,
  }) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
}

Widget _app(Widget child, String locale) => MaterialApp(
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
  for (final locale in ['ru', 'en']) {
    testWidgets('нет распознавания речи → сразу «Ввести текстом» ($locale)',
        (t) async {
      final speech = _FakeSpeech(unavailable: true);
      await t.pumpWidget(_app(
          VoiceRecordScreen(companyId: 'c', objects: const [], speech: speech),
          locale));
      await t.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(Locale(locale));
      expect(speech.inits, 0, reason: 'микрофон не включаем');
      expect(find.text(l.voiceOnlyChromeEdge), findsOneWidget);
      expect(find.text(l.voiceTypeTitle), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);
      // Ни ошибки, ни «Ещё раз».
      expect(find.text(l.voiceFailedTitle), findsNothing);
      expect(find.text(l.voiceUnsupportedWeb), findsNothing);
      expect(find.text(l.voiceAgain), findsNothing);
    });
  }

  testWidgets('Chrome: сразу слушаем, подсказки нет', (t) async {
    final speech = _FakeSpeech(unavailable: false);
    await t.pumpWidget(_app(
        VoiceRecordScreen(companyId: 'c', objects: const [], speech: speech),
        'ru'));
    await t.pump();
    await t.pump();
    final l = await AppLocalizations.delegate.load(const Locale('ru'));
    expect(speech.inits, 1);
    expect(find.text(l.voiceOnlyChromeEdge), findsNothing);
    expect(find.text(l.voiceListening), findsOneWidget);
    // Закрыть экран, чтобы таймеры остановились.
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
      'медленный ИИ: 3 с — «ИИ разбирает заявку…», 8 с — «Ещё немного…»',
      (t) async {
    final slow = _SlowIntake();
    await t.pumpWidget(_app(
        VoiceRecordScreen(
            companyId: 'c',
            objects: const [],
            speech: _FakeSpeech(unavailable: true),
            client: slow),
        'ru'));
    await t.pumpAndSettle();
    final l = await AppLocalizations.delegate.load(const Locale('ru'));
    await t.enterText(find.byType(TextField), 'не работает кондиционер');
    await t.pump();
    await t.tap(find.text(l.voiceNext));
    await t.pump();
    expect(find.text(l.voiceProcessing), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(find.text(l.voiceAiParsing), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    expect(find.text(l.voiceAiAlmost), findsOneWidget);
    // Разбор не удался — экран с ошибкой и «Ввести текстом» (как раньше).
    slow.done.completeError(StateError('нет ответа'));
    await t.pump();
    expect(find.text(l.voiceAiAlmost), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
}

/// Разбор, который отвечает, когда тест скажет.
class _SlowIntake implements VoiceIntakeClient {
  final done = Completer<VoiceDraft>();
  @override
  Future<VoiceDraft> process(String transcript,
          {required String locale, required IntakeCatalog catalog}) =>
      done.future;
}
