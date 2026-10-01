import 'package:flutter/material.dart';

/// Стрелка «дальше» в конце строки. При письме справа налево (арабский)
/// смотрит в другую сторону.
class ChevronEnd extends StatelessWidget {
  const ChevronEnd({super.key, this.color, this.size});
  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) => Icon(
        Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right,
        color: color,
        size: size,
      );
}
