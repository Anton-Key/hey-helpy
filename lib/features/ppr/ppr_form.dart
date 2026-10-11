import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import '../directory/city.dart';
import '../directory/directory.dart';
import 'ppr_logic.dart';
import 'ppr_repository.dart';
import 'ppr_tab.dart';
import 'ppr_text.dart';

/// Форма плана ППР (новый или изменить). Сохраняет менеджер — права
/// проверяет база (0015: mplans_manage, проверка объекта / помещения /
/// оборудования / системы одной компании). Возвращает true, если сохранили.
class PprPlanFormScreen extends StatefulWidget {
  const PprPlanFormScreen({super.key, required this.data, this.plan});
  final PprData data;
  final MaintenancePlan? plan;

  @override
  State<PprPlanFormScreen> createState() => _PprPlanFormScreenState();
}

class _PprPlanFormScreenState extends State<PprPlanFormScreen> {
  final _repo = PprRepository();
  final _dir = DirectoryRepo();
  late final _title = TextEditingController(text: widget.plan?.title ?? '');
  late final _desc =
      TextEditingController(text: widget.plan?.description ?? '');
  late final _checklist =
      TextEditingController(text: (widget.plan?.checklist ?? []).join('\n'));
  late final _days = TextEditingController(text: '${widget.plan?.days ?? 7}');

  String? _objectId;
  String? _locationId;
  String? _assetId;
  String? _layerId;
  PeriodKind _kind = PeriodKind.month;
  DateTime _startsOn = dateOnly(DateTime.now());
  String _priority = 'normal';
  bool _photo = true;
  bool _busy = false;

  List<Place> _places = const [];
  List<({String id, String name, String locationId})> _assets = const [];

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    if (p != null) {
      _objectId = p.objectId;
      _locationId = p.locationId;
      _assetId = p.assetId;
      _layerId = p.layerId;
      _kind = p.kind;
      _startsOn = p.startsOn;
      _priority = p.priority;
      _photo = p.requiresPhoto;
      _loadObjectParts(p.objectId);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _checklist.dispose();
    _days.dispose();
    super.dispose();
  }

  Future<void> _loadObjectParts(String objectId) async {
    try {
      final r = await Future.wait<Object>(
          [_dir.placesOf(objectId), _repo.assetsOf(objectId)]);
      if (!mounted || _objectId != objectId) return;
      setState(() {
        _places = r[0] as List<Place>;
        _assets = r[1] as List<({String id, String name, String locationId})>;
      });
    } catch (e) {
      debugPrint('PprForm parts: $e');
    }
  }

  Obj? get _object {
    for (final o in widget.data.objects) {
      if (o.id == _objectId) return o;
    }
    return null;
  }

