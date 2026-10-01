import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n_ext.dart';

class Obj {
  final String id;
  final String name;
  final String? address;
  final String type;
  Obj({required this.id, required this.name, this.address, required this.type});
  factory Obj.fromMap(Map<String, dynamic> m) => Obj(
        id: m['id'] as String,
        name: (m['name'] ?? '') as String,
        address: m['address'] as String?,
        type: (m['type'] ?? 'office') as String,
      );
}

class Contractor {
  final String id;
  final String orgName;
  Contractor({required this.id, required this.orgName});
  factory Contractor.fromMap(Map<String, dynamic> m) =>
      Contractor(id: m['id'] as String, orgName: (m['org_name'] ?? '') as String);
}

/// Помещение / зона внутри объекта.
class Place {
  final String id;
  final String objectId;
  final String name;
  final String? objectName;
  Place({required this.id, required this.objectId, required this.name, this.objectName});
  factory Place.fromMap(Map<String, dynamic> m) => Place(
        id: m['id'] as String,
        objectId: m['object_id'] as String,
        name: (m['name'] ?? '') as String,
        objectName: (m['objects'] as Map<String, dynamic>?)?['name'] as String?,
      );
  String get fullName => objectName == null ? name : '$objectName · $name';
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
            if (e.value is String && (e.value as String).isNotEmpty) '${e.key}': e.value as String,
        },
      );

  /// Название на языке интерфейса; если перевода нет — русское, затем основное.
  String label(String localeCode) => names[localeCode] ?? names['ru'] ?? name;

  /// Совпадает ли [text] с названием слоя на любом языке (без учёта регистра).
  bool matches(String text) {
    final t = text.trim().toLowerCase();
    return name.toLowerCase() == t || names.values.any((v) => v.toLowerCase() == t);
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
    final r = await _c.from('profiles').select('company_id').eq('id', uid).maybeSingle();
    return r?['company_id'] as String?;
  }
  Future<List<Obj>> objects() async {
    final rows = await _c.from('objects').select().order('created_at');
    return (rows as List).map((e) => Obj.fromMap(e as Map<String, dynamic>)).toList();
  }
  Future<void> addObject({required String name, String? address, required String type, required String companyId}) async {
    await _c.from('objects').insert({'name': name, 'address': address, 'type': type, 'company_id': companyId});
  }
  Future<List<Contractor>> contractors() async {
    final rows = await _c.from('contractors').select().order('created_at');
    return (rows as List).map((e) => Contractor.fromMap(e as Map<String, dynamic>)).toList();
  }
  Future<void> addContractor({required String orgName, required String companyId}) async {
    await _c.from('contractors').insert({'org_name': orgName, 'company_id': companyId});
  }

  /// Помещения всех объектов компании (доступ ограничен RLS).
  Future<List<Place>> places() async {
    final rows = await _c.from('locations').select('id,object_id,name,objects(name)').order('name');
    return (rows as List).map((e) => Place.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// Слои компании (климат, электрика, системы безопасности…) в порядке
  /// отображения. Добавляются в базе без изменения приложения.
  /// select() без списка полей: name_i18n появляется только после миграции 0007.
  Future<List<Layer>> layers() async {
    final rows = await _c.from('layers').select().order('sort').order('name');
    return (rows as List).map((e) => Layer.fromMap(e as Map<String, dynamic>)).toList();
  }
}

const _ink = Color(0xFF1C1E22);
const _muted = Color(0xFF8A9098);
const _line = Color(0xFFE8EAED);
const _onBrand = Color(0xFF06342A);

BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line));

class ObjectsTab extends StatefulWidget {
  const ObjectsTab({super.key});
  @override
  State<ObjectsTab> createState() => _ObjectsTabState();
}

