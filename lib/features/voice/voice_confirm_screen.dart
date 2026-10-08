import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../directory/directory.dart';
import '../requests/requests.dart';
import 'voice_draft.dart';
import 'voice_intake_client.dart';

const _ink = Color(0xFF1C1E22);
const _muted = Color(0xFF8A9098);
const _onBrand = Color(0xFF06342A);
const _mint = Color(0xFFD8F0EA);
const _danger = Color(0xFFC24444);

const _priorities = ['low', 'normal', 'high', 'critical'];

/// Проверка черновика голосовой заявки: что распознано, заголовок и описание
/// (можно поправить), вид работ, место, срочность. Заявка создаётся только по
/// кнопке «Отправить»; подрядчика затем назначает база по слою.
class VoiceConfirmScreen extends StatefulWidget {
  const VoiceConfirmScreen(
      {super.key,
      required this.draft,
      required this.companyId,
      required this.objects,
      this.catalog,
      this.typed = false});
  final VoiceDraft draft;
  final String companyId;
  final List<Obj> objects;

  /// Уже загруженные слои и помещения; если пусто — экран загрузит сам.
  final IntakeCatalog? catalog;

  /// Текст набран, а не сказан: «Вы написали», канал заявки — text.
  final bool typed;

  @override
  State<VoiceConfirmScreen> createState() => _VoiceConfirmScreenState();
}

class _VoiceConfirmScreenState extends State<VoiceConfirmScreen> {
  final _dir = DirectoryRepo();
  final _repo = RequestsRepo();
  late final _titleC = TextEditingController(text: widget.draft.title);
  late final _descC =
      TextEditingController(text: widget.draft.description ?? '');
  late String _priority = widget.draft.priority;
  List<Layer> _layers = const [];
  List<Place> _places = const [];
  Layer? _layer;

