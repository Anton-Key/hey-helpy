import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/location.dart';
import '../../l10n/app_localizations.dart';
import '../floors/floor_models.dart';
import '../floors/floor_repository.dart';
import '../floors/floors_section.dart';
import '../regions/countries.dart';
import '../regions/geo_pickers.dart';
import '../regions/region.dart';
import '../../core/schema_compat.dart';
import '../requests/order_list.dart';
import 'contractor_card.dart';
import 'city.dart';
import 'directory.dart';
import '../../core/app_message.dart';

/// Карточка объекта: тип, адрес, координаты и радиус геозоны (меняет только
/// менеджер — проверяет база), помещения, подрядчики по видам работ,
/// последние заявки.
class ObjectCardScreen extends StatefulWidget {
  const ObjectCardScreen({super.key, required this.object});
  final Obj object;

  @override
  State<ObjectCardScreen> createState() => _ObjectCardScreenState();
}

class _ObjectCardScreenState extends State<ObjectCardScreen> {
  final _dir = DirectoryRepo();
  late Obj _obj = widget.object;
  OrderContext? _ctx;
  List<Place> _places = const [];
  List<Binding> _bindings = const [];
  List<Map<String, dynamic>> _recent = const [];
  List<Floor> _floors = const [];
  List<PlanItem> _planItems = const [];
  List<PlanOrder> _openOrders = const [];
  bool _loading = true;
  bool _failed = false;

