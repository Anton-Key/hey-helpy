import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import '../directory/city.dart';
import '../directory/directory.dart';
import '../equipment/asset_card.dart';
import '../equipment/equipment_form.dart';
import '../equipment/equipment_kinds.dart';
import '../equipment/equipment_models.dart';
import '../equipment/equipment_repository.dart';
import '../floors/floor_models.dart';
import '../floors/floor_repository.dart';
import '../floors/plan_logic.dart';
import '../photos/photo_repository.dart';
import '../regions/geo_pickers.dart';
import '../requests/requests.dart';
import '../voice/voice_intake_client.dart' show IntakeWait, intakeWaitStage;
import 'identify_client.dart';
import 'identify_log.dart';
import 'identify_models.dart';
import 'photo_compress.dart';
import 'photo_recompress.dart' deferred as recompress;

/// Нарисованный снимок кондиционера для заглушки (`VOICE_MOCK`): в браузере
/// Playwright нет камеры. Не фото реального объекта.
const kMockPhotoAsset = 'assets/demo_photos/ac_indoor.jpg';

/// Откуда открыли «Узнать по фото» — куда ведёт «Это он».
enum PhotoIdentifyOrigin {
  /// «+ Заявка» / план этажа: «Это он» → новая заявка со снимком.
  order,

  /// Раздел оборудования объекта: «Это он» → карточка оборудования.
  equipment,
}

/// Экран «Узнать по фото» (шаг 22): «Где я» → снимок → вид, система,
/// шильдик, неисправность и до 3 кандидатов из реестра → «Это он».
/// Возвращает true, если создана заявка.
class PhotoIdentifyScreen extends StatefulWidget {
  const PhotoIdentifyScreen({
    super.key,
    this.objectId,
    this.floorId,
    this.locationId,
    this.orderId,
    this.origin = PhotoIdentifyOrigin.order,
  });

  final String? objectId;
  final String? floorId;
  final String? locationId;
  final String? orderId;
  final PhotoIdentifyOrigin origin;

  @override
  State<PhotoIdentifyScreen> createState() => _PhotoIdentifyScreenState();
}

class _PhotoIdentifyScreenState extends State<PhotoIdentifyScreen> {
  final _dir = DirectoryRepo();
  final _log = IdentifyLog();

  String? _companyId;
  bool _manager = false;
  List<Obj> _objects = const [];
  List<Layer> _layers = const [];

  // Где я.
  String? _objectId;
  String? _floorId;
  String? _locationId;
  List<PlanItem> _items = const [];
  List<Floor> _floors = const [];
  Map<String, String> get _floorNames =>
      {for (final f in _floors) f.id: f.name};

