import 'package:flutter/material.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../directory/directory.dart';
import 'map_logic.dart';

const _ink = Color(0xFF1C1E22);
const _muted = Color(0xFF8A9098);
const _line = Color(0xFFE8EAED);
const _danger = Color(0xFFC24444);

/// Цвет маркера и текста на нём (контраст текста ≥ 4,5:1).
(Color, Color) toneColors(MarkerTone t) => switch (t) {
      MarkerTone.alert => (const Color(0xFFCF3B3B), Colors.white),
      MarkerTone.warning => (const Color(0xFFF08C2E), const Color(0xFF3A1F00)),
      MarkerTone.open => (HeyHelpyTheme.brand, HeyHelpyTheme.onBrand),
      MarkerTone.idle => (const Color(0xFFA9BDB6), const Color(0xFF1F2D28)),
    };

/// Маркер объекта: круг с числом открытых заявок.
class ObjectMarker extends StatelessWidget {
  const ObjectMarker(
      {super.key,
      required this.name,
      required this.stats,
      required this.selected,
      required this.onTap});
  final String name;
  final ObjectStats stats;
  final bool selected;
  final VoidCallback onTap;

  static const size = 36.0;
  static const selectedSize = 50.0;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(markerTone(stats));
    final d = selected ? selectedSize : size;
    return Center(
      child: Tooltip(
        message: '$name · ${context.l10n.mapOpenOrders(stats.open)}',
        waitDuration: const Duration(milliseconds: 300),
        child: Semantics(
          button: true,
          label: name,
          child: GestureDetector(
            onTap: onTap,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: d,
                height: d,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: selected ? _ink : Colors.white,
                      width: selected ? 3 : 2.5),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 6,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: Text('${stats.open}',
                    style: TextStyle(
                        color: fg,
                        fontSize: selected ? 18 : 14,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Кластер: несколько объектов рядом. Число — сумма открытых заявок,
/// кольцо — цвет самого тревожного объекта.
class ClusterMarker extends StatelessWidget {
  const ClusterMarker(
      {super.key,
      required this.objects,
      required this.open,
      required this.tone,
      required this.onTap});
  final int objects;
  final int open;
  final MarkerTone tone;
  final VoidCallback onTap;

  static const size = 50.0;

  @override
  Widget build(BuildContext context) {
    final (ring, _) = toneColors(tone);
    final label = context.l10n.mapCluster(objects);
    return Center(
      child: Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 300),
        child: Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTap: onTap,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: 6),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 6,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$open',
                      style: const TextStyle(
                          color: _ink,
                          fontSize: 15,
                          height: 1.1,
                          fontWeight: FontWeight.w800)),
                  Icon(Icons.apartment, size: 11, color: ring),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Синяя точка «Я здесь».
class MeDot extends StatelessWidget {
  const MeDot({super.key});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2F6FE4),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Color(0x552F6FE4), blurRadius: 10, spreadRadius: 4)
          ],
        ),
      );
}

/// Карточка объекта на карте: адрес, счётчики заявок, действия.
class ObjectInfoCard extends StatelessWidget {
  const ObjectInfoCard(
      {super.key,
      required this.object,
      required this.stats,
      required this.isManager,
      required this.onOpen,
      required this.onOrders,
      required this.onCreate,
      required this.onMove,
      required this.onClose});
  final Obj object;
  final ObjectStats stats;
  final bool isManager;
  final VoidCallback onOpen;
  final VoidCallback onOrders;
  final VoidCallback onCreate;
  final VoidCallback onMove;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (bg, fg) = toneColors(markerTone(stats));
    final address = object.address?.isNotEmpty == true
        ? object.address!
        : l.objectType(object.type);
    Widget counter(String label, int value, {bool alert = false}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: alert && value > 0
                  ? const Color(0xFFFBE8E8)
                  : const Color(0xFFF4F6F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Text('$value',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: alert && value > 0 ? _danger : _ink)),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: _muted)),
            ]),
          ),
        );
    const gap = SizedBox(width: 6);
    const buttonSize = WidgetStatePropertyAll(Size.fromHeight(44));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Text('${stats.open}',
                style: TextStyle(
                    color: fg, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(object.name,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 2),
              Text(address,
                  style: const TextStyle(color: _muted, fontSize: 13)),
              const SizedBox(height: 2),
              Text(l.mapOpenOrders(stats.open),
                  style: const TextStyle(
                      color: HeyHelpyTheme.link,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, semanticLabel: l.mapClose),
            visualDensity: VisualDensity.compact,
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          counter(l.mapCountNew, stats.fresh),
          gap,
          counter(l.mapCountInWork, stats.inWork),
          gap,
          counter(l.mapCountOnReview, stats.onReview),
          gap,
          counter(l.mapCountOverdue, stats.overdue, alert: true),
        ]),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: brandButtonStyle().copyWith(minimumSize: buttonSize),
          onPressed: onOpen,
          icon: const Icon(Icons.apartment, size: 20),
          label: Text(l.mapOpenObject,
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: const ButtonStyle(minimumSize: buttonSize),
          onPressed: onOrders,
          icon: const Icon(Icons.list_alt_rounded, size: 20),
          label: Text(l.mapOrders),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: const ButtonStyle(minimumSize: buttonSize),
          onPressed: onCreate,
          icon: const Icon(Icons.add, size: 20),
          label: Text(l.mapCreateHere),
        ),
        if (isManager)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onMove,
              icon: const Icon(Icons.edit_location_alt_outlined, size: 20),
              label: Text(l.mapMoveOnMap),
            ),
          ),
      ],
    );
  }
}

