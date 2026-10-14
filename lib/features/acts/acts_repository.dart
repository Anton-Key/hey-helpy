import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/paging.dart';
import '../../core/schema_compat.dart';
import '../directory/directory.dart';
import 'act_logic.dart';

/// Сформированный акт (contractor_acts, миграция 0021).
class SavedAct {
  const SavedAct({
    required this.id,
    required this.number,
    required this.contractorId,
    required this.periodStart,
    required this.periodEnd,
    required this.replaced,
    required this.createdAt,
    this.pdfPath,
    this.paid = 0,
    this.rejected = 0,
    this.sum,
    this.currency,
    this.authorName,
  });
  final String id;
  final String number;
  final String contractorId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final bool replaced;
  final DateTime createdAt;
  final String? pdfPath;
  final int paid;
  final int rejected;
  final double? sum;
  final String? currency;
  final String? authorName;

  factory SavedAct.fromRow(Map<String, dynamic> r) {
    final t = (r['totals'] as Map<String, dynamic>?) ?? const {};
    return SavedAct(
      id: r['id'] as String,
      number: (r['number'] ?? '') as String,
      contractorId: r['contractor_id'] as String,
      periodStart: DateTime.parse('${r['period_start']}'),
      periodEnd: DateTime.parse('${r['period_end']}'),
      replaced: r['status'] == 'replaced',
      createdAt: DateTime.tryParse('${r['created_at']}') ?? DateTime.now(),
      pdfPath: r['pdf_path'] as String?,
      paid: (t['paid'] as num?)?.toInt() ?? 0,
      rejected: (t['rejected'] as num?)?.toInt() ?? 0,
      sum: (t['sum'] as num?)?.toDouble(),
      currency: t['currency'] as String?,
      authorName:
          (r['author'] as Map<String, dynamic>?)?['full_name'] as String?,
    );
  }
}

class ActsRepository {
  static const bucket = 'contractor-acts';
  final SupabaseClient _c = Supabase.instance.client;

  Future<List<Contractor>> contractors() => DirectoryRepo().contractors();

  /// Ставки подрядчика; без 0021 или без строки — без сумм.
  Future<ActRates> rates(String contractorId) =>
      SchemaCompat.run('0021', () async {
        final r = await _c
            .from('contractor_rates')
            .select('rate_order,rate_visit,currency')
            .eq('contractor_id', contractorId)
            .maybeSingle();
        if (r == null) return const ActRates();
        return ActRates(
            perOrder: (r['rate_order'] as num?)?.toDouble(),
            perVisit: (r['rate_visit'] as num?)?.toDouble(),
            currency: (r['currency'] ?? 'RUB') as String);
      }, legacy: () async => const ActRates());

  /// Ставки: администратор и менеджер без зон (база: contractor_rates_*).
  Future<void> saveRates(
      {required String companyId,
      required String contractorId,
      double? perOrder,
      double? perVisit,
      String currency = 'RUB'}) async {
    await _c.from('contractor_rates').upsert({
      'contractor_id': contractorId,
      'company_id': companyId,
      'rate_order': perOrder,
      'rate_visit': perVisit,
      'currency': currency,
    });
  }

