import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../directory/city.dart';
import '../directory/directory.dart';
import '../equipment/equipment_kinds.dart';
import '../floors/floor_models.dart';
import '../floors/floor_repository.dart';
import '../floors/plan_logic.dart';
import '../photo_identify/here_pickers.dart';
import '../photo_identify/identify_log.dart' show newUuid;
import '../photo_identify/photo_compress.dart';
import '../photo_identify/photo_recompress.dart' deferred as recompress;
import '../requests/requests.dart' show PlacePickerSheet;
import 'eval_labels.dart';
import 'eval_models.dart';
import 'eval_repository.dart';

/// «Добавить фото» в набор теста (шаг 34): объект и помещение → снимок
/// (камера; в браузере — файл) → человек отмечает, что на фото (единица
/// реестра помещения или «нет в реестре») → условия съёмки → сохранить.
/// ИИ здесь не запускается — его ответ не должен влиять на разметку.
/// «Сохранить и снять ещё» — серия: та же единица и условия, следующий кадр.
class EvalAddPhotoScreen extends StatefulWidget {
  const EvalAddPhotoScreen(
      {super.key,
      required this.set,
      required this.companyId,
      required this.repo});
  final EvalSet set;
  final String companyId;
  final EvalRepository repo;

  @override
  State<EvalAddPhotoScreen> createState() => _EvalAddPhotoScreenState();
}

/// «Нет в реестре» в выборе «что на фото».
const _unregistered = '';

class _EvalAddPhotoScreenState extends State<EvalAddPhotoScreen> {
  List<Obj> _objects = const [];
  String? _siteId;
  String? _roomId;
  List<PlanItem> _items = const [];
  List<Floor> _floors = const [];
  Uint8List? _photo;

