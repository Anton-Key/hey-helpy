import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../directory/directory.dart';
import 'speech_input.dart';
import 'text_intake.dart';
import 'voice_confirm_screen.dart';
import 'voice_intake_client.dart';

const _ink = Color(0xFF1C1E22);
const _muted = Color(0xFF8A9098);
const _onBrand = Color(0xFF06342A);
const _mint = Color(0xFFD8F0EA);
const _danger = Color(0xFFC24444);

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
  late final _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));
  late final Future<IntakeCatalog> _catalog = _loadCatalog();

  _Phase _phase = _Phase.starting;
  SpeechProblem? _error;
  String _text = '';
  double _level = 0;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  Timer? _stopGuard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopGuard?.cancel();
    if (_phase == _Phase.listening) _speech.cancel();
    _pulse.dispose();
    _typeC.dispose();
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
    setState(() {
      _phase = _Phase.starting;
      _error = null;
      _text = '';
      _elapsed = Duration.zero;
    });
    final problem = await _speech.init();
    if (!mounted) return;
    if (problem != null) return _fail(problem);
    setState(() => _phase = _Phase.listening);
    _pulse.repeat();
    final startedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(startedAt));
      if (_elapsed >= VoiceRecordScreen.listenFor) _finish();
    });
    await _speech.start(
      localeId: localeId,
      listenFor: VoiceRecordScreen.listenFor,
      pauseFor: VoiceRecordScreen.pauseFor,
      onText: (t) {
        if (mounted && _phase == _Phase.listening) setState(() => _text = t);
      },
      onLevel: (l) {
        if (mounted) setState(() => _level = l);
      },
      onDone: _onSpeechDone,
      onError: (p) {
        if (!mounted || _phase != _Phase.listening) return;
        // «Не расслышал» после сказанного — просто конец речи.
        if (p == SpeechProblem.nothingHeard && _text.trim().isNotEmpty) {
          _onSpeechDone();
        } else {
          _fail(p);
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

  void _stopListening() {
    _ticker?.cancel();
    _pulse.stop();
    _level = 0;
  }

  Future<void> _process(String text, {required bool typed}) async {
    final locale = context.localeCode;
    setState(() => _phase = _Phase.processing);
    try {
      final catalog = await _catalog;
      final draft =
          await _client.process(text, locale: locale, catalog: catalog);
      if (!mounted) return;
      final created = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
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
        setState(() => _phase = _Phase.typing);
      }
    } catch (_) {
      _fail(SpeechProblem.failed);
    }
  }

  void _fail(SpeechProblem problem) {
    _stopGuard?.cancel();
    _stopGuard = null;
    _stopListening();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _error = problem;
    });
  }

  void _typeInstead() {
    if (_phase == _Phase.listening) {
      _stopListening();
      _speech.cancel();
    }
    if (_typeC.text.isEmpty) _typeC.text = TextIntake.stripWakePhrase(_text);
    setState(() => _phase = _Phase.typing);
  }

  void _submitTyped() {
    final text = _typeC.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.formWhatRequired)));
      return;
    }
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
      SpeechProblem.network => l.voiceNetwork,
      SpeechProblem.micFailed => l.voiceMicFailed,
      SpeechProblem.nothingHeard => l.voiceNothingHeard,
      SpeechProblem.failed => l.voiceRecognizeFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          title: Text(context.l10n.voiceTitle), backgroundColor: Colors.white),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: _phase == _Phase.typing ? _typing() : _voice(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _voice() {
    final l = context.l10n;
    final listening = _phase == _Phase.listening;
    final left = VoiceRecordScreen.listenFor - _elapsed;
    final canRetry =
        _phase == _Phase.error && _error != SpeechProblem.unsupported;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 8),
      _MicCircle(
          pulse: _pulse,
          level: _level,
          active: listening,
          busy: _phase == _Phase.processing || _phase == _Phase.starting,
          // Круг нажимается так же, как главная кнопка: «Готово» или «Ещё раз».
          onTap: listening ? _finish : (canRetry ? _start : null)),
      const SizedBox(height: 20),
      Text(_title(),
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: _ink, fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      if (listening || _phase == _Phase.processing) ...[
        _LiveText(text: _text, placeholder: l.voicePrompt),
        const SizedBox(height: 10),
        if (listening)
          Text(
              '${l.voiceTimer(_fmt(_elapsed), left.inSeconds < 0 ? 0 : left.inSeconds)}\n${l.voiceAutoStop}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.4)),
      ],
      if (_phase == _Phase.error && _error != null)
        Text(_problemText(_error!),
            textAlign: TextAlign.center,
            style: const TextStyle(color: _danger, fontSize: 15, height: 1.4)),
      const SizedBox(height: 28),
      if (listening)
        FilledButton.icon(
            style: brandButtonStyle().copyWith(
                minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56))),
            onPressed: _finish,
            icon: const Icon(Icons.check_rounded),
            label: Text(l.voiceDone,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 17))),
      if (canRetry)
        FilledButton.icon(
            style: brandButtonStyle().copyWith(
                minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56))),
            onPressed: _start,
            icon: const Icon(Icons.mic),
            label: Text(l.voiceAgain,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 17))),
      if (listening || _phase == _Phase.error) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: HeyHelpyTheme.link,
                minimumSize: const Size.fromHeight(50)),
            onPressed: _typeInstead,
            icon: const Icon(Icons.keyboard_alt_outlined),
            label: Text(l.voiceTypeInstead,
                style: const TextStyle(fontWeight: FontWeight.w700))),
      ],
      const SizedBox(height: 8),
      if (_phase != _Phase.processing) _cancel(),
    ]);
  }

  Widget _typing() {
    final l = context.l10n;
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.voiceTypeTitle,
              style: const TextStyle(
                  color: _ink, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(
            controller: _typeC,
            autofocus: true,
            minLines: 4,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
                hintText: l.voiceTypeHint,
                hintMaxLines: 3,
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          FilledButton(
              style: brandButtonStyle().copyWith(
                  minimumSize:
                      const WidgetStatePropertyAll(Size.fromHeight(56))),
              onPressed: _submitTyped,
              child: Text(l.voiceNext,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 17))),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: HeyHelpyTheme.link,
                  minimumSize: const Size.fromHeight(50)),
              onPressed: _start,
              icon: const Icon(Icons.mic),
              label: Text(l.voiceAgain,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(height: 8),
          _cancel(),
        ]);
  }

  Widget _cancel() => TextButton(
      onPressed: () => Navigator.pop(context, false),
      child: Text(context.l10n.commonCancel,
          style: const TextStyle(
              color: HeyHelpyTheme.link, fontWeight: FontWeight.w700)));

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
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      decoration:
          BoxDecoration(color: _mint, borderRadius: BorderRadius.circular(16)),
      child: Text(empty ? placeholder : text,
          textAlign: empty ? TextAlign.center : TextAlign.start,
          style: TextStyle(
              color: empty ? _muted : _ink,
              fontSize: empty ? 15 : 18,
              height: 1.4,
              fontWeight: empty ? FontWeight.w400 : FontWeight.w600)),
    );
  }
}