  // Снимок и разбор.
  Uint8List? _photo;
  DateTime? _takenAt;
  bool _busy = false;
  DateTime? _startedAt;
  Timer? _ticker;
  PhotoIdentification? _result;
  IdentifyProblem? _problem;
  String? _logId;
  bool _decided = false;
  bool _choosing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_result != null && !_decided) {
      unawaited(_log.finish(_logId, IdentifyOutcome.dismissed));
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Данные
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    try {
      final r = await Future.wait<Object?>([
        _dir.myCompanyId(),
        RequestsRepo().myRole(),
        _dir.objects(),
        _dir.layers(),
      ]);
      _companyId = r[0] as String?;
      final role = r[1] as String?;
      _manager = role == 'manager' || role == 'admin';
      _objects = r[2] as List<Obj>;
      _layers = r[3] as List<Layer>;
    } catch (e) {
      debugPrint('PhotoIdentify refs: ${e.runtimeType}');
    }
    var objectId = widget.objectId;
    var locationId = widget.locationId;
    if (objectId == null && locationId == null && widget.orderId == null) {
      final saved = await _loadHere();
      objectId = saved.$1;
      locationId = saved.$2;
    }
    if (objectId != null && !_objects.any((o) => o.id == objectId)) {
      objectId = null;
      locationId = null;
    }
    if (!mounted) return;
    setState(() {
      _objectId = objectId;
      _locationId = locationId;
      _floorId = widget.floorId;
    });
    await _loadPlace();
  }

  Future<void> _loadPlace() async {
    final objectId = _objectId;
    if (objectId == null) {
      setState(() {
        _items = const [];
        _floors = const [];
      });
      return;
    }
    try {
      final repo = FloorRepo();
      final r = await Future.wait<Object>(
          [repo.itemsOf(objectId), repo.floorsOf(objectId)]);
      if (!mounted || objectId != _objectId) return;
      final items = r[0] as List<PlanItem>;
      setState(() {
        _items = items;
        _floors = r[1] as List<Floor>;
        // Этаж — из помещения, если его не передали.
        final room = _place(_locationId);
        if (_locationId != null && room == null) _locationId = null;
        if (room != null) _floorId = room.floorId ?? _floorId;
      });
    } catch (e) {
      debugPrint('PhotoIdentify place: ${e.runtimeType}');
    }
  }

  PlanItem? _place(String? id) {
    if (id == null) return null;
    for (final i in _items) {
      if (i.isPlace && i.id == id) return i;
    }
    return null;
  }

  static String _hereKey(String uid) => 'photo_here_v1_$uid';

  Future<(String?, String?)> _loadHere() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return (null, null);
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_hereKey(uid))?.split('|');
      if (v == null || v.isEmpty || v[0].isEmpty) return (null, null);
      return (v[0], v.length > 1 && v[1].isNotEmpty ? v[1] : null);
    } catch (_) {
      return (null, null);
    }
  }

  Future<void> _saveHere() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _hereKey(uid), '${_objectId ?? ''}|${_locationId ?? ''}');
    } catch (_) {}
  }

  IdentifyPlace get _here => IdentifyPlace(
      objectId: _objectId,
      floorId: _floorId,
      locationId: _locationId,
      orderId: widget.orderId);

  // ---------------------------------------------------------------------------
  // Снимок и разбор
  // ---------------------------------------------------------------------------

  Future<void> _take() async {
    final l = context.l10n;
    Uint8List? bytes;
    try {
      if (photoIdentifyMock) {
        bytes = (await rootBundle.load(kMockPhotoAsset)).buffer.asUint8List();
      } else {
        final file = await ImagePicker().pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          maxWidth: kIdentifyMaxSide.toDouble(),
          maxHeight: kIdentifyMaxSide.toDouble(),
          imageQuality: kIdentifyQuality,
          requestFullMetadata: false,
        );
        if (file == null) return;
        bytes = await file.readAsBytes();
      }
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
      debugPrint('PhotoIdentify pick: ${e.runtimeType}');
      bytes = null;
    }
    if (!mounted) return;
    if (bytes == null) {
      showAppMessage(context, l.photoFailed, type: AppMessageType.error);
      return;
    }
    // Прошлое узнавание без выбора — «никто не выбран».
    if (_result != null && !_decided) {
      unawaited(_log.finish(_logId, IdentifyOutcome.dismissed));
    }
    setState(() {
      _photo = bytes;
      _takenAt = DateTime.now();
    });
    await _analyze();
  }

  Future<void> _analyze() async {
    final photo = _photo;
    if (photo == null) return;
    final locale = context.localeCode;
    final started = DateTime.now();
    setState(() {
      _busy = true;
      _startedAt = started;
      _result = null;
      _problem = null;
      _logId = null;
      _decided = false;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
    PhotoIdentification? result;
    IdentifyProblem? problem;
    try {
      if (photoIdentifyMock) {
        final hvac = defaultLayerForKind('ac', _layers);
        result = await const MockPhotoIdentify().identify(
            items: _items,
            floorNames: _floorNames,
            place: _here,
            hvacLayerId: hvac?.id,
            hvacLayerName: hvac?.label(locale));
      } else {
        result = await PhotoIdentifyClient()
            .identify(photo, locale: locale, place: _here);
      }
    } on IdentifyException catch (e) {
      problem = e.problem;
    } catch (e) {
      debugPrint('PhotoIdentify: ${e.runtimeType}');
      problem = IdentifyProblem.failed;
    }
    _ticker?.cancel();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
      _problem = problem;
    });
    final r = result;
    final companyId = _companyId;
    if (r != null && companyId != null) {
      final ms = DateTime.now().difference(started).inMilliseconds;
      final id =
          await _log.add(companyId: companyId, place: _here, r: r, ms: ms);
      if (mounted) setState(() => _logId = id);
    }
  }

  // ---------------------------------------------------------------------------
  // Где я
  // ---------------------------------------------------------------------------

  Future<void> _pickHere() async {
    final l = context.l10n;
    final picked = await showAppSheet<String>(
      context: context,
      builder: (_) =>
          _ObjectPickerSheet(objects: _objects, selected: _objectId),
    );
    if (picked == null || !mounted) return;
    final objectId = picked.isEmpty ? null : picked;
    final changedObject = objectId != _objectId;
    setState(() {
      _objectId = objectId;
      if (changedObject) {
        _locationId = null;
        _floorId = null;
        _items = const [];
      }
    });
    if (changedObject) await _loadPlace();
    if (!mounted) return;
    if (objectId != null) {
      final places = sortPlacesForPicker([
        for (final i in _items)
          if (i.isPlace) i
      ], _floors);
      if (places.isNotEmpty) {
        final room = await showAppSheet<String>(
            context: context,
            builder: (_) => PlacePickerSheet(
                places: places,
                floors: _floorNames,
                selected: _locationId,
                noneLabel: l.photoWhereWholeObject));
        if (!mounted) return;
        if (room != null) {
          setState(() {
            _locationId = room.isEmpty ? null : room;
            _floorId = _place(_locationId)?.floorId;
          });
        }
      }
    }
    unawaited(_saveHere());
    // Место сменилось после снимка — подсказать заново.
    if (_photo != null && !_busy) await _analyze();
  }

  String _hereText(AppLocalizations l) {
    final obj = _objects.where((o) => o.id == _objectId).firstOrNull;
    if (obj == null) return l.photoWhereNoObject;
    final room = _place(_locationId);
    final floor = _floorNames[room?.floorId ?? _floorId];
    return [
      objectDisplayName(obj),
      if (floor != null) floor,
      room?.label ?? l.photoWhereWholeObject,
    ].join(' · ');
  }

  // ---------------------------------------------------------------------------
  // Выбор
  // ---------------------------------------------------------------------------

  Future<void> _chooseCandidate(IdentifyCandidate c) => _choose(
      assetId: c.assetId,
      assetName: c.name,
      locationId: c.locationId,
      outcome: outcomeFor(_result!, c.assetId));

  Future<void> _chooseOther() async {
    final l = context.l10n;
    if (_objectId == null) {
      showAppMessage(context, l.photoNeedObject);
      await _pickHere();
      if (_objectId == null || !mounted) return;
    }
    final assets = [
      for (final i in _items)
        if (!i.isPlace) i
    ];
    if (assets.isEmpty) {
      showAppMessage(context, l.photoNoAssets);
      return;
    }
    final picked = await showAppSheet<PlanItem>(
      context: context,
      builder: (_) => _AssetPickerSheet(
          assets: assets,
          places: {
            for (final i in _items)
              if (i.isPlace) i.id: i
          },
          here: _locationId),
    );
    if (picked == null || !mounted) return;
    await _choose(
        assetId: picked.id,
        assetName: picked.name,
        locationId: picked.locationId,
        outcome: _result == null ? null : outcomeFor(_result!, picked.id));
  }

  Future<void> _addNew() async {
    final l = context.l10n;
    final objectId = _objectId;
    if (objectId == null) {
      showAppMessage(context, l.photoNeedObject);
      await _pickHere();
      return;
    }
    final r = _result;
    final places = await _dir.placesOf(objectId);
    if (!mounted) return;
    final kind = r?.kind;
    final draft = AssetDraft(
      name: kind == null ? '' : equipmentKindLabel(l, kind),
      locationId: _locationId ?? '',
      layerId: r?.layerId ?? defaultLayerForKind(kind, _layers)?.id,
      manufacturer: r?.nameplate?.manufacturer,
      model: r?.nameplate?.model,
      serialNo: r?.nameplate?.serial,
      kind: kind == 'other' ? null : kind,
    );
    final id = await showAssetFormForId(context,
        objectId: objectId, places: places, layers: _layers, prefill: draft);
    if (id == null || !mounted) return;
    await _loadPlace();
    final added = _items.where((i) => !i.isPlace && i.id == id).firstOrNull;
    await _choose(
        assetId: id,
        assetName: added?.name ?? draft.name,
        locationId: added?.locationId,
        outcome: r == null ? null : IdentifyOutcome.newAsset);
  }

  Future<void> _choose(
      {required String assetId,
      required String assetName,
      String? locationId,
      IdentifyOutcome? outcome}) async {
    if (_choosing) return;
    final l = context.l10n;
    setState(() => _choosing = true);
    try {
      if (outcome != null) {
        _decided = true;
        unawaited(_log.finish(_logId, outcome, chosenAssetId: assetId));
      }
      if (widget.origin == PhotoIdentifyOrigin.equipment) {
        await _openAssetCard(assetId);
      } else {
        await _createOrder(assetId, assetName, locationId);
      }
    } catch (e) {
      debugPrint('PhotoIdentify choose: ${e.runtimeType}');
      if (mounted) {
        showAppMessage(context, l.formSaveFailed, type: AppMessageType.error);
      }
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  Future<String?> _objectOfPlace(String? locationId) async {
    if (locationId == null) return _objectId;
    final local = _place(locationId);
    if (local != null) return _objectId;
    final r = await Supabase.instance.client
        .from('locations')
        .select('object_id')
        .eq('id', locationId)
        .maybeSingle();
    return r?['object_id'] as String? ?? _objectId;
  }

  Future<void> _createOrder(
      String assetId, String assetName, String? locationId) async {
    final companyId = _companyId;
    if (companyId == null) return;
    final l = context.l10n;
    final r = _result;
    final objectId = await _objectOfPlace(locationId);
    final asset = await EquipmentRepo().asset(assetId);
    if (!mounted) return;
    final photo = _photo;
    final ok = await showOrderForm(
      context: context,
      repo: RequestsRepo(),
      objects: _objects,
      companyId: companyId,
      initialObjectId: objectId,
      initialLocationId: locationId ?? asset?.locationId,
      initialAssetId: assetId,
      initialAssetName: assetName,
      initialLayerId: r?.layerId ?? asset?.layerId,
      initialTitle:
          r == null ? l.photoOrderTitleCheck(assetName) : photoOrderTitle(l, r),
      initialDescription: r == null ? null : photoOrderDescription(l, r),
      photo: photo == null
          ? null
          : CapturedPhoto(bytes: photo, takenAt: _takenAt ?? DateTime.now()),
    );
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _openAssetCard(String assetId) async {
    final asset = await EquipmentRepo().asset(assetId);
    if (asset == null || !mounted) return;
    final objectId = await _objectOfPlace(asset.locationId);
    final obj = _objects.where((o) => o.id == objectId).firstOrNull;
    if (obj == null || !mounted) return;
    final places = await _dir.placesOf(obj.id);
    if (!mounted) return;
    await Navigator.pushReplacement(
        context,
        appRoute(
            (_) => AssetCardScreen(
                asset: asset,
                object: obj,
                places: places,
                layers: _layers,
                isManager: _manager),
            title: obj.name));
  }

  // ---------------------------------------------------------------------------
  // Вид
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final photo = _photo;
    return AppScaffold(
      title: l.photoTitle,
      large: false,
      bottomBar: BottomActionBar(
        child: photo == null
            ? AppButton.primary(
                label: l.photoTake, icon: AppIcons.camera, onPressed: _take)
            : AppButton.secondary(
                label: l.photoRetake,
                icon: AppIcons.camera,
                onPressed: _busy || _choosing ? null : _take),
      ),
      slivers: [
        SliverContent(
          sliver: SliverList.list(children: [
            AppGroup(header: l.photoWhere, children: [
              AppRow(
                leading: const LeadingIcon(AppIcons.place),
                title: _hereText(l),
                onTap: _busy ? null : _pickHere,
              ),
            ]),
            if (photo == null)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpace.rowH, vertical: AppSpace.s),
                child: Text(l.photoIntro, style: AppText.footnote),
              )
            else
              _Preview(bytes: photo, dim: _busy),
            if (_busy) _waiting(l),
            if (!_busy && _problem != null) ..._problemView(l),
            if (!_busy && _result != null) ..._resultView(l, _result!),
            if (photo != null && !_busy) ..._manualActions(l),
            const SizedBox(height: AppSpace.xl),
          ]),
        ),
      ],
    );
  }

  Widget _waiting(AppLocalizations l) {
    final elapsed = DateTime.now().difference(_startedAt ?? DateTime.now());
    final text = switch (intakeWaitStage(elapsed)) {
      IntakeWait.reading => l.photoWaitLook,
      IntakeWait.ai => l.photoWaitAi,
      IntakeWait.almost => l.photoWaitAlmost,
    };
    return Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(width: 24, height: 24, child: AppLoader()),
        const SizedBox(width: AppSpace.m),
        Flexible(
          child: Semantics(
              liveRegion: true, child: Text(text, style: AppText.callout)),
        ),
      ]),
    );
  }

  List<Widget> _problemView(AppLocalizations l) => [
        AppGroup(children: [
          AppRow(
            leading: const LeadingIcon(AppIcons.warning,
                color: AppColors.secondary, background: AppColors.fill),
            title: _problem == IdentifyProblem.tooLarge
                ? l.photoTooLarge
                : l.photoFailed,
            titleStyle: AppText.callout,
            subtitleMaxLines: 4,
            chevron: false,
          ),
        ]),
      ];

  List<Widget> _resultView(AppLocalizations l, PhotoIdentification r) {
    final locale = context.localeCode;
    final layer = _layers.where((y) => y.id == r.layerId).firstOrNull;
    final kindIcon = equipmentKind(r.kind)?.icon ?? AppIcons.eqOther;
    final pct = r.percent;
    return [
      AppGroup(children: [
        AppRow(
          leading: LeadingIcon(kindIcon),
          title: equipmentKindLabel(l, r.kind),
          subtitle: [
            if (layer != null)
              layer.label(locale)
            else if (r.layerName != null)
              r.layerName!,
            if (pct != null) '$pct%',
          ].join(' · '),
          trailing: _AiBadge(label: l.photoAiBadge),
          chevron: false,
        ),
        if (r.nameplate != null)
          AppRow(
              title: l.photoNameplate,
              value: r.nameplate!.text,
              chevron: false),
        if (r.defect != null)
          AppRow(
              leading: const LeadingIcon(AppIcons.warning),
              title: r.defect!,
              subtitle: l.photoDefect,
              chevron: false),
      ]),
      if (r.candidates.isEmpty)
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpace.rowH, vertical: AppSpace.s),
          child: Text(l.photoNoCandidates, style: AppText.footnote),
        )
      else
        AppGroup(header: l.photoLikely, children: [
          for (var i = 0; i < r.candidates.length; i++)
            _candidateRow(l, r.candidates[i], top: i == 0),
        ]),
    ];
  }

  Widget _candidateRow(AppLocalizations l, IdentifyCandidate c,
      {required bool top}) {
    final kind = _items
        .where((i) => !i.isPlace && i.id == c.assetId)
        .firstOrNull
        ?.equipmentKind;
    final button = top
        ? AppButton.primary(
            label: l.photoThisOne,
            small: true,
            expand: false,
            onPressed: _choosing ? null : () => _chooseCandidate(c))
        : AppButton.tinted(
            label: l.photoThisOne,
            small: true,
            expand: false,
            onPressed: _choosing ? null : () => _chooseCandidate(c));
    return AppRow(
      leading: LeadingIcon(assetIcon(kind ?? _result?.kind, 'equipment')),
      title: c.name,
      subtitle: [
        if (c.placeText.isNotEmpty) c.placeText,
        if (c.reasons.isNotEmpty) reasonsText(l, c.reasons),
      ].join('\n'),
      subtitleMaxLines: 3,
      trailing: button,
      chevron: false,
      onTap: _choosing ? null : () => _chooseCandidate(c),
    );
  }

  List<Widget> _manualActions(AppLocalizations l) => [
        AppGroup(children: [
          AppRow(
            leading: const LeadingIcon(AppIcons.list),
            title: _problem != null ? l.photoChooseManually : l.photoOther,
            onTap: _choosing ? null : _chooseOther,
          ),
          if (_manager)
            AppRow(
              leading: const LeadingIcon(AppIcons.add),
              title: l.photoAddNew,
              titleStyle:
                  AppText.rowTitle.copyWith(color: AppColors.accentText),
              onTap: _choosing ? null : _addNew,
            ),
        ]),
      ];
}

