import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../home/home_chrome.dart';
import '../map/objects_map_view.dart';
import 'contractor_card.dart';
import 'object_card.dart';
import '../../core/app_message.dart';
import '../../core/schema_compat.dart';
import '../../l10n/app_localizations.dart';
import 'city.dart' as city;
import '../regions/countries.dart';
import '../regions/region.dart';

class Obj {
  final String id;
  final String name;
  final String? address;
  final String type;

  /// Центр геозоны (0009); null — координаты не заданы.
  final double? lat;
  final double? lng;

  /// Радиус геозоны, м (20–5000, по умолчанию 150).
  final int geofenceRadiusM;

  /// Страна (код ISO 3166-1, «RS»), город и регион компании (0015).
  /// До миграции 0015 — null; город тогда берётся из адреса ([cityName]).
  final String? countryCode;
  final String? city;
  final String? regionId;
  Obj(
      {required this.id,
      required this.name,
      this.address,
      required this.type,
      this.lat,
      this.lng,
      this.geofenceRadiusM = 150,
      this.countryCode,
      this.city,
      this.regionId});
  factory Obj.fromMap(Map<String, dynamic> m) => Obj(
        id: m['id'] as String,
        name: (m['name'] ?? '') as String,
        address: m['address'] as String?,
        type: (m['type'] ?? 'office') as String,
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        geofenceRadiusM: (m['geofence_radius_m'] as num?)?.toInt() ?? 150,
        countryCode: (m['country_code'] as String?)?.trim(),
        city: m['city'] as String?,
        regionId: m['region_id'] as String?,
      );
  bool get hasCoordinates => lat != null && lng != null;

  /// Город: поле города (0015), иначе — часть адреса до запятой; '' — нет.
  String get cityName {
    final c = city?.trim() ?? '';
    return c.isNotEmpty ? c : _cityOfAddress(address);
  }
}

/// База отказала по правам (RLS / зона доступа, шаг 17) — не «нет интернета».
bool _refused(Object e) => e is PostgrestException && e.code == '42501';

/// Город по адресу (внутри [Obj] имя `city` занято полем).
String _cityOfAddress(String? address) => city.cityOf(address);

/// Закрепление подрядчика за видом работ (слоем) и объектом
/// (contractor_layers, 0004) с нормой визитов в месяц (0010).
class Binding {
  final String id;
  final String contractorId;
  final String? contractorName;
  final Layer? layer;
  final String? objectId;
  final String? objectName;
  final String? objectAddress;
  final int? visitsPerMonth;

  /// «Москва · Офис 3»; null — закрепление на всех объектах.
  String? get objectLabel =>
      objectName == null ? null : city.objectLabel(objectName!, objectAddress);
  const Binding(
      {required this.id,
      required this.contractorId,
      this.contractorName,
      this.layer,
      this.objectId,
      this.objectName,
      this.objectAddress,
      this.visitsPerMonth});
  factory Binding.fromMap(Map<String, dynamic> m) {
    final layer = m['layers'] as Map<String, dynamic>?;
    return Binding(
      id: m['id'] as String,
      contractorId: m['contractor_id'] as String,
      contractorName:
          (m['contractors'] as Map<String, dynamic>?)?['org_name'] as String?,
      layer: layer == null ? null : Layer.fromMap(layer),
      objectId: m['object_id'] as String?,
      objectName: (m['objects'] as Map<String, dynamic>?)?['name'] as String?,
      objectAddress:
          (m['objects'] as Map<String, dynamic>?)?['address'] as String?,
      visitsPerMonth: (m['visits_per_month'] as num?)?.toInt(),
    );
  }
}

/// Исполнитель подрядчика (executors) с именем и телефоном из профиля.
class ExecutorPerson {
  final String id;
  final String? name;
  final String? phone;
  const ExecutorPerson({required this.id, this.name, this.phone});
  factory ExecutorPerson.fromMap(Map<String, dynamic> m) {
    final p = m['profiles'] as Map<String, dynamic>?;
    return ExecutorPerson(
      id: m['id'] as String,
      name: p?['full_name'] as String?,
      phone: p?['phone'] as String?,
    );
  }
}

