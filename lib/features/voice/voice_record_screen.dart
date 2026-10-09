import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../directory/directory.dart';
import 'speech_input.dart';
import 'text_intake.dart';
import 'voice_confirm_screen.dart';
import 'voice_intake_client.dart';

enum _Phase { starting, listening, processing, error, typing }

/// Экран голосовой заявки: распознавание начинается сразу, текст виден по
/// ходу речи. Стоп — «Готово», пауза 3 с или 30 с. Дальше текст разбирается
/// в поля ([VoiceIntakeClient]) и открывается экран подтверждения.
/// Нет распознавания или микрофона — можно ввести текст, разбор тот же.
/// Возвращает true, если заявка создана.
class VoiceRecordScreen extends StatefulWidget {
  const VoiceRecordScreen(
      {super.key, required this.companyId, required this.objects});
  final String companyId;
  final List<Obj> objects;

  static const listenFor = Duration(seconds: 30);
  static const pauseFor = Duration(seconds: 3);

  @override
  State<VoiceRecordScreen> createState() => _VoiceRecordScreenState();
}

class _VoiceRecordScreenState extends State<VoiceRecordScreen>
    with SingleTickerProviderStateMixin {
  final _speech = createSpeechInput();
  final _client = createVoiceIntakeClient();
  final _typeC = TextEditingController();
  final _typeFocus = FocusNode();
  late final _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));
  late final Future<IntakeCatalog> _catalog = _loadCatalog();

  _Phase _phase = _Phase.starting;
  SpeechProblem? _error;

  /// Технический код ошибки (`network`, `audio-capture`, …) — мелко под
  /// текстом ошибки, чтобы было проще разбираться.
  String? _errorCode;

  /// Индикатор громкости в браузере: микрофон всё время молчит.
  bool _micSilent = false;
  String _text = '';

  /// Громкость и время меняются по 4–10 раз в секунду: их слушают только
  /// круг и строка таймера, а не весь экран — кнопки не перестраиваются.
  final _level = ValueNotifier<double>(0);
  final _elapsed = ValueNotifier<Duration>(Duration.zero);
  Timer? _ticker;
  Timer? _stopGuard;

  /// Номер попытки: «Ввести текстом» во время запуска отменяет её.
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopGuard?.cancel();
    if (_phase == _Phase.listening || _phase == _Phase.starting) {
      _speech.cancel();
    }
    _pulse.dispose();
    _level.dispose();
    _elapsed.dispose();
    _typeC.dispose();
    _typeFocus.dispose();
    super.dispose();
  }

  /// Слои и помещения компании — для разбора текста; грузятся, пока
  /// человек говорит. Не загрузились — разбор без справочников.
  Future<IntakeCatalog> _loadCatalog() async {
    final dir = DirectoryRepo();
    List<Layer> layers = const [];
    List<Place> places = const [];
    try {
      layers = await dir.layers();
    } catch (_) {}
    try {
      places = await dir.places();
    } catch (_) {}
    return IntakeCatalog(
        layers: layers, places: places, objects: widget.objects);
  }

  Future<void> _start() async {
    if (!mounted) return;
    final localeId = speechLocaleId(context.localeCode);
    final attempt = ++_attempt;
    _elapsed.value = Duration.zero;
    setState(() {
      _phase = _Phase.starting;
      _error = null;
      _errorCode = null;
      _micSilent = false;
      _text = '';
    });
    final problem = await _speech.init();
    if (!mounted || attempt != _attempt) return;
    if (problem != null) return _fail(problem);
    setState(() => _phase = _Phase.listening);
    _pulse.repeat();
    final startedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      _elapsed.value = DateTime.now().difference(startedAt);
      if (_elapsed.value >= VoiceRecordScreen.listenFor) _finish();
    });
    await _speech.start(
      localeId: localeId,
      listenFor: VoiceRecordScreen.listenFor,
      pauseFor: VoiceRecordScreen.pauseFor,
      onText: (t) {
        if (mounted && _phase == _Phase.listening) setState(() => _text = t);
      },
      onLevel: (l) {
        if (mounted && _phase == _Phase.listening) _level.value = l;
      },
      onMicSilent: (silent) {
        if (mounted && _phase == _Phase.listening && silent != _micSilent) {
          setState(() => _micSilent = silent);
        }
      },
      onDone: _onSpeechDone,
      onError: (p, code) {
        if (!mounted || _phase != _Phase.listening) return;
        // «Не расслышал» после сказанного — просто конец речи.
        if (p == SpeechProblem.nothingHeard && _text.trim().isNotEmpty) {
          _onSpeechDone();
        } else {
          _fail(p, code: code);
        }
      },
    );
  }

  /// «Готово» или 30 с: просим распознаватель остановиться и ждём последний
  /// результат; если он не ответил за 2 с — берём то, что уже есть.
  void _finish() {
    if (_phase != _Phase.listening || _stopGuard != null) return;
    _stopGuard = Timer(const Duration(seconds: 2), _onSpeechDone);
    _speech.stop();
  }

  void _onSpeechDone() {
    _stopGuard?.cancel();
    _stopGuard = null;
    if (!mounted || _phase != _Phase.listening) return;
    _stopListening();
    final text = _text.trim();
    if (TextIntake.stripWakePhrase(text).isEmpty) {
      return _fail(SpeechProblem.nothingHeard);
    }
    _process(text, typed: false);
  }

  /// Перестать слушать. Распознаватель тоже останавливаем: если его итог
  /// не пришёл за 2 с, в браузере иначе остался бы включённым микрофон.
  void _stopListening() {
    _ticker?.cancel();
    _pulse.stop();
    _level.value = 0;
    _micSilent = false;
    _speech.cancel();
  }

  Future<void> _process(String text, {required bool typed}) async {
    final locale = context.localeCode;
    setState(() {
      _phase = _Phase.processing;
      _text = text;
    });
    try {
      final catalog = await _catalog;
      final draft =
          await _client.process(text, locale: locale, catalog: catalog);
      if (!mounted) return;
      // Снизу, как шторка (fullscreenDialog), с переходом iOS.
      final created = await Navigator.push<bool>(
          context,
          CupertinoPageRoute(
            fullscreenDialog: true,
            title: context.l10n.voiceTitle,
            builder: (_) => VoiceConfirmScreen(
                draft: draft,
                companyId: widget.companyId,
                objects: widget.objects,
                catalog: catalog,
                typed: typed),
          ));
      if (!mounted) return;
      if (created == true) {
        Navigator.pop(context, true);
      } else {
        // Вернулись без отправки — можно сказать заново или поправить текст.
        _typeC.text = TextIntake.stripWakePhrase(text);
        _openTyping();
      }
    } catch (_) {
      _fail(SpeechProblem.failed);
    }
  }

  void _fail(SpeechProblem problem, {String? code}) {
    _stopGuard?.cancel();
    _stopGuard = null;
    _stopListening();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _error = problem;
      _errorCode = code;
    });
  }

  /// «Ввести текстом» — одним нажатием в любом состоянии: останавливает
  /// распознавание (и запуск, если он ещё идёт), закрывает микрофон и
  /// открывает поле с курсором в нём.
  void _typeInstead() {
    _attempt++;
    _stopGuard?.cancel();
    _stopGuard = null;
    _stopListening();
    if (_typeC.text.isEmpty) _typeC.text = TextIntake.stripWakePhrase(_text);
    _openTyping();
  }

  void _openTyping() {
    setState(() => _phase = _Phase.typing);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _phase == _Phase.typing) _typeFocus.requestFocus();
    });
  }

  void _submitTyped() {
    final text = _typeC.text.trim();
    // Кнопка «Далее» неактивна, пока поле пустое.
    if (text.isEmpty) return;
    _process(text, typed: true);
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  String _problemText(SpeechProblem p) {
    final l = context.l10n;
    return switch (p) {
      SpeechProblem.unsupported =>
        kIsWeb ? l.voiceUnsupportedWeb : l.voiceUnsupportedApp,
      SpeechProblem.noPermission => kIsWeb
          ? l.voiceNoMicPermissionWeb
          : l.voiceNoMicPermissionApp(l.appName),
      SpeechProblem.network => kIsWeb ? l.voiceNetworkWeb : l.voiceNetwork,
      SpeechProblem.micFailed =>
        kIsWeb ? l.voiceMicFailedWeb : l.voiceMicFailed,
      SpeechProblem.nothingHeard => l.voiceNothingHeard,
      SpeechProblem.failed => l.voiceRecognizeFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final typing = _phase == _Phase.typing;
    return AppScaffold(
      title: l.voiceTitle,
      large: false,
      // «Отмена» — как у модального экрана iOS: закрыть без заявки.
      leading: AppBarTextButton(
          label: l.commonCancel,
          onPressed: () => Navigator.pop(context, false)),
      slivers: [
        SliverContent(
          maxWidth: 520,
          top: AppSpace.l,
          sliver: SliverToBoxAdapter(child: typing ? _typing() : _voice()),
        ),
      ],
      // Кнопки закреплены внизу и не сдвигаются, когда растёт распознанный
      // текст; с клавиатурой «Далее» поднимается вместе с ней.
      bottomBar: typing
          ? BottomActionBar(
              maxWidth: 520,
              // «Далее» неактивна, пока поле пустое.
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _typeC,
                builder: (context, v, _) => AppButton.primary(
                    label: l.voiceNext,
                    onPressed: v.text.trim().isEmpty ? null : _submitTyped),
              ),
            )
          : (_phase == _Phase.processing
              ? null
              : BottomActionBar(maxWidth: 520, child: _voiceButtons())),
    );
  }

  Widget _voiceButtons() {
    final l = context.l10n;
    final listening = _phase == _Phase.listening;
    final canRetry =
        _phase == _Phase.error && _error != SpeechProblem.unsupported;
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (listening)
            AppButton.primary(
                key: const ValueKey('voice-done'),
                label: l.voiceDone,
                icon: AppIcons.check,
                onPressed: _finish),
          if (canRetry)
            AppButton.primary(
                key: const ValueKey('voice-again'),
                label: l.voiceAgain,
                icon: AppIcons.mic,
                onPressed: _start),
          if (listening || canRetry) const SizedBox(height: AppSpace.s),
          // Всегда активна: и пока включается микрофон, и пока слушаем,
          // и после ошибки.
          AppButton.tinted(
              key: const ValueKey('voice-type'),
              label: l.voiceTypeInstead,
              icon: AppIcons.keyboard,
              onPressed: _typeInstead),
        ]);
  }

  Widget _voice() {
    final l = context.l10n;
    final listening = _phase == _Phase.listening;
    final canRetry =
        _phase == _Phase.error && _error != SpeechProblem.unsupported;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_speech.weakBrowser) _Notice(text: l.voiceBrowserHint),
      const SizedBox(height: AppSpace.s),
      _MicCircle(
          pulse: _pulse,
          level: _level,
          active: listening,
          busy: _phase == _Phase.processing || _phase == _Phase.starting,
          label: listening ? l.voiceDone : (canRetry ? l.voiceAgain : null),
          // Круг нажимается так же, как главная кнопка: «Готово» или «Ещё раз».
          onTap: listening ? _finish : (canRetry ? _start : null)),
      const SizedBox(height: AppSpace.l),
      Text(_title(), textAlign: TextAlign.center, style: AppText.title2),
      const SizedBox(height: AppSpace.l),
      if (listening || _phase == _Phase.processing) ...[
        _LiveText(text: _text, placeholder: l.voicePrompt),
        if (listening && _micSilent) _Notice(text: l.voiceMicSilent),
        if (listening)
          ValueListenableBuilder<Duration>(
            valueListenable: _elapsed,
            builder: (context, elapsed, _) {
              final left = VoiceRecordScreen.listenFor - elapsed;
              return Text(
                  '${l.voiceTimer(_fmt(elapsed), left.inSeconds < 0 ? 0 : left.inSeconds)}\n${l.voiceAutoStop}',
                  textAlign: TextAlign.center,
                  style: AppText.footnote);
            },
          ),
      ],
      if (_phase == _Phase.error && _error != null) ...[
        const Icon(AppIcons.error, size: 36, color: AppColors.danger),
        const SizedBox(height: AppSpace.m),
        Text(_problemText(_error!),
            textAlign: TextAlign.center,
            style: AppText.callout.copyWith(color: AppColors.danger)),
        if (_errorCode?.isNotEmpty ?? false) ...[
          const SizedBox(height: 6),
          SelectableText(l.voiceErrorCode(_errorCode!),
              textAlign: TextAlign.center, style: AppText.caption),
        ],
      ],
    ]);
  }

  /// «Ввести текстом»: поле в белой карточке, «Далее» — в нижней панели.
  Widget _typing() {
    final l = context.l10n;
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.voiceTypeTitle, style: AppText.title2),
          const SizedBox(height: AppSpace.m),
          AppCard(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            child: TextField(
              controller: _typeC,
              focusNode: _typeFocus,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              style: AppText.body,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                  hintText: l.voiceTypeHint,
                  hintMaxLines: 3,
                  filled: true,
                  fillColor: AppColors.surface),
            ),
          ),
          // Подсказка обычным текстом под полем, пока оно пустое.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _typeC,
            builder: (context, v, _) => v.text.trim().isEmpty
                ? Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpace.rowH, AppSpace.s, AppSpace.rowH, 0),
                    child: Text(l.formWhatRequired, style: AppText.footnote))
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpace.l),
          AppButton.secondary(
              label: l.voiceAgain, icon: AppIcons.mic, onPressed: _start),
        ]);
  }

  String _title() {
    final l = context.l10n;
    return switch (_phase) {
      _Phase.starting => l.voiceStarting,
      _Phase.listening => l.voiceListening,
      _Phase.processing => l.voiceProcessing,
      _Phase.error => l.voiceFailedTitle,
      _Phase.typing => l.voiceTypeTitle,
    };
  }
}