  /// id единицы, [_unregistered] — «нет в реестре», null — ещё не выбрано.
  String? _truth;
  String? _seriesId;
  String _light = 'good';
  String _distance = 'medium';
  String _angle = 'front';
  bool _occlusion = false;
  bool _saving = false;
  int _saved = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final objects = await DirectoryRepo().objects();
      final (site, room) = await loadPhotoHere();
      if (!mounted) return;
      setState(() {
        _objects = objects;
        if (site != null && objects.any((o) => o.id == site)) {
          _siteId = site;
          _roomId = room;
        }
      });
      if (_siteId != null) await _loadSite();
    } catch (e) {
      debugPrint('eval add: ${e.runtimeType}');
    }
  }

  Future<void> _loadSite() async {
    final site = _siteId;
    if (site == null) return;
    final repo = FloorRepo();
    final r =
        await Future.wait<Object>([repo.itemsOf(site), repo.floorsOf(site)]);
    if (!mounted || site != _siteId) return;
    setState(() {
      _items = r[0] as List<PlanItem>;
      _floors = r[1] as List<Floor>;
      if (_roomId != null && !_items.any((i) => i.isPlace && i.id == _roomId)) {
        _roomId = null;
      }
    });
  }

  List<PlanItem> get _units => [
        for (final i in _items)
          if (!i.isPlace && i.locationId == _roomId) i
      ]..sort((a, b) => naturalCompare(a.name, b.name));

  PlanItem? get _room =>
      _items.where((i) => i.isPlace && i.id == _roomId).firstOrNull;

  Future<void> _pickSite() async {
    final picked = await showAppSheet<String>(
        context: context,
        builder: (_) =>
            HereObjectPickerSheet(objects: _objects, selected: _siteId));
    if (picked == null || picked.isEmpty || !mounted) return;
    if (picked != _siteId) {
      setState(() {
        _siteId = picked;
        _roomId = null;
        _truth = null;
        _seriesId = null;
        _items = const [];
      });
      await _loadSite();
    }
    if (mounted) await _pickRoom();
  }

  Future<void> _pickRoom() async {
    final l = context.l10n;
    final places = sortPlacesForPicker([
      for (final i in _items)
        if (i.isPlace) i
    ], _floors);
    if (places.isEmpty) return;
    final room = await showAppSheet<String>(
        context: context,
        builder: (_) => PlacePickerSheet(
            places: places,
            floors: {for (final f in _floors) f.id: f.name},
            selected: _roomId,
            noneLabel: l.evalChooseRoom));
    if (room == null || room.isEmpty || !mounted) return;
    setState(() {
      if (room != _roomId) {
        _truth = null;
        _seriesId = null;
      }
      _roomId = room;
    });
    await savePhotoHere(_siteId, _roomId);
  }

  Future<void> _take() async {
    final l = context.l10n;
    Uint8List? bytes;
    try {
      // Тот же снимок, что у «Узнать по фото»: ≤ 1280 px, JPEG 80 %.
      final file = await ImagePicker().pickImage(
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: kIdentifyMaxSide.toDouble(),
        maxHeight: kIdentifyMaxSide.toDouble(),
        imageQuality: kIdentifyQuality,
        requestFullMetadata: false,
      );
      if (file == null) return;
      bytes = await file.readAsBytes();
      if (needsRecompress(bytes)) {
        await recompress.loadLibrary();
        bytes = recompress.recompressJpeg(bytes);
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      showAppMessage(
          context,
          e.code == 'camera_access_denied'
              ? l.photoCameraDenied
              : l.photoCameraFailed,
          type: AppMessageType.error);
      return;
    } catch (e) {
      debugPrint('eval pick: ${e.runtimeType}');
      bytes = null;
    }
    if (!mounted) return;
    if (bytes == null || sniffImageMime(bytes) != 'image/jpeg') {
      showAppMessage(context, l.photoFailed, type: AppMessageType.error);
      return;
    }
    setState(() => _photo = bytes);
  }

  void _setTruth(String v) => setState(() {
        if (v != _truth) _seriesId = newUuid();
        _truth = v;
      });

  bool get _ready =>
      _siteId != null && _roomId != null && _photo != null && _truth != null;

  Future<void> _save({required bool next}) async {
    final l = context.l10n;
    if (!_ready) {
      showAppMessage(context, l.evalFillAll, type: AppMessageType.error);
      return;
    }
    setState(() => _saving = true);
    try {
      final s = await widget.repo.addSample(
        set: widget.set,
        companyId: widget.companyId,
        jpeg: _photo!,
        siteId: _siteId!,
        roomId: _roomId!,
        equipmentId: _truth == _unregistered ? null : _truth,
        seriesId: _seriesId,
        light: _light,
        distance: _distance,
        angle: _angle,
        occlusion: _occlusion,
      );
      if (!mounted) return;
      _saved++;
      showAppMessage(context, l.evalSaved(s.split));
      if (!next) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _photo = null;
        _saving = false;
      });
      await _take();
    } catch (e) {
      debugPrint('eval save: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      showAppMessage(context, l.evalSaveFailed, type: AppMessageType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final site = _objects.where((o) => o.id == _siteId).firstOrNull;
    final units = _units;
    return AppScaffold(
      title: l.evalAddTitle,
      bottomBar: BottomActionBar(
        child: Row(children: [
          Expanded(
            child: AppButton.secondary(
              label: l.evalSave,
              onPressed: _saving || !_ready ? null : () => _save(next: false),
            ),
          ),
          const SizedBox(width: AppSpace.s),
          Expanded(
            child: AppButton.primary(
              icon: AppIcons.camera,
              label: l.evalSaveNext,
              loading: _saving,
              onPressed: _saving || !_ready ? null : () => _save(next: true),
            ),
          ),
        ]),
      ),
      slivers: [
        SliverContent(
          sliver: SliverList.list(children: [
            AppGroup(header: l.evalStepPlace, children: [
              AppRow(
                leading: const LeadingIcon(AppIcons.building),
                title:
                    site == null ? l.evalChooseSite : objectDisplayName(site),
                onTap: _saving ? null : _pickSite,
              ),
              if (_siteId != null)
                AppRow(
                  leading: const LeadingIcon(AppIcons.room),
                  title: _room?.label ?? l.evalChooseRoom,
                  onTap: _saving ? null : _pickRoom,
                ),
            ]),
            AppGroup(
              header: l.evalStepPhoto,
              footer: _saved > 0 && _truth != null ? l.evalSeries : null,
              children: [
                if (_photo != null)
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.m),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.field),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: Image.memory(_photo!, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                AppRow(
                  leading: const LeadingIcon(AppIcons.camera),
                  title: _photo != null
                      ? l.evalRetake
                      : kIsWeb
                          ? l.evalUploadPhoto
                          : l.evalTakePhoto,
                  onTap: _saving ? null : _take,
                ),
              ],
            ),
            if (_roomId != null)
              AppGroup(
                header: l.evalStepTruth,
                footer: l.evalTruthHint,
                children: [
                  if (units.isEmpty)
                    AppRow(title: l.evalRoomNoUnits, chevron: false),
                  for (final u in units)
                    AppCheckRow(
                      leading: LeadingIcon(
                          assetIcon(u.equipmentKind, u.category ?? '')),
                      title: u.name,
                      subtitle: [
                        if (u.equipmentKind != null)
                          equipmentKindLabel(l, u.equipmentKind!),
                        if (u.inventoryNo != null) u.inventoryNo!,
                      ].join(' · '),
                      selected: _truth == u.id,
                      onTap: _saving ? null : () => _setTruth(u.id),
                    ),
                  AppCheckRow(
                    leading: const LeadingIcon(AppIcons.eqOther),
                    title: l.evalNotInRegistry,
                    subtitle: l.evalNotInRegistryHint,
                    selected: _truth == _unregistered,
                    onTap: _saving ? null : () => _setTruth(_unregistered),
                  ),
                ],
              ),
            AppGroup(header: l.evalStepConditions, children: [
              _segments(l.evalLight, kEvalLight, _light, evalLightLabel(l),
                  (v) => setState(() => _light = v)),
              _segments(l.evalDistance, kEvalDistance, _distance,
                  evalDistanceLabel(l), (v) => setState(() => _distance = v)),
              _segments(l.evalAngle, kEvalAngle, _angle, evalAngleLabel(l),
                  (v) => setState(() => _angle = v)),
              AppCheckRow(
                title: l.evalOcclusion,
                selected: _occlusion,
                onTap: _saving
                    ? null
                    : () => setState(() => _occlusion = !_occlusion),
              ),
            ]),
          ]),
        ),
        const SliverBottomInset(),
      ],
    );
  }

  Widget _segments(String title, List<String> values, String selected,
          String Function(String) label, ValueChanged<String> onChanged) =>
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpace.rowH, AppSpace.s, AppSpace.rowH, AppSpace.s),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppText.footnote),
          const SizedBox(height: AppSpace.xs),
          SegmentedControl<String>(
            segments: [for (final v in values) Segment(v, label(v))],
            selected: selected,
            onChanged: _saving ? (_) {} : onChanged,
          ),
        ]),
      );
}