class Contractor {
  final String id;
  final String orgName;
  Contractor({required this.id, required this.orgName});
  factory Contractor.fromMap(Map<String, dynamic> m) => Contractor(
      id: m['id'] as String, orgName: (m['org_name'] ?? '') as String);
}

/// Помещение / зона внутри объекта.
class Place {
  final String id;
  final String objectId;
  final String name;
  final String? objectName;
  final String? objectAddress;

  /// Номер помещения («305», 0015); null — без номера.
  final String? code;
  Place(
      {required this.id,
      required this.objectId,
      required this.name,
      this.objectName,
      this.objectAddress,
      this.code});
  factory Place.fromMap(Map<String, dynamic> m) => Place(
        id: m['id'] as String,
        objectId: m['object_id'] as String,
        name: (m['name'] ?? '') as String,
        objectName: (m['objects'] as Map<String, dynamic>?)?['name'] as String?,
        objectAddress:
            (m['objects'] as Map<String, dynamic>?)?['address'] as String?,
        code: (m['code'] as String?)?.trim().isEmpty == true
            ? null
            : (m['code'] as String?)?.trim(),
      );

  /// «305 · Переговорная» (с номером) или просто «Переговорная».
  String get label => placeLabel(name, code);

  /// «Москва · Офис 3 · 305 · Лобби».
  String get fullName => objectName == null
      ? label
      : '${city.objectLabel(objectName!, objectAddress)} · $label';
}

/// «305 · Переговорная»; без номера — только название.
String placeLabel(String name, String? code) {
  final c = code?.trim() ?? '';
  return c.isEmpty ? name : '$c · $name';
}

/// Слой (вид работ). [name] — основное название, по нему база назначает
/// подрядчика; [names] — переводы из layers.name_i18n.
class Layer {
  final String id;
  final String name;
  final Map<String, String> names;
  const Layer({required this.id, required this.name, this.names = const {}});
  factory Layer.fromMap(Map<String, dynamic> m) => Layer(
        id: m['id'] as String,
        name: (m['name'] ?? '') as String,
        names: {
          for (final e in ((m['name_i18n'] as Map?) ?? const {}).entries)
            if (e.value is String && (e.value as String).isNotEmpty)
              '${e.key}': e.value as String,
        },
      );

  /// Название на языке интерфейса; если перевода нет — русское, затем основное.
  String label(String localeCode) => names[localeCode] ?? names['ru'] ?? name;

  /// Совпадает ли [text] с названием слоя на любом языке (без учёта регистра).
  bool matches(String text) {
    final t = text.trim().toLowerCase();
    return name.toLowerCase() == t ||
        names.values.any((v) => v.toLowerCase() == t);
  }

  /// Слой заявки: по layer_id, иначе по тексту work_type.
  static Layer? find(List<Layer> layers, {String? id, String? name}) {
    for (final l in layers) {
      if (id != null && l.id == id) return l;
    }
    if (name == null || name.isEmpty) return null;
    for (final l in layers) {
      if (l.matches(name)) return l;
    }
    return null;
  }
}

