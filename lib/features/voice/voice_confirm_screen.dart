import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../directory/directory.dart';
import '../requests/requests.dart';
import 'voice_draft.dart';
import 'voice_intake_client.dart';
import '../../core/app_message.dart';
import '../../l10n/app_localizations.dart';

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
      showAppMessage(context, context.l10n.formWhatRequired);
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
      showAppMessage(context, context.l10n.voiceSendFailed,
          type: AppMessageType.error);
    }
  }

  /// Название выбранного места или «Не указано».
  String _whereName() {
    final w = _where;
    if (w != null && w.startsWith('p:')) {
      for (final p in _places) {
        if (p.id == w.substring(2)) return p.fullName;
      }
    } else if (w != null && w.startsWith('o:')) {
      for (final o in widget.objects) {
        if (o.id == w.substring(2)) return o.name;
      }
    }
    return context.l10n.commonNotSpecified;
  }

  /// Выбор места — шторка со списком: «Не указано», объекты, помещения.
  Future<void> _pickWhere() async {
    final l = context.l10n;
    Widget option(String? value, String title, IconData? icon) => AppRow(
          leading: icon == null ? null : LeadingIcon(icon),
          title: title,
          chevron: false,
          trailing: _where == value
              ? const Icon(AppIcons.check,
                  size: AppSizes.icon, color: AppColors.accentText)
              : null,
          // В Navigator.pop нельзя передать null как «выбрано „Не указано“»:
          // null — это «закрыли шторку». Поэтому — пустая строка.
          onTap: () => Navigator.pop(context, value ?? ''),
        );
    final picked = await showAppSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetHeader(title: l.voiceWhere, cancelLabel: l.commonCancel),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.l),
              children: [
                AppGroup(
                    separatorInset: AppSpace.separatorInsetIcon,
                    children: [
                      option(null, l.commonNotSpecified, null),
                      for (final o in widget.objects)
                        option('o:${o.id}', o.name, AppIcons.building),
                      for (final p in _places)
                        option('p:${p.id}', p.fullName, AppIcons.room),
                    ]),
              ],
            ),
          ),
        ]),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _where = picked.isEmpty ? null : picked);
  }

  /// Поле внутри белой группы: без рамки, подпись — имя поля для диктора.
  InputDecoration _field(String label) => InputDecoration(
        labelText: label,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: true,
        fillColor: AppColors.surface,
      );

  /// Срочность — сегмент-контрол. На узком экране (телефон) сегменты
  /// по ширине подписей: «Критический» не помещается в четверть строки.
  Widget _urgency() {
    final l = context.l10n;
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 440;
      final control = SegmentedControl<String>(
        expand: wide,
        segments: [
          for (final p in _priorities) Segment(p, l.priority(p)),
        ],
        selected: _priority,
        onChanged: (p) => setState(() => _priority = p),
      );
      return wide
          ? control
          : Align(alignment: AlignmentDirectional.centerStart, child: control);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = context.localeCode;
    // Вид шторки: язычок и шапка «Отмена · Проверьте заявку».
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const SheetGrabber(),
          SheetHeader(
              title: l.voiceConfirmTitle,
              cancelLabel: l.commonCancel,
              onCancel: () => Navigator.pop(context, false)),
          if (_loading)
            const Expanded(child: AppLoader())
          else ...[
            // Поля прокручиваются, «Отправить» закреплена внизу и видна всегда.
            // Полосу прокрутки с ползунком рисует AppScrollBehavior.
            Expanded(
              child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(AppSpace.screen,
                      AppSpace.s, AppSpace.screen, AppSpace.xl),
                  children: [
                    ContentWidth(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _content(l, locale)),
                    ),
                  ]),
            ),
            BottomActionBar(
              child: AppButton.primary(
                label: l.voiceSend,
                icon: AppIcons.send,
                loading: _saving,
                onPressed: _saving ? null : _submit,
              ),
            ),
          ],
        ]),
      ),
    );
  }

  List<Widget> _content(AppLocalizations l, String locale) => [
        // «Вы сказали» — на тонированном фоне, с пометкой, кто разобрал.
        AppCard(
          color: AppColors.accentTint,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(widget.typed ? l.voiceYouWrote : l.voiceYouSaid,
                    style: AppText.footnote.copyWith(
                        color: AppColors.accentText,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: AppSpace.s),
              _SourceBadge(source: widget.draft.source),
            ]),
            const SizedBox(height: 6),
            Text(l.quoted(widget.draft.transcript), style: AppText.callout),
          ]),
        ),
        Padding(
          padding:
              const EdgeInsetsDirectional.symmetric(horizontal: AppSpace.rowH),
          child: Text(l.voiceEditHint, style: AppText.footnote),
        ),
        const SizedBox(height: AppSpace.m),
        AppGroup(children: [
          TextField(
              controller: _titleC,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.body,
              decoration: _field(l.formWhat)),
          TextField(
              controller: _descC,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.body,
              decoration: _field(l.formDetailsHint)),
        ]),
        SectionHeader(l.fieldWorkType),
        if (_layers.isEmpty)
          Text(l.formLayersFailed, style: AppText.footnote)
        else
          Wrap(spacing: AppSpace.s, runSpacing: AppSpace.s, children: [
            for (final t in _layers)
              AppChip(
                  label: t.label(locale),
                  selected: _layer?.id == t.id,
                  onTap: () =>
                      setState(() => _layer = _layer?.id == t.id ? null : t)),
          ]),
        if (_layer == null && _layers.isNotEmpty)
          Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpace.s),
              child: Text(l.voicePickLayer,
                  style: AppText.footnote.copyWith(color: AppColors.danger))),
        SectionHeader(l.voiceWhere),
        AppGroup(children: [
          AppRow(
            leading: const LeadingIcon(AppIcons.place),
            title: _whereName(),
            subtitle: widget.draft.locationHint == null
                ? null
                : l.voiceHeard(widget.draft.locationHint!),
            onTap: _pickWhere,
          ),
        ]),
        SectionHeader(l.voiceUrgency),
        _urgency(),
      ];
}

/// Пометка «✦ Разобрано ИИ» / «Разобрано по словарю» — капсула.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});
  final DraftSource source;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ai = source == DraftSource.ai;
    final color = ai ? AppColors.accentText : AppColors.secondary;
    return Container(
      height: AppSizes.pillHeight,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 9),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ai ? AppIcons.sparkles : AppIcons.list, size: 14, color: color),
        const SizedBox(width: 5),
        Text(ai ? l.voiceParsedByAi : l.voiceParsedByDictionary,
            maxLines: 1,
            style: AppText.caption
                .copyWith(color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