/// Превью снимка: скруглённое, не выше 260; во время разбора — бледнее.
class _Preview extends StatelessWidget {
  const _Preview({required this.bytes, required this.dim});
  final Uint8List bytes;
  final bool dim;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: AppSpace.m),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.group),
              child: AnimatedOpacity(
                opacity: dim ? 0.6 : 1,
                duration: const Duration(milliseconds: 200),
                child: Image.memory(bytes,
                    fit: BoxFit.contain, gaplessPlayback: true),
              ),
            ),
          ),
        ),
      );
}

/// Таблетка «✨ Распознано ИИ».
class _AiBadge extends StatelessWidget {
  const _AiBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        height: AppSizes.pillHeight,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 9),
        decoration: BoxDecoration(
            color: AppColors.accentTint,
            borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(AppIcons.sparkles, size: 14, color: AppColors.accentText),
          const SizedBox(width: 5),
          Text(label,
              maxLines: 1,
              style: AppText.caption.copyWith(
                  color: AppColors.accentText, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Выбор объекта для «Где я»: «Без объекта — искать везде» и объекты по
/// городам, поиск. '' — без объекта, null — закрыли.
class _ObjectPickerSheet extends StatefulWidget {
  const _ObjectPickerSheet({required this.objects, required this.selected});
  final List<Obj> objects;
  final String? selected;

  @override
  State<_ObjectPickerSheet> createState() => _ObjectPickerSheetState();
}

class _ObjectPickerSheetState extends State<_ObjectPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = _q.trim().toLowerCase();
    final list = [
      for (final g in groupObjectsByCity(widget.objects))
        for (final o in g.items)
          if (q.isEmpty || objectDisplayName(o).toLowerCase().contains(q)) o
    ];
    return ListPickerSheet(
      title: l.photoWhereChooseObject,
      search: widget.objects.length < 6
          ? null
          : AppSearchField(
              hint: l.formChooseObject,
              onChanged: (v) => setState(() => _q = v)),
      children: [
        AppGroup(margin: EdgeInsets.zero, children: [
          if (q.isEmpty)
            AppCheckRow(
                title: l.photoWhereNoObject,
                selected: widget.selected == null,
                onTap: () => Navigator.pop(context, '')),
          for (final o in list)
            AppCheckRow(
              title: objectDisplayName(o),
              selected: o.id == widget.selected,
              onTap: () => Navigator.pop(context, o.id),
            ),
        ]),
      ],
    );
  }
}

/// «Другое оборудование…»: оборудование объекта, сначала — в помещении
/// [here], поиск по названию и инвентарному номеру.
class _AssetPickerSheet extends StatefulWidget {
  const _AssetPickerSheet(
      {required this.assets, required this.places, required this.here});
  final List<PlanItem> assets;
  final Map<String, PlanItem> places;
  final String? here;

  @override
  State<_AssetPickerSheet> createState() => _AssetPickerSheetState();
}

class _AssetPickerSheetState extends State<_AssetPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = _q.trim().toLowerCase();
    final list = [
      for (final a in widget.assets)
        if (q.isEmpty ||
            a.name.toLowerCase().contains(q) ||
            (a.inventoryNo ?? '').toLowerCase().contains(q))
          a
    ]..sort((x, y) {
        final hx = x.locationId == widget.here ? 0 : 1;
        final hy = y.locationId == widget.here ? 0 : 1;
        return hx != hy ? hx - hy : naturalCompare(x.name, y.name);
      });
    return ListPickerSheet(
      title: l.photoPickAsset,
      search: AppSearchField(
          hint: l.photoAssetSearchHint,
          onChanged: (v) => setState(() => _q = v)),
      children: [
        AppGroup(margin: EdgeInsets.zero, children: [
          for (final a in list)
            AppRow(
              leading:
                  LeadingIcon(assetIcon(a.equipmentKind, a.category ?? '')),
              title: a.name,
              subtitle: [
                if (widget.places[a.locationId] case final p?) p.label,
                if (a.inventoryNo != null) a.inventoryNo!,
              ].join(' · '),
              onTap: () => Navigator.pop(context, a),
            ),
        ]),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Text(l.equipNothingFound,
                textAlign: TextAlign.center, style: AppText.footnote),
          ),
      ],
    );
  }
}