  /// Заявки подрядчика с доказательствами за период [from, toExclusive).
  /// Объекты — для «нужен ли визит» (есть ли у объекта геозона).
  Future<List<ActOrder>> orders(String contractorId, DateTime from,
      DateTime toExclusive, List<Obj> objects) async {
    final rows = await fetchAll(() => _c
        .from('work_orders')
        .select(
            'id,title,status,requires_photo,due_at,submitted_at,accepted_at,'
            'updated_at,object_id,location_id,layer_id,recurrence')
        .eq('assigned_contractor_id', contractorId)
        .inFilter('status', const ['done', 'on_review', 'returned'])
        .gte('updated_at', from.toUtc().toIso8601String())
        .order('id'));
    DateTime dateOf(Map<String, dynamic> r) => DateTime.tryParse(
            '${r['accepted_at'] ?? r['submitted_at'] ?? r['updated_at']}')!
        .toLocal();
    final inPeriod = [
      for (final r in rows)
        if (!dateOf(r).isBefore(from) && dateOf(r).isBefore(toExclusive)) r
    ];
    final ids = [for (final r in inPeriod) r['id'] as String];
    final photos = <String>{};
    final filePhotos = <String>{};
    final visits = <String, VisitProof>{};
    final checklist = <String, (int, int)>{};
    for (final chunk in chunks(ids)) {
      final r = await Future.wait([
        // Источник фото (0023): «из файла» — не доказательство.
        SchemaCompat.run(
            '0023',
            () => _c
                .from('attachments')
                .select('work_order_id,source')
                .eq('kind', 'photo')
                .eq('stage', 'after')
                .inFilter('work_order_id', chunk),
            legacy: () => _c
                .from('attachments')
                .select('work_order_id')
                .eq('kind', 'photo')
                .eq('stage', 'after')
                .inFilter('work_order_id', chunk)),
        _c
            .from('visits')
            .select('work_order_id,in_geofence')
            .inFilter('work_order_id', chunk),
        _c
            .from('checklist_items')
            .select('work_order_id,is_done')
            .inFilter('work_order_id', chunk),
      ]);
      for (final a in r[0]) {
        (a['source'] == 'file' ? filePhotos : photos)
            .add(a['work_order_id'] as String);
      }
      for (final v in r[1]) {
        final id = v['work_order_id'] as String;
        if (v['in_geofence'] == true) {
          visits[id] = VisitProof.inZone;
        } else {
          visits.putIfAbsent(id, () => VisitProof.outOfZone);
        }
      }
      for (final c in r[2]) {
        final id = c['work_order_id'] as String;
        final (t, d) = checklist[id] ?? (0, 0);
        checklist[id] = (t + 1, d + (c['is_done'] == true ? 1 : 0));
      }
    }
    final withZone = {
      for (final o in objects)
        if (o.lat != null && o.lng != null) o.id
    };
    return [
      for (final r in inPeriod)
        ActOrder(
          id: r['id'] as String,
          title: (r['title'] ?? '') as String,
          status: r['status'] as String,
          date: dateOf(r),
          dueAt: DateTime.tryParse('${r['due_at'] ?? ''}')?.toLocal(),
          objectId: r['object_id'] as String?,
          locationId: r['location_id'] as String?,
          layerId: r['layer_id'] as String?,
          requiresPhoto: r['requires_photo'] == true,
          hasAfterPhoto: photos.contains(r['id']),
          hasFileAfterPhoto: filePhotos.contains(r['id']),
          visitRequired: withZone.contains(r['object_id']),
          visit: visits[r['id']] ?? VisitProof.none,
          checklistTotal: checklist[r['id']]?.$1 ?? 0,
          checklistDone: checklist[r['id']]?.$2 ?? 0,
          isPpr: (r['recurrence'] as Map?)?['kind'] == 'ppr',
        ),
    ];
  }

  /// Акты подрядчика (новые первыми). Без 0021 — [MigrationMissing].
  Future<List<SavedAct>> acts(String contractorId) =>
      SchemaCompat.run('0021', () async {
        final rows = await _c
            .from('contractor_acts')
            .select('id,number,contractor_id,period_start,period_end,status,'
                'totals,pdf_path,created_at,'
                'author:profiles!contractor_acts_created_by_fkey(full_name)')
            .eq('contractor_id', contractorId)
            .order('created_at', ascending: false)
            .limit(50);
        return [
          for (final r in (rows as List).cast<Map<String, dynamic>>())
            SavedAct.fromRow(r)
        ];
      });

  /// Сформировать акт: номер и прежний акт за период — в базе.
  Future<({String id, String number})> issue(
      {required String contractorId,
      required DateTime from,
      required DateTime toInclusive,
      required ActResult result}) async {
    String d(DateTime x) =>
        '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    final r = await _c.rpc('contractor_act_issue', params: {
      'p_contractor': contractorId,
      'p_from': d(from),
      'p_to': d(toInclusive),
      'p_totals': actTotalsJson(result),
      'p_items': actItemsJson(result),
    });
    final row = (r is List ? r.first : r) as Map<String, dynamic>;
    return (id: row['id'] as String, number: row['number'] as String);
  }

  /// PDF акта — в закрытое хранилище и путь в акт.
  Future<String> uploadPdf(
      {required String companyId,
      required String actId,
      required String fileBase,
      required Uint8List bytes}) async {
    final path = '$companyId/$actId/$fileBase.pdf';
    await _c.storage.from(bucket).uploadBinary(path, bytes,
        fileOptions:
            const FileOptions(contentType: 'application/pdf', upsert: false));
    await _c.rpc('contractor_act_set_pdf',
        params: {'p_act': actId, 'p_path': path});
    return path;
  }

  Future<String> signedUrl(String path) =>
      _c.storage.from(bucket).createSignedUrl(path, 60 * 60);

  /// Название компании и имя пользователя — для шапки акта.
  Future<({String? company, String? me})> header() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return (company: null, me: null);
    final p = await _c
        .from('profiles')
        .select('full_name,companies(name)')
        .eq('id', uid)
        .maybeSingle();
    return (
      company: (p?['companies'] as Map<String, dynamic>?)?['name'] as String?,
      me: p?['full_name'] as String?,
    );
  }
}
