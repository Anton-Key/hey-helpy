import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as w;
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/design/design.dart';
import 'package:hey_helpy/features/floors/floor_models.dart';
import 'package:hey_helpy/features/floors/plan_canvas.dart';
import 'package:hey_helpy/features/floors/plan_logic.dart';
import 'package:hey_helpy/features/map/map_logic.dart';

// Шаг 15 (H): подсветка маркеров плана, «дыхание» просроченного
// оборудования, подписи без наездов, этаж без повтора.

const _floor = Floor(id: 'f1', objectId: 'o', companyId: 'c', name: '3 этаж');

PlanItem _asset(String id, double x, double y) =>
    PlanItem(kind: PlanKind.asset, id: id, name: id, floorId: 'f1', x: x, y: y);

Widget _canvas(
        {String? highlight, Map<String, ObjectStats> stats = const {}}) =>
    MaterialApp(
      home: SizedBox(
        width: 800,
        height: 600,
        child: PlanCanvas(
          floor: _floor,
          items: [_asset('a', 0.3, 0.3), _asset('b', 0.7, 0.7)],
          stats: stats,
          controller: PlanCanvasController(),
          highlight: highlight,
          onMarkerTap: (_) {},
        ),
      ),
    );

void main() {
  group('цвет подсветки — цвет статуса, не чёрный', () {
    test('просрочено — красный, срочно — оранжевый, остальное — акцент', () {
      expect(
          markerGlowColor(MarkerTone.alert), StatusColors.overdue.foreground);
      expect(markerGlowColor(MarkerTone.warning), AppColors.priorityHigh);
      expect(markerGlowColor(MarkerTone.open), AppColors.accent);
      expect(markerGlowColor(MarkerTone.idle), AppColors.accent);
      for (final t in MarkerTone.values) {
        expect(markerGlowColor(t), isNot(AppColors.ink));
      }
    });

    test('оборудование: рамка и значок цвета статуса, без заявок — серое', () {
      final (bg, border, icon) = assetColors(MarkerTone.alert);
      expect(border, StatusColors.overdue.foreground);
      expect(icon, StatusColors.overdue.foreground);
      expect(bg, StatusColors.overdue.background);
      expect(assetColors(MarkerTone.idle).$2, AppColors.tertiary);
    });
  });

  group('эффект маркера (markerFx)', () {
    MarkerFx fx(
            {bool selected = false,
            bool pulsing = false,
            bool isPlace = false,
            int overdue = 0,
            bool reduce = false}) =>
        markerFx(
            selected: selected,
            pulsing: pulsing,
            isPlace: isPlace,
            overdue: overdue,
            reduceMotion: reduce);

    test('выбранный: волны 4 с, потом ореол', () {
      expect(fx(selected: true, pulsing: true), MarkerFx.ripple);
      expect(fx(selected: true), MarkerFx.halo);
      expect(kPlanPulseWindow, const Duration(seconds: 4));
    });

    test('просроченное оборудование «дышит», помещение и без заявок — нет', () {
      expect(fx(overdue: 1), MarkerFx.breathe);
      expect(fx(overdue: 1, isPlace: true), MarkerFx.none);
      expect(fx(), MarkerFx.none);
    });

    test('«уменьшение движения» отключает анимацию', () {
      expect(fx(selected: true, pulsing: true, reduce: true), MarkerFx.halo);
      expect(fx(overdue: 2, reduce: true), MarkerFx.none);
      expect(planNeedsTicker([MarkerFx.halo, MarkerFx.none]), isFalse);
      expect(planNeedsTicker([MarkerFx.none, MarkerFx.breathe]), isTrue);
    });
  });

  group('подписи', () {
    test('помещение — только выбранное / наведённое или сильное приближение',
        () {
      bool w(
              {bool place = true,
              bool sel = false,
              bool hov = false,
              double s = 1}) =>
          planLabelWanted(
              isPlace: place,
              selected: sel,
              hovered: hov,
              scale: s,
              fitScale: 1);
      expect(w(), isFalse);
      expect(w(s: 2), isFalse);
      expect(w(sel: true), isTrue);
      expect(w(hov: true), isTrue);
      expect(w(s: 4), isTrue);
      expect(w(place: false, s: 2), isTrue);
      expect(w(place: false), isFalse);
    });

    test('подпись не наезжает на соседний маркер; выбранная — всегда', () {
      // «Серверная, 3 этаж» над «Серверная стойка R1»: подпись помещения
      // попала бы на маркер стойки.
      const room = PlanLabelBox('room', Offset(100, 100), 'Серверная, 3 этаж');
      const rack =
          PlanLabelBox('rack', Offset(100, 130), 'Серверная стойка R1');
      expect(planLabelLayout([room, rack]), {'rack'});
      const roomSel = PlanLabelBox(
          'room', Offset(100, 100), 'Серверная, 3 этаж',
          priority: true);
      expect(planLabelLayout([roomSel, rack]), contains('room'));
      // Далеко друг от друга — обе.
      const far = PlanLabelBox('far', Offset(400, 400), 'Щит');
      expect(planLabelLayout([room, far]), {'room', 'far'});
      // Не хочется — не показывается.
      const off = PlanLabelBox('x', Offset(10, 10), 'X', wanted: false);
      expect(planLabelLayout([off]), isEmpty);
    });
  });

  group('этаж в шторке без повтора', () {
    test('этаж уже в названии помещения — не повторяется', () {
      expect(
          floorPartIfNew('3 этаж', ['Стойка R1', 'Серверная, 3 этаж']), isNull);
      expect(floorPartIfNew('3 этаж', ['Стойка R1', 'Серверная']), '3 этаж');
      expect(floorPartIfNew('3 ЭТАЖ', ['серверная, 3 этаж']), isNull);
    });
    test('«3 этаж» не путается с «13 этаж»', () {
      expect(floorPartIfNew('3 этаж', ['Холл, 13 этаж']), '3 этаж');
    });
    test('пустой этаж — нет части', () {
      expect(floorPartIfNew(null, ['A']), isNull);
      expect(floorPartIfNew(' ', ['A']), isNull);
    });
  });

  group('холст: один тикер, «уменьшение движения»', () {
    const overdue = {'asset:a': ObjectStats(open: 1, overdue: 1)};

    testWidgets('выбранный маркер: волны 4 с, потом тикер останавливается',
        (t) async {
      await t.pumpWidget(_canvas(highlight: 'asset:a'));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.binding.hasScheduledFrame, isTrue, reason: 'волны идут');
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      expect(t.binding.hasScheduledFrame, isFalse, reason: 'остался ореол');
    });

    testWidgets('просроченное оборудование «дышит»', (t) async {
      await t.pumpWidget(_canvas(stats: overdue));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(seconds: 6));
      expect(t.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('«уменьшение движения» — без анимации', (t) async {
      await t.pumpWidget(MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _canvas(highlight: 'asset:a', stats: overdue)));
      await t.pump(const Duration(milliseconds: 100));
      await t.pumpAndSettle();
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('40 «дышащих» маркеров: тикер не перестраивает маркеры',
        (t) async {
      final items = [
        for (var i = 0; i < 40; i++)
          _asset('m$i', 0.05 + (i % 8) * 0.12, 0.1 + (i ~/ 8) * 0.18)
      ];
      final stats = {
        for (final i in items) i.key: const ObjectStats(open: 1, overdue: 1)
      };
      await t.pumpWidget(MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: PlanCanvas(
            floor: _floor,
            items: items,
            stats: stats,
            controller: PlanCanvasController(),
            highlight: 'asset:m0',
            onMarkerTap: (_) {},
          ),
        ),
      ));
      await t.pump(const Duration(milliseconds: 100));
      var rebuilt = 0;
      w.debugOnRebuildDirtyWidget = (e, _) {
        if (e.widget is PlanMarker) rebuilt++;
      };
      // 2 с анимации (~120 кадров): только перерисовка колец.
      for (var i = 0; i < 120; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      w.debugOnRebuildDirtyWidget = null;
      expect(t.binding.hasScheduledFrame, isTrue, reason: 'анимация идёт');
      expect(rebuilt, 0);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('выбранный маркер увеличен в 1,25 раза', (t) async {
      await t.pumpWidget(MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _canvas(highlight: 'asset:a')));
      await t.pumpAndSettle();
      final scales = t
          .widgetList<Transform>(find.descendant(
              of: find.byType(PlanMarker), matching: find.byType(Transform)))
          .map((w) => w.transform.getMaxScaleOnAxis())
          .where((s) => (s - 1.25).abs() < 0.001);
      expect(scales, hasLength(1));
    });
  });
}