class DirectoryRepo {
  final SupabaseClient _c = Supabase.instance.client;
  Future<String?> myCompanyId() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return null;
    final r = await _c
        .from('profiles')
        .select('company_id')
        .eq('id', uid)
        .maybeSingle();
    return r?['company_id'] as String?;
  }

  /// Менеджер или админ — им показываем кнопку «Добавить». Право на запись
  /// всё равно проверяет база (RLS).
  Future<bool> amIManager() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return false;
    final r =
        await _c.from('profiles').select('role').eq('id', uid).maybeSingle();
    final role = r?['role'] as String?;
    return role == 'admin' || role == 'manager';
  }

  Future<List<Obj>> objects() async {
    final rows = await _c.from('objects').select().order('created_at');
    return (rows as List)
        .map((e) => Obj.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addObject(
      {required String name,
      String? address,
      required String type,
      required String companyId}) async {
    await _c.from('objects').insert({
      'name': name,
      'address': address,
      'type': type,
      'company_id': companyId
    });
  }

  Future<List<Contractor>> contractors() async {
    final rows = await _c.from('contractors').select().order('created_at');
    return (rows as List)
        .map((e) => Contractor.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addContractor(
      {required String orgName, required String companyId}) async {
    await _c
        .from('contractors')
        .insert({'org_name': orgName, 'company_id': companyId});
  }

  /// Помещения всех объектов компании (доступ ограничен RLS).
  Future<List<Place>> places() async {
    final rows = await SchemaCompat.run(
        '0015',
        () => _c
            .from('locations')
            .select('id,object_id,name,code,objects(name,address)')
            .order('name'),
        legacy: () => _c
            .from('locations')
            .select('id,object_id,name,objects(name,address)')
            .order('name'));
    return (rows as List)
        .map((e) => Place.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<Obj?> object(String id) async {
    final r = await _c.from('objects').select().eq('id', id).maybeSingle();
    return r == null ? null : Obj.fromMap(r);
  }

  /// Адрес, координаты и радиус геозоны. Менять может только менеджер —
  /// это проверяет база (политика objects_manage, 0008); радиус 20–5000 м — 0009.
  Future<void> updateObjectGeo(String id,
      {String? address, double? lat, double? lng, required int radiusM}) async {
    final rows = await _c
        .from('objects')
        .update({
          'address': address,
          'lat': lat,
          'lng': lng,
          'geofence_radius_m': radiusM,
        })
        .eq('id', id)
        .select('id');
    if ((rows as List).isEmpty) {
      throw const PostgrestException(message: 'not allowed');
    }
  }

  /// Помещения одного объекта.
  Future<List<Place>> placesOf(String objectId) async {
    final rows = await SchemaCompat.run(
        '0015',
        () => _c
            .from('locations')
            .select('id,object_id,name,code')
            .eq('object_id', objectId)
            .order('name'),
        legacy: () => _c
            .from('locations')
            .select('id,object_id,name')
            .eq('object_id', objectId)
            .order('name'));
    return (rows as List)
        .map((e) => Place.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static const _bindingFields =
      'id,contractor_id,object_id,visits_per_month,contractors(org_name),objects(name,address),layers(id,name,name_i18n,sort)';

  /// Закрепления подрядчика: виды работ, объекты, нормы визитов.
  Future<List<Binding>> bindingsOfContractor(String contractorId) async {
    final rows = await _c
        .from('contractor_layers')
        .select(_bindingFields)
        .eq('contractor_id', contractorId)
        .order('created_at');
    return (rows as List)
        .map((e) => Binding.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Все закрепления компании (RLS) — для выбора подрядчика к заявке.
  Future<List<Binding>> allBindings() async {
    final rows = await _c
        .from('contractor_layers')
        .select(_bindingFields)
        .order('created_at');
    return (rows as List)
        .map((e) => Binding.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Сколько исполнителей у каждого подрядчика компании.
  Future<Map<String, int>> executorCounts() async {
    final rows = await _c.from('executors').select('contractor_id');
    final out = <String, int>{};
    for (final r in rows as List) {
      final id = (r as Map<String, dynamic>)['contractor_id'] as String;
      out[id] = (out[id] ?? 0) + 1;
    }
    return out;
  }

  /// Подрядчики объекта: закреплённые за ним и «на все объекты».
  Future<List<Binding>> bindingsOfObject(String objectId) async {
    final rows = await _c
        .from('contractor_layers')
        .select(_bindingFields)
        .or('object_id.eq.$objectId,object_id.is.null')
        .order('created_at');
    return (rows as List)
        .map((e) => Binding.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Норма визитов в месяц; null — убрать норму. Только менеджер (RLS, 0004).
  Future<void> setVisitNorm(String bindingId, int? visitsPerMonth) async {
    final rows = await _c
        .from('contractor_layers')
        .update({'visits_per_month': visitsPerMonth})
        .eq('id', bindingId)
        .select('id');
    // RLS не даёт ошибки, а просто ничего не меняет — проверяем, что строка обновилась.
    if ((rows as List).isEmpty) {
      throw const PostgrestException(message: 'not allowed');
    }
  }

  /// Исполнители подрядчика с именем и телефоном.
  Future<List<ExecutorPerson>> executorsOf(String contractorId) async {
    final rows = await _c
        .from('executors')
        .select('id,profiles(full_name,phone)')
        .eq('contractor_id', contractorId)
        .order('created_at');
    return (rows as List)
        .map((e) => ExecutorPerson.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Слои компании (климат, электрика, системы безопасности…) в порядке
  /// отображения. Добавляются в базе без изменения приложения.
  /// select() без списка полей: name_i18n появляется только после миграции 0007.
  Future<List<Layer>> layers() async {
    final rows = await _c.from('layers').select().order('sort').order('name');
    return (rows as List)
        .map((e) => Layer.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}

class ObjectsTab extends StatefulWidget {
  const ObjectsTab({super.key, this.onShowOrders});

  /// «Заявки» в карточке объекта на карте — открыть заявки объекта.
  final ValueChanged<Obj>? onShowOrders;
  @override
  State<ObjectsTab> createState() => _ObjectsTabState();
}

class _ObjectsTabState extends State<ObjectsTab> {
  final _repo = DirectoryRepo();
  late Future<List<Obj>> _future;
  String? _companyId;
  bool _isManager = false;

  /// Регионы компании (0015): группировка «Регион → страна → город».
  List<Region> _regions = const [];

  /// Режим вкладки: список карточек или карта. Запоминается на устройстве.
  bool _mapMode = false;
  static const _modeKey = 'locations_view_mode';

  @override
  void initState() {
    super.initState();
    _repo.amIManager().then((v) {
      if (mounted) setState(() => _isManager = v);
    }, onError: (_) {});
    _future = _repo.objects();
    _repo.myCompanyId().then((v) {
      if (mounted) setState(() => _companyId = v);
    }, onError: (_) {});
    _loadMode();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    final r = await RegionRepository().listOrEmpty();
    if (mounted) setState(() => _regions = r);
  }

  Future<void> _loadMode() async {
    try {
      final p = await SharedPreferences.getInstance();
      final map = p.getString(_modeKey) == 'map';
      if (mounted && map != _mapMode) setState(() => _mapMode = map);
    } catch (_) {}
  }

  Future<void> _setMode(bool map) async {
    setState(() => _mapMode = map);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_modeKey, map ? 'map' : 'list');
    } catch (_) {}
  }

  void _reload() {
    setState(() => _future = _repo.objects());
    _loadRegions();
  }

  Future<void> _reloadAndWait() async {
    final f = _repo.objects();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  /// «Список | Карта» — запоминается на устройстве.
  Widget _modeSwitch(AppLocalizations l) => SegmentedControl<bool>(
        segments: [
          Segment(false, l.mapViewList, icon: AppIcons.list),
          Segment(true, l.mapViewMap, icon: AppIcons.map),
        ],
        selected: _mapMode,
        onChanged: _setMode,
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_mapMode) {
      // Карта — во всю ширину, шапка компактная.
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        HomeTopBar(
            title: l.tabLocations, actions: _actions(l), onRefresh: _reload),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.s),
          child: ContentWidth(child: _modeSwitch(l)),
        ),
        Expanded(
          child: MediaQuery.removePadding(
              context: context, removeTop: true, child: _mapView(l)),
        ),
      ]);
    }
    return _listView(l);
  }

  List<Widget> _actions(AppLocalizations l) => [
        if (_isManager)
          AppIconButton(
              icon: AppIcons.add,
              label: l.commonAdd,
              onPressed: () => _openForm(context)),
      ];

  Widget _mapView(AppLocalizations l) => FutureBuilder<List<Obj>>(
        future: _future,
        builder: (context, snap) {
          // При перечитывании остаётся прежний список — карта не сбрасывается.
          if (!snap.hasData) {
            if (snap.hasError) {
              return AppEmptyState(text: l.objectsLoadFailed, error: true);
            }
            return const AppLoader();
          }
          return ObjectsMapView(
            objects: snap.data!,
            isManager: _isManager,
            companyId: _companyId,
            onReload: _reloadAndWait,
            onShowOrders: (o) => widget.onShowOrders?.call(o),
          );
        },
      );

  Widget _listView(AppLocalizations l) {
    return FutureBuilder<List<Obj>>(
      future: _future,
      builder: (context, snap) {
        final Widget content;
        if (snap.connectionState == ConnectionState.waiting) {
          content = const SliverFillRemaining(
              hasScrollBody: false, child: AppLoader());
        } else if (snap.hasError) {
          content = SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(text: l.objectsLoadFailed, error: true));
        } else if ((snap.data ?? const []).isEmpty) {
          content = SliverFillRemaining(
              hasScrollBody: false,
              child:
                  AppEmptyState(icon: AppIcons.building, text: l.objectsEmpty));
        } else {
          Widget row(Obj o) => AppRow(
                leading: const LeadingIcon(AppIcons.building),
                title: o.name,
                subtitle: o.address?.isNotEmpty == true
                    ? '${o.address} · ${l.objectType(o.type)}'
                    : l.objectType(o.type),
                onTap: () async {
                  await Navigator.push(
                      context,
                      appRoute((_) => ObjectCardScreen(object: o),
                          title: l.tabLocations));
                  _reload();
                },
              );
          final geo = city.groupObjectsByRegion(
              snap.data!, _regions, context.localeCode);
          if (geo != null) {
            // Регион → страна → город (шаг 16): «ЕВРОПА · 7» → «🇷🇸 Сербия» →
            // «БЕЛГРАД · 7».
            content = SliverContent(
              top: 0,
              sliver: SliverList.list(children: [
                for (final r in geo) ...[
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                        top: AppSpace.s, bottom: AppSpace.xs),
                    child: Semantics(
                      header: true,
                      child: Text(
                          l.cityCount(
                              r.region?.name ?? l.regionNone, r.count),
                          style: AppText.title2),
                    ),
                  ),
                  for (final c in r.countries) ...[
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                          top: AppSpace.xs, bottom: AppSpace.xxs),
                      child: Text(
                          c.code.isEmpty
                              ? l.countryNone
                              : countryLabel(c.code, context.localeCode),
                          style: AppText.headline),
                    ),
                    for (final g in c.cities)
                      AppGroup(
                        header: l.cityCount(
                            g.city.isEmpty ? l.cityNone : g.city,
                            g.items.length),
                        children: [for (final o in g.items) row(o)],
                      ),
                  ],
                ],
              ]),
            );
          } else {
            // Секции по городам («МОСКВА · 5»): поле города, иначе адрес.
            final groups = city.groupObjectsByCity(snap.data!);
            content = SliverContent(
              top: 0,
              sliver: SliverList.list(children: [
                for (final g in groups)
                  AppGroup(
                    header: l.cityCount(
                        g.city.isEmpty ? l.cityNone : g.city, g.items.length),
                    children: [for (final o in g.items) row(o)],
                  ),
              ]),
            );
          }
        }
        return CustomScrollView(slivers: [
          HomeHeader(
              title: l.tabLocations, actions: _actions(l), onRefresh: _reload),
          SliverContent(
            top: AppSpace.s,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsetsDirectional.only(bottom: AppSpace.group),
                child: _modeSwitch(l),
              ),
            ),
          ),
          content,
          const SliverBottomInset(),
        ]);
      },
    );
  }

  Future<void> _openForm(BuildContext context) async {
    final l = context.l10n;
    if (_companyId == null) {
      _snack(l.requestsNoCompany, type: AppMessageType.error);
      return;
    }
    final nameC = TextEditingController();
    final addrC = TextEditingController();
    String type = 'office';
    final saved = await showAppSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsetsDirectional.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSt) => _FormSheet(
            title: l.objectFormTitle,
            children: [
              _field(l.objectFormName, nameC, l.objectFormNameHint),
              _field(l.objectFormAddress, addrC, l.objectFormAddressHint),
              SectionHeader(l.objectFormType),
              Wrap(spacing: AppSpace.s, runSpacing: AppSpace.s, children: [
                for (final t in const [
                  'office',
                  'hotel',
                  'apartments',
                  'warehouse'
                ])
                  AppChip(
                      label: l.objectType(t),
                      selected: type == t,
                      onTap: () => setSt(() => type = t)),
              ]),
            ],
            onSubmit: () async {
              if (nameC.text.trim().isEmpty) {
                _snack(l.objectFormNameRequired);
                return;
              }
              try {
                await _repo.addObject(
                    name: nameC.text.trim(),
                    address:
                        addrC.text.trim().isEmpty ? null : addrC.text.trim(),
                    type: type,
                    companyId: _companyId!);
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                debugPrint('addObject: $e');
                _snack(_refused(e) ? l.zoneRefused : l.saveFailed, type: AppMessageType.error);
              }
            },
          ),
        ),
      ),
    );
    if (saved == true) {
      _reload();
      _snack(l.objectAdded, type: AppMessageType.success);
    }
  }

  void _snack(String m, {AppMessageType type = AppMessageType.info}) {
    if (mounted) showAppMessage(context, m, type: type);
  }
}

