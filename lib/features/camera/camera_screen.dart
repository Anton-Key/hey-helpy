import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/location.dart';
import '../../core/web_bridge.dart';
import '../../l10n/app_localizations.dart';
import '../directory/city.dart';
import '../directory/directory.dart';
import '../equipment/asset_card.dart';
import '../equipment/asset_place.dart';
import '../equipment/equipment_kinds.dart';
import '../equipment/equipment_repository.dart';
import '../floors/floor_models.dart';
import '../floors/floor_repository.dart';
import '../floors/plan_logic.dart';
import '../photo_identify/here_pickers.dart';
import '../photo_identify/identify_client.dart';
import '../photo_identify/identify_log.dart';
import '../photo_identify/identify_models.dart';
import '../photo_identify/photo_identify_screen.dart';
import '../photos/photo_repository.dart';
import '../requests/order_form_place.dart';
import '../requests/order_list.dart';
import '../requests/requests.dart';
import '../vps/vps_channel.dart';
import '../arlabel/arlabel_channel.dart';
import '../arlabel/arlabel_launch.dart';
import '../arlabel/arlabel_logic.dart';
import '../vps/vps_launch.dart';
import '../vps/vps_logic.dart';
import 'asset_facts_repository.dart';
import 'camera_logic.dart';
import 'live_camera.dart';

/// Что сейчас с камерой на экране.
enum _Cam { starting, live, frozen, error }