/// Строка объекта в списке рядом с картой.
class ObjectMapRow extends StatelessWidget {
  const ObjectMapRow(
      {super.key,
      required this.object,
      required this.stats,
      required this.selected,
      required this.onTap,
      this.distanceText});
  final Obj object;
  final ObjectStats stats;
  final bool selected;
  final VoidCallback onTap;
  final String? distanceText;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (bg, fg) = toneColors(markerTone(stats));
    final sub = [
      if (distanceText != null) distanceText!,
      object.address?.isNotEmpty == true
          ? object.address!
          : l.objectType(object.type),
    ].join(' · ');
    return TapCard(
      onTap: onTap,
      chevron: false,
      color: selected ? HeyHelpyTheme.mint : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      margin: const EdgeInsetsDirectional.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Text('${stats.open}',
              style: TextStyle(
                  color: fg, fontSize: 13, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(object.name,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 2),
            Text(sub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }
}

/// Объект без координат: в группе «Без места на карте».
class UnplacedRow extends StatelessWidget {
  const UnplacedRow(
      {super.key,
      required this.object,
      required this.isManager,
      required this.onPlace});
  final Obj object;
  final bool isManager;
  final VoidCallback onPlace;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 8),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 6, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Row(children: [
        const Icon(Icons.location_off_outlined, color: _muted, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(object.name,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        if (isManager)
          TextButton.icon(
            onPressed: onPlace,
            icon: const Icon(Icons.add_location_alt_outlined, size: 20),
            label: Text(l.mapSetOnMap),
          ),
      ]),
    );
  }
}

/// Круглая кнопка управления картой (белая, с тенью).
class MapControlButton extends StatelessWidget {
  const MapControlButton(
      {super.key,
      required this.icon,
      required this.label,
      required this.onPressed,
      this.active = false,
      this.busy = false});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: active ? HeyHelpyTheme.brand : Colors.white,
          shape: const CircleBorder(),
          elevation: 3,
          shadowColor: const Color(0x55000000),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 44,
              height: 44,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(icon,
                      size: 22,
                      semanticLabel: label,
                      color: active ? HeyHelpyTheme.onBrand : _ink),
            ),
          ),
        ),
      ),
    );
  }
}