class ContractorsTab extends StatefulWidget {
  const ContractorsTab({super.key});
  @override
  State<ContractorsTab> createState() => _ContractorsTabState();
}

class _ContractorsTabState extends State<ContractorsTab> {
  final _repo = DirectoryRepo();
  late Future<List<Contractor>> _future;
  String? _companyId;
  bool _isManager = false;
  String _query = '';

  /// Объекты и закрепления — для строки «Москва · 5 объектов».
  List<Obj> _objects = const [];
  List<Binding> _bindings = const [];

  @override
  void initState() {
    super.initState();
    _repo.amIManager().then((v) {
      if (mounted) setState(() => _isManager = v);
    }, onError: (_) {});
    _future = _repo.contractors();
    _repo.myCompanyId().then((v) => setState(() => _companyId = v));
    _loadCoverage();
  }

  Future<void> _loadCoverage() async {
    try {
      final r =
          await Future.wait<Object>([_repo.objects(), _repo.allBindings()]);
      if (!mounted) return;
      setState(() {
        _objects = r[0] as List<Obj>;
        _bindings = r[1] as List<Binding>;
      });
    } catch (e) {
      debugPrint('Contractors coverage: $e');
    }
  }

  void _reload() {
    setState(() => _future = _repo.contractors());
    _loadCoverage();
  }