/// «Камера-помощник» (шаг 25): живое видео на весь экран, «Где я» сверху,
/// рамка-прицел и «Что это?». Кадр уходит в `photo-identify` (тот же клиент и
/// журнал, что у «Узнать по фото»); по ответу кадр замирает, рамка зеленеет
/// («КД-301 · 95 %»), снизу выезжает карточка: заявки, плановое ТО, последняя
/// работа, «Создать заявку», «Карточка оборудования», «Не тот», «Ещё раз».
///
/// На показе это «распознавание оборудования камерой», не AR: метка не
/// держится на оборудовании. Камера выключается при уходе с экрана, при
/// сворачивании приложения и на стоп-кадре. Возвращает true, если создана
/// заявка.
class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    this.objectId,
    this.floorId,
    this.locationId,
    this.origin = PhotoIdentifyOrigin.order,
    this.camera,
    this.offline = false,
    this.identify,
  });

  final String? objectId;
  final String? floorId;
  final String? locationId;
  final PhotoIdentifyOrigin origin;

  /// Камера (тесты передают заглушку); null — [createLiveCamera].
  final LiveCamera? camera;

  /// Без сервера (виджет-тесты): справочники не загружаются.
  @visibleForTesting
  final bool offline;

  /// Подмена `photo-identify` (виджет-тесты).
  @visibleForTesting
  final Future<PhotoIdentification> Function(Uint8List jpeg)? identify;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final LiveCamera _camera = widget.camera ?? createLiveCamera();
  late final AnimationController _breath;

  _Cam _cam = _Cam.starting;
  CameraProblem? _camProblem;

  /// Камеру выключило сворачивание приложения — включить при возврате.
  bool _pausedByApp = false;

  // Справочники и «Где я».
  String? _companyId;
  bool _manager = false;

  /// Шаг 28: VPS-вариант APK — кнопка «Метки VPS (эксперимент)».
  VpsStatus _vps = VpsStatus.none;

  /// Шаг 31: телефон с ARCore — кнопка «AR-метки».
  ArLabelStatus _ar = ArLabelStatus.none;
  List<Obj> _objects = const [];
  List<Layer> _layers = const [];
  OrderContext? _ctx;
  String? _objectId;
  String? _floorId;
  String? _locationId;
  List<PlanItem> _items = const [];
  List<Floor> _floors = const [];
  Map<String, String> get _floorNames =>
      {for (final f in _floors) f.id: f.name};

  // Стоп-кадр и разбор (один снимок в памяти).
  Uint8List? _photo;
  DateTime? _takenAt;
  bool _busy = false;
  PhotoIdentification? _result;
  IdentifyProblem? _problem;
  int _index = 0;

  /// Выбрано вручную из списка («Не узнал», «Выбрать вручную»).
  IdentifyCandidate? _manual;

  // Сводка по показанному оборудованию.
  String? _factsFor;
  AssetFacts? _facts;
  bool _factsLoading = false;

  Future<String?> _logRow = Future.value(null);
  bool _decided = false;
  bool _acting = false;

  // «Авто» (по умолчанию выключено).
  bool _auto = false;
  Timer? _autoTimer;
  final _gate = AutoScanGate();
  List<int>? _prevLuma;
  bool _autoBusy = false;
  (Uint8List, PhotoIdentification)? _autoHit;

  /// Время «Авто» — по тикам таймера (в тестах время подменяется).
  DateTime _autoEpoch = DateTime.now();
  DateTime get _autoNow => _autoTimer == null
      ? DateTime.now()
      : _autoEpoch.add(Duration(milliseconds: 300 * _autoTimer!.tick));

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    WidgetsBinding.instance.addObserver(this);
    unawaited(_startCamera());
    if (!widget.offline) unawaited(_init());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoTimer?.cancel();
    unawaited(_camera.stop());
    _breath.dispose();
    if (_result != null && !_decided) _finishLog(IdentifyOutcome.dismissed);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_pausedByApp && _cam != _Cam.frozen) unawaited(_startCamera());
      _pausedByApp = false;
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_camera.running) {
        _pausedByApp = true;
        unawaited(_camera.stop());
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Камера
  // ---------------------------------------------------------------------------

  Future<void> _startCamera() async {
    if (mounted) {
      setState(() {
        _cam = _Cam.starting;
        _camProblem = null;
      });
    }
    try {
      await _camera.start();
      if (!mounted) {
        await _camera.stop();
        return;
      }
      setState(() => _cam = _Cam.live);
    } on LiveCameraException catch (e) {
      if (mounted) {
        setState(() {
          _cam = _Cam.error;
          _camProblem = e.problem;
        });
      }
    } catch (e) {
      debugPrint('Camera start: ${e.runtimeType}');
      if (mounted) {
        setState(() {
          _cam = _Cam.error;
          _camProblem = CameraProblem.failed;
        });
      }
    }
  }

  Future<void> _pickPhoto() => Navigator.pushReplacement(
      context,
      appRoute(
          (_) => PhotoIdentifyScreen(
              objectId: _objectId ?? widget.objectId,
              floorId: _floorId ?? widget.floorId,
              locationId: _locationId ?? widget.locationId,
              origin: widget.origin),
          title: context.l10n.cameraTitle));

  // ---------------------------------------------------------------------------
  // Данные и «Где я»
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    final dir = DirectoryRepo();
    try {
      final r = await Future.wait<Object?>([
        dir.myCompanyId(),
        RequestsRepo().myRole(),
        dir.objects(),
        dir.layers(),
      ]);
      _companyId = r[0] as String?;
      final role = r[1] as String?;
      _manager = role == 'manager' || role == 'admin';
      _vps = await VpsChannel.status();
      _ar = await ArLabelChannel.status();
      _objects = r[2] as List<Obj>;
      _layers = r[3] as List<Layer>;
    } catch (e) {
      debugPrint('Camera refs: ${e.runtimeType}');
    }
    // Контекст → последнее выбранное → ближайший объект по GPS.
    var objectId = widget.objectId;
    var locationId = widget.locationId;
    if (objectId == null && locationId == null) {
      final saved = await loadPhotoHere();
      objectId = saved.$1;
      locationId = saved.$2;
    }
    // Ссылка «…/#/camera?location=…» — объект берётся из помещения.
    if (objectId == null && locationId != null) {
      try {
        final r = await Supabase.instance.client
            .from('locations')
            .select('object_id')
            .eq('id', locationId)
            .maybeSingle();
        objectId = r?['object_id'] as String?;
      } catch (_) {}
    }
    if (objectId != null && !_objects.any((o) => o.id == objectId)) {
      objectId = null;
      locationId = null;
    }
    if (objectId == null && _objects.isNotEmpty) {
      final pos = await quickPosition();
      if (pos != null) {
        objectId = nearestObject(_objects, pos.lat, pos.lng)?.object.id;
      }
    }
    if (!mounted) return;
    setState(() {
      _objectId = objectId;
      _locationId = locationId;
      _floorId = widget.floorId;
    });
    await _loadPlace();
    try {
      final ctx = await OrderContext.load();
      if (mounted) setState(() => _ctx = ctx);
    } catch (e) {
      debugPrint('Camera ctx: ${e.runtimeType}');
    }
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
      setState(() {
        _items = r[0] as List<PlanItem>;
        _floors = r[1] as List<Floor>;
        final room = _place(_locationId);
        if (_locationId != null && room == null) _locationId = null;
        if (room != null) _floorId = room.floorId ?? _floorId;
      });
    } catch (e) {
      debugPrint('Camera place: ${e.runtimeType}');
    }
  }

  PlanItem? _place(String? id) {
    if (id == null) return null;
    for (final i in _items) {
      if (i.isPlace && i.id == id) return i;
    }
    return null;
  }

  IdentifyPlace get _here => IdentifyPlace(
      objectId: _objectId, floorId: _floorId, locationId: _locationId);

  String _hereText(AppLocalizations l) {
    final obj = _objects.where((o) => o.id == _objectId).firstOrNull;
    if (obj == null) return l.photoWhereNoObject;
    final room = _place(_locationId);
    final floor =
        floorPartIfNew(_floorNames[room?.floorId ?? _floorId], [room?.name]);
    return [
      objectDisplayName(obj),
      if (floor != null) floor,
      room?.label ?? l.photoWhereWholeObject,
    ].join(' · ');
  }

  Future<void> _pickHere() async {
    if (widget.offline) return;
    final l = context.l10n;
    final picked = await showAppSheet<String>(
      context: context,
      builder: (_) =>
          HereObjectPickerSheet(objects: _objects, selected: _objectId),
    );
    if (picked == null || !mounted) return;
    final objectId = picked.isEmpty ? null : picked;
    final changed = objectId != _objectId;
    setState(() {
      _objectId = objectId;
      if (changed) {
        _locationId = null;
        _floorId = null;
        _items = const [];
      }
    });
    if (changed) await _loadPlace();
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
    unawaited(savePhotoHere(_objectId, _locationId));
  }

  // ---------------------------------------------------------------------------
  // «Что это?»
  // ---------------------------------------------------------------------------

  Future<void> _whatIsIt() async {
    if (_busy || _cam != _Cam.live) return;
    final l = context.l10n;
    final locale = context.localeCode;
    final hvacDefect = l.photoMockDefect;
    _gate.onManual(_autoNow);
    setState(() {
      _busy = true;
      _autoHit = null;
    });
    unawaited(_breath.repeat(reverse: true));
    Uint8List bytes;
    try {
      bytes = await _camera.capture();
    } catch (e) {
      debugPrint('Camera capture: ${e.runtimeType}');
      _breath.stop();
      if (!mounted) return;
      setState(() => _busy = false);
      showAppMessage(context, l.photoCameraFailed, type: AppMessageType.error);
      return;
    }
    // Стоп-кадр: камера выключается до «Ещё раз».
    await _camera.stop();
    if (!mounted) return;
    final started = DateTime.now();
    setState(() {
      _cam = _Cam.frozen;
      _photo = bytes;
      _takenAt = started;
      _result = null;
      _problem = null;
      _index = 0;
      _manual = null;
      _facts = null;
      _factsFor = null;
      _logRow = Future.value(null);
      _decided = false;
    });
    final (result, problem) = await _identify(bytes, locale, hvacDefect);
    _breath
      ..stop()
      ..value = 0;
    if (!mounted || _photo != bytes) return;
    _showResult(result, problem, started);
  }

  /// Кадр → ответ `photo-identify` (с `VOICE_MOCK` — заглушка).
  Future<(PhotoIdentification?, IdentifyProblem?)> _identify(
      Uint8List bytes, String locale, String mockDefect) async {
    try {
      if (widget.identify case final f?) return (await f(bytes), null);
      if (photoIdentifyMock) {
        final hvac = defaultLayerForKind('ac', _layers);
        return (
          await const MockPhotoIdentify().identify(
              items: _items,
              floorNames: _floorNames,
              place: _here,
              hvacLayerId: hvac?.id,
              hvacLayerName: hvac?.label(locale),
              defect: mockDefect),
          null
        );
      }
      return (
        await PhotoIdentifyClient()
            .identify(bytes, locale: locale, place: _here),
        null
      );
    } on IdentifyException catch (e) {
      return (null, e.problem);
    } catch (e) {
      debugPrint('Camera identify: ${e.runtimeType}');
      return (null, IdentifyProblem.failed);
    }
  }

  /// Ответ на стоп-кадре: карточка, журнал (0017), сводка по оборудованию.
  void _showResult(
      PhotoIdentification? r, IdentifyProblem? problem, DateTime started) {
    setState(() {
      _busy = false;
      _result = r;
      _problem = problem;
    });
    final companyId = _companyId;
    if (r != null && companyId != null && !widget.offline) {
      final ms = DateTime.now().difference(started).inMilliseconds;
      _logRow =
          IdentifyLog().add(companyId: companyId, place: _here, r: r, ms: ms);
    }
    unawaited(_loadFacts());
  }

  // ---------------------------------------------------------------------------
  // «Авто» (блок 2): телефон неподвижен ~1,5 с → кадр в photo-identify, не
  // чаще раза в 6 с и не больше 20 за экран; результат — плашка сверху,
  // карточка сама не выезжает. Только где камера умеет [LiveCamera.sampleLuma].
  // ---------------------------------------------------------------------------

  void _toggleAuto() {
    setState(() {
      _auto = !_auto;
      _autoHit = null;
    });
    _autoTimer?.cancel();
    _autoTimer = null;
    _prevLuma = null;
    if (_auto) {
      _autoEpoch = DateTime.now();
      _autoTimer = Timer.periodic(
          const Duration(milliseconds: 300), (_) => unawaited(_autoTick()));
    }
  }

  Future<void> _autoTick() async {
    if (!_auto || _cam != _Cam.live || _busy || _autoBusy || _gate.exhausted) {
      return;
    }
    final luma = await _camera.sampleLuma();
    if (luma == null || !mounted) return;
    final prev = _prevLuma;
    _prevLuma = luma;
    final diff = prev == null ? 1.0 : frameDiff(prev, luma);
    if (!_gate.onFrame(diff, _autoNow)) return;
    _autoBusy = true;
    final locale = context.localeCode;
    final defect = context.l10n.photoMockDefect;
    try {
      final bytes = await _camera.capture();
      final (r, _) = await _identify(bytes, locale, defect);
      if (!mounted || !_auto || _cam != _Cam.live || _busy) return;
      if (r?.top != null) setState(() => _autoHit = (bytes, r!));
    } catch (e) {
      debugPrint('Camera auto: ${e.runtimeType}');
    } finally {
      _autoBusy = false;
    }
  }

  /// «Похоже: … — открыть» → тот же стоп-кадр с карточкой, что у «Что это?».
  Future<void> _openAutoHit() async {
    final hit = _autoHit;
    if (hit == null || _busy) return;
    await _camera.stop();
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      _autoHit = null;
      _cam = _Cam.frozen;
      _photo = hit.$1;
      _takenAt = now;
      _index = 0;
      _manual = null;
      _facts = null;
      _factsFor = null;
      _logRow = Future.value(null);
      _decided = false;
    });
    _showResult(hit.$2, null, now);
  }

  Future<void> _again() async {
    if (_result != null && !_decided) _finishLog(IdentifyOutcome.dismissed);
    _prevLuma = null;
    setState(() {
      _autoHit = null;
      _photo = null;
      _result = null;
      _problem = null;
      _manual = null;
      _facts = null;
      _factsFor = null;
      _index = 0;
      _busy = false;
    });
    await _startCamera();
  }

  void _notThis() {
    setState(() {
      _manual = null;
      _index++;
    });
    unawaited(_loadFacts());
  }

  void _finishLog(IdentifyOutcome outcome, {String? chosenAssetId}) {
    if (widget.offline) return;
    final row = _logRow;
    unawaited(row.then((id) =>
        IdentifyLog().finish(id, outcome, chosenAssetId: chosenAssetId)));
  }

  CameraCard get _card => cameraCard(
      busy: _busy, result: _result, problem: _problem, index: _index);

  /// Кто сейчас в карточке: выбранный вручную или кандидат ИИ.
  IdentifyCandidate? get _shown => _manual ?? _card.candidate;

  Future<void> _loadFacts() async {
    final c = _shown;
    if (c == null || widget.offline || c.assetId == _factsFor) return;
    setState(() {
      _factsFor = c.assetId;
      _facts = null;
      _factsLoading = true;
    });
    AssetFacts? facts;
    try {
      final asset = await EquipmentRepo().asset(c.assetId);
      final objectId = await _objectOfPlace(asset?.locationId ?? c.locationId);
      facts = await AssetFactsRepo().load(
          assetId: c.assetId, objectId: objectId, layerId: asset?.layerId);
    } catch (e) {
      debugPrint('Camera facts: ${e.runtimeType}');
    }
    if (!mounted || _factsFor != c.assetId) return;
    setState(() {
      _facts = facts;
      _factsLoading = false;
    });
  }

  Future<String?> _objectOfPlace(String? locationId) async {
    if (locationId == null || _place(locationId) != null) return _objectId;
    final r = await Supabase.instance.client
        .from('locations')
        .select('object_id')
        .eq('id', locationId)
        .maybeSingle();
    return r?['object_id'] as String? ?? _objectId;
  }

  // ---------------------------------------------------------------------------
  // Действия карточки
  // ---------------------------------------------------------------------------

  void _decide(String assetId) {
    if (_decided) return;
    final r = _result;
    _decided = true;
    _finishLog(r == null ? IdentifyOutcome.dismissed : outcomeFor(r, assetId),
        chosenAssetId: assetId);
  }

  Future<void> _act(Future<void> Function() f) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await f();
    } catch (e) {
      debugPrint('Camera action: ${e.runtimeType}');
      if (mounted) {
        showAppMessage(context, context.l10n.formSaveFailed,
            type: AppMessageType.error);
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _createOrder(IdentifyCandidate c) => _act(() async {
        final companyId = _companyId;
        if (companyId == null) return;
        final l = context.l10n;
        final r = _result;
        _decide(c.assetId);
        final asset = await EquipmentRepo().asset(c.assetId);
        final objectId =
            await _objectOfPlace(asset?.locationId ?? c.locationId);
        if (!mounted) return;
        final photo = _photo;
        final ok = await showOrderForm(
          context: context,
          repo: RequestsRepo(),
          objects: _objects,
          companyId: companyId,
          initialObjectId: objectId,
          origin: PlaceOrigin.camera,
          initialLocationId: asset?.locationId ?? c.locationId,
          initialAssetId: c.assetId,
          initialAssetName: c.name,
          initialLayerId: r?.layerId ?? asset?.layerId,
          initialTitle: r == null
              ? l.photoOrderTitleCheck(c.name)
              : photoOrderTitle(l, r),
          initialDescription: r == null ? null : photoOrderDescription(l, r),
          photo: photo == null
              ? null
              : CapturedPhoto(
                  bytes: photo,
                  takenAt: _takenAt ?? DateTime.now(),
                  source: 'camera'),
        );
        if (ok == true && mounted) Navigator.pop(context, true);
      });

  /// Шаг 28: «Метки VPS» для помещения из «Где я». Камеру Flutter выключаем
  /// заранее: ARCore нужна та же камера.
  Future<void> _openVps() async {
    final room = _locationId;
    if (room == null) {
      showAppMessage(context, context.l10n.vpsNoPlace);
      return;
    }
    await _camera.stop();
    if (!mounted) return;
    final assetId = await openVpsMarks(context,
        locationId: room,
        placeName: _place(room)?.name ?? '',
        canEdit: _manager);
    if (!mounted) return;
    if (_cam != _Cam.frozen) unawaited(_startCamera());
    if (assetId != null) await _act(() => _openAssetById(assetId));
  }

  /// Шаг 31: «AR-метки» с контекстом «Где я». Камеру Flutter выключаем
  /// заранее: ARCore нужна та же камера.
  Future<void> _openArLabels() async {
    if (_objectId == null) {
      showAppMessage(context, context.l10n.arNoPlace);
      return;
    }
    await _camera.stop();
    if (!mounted) return;
    final r = await openArLabels(context,
        objectId: _objectId,
        floorId: _floorId,
        locationId: _locationId,
        companyId: _companyId);
    if (!mounted) return;
    if (_cam != _Cam.frozen) unawaited(_startCamera());
    if (r == null) return;
    switch (r.action) {
      case ArLabelAction.asset:
        await _act(() => _openAssetById(r.assetId));
      case ArLabelAction.order:
        final companyId = _companyId;
        if (companyId == null) return;
        await _act(() async {
          final ok = await createOrderFromArLabel(context, r,
              objects: _objects, companyId: companyId);
          if (ok && mounted) Navigator.pop(context, true);
        });
    }
  }

  Future<void> _openAssetCard(IdentifyCandidate c) => _act(() async {
        _decide(c.assetId);
        await _openAssetById(c.assetId);
      });

  Future<void> _openAssetById(String assetId) async {
    final asset = await EquipmentRepo().asset(assetId);
    if (asset == null || !mounted) return;
    final objectId = await _objectOfPlace(asset.locationId);
    final obj = _objects.where((o) => o.id == objectId).firstOrNull;
    if (obj == null || !mounted) return;
    final places = await DirectoryRepo().placesOf(obj.id);
    if (!mounted) return;
    await Navigator.push(
        context,
        appRoute(
            (_) => AssetCardScreen(
                asset: asset,
                object: obj,
                places: places,
                layers: _layers,
                isManager: _manager),
            title: context.l10n.cameraTitle));
    // Вернулись — данные могли измениться (новая заявка из карточки).
    _factsFor = null;
    if (mounted) unawaited(_loadFacts());
  }

  Future<void> _openOrder(Map<String, dynamic> row) async {
    final ctx = _ctx;
    if (ctx == null) return;
    await ctx.open(context, row);
    _factsFor = null;
    if (mounted) unawaited(_loadFacts());
  }

  void _pickFromList(PlanItem a) {
    final room = _place(a.locationId);
    setState(() {
      _manual = IdentifyCandidate(
        assetId: a.id,
        name: a.name,
        locationId: a.locationId ?? '',
        locationLabel: room?.label ?? '',
        floorLabel: _floorNames[a.floorId ?? room?.floorId],
      );
    });
    unawaited(_loadFacts());
  }

  Future<void> _pickAll() async {
    final l = context.l10n;
    final assets = [
      for (final i in _items)
        if (!i.isPlace) i
    ];
    if (_objectId == null) {
      showAppMessage(context, l.photoNeedObject);
      await _pickHere();
      return;
    }
    if (assets.isEmpty) {
      showAppMessage(context, l.photoNoAssets);
      return;
    }
    final picked = await showAppSheet<PlanItem>(
      context: context,
      builder: (_) => HereAssetPickerSheet(
          assets: assets,
          places: {
            for (final i in _items)
              if (i.isPlace) i.id: i
          },
          here: _locationId),
    );
    if (picked != null && mounted) _pickFromList(picked);
  }

  /// Оборудование «здесь»: помещение → этаж → весь объект.
  List<PlanItem> get _assetsHere {
    final all = [
      for (final i in _items)
        if (!i.isPlace) i
    ];
    if (_locationId != null) {
      final room = [
        for (final a in all)
          if (a.locationId == _locationId) a
      ];
      if (room.isNotEmpty) return room;
    }
    if (_floorId != null) {
      final floor = [
        for (final a in all)
          if ((a.floorId ?? _place(a.locationId)?.floorId) == _floorId) a
      ];
      if (floor.isNotEmpty) return floor;
    }
    return all;
  }

  // ---------------------------------------------------------------------------
  // Вид
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final frozen = _cam == _Cam.frozen && _photo != null;
    return Scaffold(
      backgroundColor: AppColors.camera,
      body: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= AppSpace.wideFrom;
        final side = (box.biggest.shortestSide * 0.62).clamp(160.0, 420.0);
        return Stack(fit: StackFit.expand, children: [
          if (frozen)
            Image.memory(_photo!, fit: BoxFit.cover, gaplessPlayback: true)
          else if (_cam == _Cam.live)
            _camera.preview(),
          if (_cam == _Cam.starting)
            Center(
              child: _Bubble(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(width: 20, height: 20, child: AppLoader()),
                const SizedBox(width: AppSpace.s),
                Text(l.cameraStarting,
                    style: AppText.callout.copyWith(color: AppColors.onCamera)),
              ])),
            ),
          if (_cam == _Cam.live || frozen)
            _reticle(l, side, raise: frozen && !_busy && !wide),
          if (_cam == _Cam.error) Center(child: _errorPanel(l)),
          _topBar(l),
          if (_autoHit != null && _cam == _Cam.live && !_busy) _autoPlaque(l),
          if (_cam == _Cam.live && !_busy) _shutter(l),
          if (frozen) _cardLayer(l, wide: wide, height: box.maxHeight),
        ]);
      }),
    );
  }

  Widget _topBar(AppLocalizations l) => PositionedDirectional(
        top: 0,
        start: 0,
        end: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.m),
            child: Row(children: [
              AppIconButton(
                  icon: AppIcons.close,
                  label: l.commonClose,
                  onPressed: () => Navigator.maybePop(context)),
              const SizedBox(width: AppSpace.s),
              Flexible(
                child: Pressable(
                  onTap: _busy ? null : _pickHere,
                  semanticLabel: '${l.photoWhere}: ${_hereText(l)}',
                  child: _Bubble(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(AppIcons.place,
                          size: AppSizes.iconS, color: AppColors.onCamera),
                      const SizedBox(width: AppSpace.xs),
                      Flexible(
                        child: Text(_hereText(l),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.footnote
                                .copyWith(color: AppColors.onCamera)),
                      ),
                      const SizedBox(width: AppSpace.xxs),
                      const Icon(AppIcons.chevronDown,
                          size: AppSizes.iconS, color: AppColors.onCamera),
                    ]),
                  ),
                ),
              ),
              if (_camera.canSample && _cam != _Cam.error) ...[
                const SizedBox(width: AppSpace.s),
                Semantics(
                  toggled: _auto,
                  child: Pressable(
                    onTap: _toggleAuto,
                    semanticLabel: l.cameraAuto,
                    child: _Bubble(
                      color: _auto ? AppColors.accent : null,
                      child: Text(l.cameraAuto,
                          style: AppText.footnote.copyWith(
                              color: _auto
                                  ? AppColors.onAccent
                                  : AppColors.onCamera,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
              if (WebBridge.arLikely) ...[
                const SizedBox(width: AppSpace.s),
                Pressable(
                  onTap: _openAr,
                  child: _Bubble(
                    child: Text(l.cameraArDemo,
                        style: AppText.footnote.copyWith(
                            color: AppColors.onCamera,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ]),
          ),
        ),
      );

  /// «AR (демо)» — отдельная страница сайта `ar/` (WebXR, Chrome на Android).
  Future<void> _openAr() async {
    await _camera.stop();
    await launchUrl(
        WebBridge.arPage(locationId: _locationId, objectId: _objectId),
        webOnlyWindowName: '_self');
  }

  /// Рамка-прицел в центре: белая; ждём — «дышит» с подписью «Смотрю…»;
  /// узнали — зелёная с подписью «КД-301 · 95 %».
  Widget _reticle(AppLocalizations l, double side, {required bool raise}) {
    final c = _shown;
    final found = !_busy && c != null;
    final label = _busy
        ? l.cameraLooking
        : found
            ? frameLabel(c.name, _manual == null ? _result?.percent : null)
            : null;
    final color = found ? AppColors.accent : AppColors.cameraFrame;
    return Align(
      alignment: raise
          ? const AlignmentDirectional(0, -0.72)
          : const AlignmentDirectional(0, -0.1),
      child: AnimatedBuilder(
        animation: _breath,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_breath.value);
          return Transform.scale(
              scale: (raise ? 0.6 : 1) * (1 + 0.05 * t),
              child: Opacity(opacity: _busy ? 0.6 + 0.4 * t : 1, child: child));
        },
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (label != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpace.s),
              child: Semantics(
                liveRegion: true,
                child: _Bubble(
                    color: found ? AppColors.accent : null,
                    child: Text(label,
                        style: AppText.callout.copyWith(
                            color:
                                found ? AppColors.onAccent : AppColors.onCamera,
                            fontWeight: FontWeight.w600))),
              ),
            ),
          SizedBox.square(
            dimension: side,
            child: CustomPaint(painter: _FramePainter(color, thick: found)),
          ),
        ]),
      ),
    );
  }

  /// Плашка «Похоже: Кондиционер КД-301 — открыть» под строкой «Где я».
  Widget _autoPlaque(AppLocalizations l) => PositionedDirectional(
        top: 0,
        start: 0,
        end: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpace.m, 64, AppSpace.m, 0),
            child: Center(
              child: Semantics(
                liveRegion: true,
                child: Pressable(
                  onTap: _openAutoHit,
                  child: _Bubble(
                    color: AppColors.accent,
                    child: Text(l.cameraAutoSeen(_autoHit!.$2.top!.name),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: AppText.callout.copyWith(
                            color: AppColors.onAccent,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _shutter(AppLocalizations l) => PositionedDirectional(
        start: 0,
        end: 0,
        bottom: 0,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _Bubble(
                child: Text(l.cameraAimHint,
                    textAlign: TextAlign.center,
                    style:
                        AppText.footnote.copyWith(color: AppColors.onCamera)),
              ),
              const SizedBox(height: AppSpace.l),
              Pressable(
                onTap: _whatIsIt,
                semanticLabel: l.cameraWhatIsIt,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.onCamera, width: 4),
                      boxShadow: AppShadows.floating,
                    ),
                    child: const Icon(AppIcons.scan,
                        size: 34, color: AppColors.onAccent),
                  ),
                  const SizedBox(height: AppSpace.s),
                  Text(l.cameraWhatIsIt,
                      style:
                          AppText.headline.copyWith(color: AppColors.onCamera)),
                ]),
              ),
              const SizedBox(height: AppSpace.m),
              // Готовый снимок из галереи / файла — прежний «Узнать по фото».
              Pressable(
                onTap: _pickPhoto,
                child: _Bubble(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(AppIcons.image,
                        size: AppSizes.iconS, color: AppColors.onCamera),
                    const SizedBox(width: AppSpace.xs),
                    Text(l.cameraPickPhoto,
                        style: AppText.footnote
                            .copyWith(color: AppColors.onCamera)),
                  ]),
                ),
              ),
              // Шаг 31: «AR-метки» — только Android с ARCore.
              if (_ar.available) ...[
                const SizedBox(height: AppSpace.s),
                Pressable(
                  onTap: _openArLabels,
                  child: _Bubble(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(AppIcons.scan,
                          size: AppSizes.iconS, color: AppColors.onCamera),
                      const SizedBox(width: AppSpace.xs),
                      Text(l.arLabelsButton,
                          style: AppText.footnote
                              .copyWith(color: AppColors.onCamera)),
                    ]),
                  ),
                ),
              ],
              // Шаг 28: только VPS-вариант APK.
              if (_vps.available) ...[
                const SizedBox(height: AppSpace.s),
                Pressable(
                  onTap: _openVps,
                  child: _Bubble(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(AppIcons.place,
                          size: AppSizes.iconS, color: AppColors.onCamera),
                      const SizedBox(width: AppSpace.xs),
                      Text(l.vpsMarksButton,
                          style: AppText.footnote
                              .copyWith(color: AppColors.onCamera)),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
        ),
      );

  Widget _errorPanel(AppLocalizations l) {
    final text = switch (_camProblem) {
      CameraProblem.denied => l.cameraDenied,
      CameraProblem.noCamera => l.cameraNoCamera,
      CameraProblem.unsupported => l.cameraUnsupported,
      _ => l.cameraFailed,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        margin: const EdgeInsets.all(AppSpace.l),
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(AppRadius.group)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(AppIcons.camera,
              size: AppSizes.iconL, color: AppColors.secondary),
          const SizedBox(height: AppSpace.s),
          Text(text, textAlign: TextAlign.center, style: AppText.callout),
          const SizedBox(height: AppSpace.l),
          AppButton.primary(
              label: l.cameraPickPhoto,
              icon: AppIcons.image,
              onPressed: _pickPhoto),
          const SizedBox(height: AppSpace.s),
          AppButton.secondary(
              label: l.cameraRetryStart,
              icon: AppIcons.refresh,
              onPressed: _startCamera),
        ]),
      ),
    );
  }

  // --- Карточка поверх стоп-кадра ---------------------------------------------

  Widget _cardLayer(AppLocalizations l,
      {required bool wide, required double height}) {
    final card = Container(
      constraints: BoxConstraints(maxHeight: height * (wide ? 0.86 : 0.6)),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.group),
        boxShadow: AppShadows.floating,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.group),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.l),
          child: _busy ? _lookingBody(l) : _cardBody(l),
        ),
      ),
    );
    return PositionedDirectional(
      start: wide ? null : 0,
      end: 0,
      bottom: 0,
      width: wide ? AppSizes.sidePanel : null,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (context, v, child) => FractionalTranslation(
                translation: Offset(0, v * 0.3),
                child: Opacity(opacity: 1 - v, child: child)),
            child: card,
          ),
        ),
      ),
    );
  }

  Widget _lookingBody(AppLocalizations l) => Row(children: [
        const SizedBox(width: 22, height: 22, child: AppLoader()),
        const SizedBox(width: AppSpace.m),
        Expanded(child: Text(l.photoWaitAi, style: AppText.callout)),
      ]);

  Widget _cardBody(AppLocalizations l) {
    final c = _shown;
    if (c != null) return _recognized(l, c);
    final manual = _card.kind == CameraCardKind.manual;
    final list = _assetsHere;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              manual
                  ? l.cameraPickManually
                  : _card.kind == CameraCardKind.noEquipment
                      ? l.cameraNoEquipment
                      : l.cameraNotRecognized,
              style: AppText.headline),
          if (_problem != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(l.cameraFailedAi, style: AppText.footnote),
          ],
          const SizedBox(height: AppSpace.m),
          if (list.isEmpty)
            Text(l.cameraNoAssetsHere, style: AppText.footnote)
          else
            AppGroup(margin: EdgeInsets.zero, children: [
              for (final a in list.take(8))
                AppRow(
                  leading:
                      LeadingIcon(assetIcon(a.equipmentKind, a.category ?? '')),
                  title: a.name,
                  subtitle: _place(a.locationId)?.label,
                  onTap: () => _pickFromList(a),
                ),
            ]),
          const SizedBox(height: AppSpace.s),
          AppButton.plain(
              label: l.cameraAllAssets, onPressed: _acting ? null : _pickAll),
          const SizedBox(height: AppSpace.s),
          AppButton.secondary(
              label: l.cameraAgain, icon: AppIcons.camera, onPressed: _again),
        ]);
  }

  Widget _recognized(AppLocalizations l, IdentifyCandidate c) {
    final locale = context.localeCode;
    final r = _result;
    final item =
        _items.where((i) => !i.isPlace && i.id == c.assetId).firstOrNull;
    final kind = item?.equipmentKind ?? (_manual == null ? r?.kind : null);
    final layer = _manual == null
        ? _layers.where((y) => y.id == r?.layerId).firstOrNull
        : null;
    final card = _card;
    // Шаг 27: где именно — «потолок · 2,8 м · над дверью, слева».
    final mountText = item == null ? null : formatMountLine(l, item.mount);
    final sub = [
      if (kind != null) equipmentKindLabel(l, kind),
      if (c.placeText.isNotEmpty) c.placeText,
      if (layer != null) layer.label(locale),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LeadingIcon(assetIcon(kind, 'equipment')),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, style: AppText.headline),
              if (sub.isNotEmpty)
                Text(sub, style: AppText.footnote, maxLines: 3),
              if (mountText != null)
                Text(mountText,
                    style: AppText.footnote.copyWith(color: AppColors.ink),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              if (_manual == null && card.total > 1)
                Text(l.cameraCandidateOf(card.index + 1, card.total),
                    style:
                        AppText.caption.copyWith(color: AppColors.secondary)),
            ]),
          ),
        ]),
        const SizedBox(height: AppSpace.m),
        _factsView(l),
        const SizedBox(height: AppSpace.m),
        AppButton.primary(
            label: l.cameraCreateOrder,
            icon: AppIcons.add,
            loading: _acting,
            onPressed: _acting ? null : () => _createOrder(c)),
        const SizedBox(height: AppSpace.s),
        Row(children: [
          Expanded(
            child: AppButton.secondary(
                label: l.cameraAssetCard,
                small: true,
                onPressed: _acting ? null : () => _openAssetCard(c)),
          ),
        ]),
        const SizedBox(height: AppSpace.s),
        Row(children: [
          Expanded(
            child: AppButton.tinted(
                label: _manual != null || card.hasNext
                    ? l.cameraNotThis
                    : l.photoChooseManually,
                small: true,
                onPressed: _acting
                    ? null
                    : _manual != null
                        ? _pickAll
                        : _notThis),
          ),
          const SizedBox(width: AppSpace.s),
          Expanded(
            child: AppButton.tinted(
                label: l.cameraAgain,
                icon: AppIcons.camera,
                small: true,
                onPressed: _acting ? null : _again),
          ),
        ]),
      ],
    );
  }

  Widget _factsView(AppLocalizations l) {
    final f = _facts;
    if (f == null) {
      return _factsLoading
          ? const Padding(
              padding: EdgeInsets.all(AppSpace.s),
              child: SizedBox(height: 22, child: AppLoader()))
          : const SizedBox.shrink();
    }
    final now = DateTime.now();
    final next = f.next;
    final last = f.lastDone;
    final lastBy = _ctx?.contractorName(last?.contractorId);
    return AppGroup(margin: EdgeInsets.zero, children: [
      if (f.openOrders.isEmpty)
        AppRow(
            leading: const LeadingIcon.neutral(AppIcons.check),
            title: l.cameraNoOpenOrders,
            chevron: false)
      else ...[
        AppRow(
            leading: const LeadingIcon(AppIcons.inbox),
            title: l.cameraOpenOrders(f.openCount),
            titleStyle: AppText.rowTitle.copyWith(fontWeight: FontWeight.w600),
            chevron: false),
        for (final o in f.openOrders)
          AppRow(
            title: '${o['title'] ?? ''}',
            trailing: StatusPill('${o['status'] ?? 'new'}'),
            onTap: _ctx == null ? null : () => _openOrder(o),
          ),
      ],
      AppRow(
        leading: LeadingIcon(AppIcons.calendar,
            color: next != null && next.overdue(now)
                ? AppColors.danger
                : AppColors.accentText,
            background: next != null && next.overdue(now)
                ? AppColors.dangerTint
                : AppColors.accentTint),
        title: next == null ? l.cameraNoMaintenance : l.cameraNextMaintenance,
        subtitle: next == null
            ? null
            : [
                next.overdue(now)
                    ? l.cameraMaintenanceOverdue(l.date(next.due))
                    : l.cameraMaintenanceDue(l.date(next.due)),
                if (!next.forAsset) l.cameraMaintenanceSystem,
              ].join(' · '),
        chevron: next != null && _ctx != null,
        onTap: next == null || _ctx == null ? null : () => _openOrder(next.row),
      ),
      AppRow(
        leading: const LeadingIcon.neutral(AppIcons.history),
        title: last == null ? l.cameraNoHistory : l.cameraLastDone,
        subtitle: last == null
            ? null
            : [
                l.date(last.at),
                if (lastBy != null) lastBy,
                '${last.row['title'] ?? ''}',
              ].where((s) => s.isNotEmpty).join(' · '),
        chevron: last != null && _ctx != null,
        onTap: last == null || _ctx == null ? null : () => _openOrder(last.row),
      ),
    ]);
  }
}

/// Тёмная полупрозрачная подложка для подписей поверх видео.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.child, this.color});
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpace.m, vertical: AppSpace.s),
        decoration: BoxDecoration(
            color: color ?? AppColors.cameraOverlay,
            borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: child,
      );
}

/// Рамка-прицел: четыре уголка.
class _FramePainter extends CustomPainter {
  _FramePainter(this.color, {required this.thick});
  final Color color;
  final bool thick;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thick ? 5 : 3
      ..strokeCap = StrokeCap.round;
    final len = size.shortestSide * 0.18;
    final w = size.width, h = size.height;
    for (final (x, y, dx, dy) in [
      (0.0, 0.0, 1.0, 1.0),
      (w, 0.0, -1.0, 1.0),
      (0.0, h, 1.0, -1.0),
      (w, h, -1.0, -1.0),
    ]) {
      canvas.drawLine(Offset(x, y), Offset(x + dx * len, y), p);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy * len), p);
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.color != color || old.thick != thick;
}
