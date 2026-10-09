import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import '../../models/profile.dart';
import '../requests/order_list.dart';
import 'notification_repository.dart';

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
    final ctx = _ctx;
    return AppScaffold(
      title: l.profileNotifications,
      onRefresh: _load,
      slivers: [
        SliverContent(
          sliver: SliverList.list(children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpace.rowH, 0, AppSpace.rowH, AppSpace.s),
              child: Row(children: [
                Expanded(
                  child: Text(l.notifPeriod(NotificationRepository.days),
                      style: AppText.footnote
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
                if (_loading && ctx != null)
                  const CupertinoActivityIndicator(radius: 8),
              ]),
            ),
            if (_loading && ctx == null)
              const Padding(
                padding: EdgeInsetsDirectional.symmetric(vertical: 40),
                child: AppLoader(),
              )
            else if (_failed)
              AppEmptyState(
                  text: l.notifLoadFailed,
                  error: true,
                  actionLabel: l.commonRetry,
                  onAction: _load)
            else if (!_loading && _items.isEmpty)
              AppEmptyState(text: l.notifEmpty, icon: AppIcons.bell)
            else if (ctx != null)
              AppGroup(children: [
                for (final n in _items) _tile(l, ctx, n),
              ]),
          ]),
        ),
      ],
    );
  }

  Widget _tile(AppLocalizations l, OrderContext ctx, AppNotification n) {
    final isNew = _seenBefore == null || n.at.isAfter(_seenBefore!);
    final (icon, colors) = _look(n.kind);
    final reason = (n.order['return_reason'] as String?) ?? '';
    return AppRow(
      leading: LeadingIcon(icon,
          color: colors.foreground, background: colors.background),
      title: _text(l, n),
      titleStyle: AppText.rowTitle.copyWith(fontWeight: FontWeight.w600),
      subtitle: (n.order['title'] ?? '') as String,
      trailing: isNew
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: AppColors.accent, shape: BoxShape.circle))
          : null,
      extra: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ctx.placeLine(context, n.order), style: AppText.caption),
        if (n.kind == NotificationKind.returned && reason.isNotEmpty)
          Text(l.returnedWithReason(reason),
              style: AppText.caption.copyWith(color: AppColors.danger)),
        Text(l.dateTime(n.at),
            style: AppText.caption.copyWith(color: AppColors.secondary)),
      ]),
      onTap: () async {
        await ctx.open(context, n.order);
        if (mounted) await _load();
      },
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

  /// Значок и цвета квадрата — как у статуса, к которому относится событие.
  (IconData, StatusColors) _look(NotificationKind k) => switch (k) {
        NotificationKind.assigned => (
            AppIcons.executor,
            StatusColors.of('assigned')
          ),
        NotificationKind.returned => (
            AppIcons.undo,
            StatusColors.of('returned')
          ),
        NotificationKind.onReview => (
            AppIcons.checklist,
            StatusColors.of('on_review')
          ),
        NotificationKind.overdue => (
            AppIcons.clock,
            StatusColors.of('overdue')
          ),
        NotificationKind.visitOutside => (
            AppIcons.placeOff,
            StatusColors.of('overdue')
          ),
        NotificationKind.visitMock => (
            AppIcons.warning,
            StatusColors.of('overdue')
          ),
        NotificationKind.inProgress => (
            AppIcons.wrench,
            StatusColors.of('in_progress')
          ),
        NotificationKind.accepted => (
            AppIcons.accepted,
            StatusColors.of('done')
          ),
      };
}