class _ObjectsTabState extends State<ObjectsTab> {
  final _repo = DirectoryRepo();
  late Future<List<Obj>> _future;
  String? _companyId;
  @override
  void initState() {
    super.initState();
    _future = _repo.objects();
    _repo.myCompanyId().then((v) => setState(() => _companyId = v));
  }
  void _reload() => setState(() => _future = _repo.objects());
  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    final l = context.l10n;
    return Stack(children: [
      FutureBuilder<List<Obj>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return _ErrorView(text: l.objectsLoadFailed);
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return _EmptyView(icon: Icons.apartment_outlined, text: l.objectsEmpty);
          }
          return ListView.builder(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 120),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final o = list[i];
              return Container(
                margin: const EdgeInsetsDirectional.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: _cardDeco(),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: const Color(0xFFE8F6F2), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.apartment, color: brand)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(o.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(o.address?.isNotEmpty == true ? o.address! : l.objectType(o.type),
                          style: const TextStyle(color: _muted, fontSize: 13)),
                    ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFF2F3F5), borderRadius: BorderRadius.circular(20)),
                    child: Text(l.objectType(o.type), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _muted))),
                ]),
              );
            },
          );
        },
      ),
      PositionedDirectional(
        end: 4, bottom: 8,
        child: FloatingActionButton.extended(
          heroTag: 'addObj', backgroundColor: brand, foregroundColor: _onBrand,
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.add), label: Text(l.commonAdd, style: const TextStyle(fontWeight: FontWeight.w800)))),
    ]);
  }
  Future<void> _openForm(BuildContext context) async {
    final l = context.l10n;
    if (_companyId == null) { _snack(l.requestsNoCompany); return; }
    final nameC = TextEditingController();
    final addrC = TextEditingController();
    String type = 'office';
    final saved = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsetsDirectional.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSt) => _FormSheet(
            title: l.objectFormTitle,
            children: [
              _label(l.objectFormName),
              _input(nameC, l.objectFormNameHint),
              _label(l.objectFormAddress),
              _input(addrC, l.objectFormAddressHint),
              _label(l.objectFormType),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in const ['office', 'hotel', 'apartments', 'warehouse'])
                  _typeChip(l.objectType(t), type == t, () => setSt(() => type = t)),
              ]),
            ],
            onSubmit: () async {
              if (nameC.text.trim().isEmpty) { _snack(l.objectFormNameRequired); return; }
              try {
                await _repo.addObject(name: nameC.text.trim(),
                    address: addrC.text.trim().isEmpty ? null : addrC.text.trim(),
                    type: type, companyId: _companyId!);
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) { debugPrint('addObject: $e'); _snack(l.saveFailed); }
            },
          ),
        ),
      ),
    );
    if (saved == true) { _reload(); _snack(l.objectAdded); }
  }
  void _snack(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }
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
  @override
  void initState() {
    super.initState();
    _future = _repo.contractors();
    _repo.myCompanyId().then((v) => setState(() => _companyId = v));
  }
  void _reload() => setState(() => _future = _repo.contractors());
  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    final l = context.l10n;
    return Stack(children: [
      FutureBuilder<List<Contractor>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return _ErrorView(text: l.contractorsLoadFailed);
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return _EmptyView(icon: Icons.handshake_outlined, text: l.contractorsEmpty);
          }
          return ListView.builder(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 120),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final c = list[i];
              return Container(
                margin: const EdgeInsetsDirectional.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: _cardDeco(),
                child: Row(children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(color: const Color(0xFFE8F6F2), borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.business, color: brand)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(c.orgName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                ]),
              );
            },
          );
        },
      ),
      PositionedDirectional(
        end: 4, bottom: 8,
        child: FloatingActionButton.extended(
          heroTag: 'addCon', backgroundColor: brand, foregroundColor: _onBrand,
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.add), label: Text(l.commonAdd, style: const TextStyle(fontWeight: FontWeight.w800)))),
    ]);
  }
  Future<void> _openForm(BuildContext context) async {
    final l = context.l10n;
    if (_companyId == null) { _snack(l.requestsNoCompany); return; }
    final nameC = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsetsDirectional.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _FormSheet(
          title: l.contractorFormTitle,
          children: [_label(l.contractorFormName), _input(nameC, l.contractorFormNameHint)],
          onSubmit: () async {
            if (nameC.text.trim().isEmpty) { _snack(l.contractorFormNameRequired); return; }
            try {
              await _repo.addContractor(orgName: nameC.text.trim(), companyId: _companyId!);
              if (ctx.mounted) Navigator.pop(ctx, true);
            } catch (e) { debugPrint('addContractor: $e'); _snack(l.saveFailed); }
          },
        ),
      ),
    );
    if (saved == true) { _reload(); _snack(l.contractorAdded); }
  }
  void _snack(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }
}

class _FormSheet extends StatelessWidget {
  const _FormSheet({required this.title, required this.children, required this.onSubmit});
  final String title;
  final List<Widget> children;
  final Future<void> Function() onSubmit;
  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsetsDirectional.only(bottom: 14),
                decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(4)))),
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            ...children,
            const SizedBox(height: 22),
            FilledButton(
              onPressed: onSubmit,
              style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: _onBrand),
              child: Text(context.l10n.commonSave, style: const TextStyle(fontWeight: FontWeight.w800))),
          ],
        ),
      ),
    );
  }
}

Widget _label(String t) => Padding(padding: const EdgeInsetsDirectional.only(top: 16, bottom: 8),
    child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ink)));

Widget _input(TextEditingController c, String hint) => TextField(controller: c,
    decoration: InputDecoration(hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14)));

Widget _typeChip(String label, bool on, VoidCallback onTap) => GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: on ? const Color(0xFFE8F6F2) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: on ? const Color(0xFF35C4AB) : _line)),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: on ? const Color(0xFF249F88) : _ink))));

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 52, color: _muted),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
          ])));
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFC24444)))));
}