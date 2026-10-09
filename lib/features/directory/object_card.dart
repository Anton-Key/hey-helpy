import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/l10n_ext.dart';
import '../../core/location.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../l10n/app_localizations.dart';
import '../requests/order_list.dart';
import 'contractor_card.dart';
import 'directory.dart';
import '../../core/app_message.dart';

const _muted = Color(0xFF8A9098);
const _danger = Color(0xFFC24444);

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
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final id = widget.object.id;
      final ctx = _ctx ?? await OrderContext.load();
      final results = await Future.wait<Object?>([
        _dir.object(id),
        _dir.placesOf(id),
        _dir.bindingsOfObject(id),
        ctx.repo.listBy(objectId: id, limit: 5),
      ]);
      if (!mounted) return;
      setState(() {
        _ctx = ctx;
        _obj = (results[0] as Obj?) ?? _obj;
        _places = results[1] as List<Place>;
        _bindings = results[2] as List<Binding>;
        _recent = results[3] as List<Map<String, dynamic>>;
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
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(_obj.name)),
      body: _loading && _ctx == null
          ? const Center(child: CircularProgressIndicator())
          : _failed
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(l.cardLoadFailed,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _danger)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                          onPressed: _load, child: Text(l.commonRetry)),
                    ]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 40),
                    children: _content(l),
                  ),
                ),
    );
  }

  List<Widget> _content(AppLocalizations l) {
    final ctx = _ctx!;
    final locale = context.localeCode;
    final coord = NumberFormat('0.00000', l.localeName);
    final num = NumberFormat.decimalPattern(l.localeName);
    Widget info(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsetsDirectional.only(top: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: _muted),
            const SizedBox(width: 8),
            SizedBox(
                width: 110,
                child: Text(label,
                    style: const TextStyle(color: _muted, fontSize: 13))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        );
    return [
      TapCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: HeyHelpyTheme.mint,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.apartment, color: HeyHelpyTheme.link),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_obj.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 6),
          info(Icons.category_outlined, l.objectFormType,
              l.objectType(_obj.type)),
          info(
              Icons.place_outlined,
              l.objectFormAddress,
              _obj.address?.isNotEmpty == true
                  ? _obj.address!
                  : l.commonNotSpecified),
          info(
              Icons.my_location,
              l.cardCoordinates,
              _obj.hasCoordinates
                  ? '${coord.format(_obj.lat)}, ${coord.format(_obj.lng)}'
                  : l.cardCoordinatesNotSet),
          info(Icons.radar, l.cardGeofenceRadius,
              l.cardMeters(num.format(_obj.geofenceRadiusM))),
          if (!_obj.hasCoordinates)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 8),
              child: Text(l.cardNoCoordinatesHint,
                  style: const TextStyle(color: _danger, fontSize: 12)),
            ),
        ]),
      ),
      if (ctx.isManager)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.icon(
            style: brandButtonStyle().copyWith(
                minimumSize: const WidgetStatePropertyAll(Size(0, 48))),
            onPressed: _edit,
            icon: const Icon(Icons.edit_location_alt_outlined, size: 20),
            label: Text(l.cardEditGeo,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),

      // Помещения
      SectionTitle(l.cardPlacesTitle),
      if (_places.isEmpty)
        Text(l.cardPlacesEmpty, style: const TextStyle(color: _muted))
      else
        for (final p in _places)
          TapCard(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => WorkOrderListScreen(
                        title: p.name, subtitle: _obj.name, locationId: p.id))),
            child: Row(children: [
              const Icon(Icons.meeting_room_outlined, color: _muted),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(p.name,
                      style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),

      // Подрядчики по видам работ
      SectionTitle(l.cardObjectContractorsTitle),
      if (_bindings.isEmpty)
        Text(l.cardBindingsEmpty, style: const TextStyle(color: _muted))
      else
        for (final b in _bindings)
          TapCard(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ContractorCardScreen(
                        contractor: Contractor(
                            id: b.contractorId,
                            orgName: b.contractorName ??
                                ctx.contractorName(b.contractorId) ??
                                l.contractorUnknown)))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.layer?.label(locale) ?? l.commonNotSpecified,
                  style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                  b.contractorName ??
                      ctx.contractorName(b.contractorId) ??
                      l.contractorUnknown,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if (b.objectId == null)
                Text(l.cardAllObjects,
                    style: const TextStyle(color: _muted, fontSize: 12)),
            ]),
          ),

      // Последние заявки
      SectionTitle(l.cardRecentOrders),
      if (_recent.isEmpty)
        Text(l.cardOrdersEmpty, style: const TextStyle(color: _muted))
      else ...[
        for (final r in _recent)
          OrderTile(
            title: (r['title'] ?? '') as String,
            status: (r['status'] ?? 'new') as String,
            lines: [
              ctx.placeLine(context, r),
              l.dateTime(DateTime.parse('${r['created_at']}')),
            ],
            onTap: () async {
              await ctx.open(context, r);
              if (mounted) await _load();
            },
          ),
        TextButton.icon(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => WorkOrderListScreen(
                      title: l.cardAllObjectOrders,
                      subtitle: _obj.name,
                      objectId: _obj.id))),
          icon: const Icon(Icons.list_alt_rounded),
          label: Text(l.cardAllObjectOrders),
        ),
      ],
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
    InputDecoration deco(String label, [String? hint]) => InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        );
    const numKeys =
        TextInputType.numberWithOptions(decimal: true, signed: true);
    return Padding(
      padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.cardEditGeo,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(
                  controller: _address,
                  decoration:
                      deco(l.objectFormAddress, l.objectFormAddressHint)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: _lat,
                        keyboardType: numKeys,
                        decoration: deco(l.cardLatitude))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: _lng,
                        keyboardType: numKeys,
                        decoration: deco(l.cardLongitude))),
              ]),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _locating ? null : _useMyLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: Text(l.cardUseMyLocation),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _radius,
                  keyboardType: TextInputType.number,
                  decoration: deco(l.cardGeofenceRadiusInput)),
              if (_error != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 10),
                  child: Text(_error!,
                      style: const TextStyle(color: _danger, fontSize: 13)),
                ),
              const SizedBox(height: 18),
              FilledButton(
                style: brandButtonStyle(),
                onPressed: _saving ? null : _save,
                child: Text(l.commonSave,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
