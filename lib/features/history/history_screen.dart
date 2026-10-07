import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n_ext.dart';
import '../../core/paging.dart';
import '../../core/period.dart';
import '../../l10n/app_localizations.dart';
import '../requests/order_list.dart';

const _muted = Color(0xFF8A9098);
const _danger = Color(0xFFC24444);

/// Завершённая заявка в истории.
class HistoryItem {
  HistoryItem(this.row, {this.visitPerson, this.visitGeofence});
  final Map<String, dynamic> row;

  /// Кто отметился на объекте (если визит виден по правам).
  final String? visitPerson;

  /// true — все видимые визиты в геозоне, false — хотя бы один вне её
  /// или с подменой GPS, null — визитов не видно.
  final bool? visitGeofence;

  String get status => (row['status'] ?? 'done') as String;

  /// Когда заявка завершена: принята — accepted_at; отменена — время
  /// последнего изменения (отдельного поля «отменена в» в базе нет).
  DateTime get finishedAt => DateTime.parse(
      '${status == 'done' ? row['accepted_at'] ?? row['updated_at'] : row['updated_at']}');

  Duration? get execution {
    final start = DateTime.tryParse('${row['started_at']}');
    final end = DateTime.tryParse('${row['submitted_at']}');
    if (start == null || end == null || end.isBefore(start)) return null;
    return end.difference(start);
  }

  int get returnCount => ((row['return_count'] as num?) ?? 0).toInt();
}

class HistoryRepository {
  final SupabaseClient _c = Supabase.instance.client;

  /// Принятые и отменённые заявки за период. Сколько видно — решает RLS:
  /// заявитель — свои, исполнитель — своего подрядчика, менеджер — все.
  Future<List<HistoryItem>> load(DateTime from, DateTime to) async {
    final f = from.toUtc().toIso8601String();
    final t = to.toUtc().toIso8601String();
    final rows = await fetchAll(() => _c
        .from('work_orders')
        .select(
            'id,title,work_type,layer_id,priority,status,recurrence,object_id,'
            'location_id,assigned_contractor_id,created_at,started_at,'
            'submitted_at,accepted_at,updated_at,return_count,locations(name)')
        .or('and(status.eq.done,accepted_at.gte."$f",accepted_at.lt."$t"),'
            'and(status.eq.cancelled,updated_at.gte."$f",updated_at.lt."$t")')
        .order('updated_at', ascending: false)
        .order('id'));

    // Визиты: менеджер видит все, остальные — только свои (RLS).
    final ids = [for (final r in rows) r['id'] as String];
    final person = <String, String>{};
    final geofence = <String, bool>{};
    for (final chunk in chunks(ids)) {
      final visits = await fetchAll(() => _c
          .from('visits')
          .select(
              'id,work_order_id,in_geofence,mock_location,profiles(full_name)')
          .inFilter('work_order_id', chunk)
          .order('started_at')
          .order('id'));
      for (final v in visits) {
        final id = v['work_order_id'] as String;
        final name =
            (v['profiles'] as Map<String, dynamic>?)?['full_name'] as String?;
        if (name != null && name.isNotEmpty) person.putIfAbsent(id, () => name);
        final ok = v['in_geofence'] == true && v['mock_location'] != true;
        geofence[id] = (geofence[id] ?? true) && ok;
      }
    }

    final items = [
      for (final r in rows)
        HistoryItem(r,
            visitPerson: person[r['id']], visitGeofence: geofence[r['id']]),
    ]..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    return items;
  }
}

/// Вкладка «История»: завершённые заявки (принятые и отменённые) за период.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _repo = HistoryRepository();
  Period _period = const Period(PeriodKind.month);
  OrderContext? _ctx;
  List<HistoryItem> _items = const [];
  bool _loading = true;
  bool _failed = false;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final ctx = _ctx ?? await OrderContext.load();
      final r = _period.range();
      final items = await _repo.load(r.from, r.to);
      if (!mounted || seq != _seq) return;
      setState(() {
        _ctx = ctx;
        _items = items;
        _loading = false;
      });
    } catch (e) {
      debugPrint('History: $e');
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final done = _items.where((i) => i.status == 'done').length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 120),
        children: [
          PeriodBar(
              period: _period,
              onChanged: (p) {
                setState(() => _period = p);
                _load();
              }),
          const SizedBox(height: 6),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_failed)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Text(l.historyLoadFailed,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _danger)),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _load, child: Text(l.commonRetry)),
              ]),
            )
          else if (_ctx != null) ...[
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 8, bottom: 10),
              child: Text(l.historyDoneInPeriod(done),
                  style: const TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(l.historyEmpty,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted)),
              )
            else
              for (final i in _items) _tile(l, _ctx!, i),
          ],
        ],
      ),
    );
  }

  Widget _tile(AppLocalizations l, OrderContext ctx, HistoryItem i) {
    final r = i.row;
    final contractor =
        ctx.contractorName(r['assigned_contractor_id'] as String?);
    final who = [
      if (i.visitPerson != null) i.visitPerson!,
      if (contractor != null) contractor,
    ].join(' · ');
    final when = l.dateTime(i.finishedAt);
    return OrderTile(
      title: (r['title'] ?? '') as String,
      status: i.status,
      lines: [
        ctx.placeLine(context, r),
        i.status == 'done'
            ? l.historyAcceptedAt(when)
            : l.historyCancelledAt(when),
        if (i.execution != null) l.historyExecution(l.duration(i.execution!)),
        if (who.isNotEmpty) l.historyExecutor(who),
        if (i.visitGeofence == true) l.historyVisitInGeofence,
      ],
      alerts: [
        if (i.returnCount > 0) l.reportsReturnedTimes(i.returnCount),
        if (i.visitGeofence == false) l.historyVisitOutside,
      ],
      onTap: () async {
        await ctx.open(context, r);
        if (mounted) await _load();
      },
    );
  }
}