  /// Регионы компании и все объекты — для строк «Страна / Город / Регион»
  /// и подсказок городов (шаг 16, 0015).
  List<Region> _regions = const [];
  List<Obj> _allObjects = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadGeo();
  }

  Future<void> _loadGeo() async {
    final regions = await RegionRepository().listOrEmpty();
    List<Obj> objects = const [];
    try {
      objects = await _dir.objects();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _regions = regions;
        _allObjects = objects;
      });
    }
  }

  Future<void> _editGeo() async {
    final l = context.l10n;
    final saved = await showObjectGeoSheet(context,
        object: _obj,
        allObjects: _allObjects.isEmpty ? [_obj] : _allObjects,
        regions: _regions,
        companyId: _ctx?.companyId);
    if (saved == true) {
      await _load();
      await _loadGeo();
      _snack(l.toastSaved, type: AppMessageType.success);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final id = widget.object.id;
      final ctx = _ctx ?? await OrderContext.load();
      final floors = FloorRepo();
      final results = await Future.wait<Object?>([
        _dir.object(id),
        _dir.placesOf(id),
        _dir.bindingsOfObject(id),
        ctx.repo.listBy(objectId: id, limit: 5),
        // Этажи (0013): если что-то не так — карточка всё равно открывается.
        floors.floorsOf(id).catchError((_) => const <Floor>[]),
        floors.itemsOf(id).catchError((_) => const <PlanItem>[]),
        floors.openOrdersOf(id).catchError((_) => const <PlanOrder>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _ctx = ctx;
        _obj = (results[0] as Obj?) ?? _obj;
        _places = results[1] as List<Place>;
        _bindings = results[2] as List<Binding>;
        _recent = results[3] as List<Map<String, dynamic>>;
        _floors = results[4] as List<Floor>;
        _planItems = results[5] as List<PlanItem>;
        _openOrders = results[6] as List<PlanOrder>;
        _loading = false;
      });
    } catch (e) {
      debugPrint('ObjectCard: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _snack(String m, {AppMessageType type = AppMessageType.info}) {
    if (mounted) showAppMessage(context, m, type: type);
  }

  Future<void> _edit() async {
    final l = context.l10n;
    final saved = await showAppSheet<bool>(
      context: context,
      builder: (_) => _GeoForm(object: _obj, repo: _dir),
    );
    if (saved == true) {
      await _load();
      _snack(l.toastSaved, type: AppMessageType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final List<Widget> slivers;
    if (_loading && _ctx == null) {
      slivers = const [
        SliverFillRemaining(hasScrollBody: false, child: AppLoader())
      ];
    } else if (_failed) {
      slivers = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
              text: l.cardLoadFailed,
              error: true,
              actionLabel: l.commonRetry,
              onAction: _load),
        )
      ];
    } else {
      slivers = [
        SliverContent(sliver: SliverList.list(children: _content(l))),
      ];
    }
    return AppScaffold(
      title: _obj.name,
      onRefresh: _load,
      slivers: slivers,
    );
  }

  /// «3 этаж», «3 этаж · не на плане» или «не на плане».
  String _placeFloorTag(AppLocalizations l, String placeId) {
    PlanItem? item;
    for (final i in _planItems) {
      if (i.isPlace && i.id == placeId) item = i;
    }
    String? floor;
    for (final f in _floors) {
      if (f.id == item?.floorId) floor = f.name;
    }
    // Этаж уже в названии («Холл, 1 этаж») — не повторяем.
    final named = floor != null &&
        (item?.name ?? '').toLowerCase().contains(floor.toLowerCase());
    return [
      if (floor != null && !named) floor,
      if (item == null || !item.placed) l.placeNotOnPlan,
    ].join(' · ');
  }

  List<Widget> _content(AppLocalizations l) {
    final ctx = _ctx!;
    final locale = context.localeCode;
    final coord = NumberFormat('0.00000', l.localeName);
    final num = NumberFormat.decimalPattern(l.localeName);
    String contractorOf(Binding b) =>
        b.contractorName ??
        ctx.contractorName(b.contractorId) ??
        l.contractorUnknown;
    return [
      AppGroup(
        footer: _obj.hasCoordinates ? null : l.cardNoCoordinatesHint,
        children: [
          AppRow(
              leading: const LeadingIcon(AppIcons.building),
              title: l.objectFormType,
              value: l.objectType(_obj.type)),
          AppRow(
              leading: const LeadingIcon(AppIcons.place),
              title: l.objectFormAddress,
              value: _obj.address?.isNotEmpty == true
                  ? _obj.address!
                  : l.commonNotSpecified),
          // Страна, город, регион (0015). До миграции — не показываем.
          if (SchemaCompat.has('0015') == true) ...[
            AppRow(
                leading: const LeadingIcon(AppIcons.language),
                title: l.countryTitle,
                value: _obj.countryCode == null
                    ? l.commonNotSpecified
                    : countryLabel(_obj.countryCode, locale),
                chevron: ctx.isManager,
                onTap: ctx.isManager ? _editGeo : null),
            AppRow(
                leading: const LeadingIcon(AppIcons.building),
                title: l.geoCity,
                value: _obj.cityName.isEmpty
                    ? l.commonNotSpecified
                    : _obj.cityName,
                chevron: ctx.isManager,
                onTap: ctx.isManager ? _editGeo : null),
            AppRow(
                leading: const LeadingIcon(AppIcons.map),
                title: l.regionPickTitle,
                value: _regions
                        .where((r) => r.id == _obj.regionId)
                        .firstOrNull
                        ?.name ??
                    l.regionNotSet,
                chevron: ctx.isManager,
                onTap: ctx.isManager ? _editGeo : null),
          ],
          AppRow(
              leading: const LeadingIcon(AppIcons.locate),
              title: l.cardCoordinates,
              value: _obj.hasCoordinates
                  ? '${coord.format(_obj.lat)}, ${coord.format(_obj.lng)}'
                  : l.cardCoordinatesNotSet),
          AppRow(
              leading: const LeadingIcon(AppIcons.nearby),
              title: l.cardGeofenceRadius,
              value: l.cardMeters(num.format(_obj.geofenceRadiusM))),
        ],
      ),
      if (ctx.isManager)
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpace.group),
          child: AppButton.tinted(
              icon: AppIcons.placeEdit, label: l.cardEditGeo, onPressed: _edit),
        ),

      // Этажи и планы (шаг 14b)
      FloorsSection(
        objectId: _obj.id,
        companyId: ctx.companyId,
        isManager: ctx.isManager,
        floors: _floors,
        items: _planItems,
        orders: _openOrders,
        onChanged: _load,
      ),

      // Помещения: у каждого — этаж («3 этаж») или «не на плане».
      AppGroup(header: l.cardPlacesTitle, children: [
        if (_places.isEmpty)
          AppRow(title: l.cardPlacesEmpty, titleStyle: AppText.callout)
        else
          for (final p in _places)
            AppRow(
              leading: const LeadingIcon.neutral(AppIcons.room),
              title: p.name,
              subtitle: _placeFloorTag(l, p.id),
              onTap: () => Navigator.push(
                  context,
                  appRoute(
                      (_) => WorkOrderListScreen(
                          title: p.name,
                          subtitle: objectDisplayName(_obj),
                          locationId: p.id),
                      title: _obj.name)),
            ),
      ]),

      // Подрядчики по видам работ
      AppGroup(header: l.cardObjectContractorsTitle, children: [
        if (_bindings.isEmpty)
          AppRow(title: l.cardBindingsEmpty, titleStyle: AppText.callout)
        else
          for (final b in _bindings)
            AppRow(
              leading: InitialsTile(contractorOf(b)),
              title: contractorOf(b),
              subtitle: [
                b.layer?.label(locale) ?? l.commonNotSpecified,
                if (b.objectId == null) l.cardAllObjects,
              ].join(' · '),
              onTap: () => Navigator.push(
                  context,
                  appRoute(
                      (_) => ContractorCardScreen(
                          contractor: Contractor(
                              id: b.contractorId, orgName: contractorOf(b))),
                      title: _obj.name)),
            ),
      ]),

      // Последние заявки
      AppGroup(header: l.cardRecentOrders, children: [
        if (_recent.isEmpty)
          AppRow(title: l.cardOrdersEmpty, titleStyle: AppText.callout)
        else ...[
          for (final r in _recent)
            AppRow(
              leading: PriorityDot((r['priority'] ?? 'normal') as String),
              title: (r['title'] ?? '') as String,
              subtitle: [
                ctx.placeLine(context, r),
                l.dateTime(DateTime.parse('${r['created_at']}')),
              ].join('\n'),
              trailing: StatusPill((r['status'] ?? 'new') as String),
              onTap: () async {
                await ctx.open(context, r);
                if (mounted) await _load();
              },
            ),
          AppRow(
            leading: const LeadingIcon(AppIcons.list),
            title: l.cardAllObjectOrders,
            titleStyle: AppText.rowTitle.copyWith(color: AppColors.accentText),
            onTap: () => Navigator.push(
                context,
                appRoute(
                    (_) => WorkOrderListScreen(
                        title: l.cardAllObjectOrders,
                        subtitle: objectDisplayName(_obj),
                        objectId: _obj.id),
                    title: _obj.name)),
          ),
        ],
      ]),
    ];
  }
}

