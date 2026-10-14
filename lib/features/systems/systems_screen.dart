import 'package:flutter/material.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/schema_compat.dart';
import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';
import 'system_card.dart';
import 'system_form.dart';
import 'systems_repository.dart';

/// Значок системы её цветом — для списков и карточки.
class SystemTile extends StatelessWidget {
  const SystemTile(this.layer, {super.key});
  final Layer layer;

  @override
  Widget build(BuildContext context) {
    final c =
        layer.archived ? AppColors.tertiary : SystemPalette.parse(layer.color);
    return LeadingIcon(systemIcon(layer.icon, layer.name),
        color: c, background: c.withValues(alpha: 0.14));
  }
}

/// «Моя компания» → «Системы» (шаг 24). Администратор — создаёт, меняет,
/// упорядочивает, архивирует. Менеджер — только чтение и только системы
/// своей зоны доступа (база: layers_select, 0020). Счётчики — в пределах
/// того, что видно.
class SystemsScreen extends StatefulWidget {
  const SystemsScreen(
      {super.key, required this.companyId, required this.isAdmin});
  final String companyId;
  final bool isAdmin;

  @override
  State<SystemsScreen> createState() => _SystemsScreenState();
}

class _SystemsScreenState extends State<SystemsScreen> {
  final _repo = SystemsRepository();
  List<Layer> _layers = const [];
  Map<String, SystemStats> _stats = const {};
  bool _loading = true;
  bool _failed = false;
  bool _showArchived = false;

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
      final layers = await _repo.list();
      Map<String, SystemStats> stats = const {};
      try {
        stats = await _repo.stats();
      } catch (e) {
        debugPrint('systems stats: ${e.runtimeType}');
      }
      if (!mounted) return;
      setState(() {
        _layers = layers;
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      debugPrint('systems: ${e.runtimeType}');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  bool get _canEdit => widget.isAdmin && SchemaCompat.has('0020') != false;

  Future<void> _add() async {
    final ok = await showSystemForm(context,
        companyId: widget.companyId,
        sort: (_layers.isEmpty ? 0 : _layers.last.sort) + 10);
    if (ok == true) await _load();
  }

  Future<void> _move(List<Layer> active, int i, int delta) async {
    final l = context.l10n;
    final next = moveSystem(active, i, i + delta);
    setState(() => _layers = [...next, ..._layers.where((x) => x.archived)]);
    try {
      await _repo.saveOrder(next);
    } catch (e) {
      debugPrint('systems order: ${e.runtimeType}');
      if (mounted) {
        showAppMessage(context, l.systemSaveFailed, type: AppMessageType.error);
      }
    }
    await _load();
  }

  Future<void> _open(Layer y) async {
    final changed = await Navigator.push<bool>(
        context,
        appRoute(
            (_) => SystemCardScreen(
                layer: y,
                companyId: widget.companyId,
                canEdit: _canEdit,
                stats: _stats[y.id] ?? const SystemStats()),
            title: context.l10n.systemsTitle));
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppScaffold(
      title: l.systemsTitle,
      onRefresh: _load,
      actions: [
        if (_canEdit)
          AppIconButton(
              icon: AppIcons.add, label: l.systemAdd, onPressed: _add),
      ],
      slivers: [_body(l), const SliverBottomInset()],
    );
  }

  Widget _body(AppLocalizations l) {
    if (_loading && _layers.isEmpty) {
      return const SliverFillRemaining(
          hasScrollBody: false, child: AppLoader());
    }
    if (_failed) {
      return SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
              text: l.systemsLoadFailed,
              error: true,
              actionLabel: l.commonRetry,
              onAction: _load));
    }
    if (_layers.isEmpty) {
      return SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
              icon: AppIcons.systems,
              text: widget.isAdmin ? l.systemsEmptyAdmin : l.systemsEmpty,
              actionLabel: _canEdit ? l.systemAdd : null,
              onAction: _canEdit ? _add : null));
    }
    final active = [
      for (final y in _layers)
        if (!y.archived) y
    ];
    final archived = [
      for (final y in _layers)
        if (y.archived) y
    ];
    final locale = context.localeCode;
    Widget row(Layer y, {int? index}) {
      final s = _stats[y.id] ?? const SystemStats();
      return AppRow(
        leading: SystemTile(y),
        title: y.label(locale),
        subtitle: l.systemCounts(s.assets, s.openOrders, s.contractors),
        subtitleMaxLines: 2,
        onTap: () => _open(y),
        trailing: index == null || !_canEdit
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: [
                AppIconButton(
                    icon: AppIcons.chevronUp,
                    label: l.systemMoveUp(y.label(locale)),
                    size: 32,
                    onPressed:
                        index == 0 ? null : () => _move(active, index, -1)),
                AppIconButton(
                    icon: AppIcons.chevronDown,
                    label: l.systemMoveDown(y.label(locale)),
                    size: 32,
                    onPressed: index == active.length - 1
                        ? null
                        : () => _move(active, index, 1)),
              ]),
      );
    }

    return SliverContent(
      sliver: SliverList.list(children: [
        AppGroup(
          separatorInset: AppSpace.separatorInsetIcon,
          footer: widget.isAdmin
              ? (_canEdit ? l.systemsFooterAdmin : l.migrationNeeded('0020'))
              : l.systemsFooterManager,
          children: [
            for (var i = 0; i < active.length; i++) row(active[i], index: i),
          ],
        ),
        if (archived.isNotEmpty) ...[
          AppGroup(children: [
            AppRow(
              leading: const LeadingIcon.neutral(AppIcons.archive),
              title: l.systemsArchived(archived.length),
              trailing: Icon(
                  _showArchived ? AppIcons.chevronUp : AppIcons.chevronDown,
                  size: AppSizes.iconS,
                  color: AppColors.tertiary),
              chevron: false,
              onTap: () => setState(() => _showArchived = !_showArchived),
            ),
          ]),
          if (_showArchived)
            AppGroup(
                separatorInset: AppSpace.separatorInsetIcon,
                footer: l.systemsArchivedFooter,
                children: [for (final y in archived) row(y)]),
        ],
      ]),
    );
  }
}
