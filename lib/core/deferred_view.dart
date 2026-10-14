import 'package:flutter/widgets.dart';

import 'design/design.dart';
import 'l10n_ext.dart';

/// Раздел, код которого загружается отложенно (шаг 27, первая загрузка
/// сайта): `import '…' deferred as x;` и
/// `DeferredView(load: x.loadLibrary, builder: (_) => x.Screen())`.
///
/// Пока часть загружается — индикатор; не загрузилась (нет сети) —
/// «Не получилось…» и «Повторить». На Android загрузка мгновенная.
class DeferredView extends StatefulWidget {
  const DeferredView({super.key, required this.load, required this.builder});

  final Future<void> Function() load;
  final WidgetBuilder builder;

  @override
  State<DeferredView> createState() => _DeferredViewState();
}

class _DeferredViewState extends State<DeferredView> {
  late Future<void> _future = widget.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const ColoredBox(color: AppColors.bg, child: AppLoader());
          }
          if (snap.hasError) {
            return ColoredBox(
              color: AppColors.bg,
              child: AppEmptyState(
                text: context.l10n.errorGeneric,
                error: true,
                actionLabel: context.l10n.commonRetry,
                onAction: () => setState(() {
                  _future = widget.load();
                }),
              ),
            );
          }
          return widget.builder(context);
        },
      );
}