  Future<T?> _pick<T>({
    required String title,
    required List<(T?, String)> options,
    required T? selected,
  }) {
    return showAppSheet<T>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetHeader(
              title: title,
              doneLabel: context.l10n.commonCancel,
              onDone: () => Navigator.pop(ctx)),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.xl),
              child: AppGroup(children: [
                for (final o in options)
                  AppCheckRow(
                    title: o.$2,
                    selected: o.$1 == selected,
                    onTap: () => Navigator.pop(ctx, o.$1),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _chooseObject(AppLocalizations l) async {
    final objs = [...widget.data.objects]..sort((a, b) => objectDisplayName(a)
        .toLowerCase()
        .compareTo(objectDisplayName(b).toLowerCase()));
    final id = await _pick<String>(
        title: l.pprFormObject,
        options: [for (final o in objs) (o.id, objectDisplayName(o))],
        selected: _objectId);
    if (id == null || id == _objectId) return;
    setState(() {
      _objectId = id;
      _locationId = null;
      _assetId = null;
      _places = const [];
      _assets = const [];
    });
    await _loadObjectParts(id);
  }

  Future<void> _choosePlace(AppLocalizations l) async {
    const none = '';
    final id = await _pick<String>(
        title: l.pprFormPlace,
        options: [
          (none, l.pprFormNone),
          for (final p in _places) (p.id, p.label),
        ],
        selected: _locationId ?? none);
    if (id == null) return;
    setState(() {
      _locationId = id.isEmpty ? null : id;
      if (_assetId != null &&
          _locationId != null &&
          !_assets
              .any((a) => a.id == _assetId && a.locationId == _locationId)) {
        _assetId = null;
      }
    });
  }

  Future<void> _chooseAsset(AppLocalizations l) async {
    const none = '';
    final list = [
      for (final a in _assets)
        if (_locationId == null || a.locationId == _locationId) a
    ];
    final id = await _pick<String>(
        title: l.pprFormAsset,
        options: [
          (none, l.pprFormNone),
          for (final a in list) (a.id, a.name),
        ],
        selected: _assetId ?? none);
    if (id == null) return;
    setState(() => _assetId = id.isEmpty ? null : id);
  }

  Future<void> _chooseStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startsOn,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _startsOn = dateOnly(d));
  }

  Future<void> _save() async {
    final l = context.l10n;
    final title = _title.text.trim();
    if (title.isEmpty || _objectId == null || _layerId == null) {
      showAppMessage(context, l.pprFormRequired, type: AppMessageType.error);
      return;
    }
    int? days;
    if (_kind == PeriodKind.days) {
      days = int.tryParse(_days.text.trim());
      if (days == null || days < 1 || days > 3660) {
        showAppMessage(context, l.pprFormDaysInvalid,
            type: AppMessageType.error);
        return;
      }
    }
    final plan = MaintenancePlan(
      id: widget.plan?.id ?? '',
      objectId: _objectId!,
      locationId: _locationId,
      assetId: _assetId,
      layerId: _layerId!,
      title: title,
      description: _desc.text,
      kind: _kind,
      days: days,
      startsOn: _startsOn,
      checklist: [
        for (final line in _checklist.text.split('\n'))
          if (line.trim().isNotEmpty) line.trim()
      ],
      requiresPhoto: _photo,
      priority: _priority,
      active: widget.plan?.active ?? true,
    );
    setState(() => _busy = true);
    try {
      if (widget.plan == null) {
        final cid = widget.data.companyId;
        if (cid == null) throw const PostgrestException(message: 'no company');
        await _repo.create(plan, companyId: cid);
      } else {
        await _repo.update(plan);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('PprForm save: $e');
      if (!mounted) return;
      final dup = e is PostgrestException && e.code == '23505';
      showAppMessage(context, dup ? l.pprDuplicate : l.saveFailed,
          type: AppMessageType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final obj = _object;
    String? placeName;
    for (final p in _places) {
      if (p.id == _locationId) placeName = p.label;
    }
    String? assetName;
    for (final a in _assets) {
      if (a.id == _assetId) assetName = a.name;
    }
    return AppScaffold(
      title: widget.plan == null ? l.pprFormNew : l.pprFormEdit,
      large: false,
      bottomBar: BottomActionBar(
        child: AppButton.primary(
            label: l.commonSave,
            loading: _busy,
            onPressed: _busy ? null : _save),
      ),
      slivers: [
        SliverContent(
          sliver: SliverList.list(children: [
            SectionHeader(l.pprFormTitle),
            TextField(
                controller: _title,
                maxLength: 120,
                decoration: InputDecoration(
                    hintText: l.pprFormTitleHint, counterText: '')),
            SectionHeader(l.pprFormDescription),
            TextField(
                controller: _desc,
                minLines: 2,
                maxLines: 5,
                decoration:
                    InputDecoration(hintText: l.pprFormDescriptionHint)),
            const SizedBox(height: AppSpace.group),
            AppGroup(children: [
              AppRow(
                  leading: const LeadingIcon(AppIcons.building),
                  title: l.pprFormObject,
                  value:
                      obj == null ? l.pprChooseObject : objectDisplayName(obj),
                  onTap: () => _chooseObject(l)),
              AppRow(
                  leading: const LeadingIcon(AppIcons.room),
                  title: l.pprFormPlace,
                  value: placeName ?? l.pprFormNone,
                  onTap: obj == null ? null : () => _choosePlace(l)),
              AppRow(
                  leading: const LeadingIcon(AppIcons.wrench),
                  title: l.pprFormAsset,
                  value: assetName ?? l.pprFormNone,
                  onTap: obj == null ? null : () => _chooseAsset(l)),
            ]),
            SectionHeader(l.pprFormSystem),
            Wrap(spacing: AppSpace.s, runSpacing: AppSpace.s, children: [
              for (final y in widget.data.layers)
                AppChip(
                    label: y.label(l.localeName),
                    selected: _layerId == y.id,
                    onTap: () => setState(() => _layerId = y.id)),
            ]),
            SectionHeader(l.pprFormPeriod),
            Wrap(spacing: AppSpace.s, runSpacing: AppSpace.s, children: [
              for (final k in PeriodKind.values)
                AppChip(
                    label: pprKindName(l, k),
                    selected: _kind == k,
                    onTap: () => setState(() => _kind = k)),
            ]),
            if (_kind == PeriodKind.days) ...[
              SectionHeader(l.pprFormDays),
              TextField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration()),
            ],
            const SizedBox(height: AppSpace.group),
            AppGroup(children: [
              AppRow(
                  leading: const LeadingIcon(AppIcons.calendar),
                  title: l.pprFormStarts,
                  value: l.date(_startsOn),
                  onTap: _chooseStart),
              AppRow(
                leading: const LeadingIcon(AppIcons.camera),
                title: l.pprFormPhoto,
                chevron: false,
                trailing: Switch(
                    value: _photo,
                    onChanged: (v) => setState(() => _photo = v)),
              ),
            ]),
            SectionHeader(l.fieldPriority),
            Wrap(spacing: AppSpace.s, runSpacing: AppSpace.s, children: [
              for (final p in const ['low', 'normal', 'high', 'critical'])
                AppChip(
                    label: l.priority(p),
                    selected: _priority == p,
                    onTap: () => setState(() => _priority = p)),
            ]),
            SectionHeader(l.pprFormChecklist),
            TextField(
                controller: _checklist,
                minLines: 3,
                maxLines: 10,
                decoration: InputDecoration(hintText: l.pprFormChecklistHint)),
            const SizedBox(height: AppSpace.xl),
          ]),
        ),
      ],
    );
  }
}
