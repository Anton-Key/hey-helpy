import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import 'order_list.dart';
import 'requests.dart';

/// Карточка заявки по ссылке `#/orders/<id>` (шаг 23: «Открыть в
/// приложении» из Telegram-бота). Доступ — под RLS: чужая заявка = «не
/// найдена». Ссылка переживает вход (роутер запоминает адрес). Маршрут
/// вложен в «/»: «Назад» ведёт на главный экран.
class OrderLinkScreen extends StatefulWidget {
  const OrderLinkScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<OrderLinkScreen> createState() => _OrderLinkScreenState();
}

class _OrderLinkScreenState extends State<OrderLinkScreen> {
  OrderContext? _ctx;
  WorkOrder? _order;
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
      final ctx = await OrderContext.load();
      final row = await ctx.repo.detail(widget.orderId);
      if (!mounted) return;
      setState(() {
        _ctx = ctx;
        _order = row == null ? null : WorkOrder.fromMap(row);
        _loading = false;
      });
    } catch (e) {
      debugPrint('OrderLink: $e');
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
    final o = _order;
    if (ctx != null && o != null) {
      return WorkOrderDetailScreen(
        order: o,
        objects: ctx.objects,
        contractors: ctx.contractors,
        layers: ctx.layers,
        uid: ctx.uid,
        role: ctx.role,
        repo: ctx.repo,
        companyId: ctx.companyId,
      );
    }
    return AppScaffold(
      title: l.tabRequests,
      slivers: [
        SliverContent(
          sliver: SliverList.list(children: [
            if (_loading)
              const Padding(
                padding: EdgeInsetsDirectional.only(top: AppSpace.xxl),
                child: AppLoader(),
              )
            else
              AppEmptyState(
                text: _failed ? l.errorGeneric : l.orderLinkNotFound,
                error: _failed,
                actionLabel: _failed ? l.commonRetry : l.tabRequests,
                onAction: _failed ? _load : () => context.go('/'),
              ),
          ]),
        ),
      ],
    );
  }
}