/// Правка адреса, координат и радиуса геозоны (только менеджер).
class _GeoForm extends StatefulWidget {
  const _GeoForm({required this.object, required this.repo});
  final Obj object;
  final DirectoryRepo repo;

  @override
  State<_GeoForm> createState() => _GeoFormState();
}

class _GeoFormState extends State<_GeoForm> {
  late final _address =
      TextEditingController(text: widget.object.address ?? '');
  late final _lat =
      TextEditingController(text: widget.object.lat?.toString() ?? '');
  late final _lng =
      TextEditingController(text: widget.object.lng?.toString() ?? '');
  late final _radius =
      TextEditingController(text: widget.object.geofenceRadiusM.toString());
  String? _error;
  bool _locating = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_address, _lat, _lng, _radius]) {
      c.dispose();
    }
    super.dispose();
  }

  static double? _parse(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));

  Future<void> _useMyLocation() async {
    final l = context.l10n;
    setState(() {
      _locating = true;
      _error = null;
    });
    final ok = await ensureLocationPermission();
    final pos = ok ? await currentPosition() : null;
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (pos == null) {
        _error = l.cardLocationFailed;
      } else {
        _lat.text = pos.latitude.toStringAsFixed(6);
        _lng.text = pos.longitude.toStringAsFixed(6);
      }
    });
  }

  Future<void> _save() async {
    final l = context.l10n;
    final latText = _lat.text.trim();
    final lngText = _lng.text.trim();
    final lat = _parse(latText);
    final lng = _parse(lngText);
    final radius = int.tryParse(_radius.text.trim());
    String? error;
    if (latText.isEmpty != lngText.isEmpty) {
      error = l.cardCoordinatesBoth;
    } else if (latText.isNotEmpty &&
        (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180)) {
      error = l.cardCoordinatesInvalid;
    } else if (radius == null || radius < 20 || radius > 5000) {
      error = l.cardRadiusInvalid;
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final address = _address.text.trim();
      await widget.repo.updateObjectGeo(widget.object.id,
          address: address.isEmpty ? null : address,
          lat: latText.isEmpty ? null : lat,
          lng: lngText.isEmpty ? null : lng,
          radiusM: radius!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('updateObjectGeo: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l.saveFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    InputDecoration deco(String label, [String? hint]) =>
        InputDecoration(labelText: label, hintText: hint);
    const numKeys =
        TextInputType.numberWithOptions(decimal: true, signed: true);
    return Padding(
      padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetHeader(
            title: l.cardEditGeo,
            doneLabel: l.commonSave,
            doneLoading: _saving,
            onDone: _saving ? null : _save,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                      controller: _address,
                      decoration:
                          deco(l.objectFormAddress, l.objectFormAddressHint)),
                  const SizedBox(height: AppSpace.m),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: _lat,
                            keyboardType: numKeys,
                            decoration: deco(l.cardLatitude))),
                    const SizedBox(width: AppSpace.s),
                    Expanded(
                        child: TextField(
                            controller: _lng,
                            keyboardType: numKeys,
                            decoration: deco(l.cardLongitude))),
                  ]),
                  const SizedBox(height: AppSpace.s),
                  AppButton.tinted(
                    icon: AppIcons.locate,
                    label: l.cardUseMyLocation,
                    loading: _locating,
                    onPressed: _locating ? null : _useMyLocation,
                  ),
                  const SizedBox(height: AppSpace.m),
                  TextField(
                      controller: _radius,
                      keyboardType: TextInputType.number,
                      decoration: deco(l.cardGeofenceRadiusInput)),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 10),
                      child: Text(_error!,
                          style: AppText.footnote
                              .copyWith(color: AppColors.danger)),
                    ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
