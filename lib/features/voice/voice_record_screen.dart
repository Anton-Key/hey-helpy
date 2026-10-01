import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/l10n_ext.dart';
import '../directory/directory.dart';
import 'voice_confirm_screen.dart';
import 'voice_intake_client.dart';
import 'voice_recorder.dart';

const _ink = Color(0xFF1C1E22);
const _muted = Color(0xFF8A9098);
const _onBrand = Color(0xFF06342A);
const _mint = Color(0xFFD8F0EA);
const _danger = Color(0xFFC24444);

enum _Phase { starting, recording, processing, error }

enum _Problem { noPermission, micFailed, tooShort, recognizeFailed }

/// Экран голосовой заявки: запись начинается сразу, «Готово» — стоп,
/// дальше распознавание и переход к подтверждению.
/// Возвращает true, если заявка создана.
class VoiceRecordScreen extends StatefulWidget {
  const VoiceRecordScreen({super.key, required this.companyId, required this.objects});
  final String companyId;
  final List<Obj> objects;

  @override
  State<VoiceRecordScreen> createState() => _VoiceRecordScreenState();
}

class _VoiceRecordScreenState extends State<VoiceRecordScreen> {
  final _recorder = VoiceRecorder();
  final _client = createVoiceIntakeClient();
  _Phase _phase = _Phase.starting;
  _Problem? _error;
  double _level = 0;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  StreamSubscription<double>? _levelSub;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _levelSub?.cancel();
    if (_phase == _Phase.recording) _recorder.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() { _phase = _Phase.starting; _error = null; _elapsed = Duration.zero; });
    try {
      if (!await _recorder.ensurePermission()) {
        return _fail(_Problem.noPermission);
      }
      await _recorder.start();
    } catch (_) {
      return _fail(_Problem.micFailed);
    }
    if (!mounted) return;
    _levelSub = _recorder.levels().listen((l) { if (mounted) setState(() => _level = l); });
    final startedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(startedAt));
      if (_elapsed >= VoiceRecorder.maxDuration) _finish();
    });
    setState(() => _phase = _Phase.recording);
  }

  Future<void> _finish() async {
    if (_phase != _Phase.recording) return;
    final locale = context.localeCode;
    _ticker?.cancel();
    await _levelSub?.cancel();
    setState(() { _phase = _Phase.processing; _level = 0; });

    File? audio;
    try {
      audio = await _recorder.stop();
      if (audio == null) return _fail(_Problem.tooShort);
      final draft = await _client.process(audio, locale: locale);
      if (!mounted) return;
      final created = await Navigator.push<bool>(context, MaterialPageRoute(
        builder: (_) => VoiceConfirmScreen(draft: draft, companyId: widget.companyId, objects: widget.objects),
      ));
      if (mounted) Navigator.pop(context, created ?? false);
    } catch (_) {
      _fail(_Problem.recognizeFailed);
    } finally {
      try {
        if (audio != null && await audio.exists()) await audio.delete();
      } catch (_) {}
    }
  }

  void _fail(_Problem problem) {
    _ticker?.cancel();
    _levelSub?.cancel();
    if (!mounted) return;
    setState(() { _phase = _Phase.error; _error = problem; _level = 0; });
  }

  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  String _problemText(_Problem p) {
    final l = context.l10n;
    return switch (p) {
      _Problem.noPermission => l.voiceNoMicPermission,
      _Problem.micFailed => l.voiceMicFailed,
      _Problem.tooShort => l.voiceTooShort,
      _Problem.recognizeFailed => l.voiceRecognizeFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    final left = VoiceRecorder.maxDuration - _elapsed;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(context.l10n.voiceTitle), backgroundColor: Colors.white),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 24),
          child: Column(children: [
            const Spacer(),
            _MicCircle(level: _level, active: _phase == _Phase.recording, brand: brand,
                busy: _phase == _Phase.processing || _phase == _Phase.starting),
            const SizedBox(height: 28),
            Text(_title(), textAlign: TextAlign.center,
                style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(_subtitle(left), textAlign: TextAlign.center,
                style: TextStyle(color: _phase == _Phase.error ? _danger : _muted, fontSize: 15, height: 1.35)),
            const Spacer(),
            if (_phase == _Phase.recording)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: _onBrand,
                    minimumSize: const Size.fromHeight(56)),
                onPressed: _finish,
                icon: const Icon(Icons.stop_rounded),
                label: Text(context.l10n.voiceDone, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
            if (_phase == _Phase.error)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: _onBrand,
                    minimumSize: const Size.fromHeight(56)),
                onPressed: _start,
                icon: const Icon(Icons.mic),
                label: Text(context.l10n.voiceAgain, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
            const SizedBox(height: 8),
            if (_phase != _Phase.processing)
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: Text(context.l10n.commonCancel, style: const TextStyle(color: Color(0xFF177A65), fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    );
  }

  String _title() {
    final l = context.l10n;
    return switch (_phase) {
      _Phase.starting => l.voiceStarting,
      _Phase.recording => l.voiceListening,
      _Phase.processing => l.voiceProcessing,
      _Phase.error => l.voiceFailedTitle,
    };
  }

  String _subtitle(Duration left) {
    final l = context.l10n;
    return switch (_phase) {
      _Phase.recording =>
        '${l.voicePrompt}\n\n${l.voiceTimer(_fmt(_elapsed), left.inSeconds < 0 ? 0 : left.inSeconds)}',
      _Phase.processing => l.voiceProcessingHint,
      _Phase.error => _error == null ? '' : _problemText(_error!),
      _Phase.starting => '',
    };
  }
}

class _MicCircle extends StatelessWidget {
  const _MicCircle({required this.level, required this.active, required this.busy, required this.brand});
  final double level;
  final bool active, busy;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    final ring = 150 + 60 * level;
    return SizedBox(
      width: 220, height: 220,
      child: Stack(alignment: Alignment.center, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: active ? ring : 150, height: active ? ring : 150,
          decoration: const BoxDecoration(color: _mint, shape: BoxShape.circle),
        ),
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(color: brand, shape: BoxShape.circle),
          child: busy
              ? const Padding(padding: EdgeInsets.all(38),
                  child: CircularProgressIndicator(color: _onBrand, strokeWidth: 3))
              : const Icon(Icons.mic, size: 56, color: _onBrand),
        ),
      ]),
    );
  }
}
