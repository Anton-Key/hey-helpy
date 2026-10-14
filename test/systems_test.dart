import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/design/design.dart';
import 'package:hey_helpy/features/directory/directory.dart';
import 'package:hey_helpy/features/systems/systems_repository.dart';

void main() {
  group('Системы (шаг 24)', () {
    test('счётчики: оборудование, открытые заявки, разные подрядчики', () {
      final s = countSystemStats(
        assetLayers: ['a', 'a', 'b', null],
        openOrderLayers: ['a', null, 'c'],
        bindings: [('k1', 'a'), ('k1', 'a'), ('k2', 'a'), ('k1', 'b')],
      );
      expect(s['a']!.assets, 2);
      expect(s['a']!.openOrders, 1);
      expect(s['a']!.contractors, 2);
      expect(s['b']!.contractors, 1);
      expect(s['c']!.openOrders, 1);
      expect(s.containsKey(null), isFalse);
    });

    test('порядок: вверх / вниз, за край — без изменений', () {
      const a = Layer(id: 'a', name: 'A');
      const b = Layer(id: 'b', name: 'B');
      const c = Layer(id: 'c', name: 'C');
      expect(moveSystem([a, b, c], 2, 1).map((x) => x.id), ['a', 'c', 'b']);
      expect(moveSystem([a, b, c], 0, -1).map((x) => x.id), ['a', 'b', 'c']);
    });

    test('архивные не предлагаются, кроме уже выбранной', () {
      final arch = Layer(id: 'x', name: 'X', archivedAt: DateTime(2026));
      const live = Layer(id: 'y', name: 'Y');
      expect(Layer.active([arch, live]).map((x) => x.id), ['y']);
      expect(Layer.active([arch, live], keepId: 'x').map((x) => x.id),
          ['x', 'y']);
      expect(Layer.fromMap({'id': 'z', 'name': 'Z', 'archived_at': null}).archived,
          isFalse);
    });

    test('значок по коду или по названию стандартной системы', () {
      expect(systemIconCode('lift', 'Что угодно'), 'lift');
      expect(systemIconCode(null, 'Климат'), 'climate');
      expect(systemIconCode('нет-такого', 'Электрика'), 'electric');
      expect(systemIconCode(null, 'Прочее'), 'other');
      for (final k in kSystemIcons.keys) {
        expect(RegExp(r'^[a-z][a-z0-9_]{0,23}$').hasMatch(k), isTrue,
            reason: 'код значка $k должен пройти проверку базы (0020)');
      }
    });

    test('палитра: 6–8 цветов #RRGGBB, кривой цвет — серый', () {
      expect(SystemPalette.colors.length, inInclusiveRange(6, 8));
      for (final c in SystemPalette.colors) {
        expect(RegExp(r'^#[0-9A-F]{6}$').hasMatch(c), isTrue);
      }
      expect(SystemPalette.parse('#0E8C80').toARGB32(), 0xFF0E8C80);
      expect(SystemPalette.parse('red'), SystemPalette.fallback);
    });
  });
}