  /// «Москва · 5 объектов», «Москва, Белград · 7 объектов» (города — по числу
  /// объектов). null — подрядчик ни за чем не закреплён.
  String? _coverage(AppLocalizations l, String contractorId) {
    final mine = [
      for (final b in _bindings)
        if (b.contractorId == contractorId) b
    ];
    if (mine.isEmpty) return null;
    if (mine.any((b) => b.objectId == null)) return l.cardAllObjects;
    final ids = {for (final b in mine) b.objectId!};
    final objs = [
      for (final o in _objects)
        if (ids.contains(o.id)) o
    ];
    final byCity = <String, int>{};
    for (final o in objs) {
      final c = o.cityName;
      if (c.isNotEmpty) byCity[c] = (byCity[c] ?? 0) + 1;
    }
    final cities = byCity.keys.toList()
      ..sort((a, b) {
        final n = byCity[b]!.compareTo(byCity[a]!);
        return n != 0 ? n : city.compareCities(a, b);
      });
    final count = l.objectsCount(ids.length);
    return cities.isEmpty
        ? count
        : l.contractorCoverage(cities.join(', '), count);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FutureBuilder<List<Contractor>>(
      future: _future,
      builder: (context, snap) {
        final Widget content;
        if (snap.connectionState == ConnectionState.waiting) {
          content = const SliverFillRemaining(
              hasScrollBody: false, child: AppLoader());
        } else if (snap.hasError) {
          content = SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(text: l.contractorsLoadFailed, error: true));
        } else if ((snap.data ?? const []).isEmpty) {
          content = SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                  icon: AppIcons.contractor, text: l.contractorsEmpty));
        } else {
          final q = _query.trim().toLowerCase();
          final list = [
            for (final c in snap.data!)
              if (q.isEmpty || c.orgName.toLowerCase().contains(q)) c
          ];
          content = SliverContent(
            top: 0,
            sliver: SliverToBoxAdapter(
              child: list.isEmpty
                  ? AppEmptyState(
                      icon: AppIcons.search, text: l.contractorsEmpty)
                  : AppGroup(children: [
                      for (final c in list)
                        AppRow(
                          leading: InitialsTile(c.orgName),
                          title: c.orgName,
                          subtitle: _coverage(l, c.id),
                          onTap: () => Navigator.push(
                              context,
                              appRoute(
                                  (_) => ContractorCardScreen(contractor: c),
                                  title: l.tabContractors)),
                        ),
                    ]),
            ),
          );
        }
        return CustomScrollView(slivers: [
          HomeHeader(title: l.tabContractors, onRefresh: _reload, actions: [
            if (_isManager)
              AppIconButton(
                  icon: AppIcons.add,
                  label: l.commonAdd,
                  onPressed: () => _openForm(context)),
          ]),
          SliverContent(
            top: AppSpace.s,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsetsDirectional.only(bottom: AppSpace.group),
                child: AppSearchField(
                    hint: MaterialLocalizations.of(context).searchFieldLabel,
                    onChanged: (v) => setState(() => _query = v)),
              ),
            ),
          ),
          content,
          const SliverBottomInset(),
        ]);
      },
    );
  }

  Future<void> _openForm(BuildContext context) async {
    final l = context.l10n;
    if (_companyId == null) {
      _snack(l.requestsNoCompany, type: AppMessageType.error);
      return;
    }
    final nameC = TextEditingController();
    final saved = await showAppSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsetsDirectional.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _FormSheet(
          title: l.contractorFormTitle,
          children: [
            _field(l.contractorFormName, nameC, l.contractorFormNameHint),
          ],
          onSubmit: () async {
            if (nameC.text.trim().isEmpty) {
              _snack(l.contractorFormNameRequired);
              return;
            }
            try {
              await _repo.addContractor(
                  orgName: nameC.text.trim(), companyId: _companyId!);
              if (ctx.mounted) Navigator.pop(ctx, true);
            } catch (e) {
              debugPrint('addContractor: $e');
              _snack(_refused(e) ? l.zoneRefused : l.saveFailed, type: AppMessageType.error);
            }
          },
        ),
      ),
    );
    if (saved == true) {
      _reload();
      _snack(l.contractorAdded, type: AppMessageType.success);
    }
  }

  void _snack(String m, {AppMessageType type = AppMessageType.info}) {
    if (mounted) showAppMessage(context, m, type: type);
  }
}

/// Шторка формы: «Отмена · Заголовок · Сохранить», поля ниже.
class _FormSheet extends StatefulWidget {
  const _FormSheet(
      {required this.title, required this.children, required this.onSubmit});
  final String title;
  final List<Widget> children;
  final Future<void> Function() onSubmit;

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await widget.onSubmit();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SheetHeader(
          title: widget.title,
          doneLabel: context.l10n.commonSave,
          doneLoading: _busy,
          onDone: _submit,
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
          ),
        ),
      ]),
    );
  }
}

/// Поле формы: подпись секции и белое поле ввода.
Widget _field(String label, TextEditingController c, String hint) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(label),
        TextField(controller: c, decoration: InputDecoration(hintText: hint)),
      ],
    );