  /// 'o:<id>' — объект целиком, 'p:<id>' — помещение.
  String? _where;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    var layers = widget.catalog?.layers ?? const <Layer>[];
    var places = widget.catalog?.places ?? const <Place>[];
    if (layers.isEmpty) {
      try {
        layers = await _dir.layers();
      } catch (_) {}
    }
    if (places.isEmpty) {
      try {
        places = await _dir.places();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _layers = layers;
      _places = places;
      _layer = Layer.find(layers,
          id: widget.draft.layerId, name: widget.draft.layer);
      _where = _initialWhere(widget.draft, places, widget.objects);
      _loading = false;
    });
  }

  /// Место из разбора: точное помещение или объект, иначе — по подсказке.
  static String? _initialWhere(
      VoiceDraft d, List<Place> places, List<Obj> objects) {
    if (d.locationId != null && places.any((p) => p.id == d.locationId)) {
      return 'p:${d.locationId}';
    }
    if (d.objectId != null && objects.any((o) => o.id == d.objectId)) {
      return 'o:${d.objectId}';
    }
    return _matchWhere(d.locationHint, places, objects);
  }

  /// Подбирает помещение (или объект) по словам из подсказки:
  /// побеждает вариант, где совпало больше слов. Сравниваем по началу
  /// слова, чтобы «переговорной» совпало с «Переговорная».
  static String? _matchWhere(
      String? hint, List<Place> places, List<Obj> objects) {
    if (hint == null || hint.trim().isEmpty) return null;
    final words = hint
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((w) => w.length >= 3 || RegExp(r'^\d+$').hasMatch(w))
        .map((w) => w.length > 5 ? w.substring(0, 5) : w)
        .toSet();
    if (words.isEmpty) return null;
    int score(String text) {
      final t = text.toLowerCase();
      return words.where(t.contains).length;
    }

    String? best;
    var bestScore = 0;
    for (final p in places) {
      final s = score(p.fullName);
      if (s > bestScore) {
        best = 'p:${p.id}';
        bestScore = s;
      }
    }
    for (final o in objects) {
      final s = score(o.name);
      if (s > bestScore) {
        best = 'o:${o.id}';
        bestScore = s;
      }
    }
    return best;
  }

  Future<void> _submit() async {
    final title = _titleC.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.formWhatRequired)));
      return;
    }
    String? objectId, locationId;
    final w = _where;
    if (w != null && w.startsWith('p:')) {
      final place = _places.firstWhere((p) => p.id == w.substring(2));
      locationId = place.id;
      objectId = place.objectId;
    } else if (w != null && w.startsWith('o:')) {
      objectId = w.substring(2);
    }
    setState(() => _saving = true);
    try {
      await _repo.create(
        companyId: widget.companyId,
        title: title,
        description: _descC.text.trim().isEmpty ? null : _descC.text.trim(),
        layer: _layer,
        priority: _priority,
        objectId: objectId,
        locationId: locationId,
        recurring: false,
        inputChannel: widget.typed ? 'text' : 'voice',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.voiceSendFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    const brand = HeyHelpyTheme.brand;
    final l = context.l10n;
    final locale = context.localeCode;
    final side = math.max(16.0, (MediaQuery.sizeOf(context).width - 640) / 2);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          title: Text(l.voiceConfirmTitle), backgroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              // На широком экране — колонка до 640 px по центру.
              padding: EdgeInsetsDirectional.fromSTEB(side, 8, side, 32),
              children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: _mint, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.typed ? l.voiceYouWrote : l.voiceYouSaid,
                              style: const TextStyle(
                                  color: _onBrand,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(l.quoted(widget.draft.transcript),
                              style: const TextStyle(
                                  color: _ink, fontSize: 15, height: 1.35)),
                        ]),
                  ),
                  const SizedBox(height: 10),
                  _SourceNote(source: widget.draft.source),
                  const SizedBox(height: 8),
                  Text(l.voiceEditHint,
                      style: const TextStyle(color: _muted, fontSize: 13)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _titleC,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                          labelText: l.formWhat,
                          border: const OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _descC,
                      minLines: 2,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                          labelText: l.formDetailsHint,
                          border: const OutlineInputBorder())),
                  const SizedBox(height: 18),
                  _label(l.fieldWorkType),
                  if (_layers.isEmpty)
                    Text(l.formLayersFailed,
                        style: const TextStyle(color: _muted))
                  else
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final t in _layers)
                        _chip(
                            t.label(locale),
                            _layer?.id == t.id,
                            brand,
                            () => setState(
                                () => _layer = _layer?.id == t.id ? null : t)),
                    ]),
                  if (_layer == null && _layers.isNotEmpty)
                    Padding(
                        padding: const EdgeInsetsDirectional.only(top: 6),
                        child: Text(l.voicePickLayer,
                            style:
                                const TextStyle(color: _danger, fontSize: 13))),
                  const SizedBox(height: 18),
                  _label(l.voiceWhere),
                  DropdownButtonFormField<String?>(
                    initialValue: _where,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                    items: [
                      DropdownMenuItem<String?>(
                          value: null, child: Text(l.commonNotSpecified)),
                      for (final o in widget.objects)
                        DropdownMenuItem<String?>(
                            value: 'o:${o.id}',
                            child:
                                Text(o.name, overflow: TextOverflow.ellipsis)),
                      for (final p in _places)
                        DropdownMenuItem<String?>(
                            value: 'p:${p.id}',
                            child: Text(p.fullName,
                                overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _where = v),
                  ),
                  if (widget.draft.locationHint != null)
                    Padding(
                        padding: const EdgeInsetsDirectional.only(top: 6),
                        child: Text(l.voiceHeard(widget.draft.locationHint!),
                            style:
                                const TextStyle(color: _muted, fontSize: 13))),
                  const SizedBox(height: 18),
                  _label(l.voiceUrgency),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final p in _priorities)
                      _chip(l.priority(p), _priority == p, brand,
                          () => setState(() => _priority = p)),
                  ]),
                  const SizedBox(height: 28),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: brand,
                        foregroundColor: _onBrand,
                        minimumSize: const Size.fromHeight(56)),
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: _onBrand))
                        : Text(l.voiceSend,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 17)),
                  ),
                ]),
    );
  }

  Widget _label(String t) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Text(t,
          style: const TextStyle(
              color: _ink, fontWeight: FontWeight.w700, fontSize: 15)));

  Widget _chip(String text, bool selected, Color brand, VoidCallback onTap) =>
      ChoiceTag(label: text, selected: selected, onTap: onTap, filled: true);
}

/// Пометка «Разобрано ИИ» / «Разобрано по словарю».
class _SourceNote extends StatelessWidget {
  const _SourceNote({required this.source});
  final DraftSource source;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ai = source == DraftSource.ai;
    return Row(children: [
      Icon(ai ? Icons.auto_awesome : Icons.menu_book_outlined,
          size: 16, color: ai ? HeyHelpyTheme.link : _muted),
      const SizedBox(width: 6),
      Flexible(
          child: Text(ai ? l.voiceParsedByAi : l.voiceParsedByDictionary,
              style: TextStyle(
                  color: ai ? HeyHelpyTheme.link : _muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600))),
    ]);
  }
}
