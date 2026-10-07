import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/l10n_ext.dart';
import '../../core/status_style.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../l10n/app_localizations.dart';
import '../../models/profile.dart';
import '../requests/order_list.dart';
import 'notification_repository.dart';

const _muted = Color(0xFF8A9098);
const _danger = Color(0xFFC24444);

/// Уведомления (профиль и колокольчик в шапке): события за 14 дней по роли.
/// Открытие экрана отмечает всё прочитанным; новые с прошлого раза — с точкой.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.me});
  final Profile me;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repo = NotificationRepository();
  OrderContext? _ctx;
  List<AppNotification> _items = const [];
  DateTime? _seenBefore;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _seenBefore = await _repo.seenAt(widget.me.id);
    await _load();
    await _repo.markSeen(widget.me.id);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final r = await Future.wait<Object>([
        _ctx == null ? OrderContext.load() : Future.value(_ctx!),
        _repo.load(widget.me),
      ]);
      if (!mounted) return;
      setState(() {
        _ctx = r[0] as OrderContext;
        _items = r[1] as List<AppNotification>;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Notifications: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          title: Text(l.profileNotifications), backgroundColor: Colors.white),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 40),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 10),
              child: Text(l.notifPeriod(NotificationRepository.days),
                  style: const TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_failed)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Text(l.notifLoadFailed,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _danger)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: Text(l.commonRetry)),
                ]),
              )
            else if (!_loading && _items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(l.notifEmpty,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted)),
              )
            else if (_ctx != null)
              for (final n in _items) _tile(l, _ctx!, n),
          ],
        ),
      ),
    );
  }

  Widget _tile(AppLocalizations l, OrderContext ctx, AppNotification n) {
    final isNew = _seenBefore == null || n.at.isAfter(_seenBefore!);
    final (icon, color) = _look(n.kind);
    return TapCard(
      onTap: () async {
        await ctx.open(context, n.order);
        if (mounted) await _load();
      },
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(_text(l, n),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              if (isNew)
                Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsetsDirectional.only(start: 6),
                    decoration: const BoxDecoration(
                        color: HeyHelpyTheme.brand, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 3),
            Text((n.order['title'] ?? '') as String,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(ctx.placeLine(context, n.order),
                style: const TextStyle(color: _muted, fontSize: 12)),
            if (n.kind == NotificationKind.returned &&
                ((n.order['return_reason'] as String?) ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 2),
                child: Text(l.returnedWithReason('${n.order['return_reason']}'),
                    style: const TextStyle(color: _danger, fontSize: 12)),
              ),
            const SizedBox(height: 2),
            Text(l.dateTime(n.at),
                style: const TextStyle(color: _muted, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  String _text(AppLocalizations l, AppNotification n) => switch (n.kind) {
        NotificationKind.assigned => l.notifAssigned,
        NotificationKind.returned => l.notifReturned,
        NotificationKind.onReview => l.notifOnReview,
        NotificationKind.overdue => l.notifOverdue,
        NotificationKind.visitOutside => n.distanceM == null
            ? l.notifVisitOutside
            : l.notifVisitOutsideM(NumberFormat.decimalPattern(l.localeName)
                .format(n.distanceM!.round())),
        NotificationKind.visitMock => l.notifVisitMock,
        NotificationKind.inProgress => l.notifInProgress,
        NotificationKind.accepted => l.notifAccepted,
      };

  (IconData, Color) _look(NotificationKind k) => switch (k) {
        NotificationKind.assigned => (
            Icons.assignment_ind_outlined,
            StatusStyle.blue.foreground
          ),
        NotificationKind.returned => (Icons.replay, StatusStyle.red.foreground),
        NotificationKind.onReview => (
            Icons.fact_check_outlined,
            StatusStyle.blue.foreground
          ),
        NotificationKind.overdue => (
            Icons.schedule,
            StatusStyle.red.foreground
          ),
        NotificationKind.visitOutside => (
            Icons.wrong_location_outlined,
            _danger
          ),
        NotificationKind.visitMock => (
            Icons.gps_off,
            StatusStyle.red.foreground
          ),
        NotificationKind.inProgress => (
            Icons.engineering_outlined,
            StatusStyle.blue.foreground
          ),
        NotificationKind.accepted => (Icons.task_alt, HeyHelpyTheme.ink),
      };
}