/// Распознанный текст по ходу речи; пока его нет — подсказка, что сказать.
class _LiveText extends StatelessWidget {
  const _LiveText({required this.text, required this.placeholder});
  final String text;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final empty = text.trim().isEmpty;
    return AppCard(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: SizedBox(
          width: double.infinity,
          child: Text(empty ? placeholder : text,
              textAlign: empty ? TextAlign.center : TextAlign.start,
              style: empty
                  ? AppText.callout.copyWith(color: AppColors.secondary)
                  : AppText.headline),
        ),
      ),
    );
  }
}

/// Подсказка: совет открыть в Chrome / Edge, «микрофон молчит».
class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => AppCard(
        color: StatusColors.newOrder.background,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
        child: Row(children: [
          Icon(AppIcons.info,
              size: AppSizes.iconS, color: StatusColors.newOrder.foreground),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: AppText.footnote.copyWith(color: AppColors.ink))),
        ]),
      );
}

/// Кнопка-микрофон. Пока слушаем — от неё расходятся волны («слушаю»);
/// на Android и в браузере на компьютере они растут с громкостью голоса.
class _MicCircle extends StatelessWidget {
  const _MicCircle(
      {required this.pulse,
      required this.level,
      required this.active,
      required this.busy,
      this.label,
      this.onTap});
  final Animation<double> pulse;
  final ValueListenable<double> level;
  final bool active, busy;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(alignment: Alignment.center, children: [
        // Волны и фон — только картинка: нажатия не перехватывают.
        IgnorePointer(
          child: AnimatedBuilder(
            animation: Listenable.merge([pulse, level]),
            builder: (_, __) {
              final l = level.value;
              return Stack(alignment: Alignment.center, children: [
                if (active)
                  for (final shift in const [0.0, 0.5])
                    _wave(((pulse.value + shift) % 1.0), l),
                AnimatedContainer(
                  duration: AppMotion.fast,
                  width: active ? 132 + 40 * l : 132,
                  height: active ? 132 + 40 * l : 132,
                  decoration: const BoxDecoration(
                      color: AppColors.mint, shape: BoxShape.circle),
                ),
              ]);
            },
          ),
        ),
        Pressable(
          onTap: onTap,
          semanticLabel: label,
          child: Container(
            width: 108,
            height: 108,
            decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                boxShadow: AppShadows.voice),
            child: busy
                ? const CupertinoActivityIndicator(
                    radius: 14, color: AppColors.onAccent)
                : Icon(active ? AppIcons.audio : AppIcons.mic,
                    size: 48, color: AppColors.onAccent),
          ),
        ),
      ]),
    );
  }

  /// Волна: [t] — фаза 0…1, [level] — громкость (громче — шире и ярче).
  Widget _wave(double t, double level) => Container(
        width: 120 + (50 + 30 * level) * t,
        height: 120 + (50 + 30 * level) * t,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: AppColors.accent
                    .withValues(alpha: (0.4 + 0.5 * level) * (1 - t)),
                width: 3 + 3 * level)),
      );
}