/// Кнопка-микрофон. Пока слушаем — от неё расходятся волны («слушаю»),
/// на Android они ещё и растут с громкостью голоса.
class _MicCircle extends StatelessWidget {
  const _MicCircle(
      {required this.pulse,
      required this.level,
      required this.active,
      required this.busy,
      this.onTap});
  final Animation<double> pulse;
  final double level;
  final bool active, busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const brand = HeyHelpyTheme.brand;
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(alignment: Alignment.center, children: [
        if (active)
          AnimatedBuilder(
            animation: pulse,
            builder: (_, __) => Stack(alignment: Alignment.center, children: [
              for (final shift in const [0.0, 0.5])
                _wave(((pulse.value + shift) % 1.0)),
            ]),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: active ? 132 + 40 * level : 132,
          height: active ? 132 + 40 * level : 132,
          decoration: const BoxDecoration(color: _mint, shape: BoxShape.circle),
        ),
        Material(
          color: brand,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 108,
              height: 108,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(34),
                      child: CircularProgressIndicator(
                          color: _onBrand, strokeWidth: 3))
                  : Icon(active ? Icons.graphic_eq_rounded : Icons.mic,
                      size: 52, color: _onBrand),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _wave(double t) => Container(
        width: 120 + 80 * t,
        height: 120 + 80 * t,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: HeyHelpyTheme.brand.withValues(alpha: 0.6 * (1 - t)),
                width: 3)),
      );
}
