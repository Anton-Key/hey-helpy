import 'package:flutter/material.dart';

import '../directory/directory.dart';
import '../requests/requests.dart';
import 'voice_draft.dart';

const _ink = Color(0xFF1C1E22);
const _muted = Color(0xFF8A9098);
const _line = Color(0xFFE8EAED);
const _onBrand = Color(0xFF06342A);
const _mint = Color(0xFFD8F0EA);
const _danger = Color(0xFFC24444);

const _priorities = [['low', 'Низкий'], ['normal', 'Обычный'], ['high', 'Высокий'], ['critical', 'Критич.']];

/// Проверка черновика голосовой заявки. Заявка создаётся только по кнопке
/// «Отправить»; подрядчика затем назначает база по слою.
class VoiceConfirmScreen extends StatefulWidget {
  const VoiceConfirmScreen({super.key, required this.draft, required this.companyId, required this.objects});
  final VoiceDraft draft;
  final String companyId;
  final List<Obj> objects;

  @override
  State<VoiceConfirmScreen> createState() => _VoiceConfirmScreenState();
}

class _VoiceConfirmScreenState extends State<VoiceConfirmScreen> {
  final _dir = DirectoryRepo();
  final _repo = RequestsRepo();
  late final _titleC = TextEditingController(text: widget.draft.title);
  late final _descC = TextEditingController(text: widget.draft.description ?? '');
  late String _priority = widget.draft.priority;
  List<String> _layers = const [];
  List<Place> _places = const [];
  String? _layer;
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
    List<String> layers = const [];
    List<Place> places = const [];
    try { layers = await _dir.layerNames(); } catch (_) {}
    try { places = await _dir.places(); } catch (_) {}
    if (!mounted) return;
    setState(() {
      _layers = layers;
      _places = places;
      _layer = _matchLayer(widget.draft.layer, layers);
      _where = _matchWhere(widget.draft.locationHint, places, widget.objects);
      _loading = false;
    });
  }

  static String? _matchLayer(String? layer, List<String> layers) {
    if (layer == null) return null;
    final l = layer.trim().toLowerCase();
    for (final name in layers) {
      if (name.toLowerCase() == l) return name;
    }
    return null;
  }

  /// Подбирает помещение (или объект) по словам из подсказки:
  /// побеждает вариант, где совпало больше слов. Сравниваем по началу
  /// слова, чтобы «переговорной» совпало с «Переговорная».
  static String? _matchWhere(String? hint, List<Place> places, List<Obj> objects) {
    if (hint == null || hint.trim().isEmpty) return null;
    final words = hint.toLowerCase().split(RegExp(r'[^a-zа-яё0-9]+'))
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
      if (s > bestScore) { best = 'p:${p.id}'; bestScore = s; }
    }
    for (final o in objects) {
      final s = score(o.name);
      if (s > bestScore) { best = 'o:${o.id}'; bestScore = s; }
    }
    return best;
  }

  Future<void> _submit() async {
    final title = _titleC.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Напишите, что случилось')));
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
        companyId: widget.companyId, title: title,
        description: _descC.text.trim().isEmpty ? null : _descC.text.trim(),
        workType: _layer, priority: _priority, objectId: objectId, locationId: locationId,
        recurring: false, inputChannel: 'voice',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Не удалось отправить заявку. Проверьте интернет и попробуйте ещё раз.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Проверьте заявку'), backgroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _mint, borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Вы сказали', style: TextStyle(color: _onBrand, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text('«${widget.draft.transcript}»', style: const TextStyle(color: _ink, fontSize: 15, height: 1.35)),
                ]),
              ),
              const SizedBox(height: 18),
              TextField(controller: _titleC, textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Что случилось', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: _descC, minLines: 2, maxLines: 5, textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Подробности', border: OutlineInputBorder())),
              const SizedBox(height: 18),
              _label('Вид работ'),
              if (_layers.isEmpty)
                const Text('Не удалось загрузить виды работ — заявку можно отправить без него.',
                    style: TextStyle(color: _muted))
              else
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final l in _layers) _chip(l, _layer == l, brand, () => setState(() => _layer = _layer == l ? null : l)),
                ]),
              if (widget.draft.layer != null && _layer == null && _layers.isNotEmpty)
                const Padding(padding: EdgeInsets.only(top: 6),
                    child: Text('Выберите вид работ, чтобы заявка сразу ушла нужному подрядчику.',
                        style: TextStyle(color: _danger, fontSize: 13))),
              const SizedBox(height: 18),
              _label('Где'),
              DropdownButtonFormField<String?>(
                initialValue: _where,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Не указано')),
                  for (final o in widget.objects)
                    DropdownMenuItem<String?>(value: 'o:${o.id}', child: Text(o.name, overflow: TextOverflow.ellipsis)),
                  for (final p in _places)
                    DropdownMenuItem<String?>(value: 'p:${p.id}', child: Text(p.fullName, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _where = v),
              ),
              if (widget.draft.locationHint != null)
                Padding(padding: const EdgeInsets.only(top: 6),
                    child: Text('Услышали: «${widget.draft.locationHint}»',
                        style: const TextStyle(color: _muted, fontSize: 13))),
              const SizedBox(height: 18),
              _label('Срочность'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in _priorities) _chip(p[1], _priority == p[0], brand, () => setState(() => _priority = p[0])),
              ]),
              const SizedBox(height: 28),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: _onBrand,
                    minimumSize: const Size.fromHeight(56)),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: _onBrand))
                    : const Text('Отправить', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              ),
            ]),
    );
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Text(t, style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 15)));

  Widget _chip(String text, bool selected, Color brand, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? brand : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? brand : _line),
          ),
          child: Text(text, style: TextStyle(color: selected ? _onBrand : _ink, fontWeight: FontWeight.w600)),
        ),
      );
}
