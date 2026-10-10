import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/directory/directory.dart';
import 'package:hey_helpy/features/floors/floor_models.dart';
import 'package:hey_helpy/features/floors/plan_logic.dart';
import 'package:hey_helpy/features/voice/text_intake.dart';

// Номера и области помещений (шаг 16): plan_shape, попадание в область,
// номер помещения в тексте заявки.

const _square = [(0.2, 0.2), (0.6, 0.2), (0.6, 0.6), (0.2, 0.6)];

PlanItem _room(String id,
        {List<(double, double)>? shape, String floor = 'f1', String? code}) =>
    PlanItem(
        kind: PlanKind.place,
        id: id,
        name: 'Комната $id',
        floorId: floor,
        x: 0.5,
        y: 0.5,
        code: code,
        shape: shape);

void main() {
  group('Точка в многоугольнике', () {
    test('квадрат: внутри, снаружи, на другой стороне', () {
      expect(pointInPolygon(0.4, 0.4, _square), isTrue);
      expect(pointInPolygon(0.1, 0.4, _square), isFalse);
      expect(pointInPolygon(0.7, 0.4, _square), isFalse);
      expect(pointInPolygon(0.4, 0.9, _square), isFalse);
    });

    test('невыпуклая «Г»: вырез — снаружи', () {
      const l = [
        (0.0, 0.0),
        (0.5, 0.0),
        (0.5, 0.2),
        (0.2, 0.2),
        (0.2, 0.5),
        (0.0, 0.5)
      ];
      expect(pointInPolygon(0.1, 0.4, l), isTrue);
      expect(pointInPolygon(0.4, 0.1, l), isTrue);
      expect(pointInPolygon(0.4, 0.4, l), isFalse);
    });

    test('меньше трёх точек — никогда', () {
      expect(pointInPolygon(0.1, 0.1, const [(0.0, 0.0), (1.0, 1.0)]), isFalse);
    });
  });

  group('plan_shape: чтение и запись', () {
    test('правильный многоугольник читается', () {
      final s = parsePlanShape({
        'type': 'polygon',
        'points': [
          [0.1, 0.1],
          [0.9, 0.1],
          [0.5, 0.8]
        ]
      });
      expect(s, [(0.1, 0.1), (0.9, 0.1), (0.5, 0.8)]);
    });

    test('целые числа (0 и 1) — тоже числа', () {
      final s = parsePlanShape({
        'type': 'polygon',
        'points': [
          [0, 0],
          [1, 0],
          [1, 1]
        ]
      });
      expect(s, [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0)]);
    });

    test('неправильное — null', () {
      expect(parsePlanShape(null), isNull);
      expect(parsePlanShape('polygon'), isNull);
      expect(parsePlanShape({'type': 'circle', 'points': []}), isNull);
      expect(
          parsePlanShape({
            'type': 'polygon',
            'points': [
              [0.1, 0.1],
              [0.2, 0.2]
            ]
          }),
          isNull,
          reason: 'две точки');
      expect(
          parsePlanShape({
            'type': 'polygon',
            'points': [
              [0.1, 0.1],
              [0.2, '0.2'],
              [0.3, 0.3]
            ]
          }),
          isNull,
          reason: 'строка вместо числа');
      expect(
          parsePlanShape({
            'type': 'polygon',
            'points': [
              [0.1, 0.1],
              [1.2, 0.2],
              [0.3, 0.3]
            ]
          }),
          isNull,
          reason: 'за краем плана');
      expect(
          parsePlanShape({
            'type': 'polygon',
            'points': [
              [0.1],
              [0.2, 0.2],
              [0.3, 0.3]
            ]
          }),
          isNull,
          reason: 'одна координата');
      expect(
          parsePlanShape({
            'type': 'polygon',
            'points': List.generate(kMaxAreaPoints + 1, (i) => [0.5, 0.5])
          }),
          isNull,
          reason: 'слишком много точек');
    });

    test('запись → чтение: то же самое, округление до 4 знаков', () {
      final json = planShapeJson([(0.123456, 0.5), (0.9, 0.1), (0.5, 0.87654)]);
      expect(json['type'], 'polygon');
      expect(parsePlanShape(json), [(0.1235, 0.5), (0.9, 0.1), (0.5, 0.8765)]);
    });

    test('PlanItem: код и область из строки базы, без кода — null', () {
      final i = PlanItem.placeFromMap({
        'id': 'r1',
        'name': 'Переговорная',
        'floor_id': 'f1',
        'plan_x': 0.5,
        'plan_y': 0.5,
        'code': ' 305 ',
        'plan_shape': planShapeJson(_square),
      });
      expect(i.code, '305');
      expect(i.label, '305 · Переговорная');
      expect(i.hasAreaOn('f1'), isTrue);
      expect(i.hasAreaOn('f2'), isFalse);
      final old = PlanItem.placeFromMap(
          {'id': 'r2', 'name': 'Холл', 'plan_shape': 'мусор'});
      expect(old.code, isNull);
      expect(old.label, 'Холл');
      expect(old.shape, isNull);
    });
  });

  group('Область на плане', () {
    test('прямоугольник по двум углам — в любом порядке', () {
      expect(rectShape((0.6, 0.6), (0.2, 0.2)), _square);
    });

    test('центр области', () {
      final (cx, cy) = polygonCentroid(_square);
      expect(cx, closeTo(0.4, 1e-9));
      expect(cy, closeTo(0.4, 1e-9));
    });

    test('нажатие: вложенная область важнее (меньше)', () {
      const plan = Size(2000, 1000);
      final big = _room('big',
          shape: const [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]);
      final small = _room('small', shape: _square);
      final other = _room('other', shape: _square, floor: 'f2');
      final items = [big, small, other];
      expect(areaAt(items, 'f1', 0.3, 0.3, plan)?.id, 'small');
      expect(areaAt(items, 'f1', 0.9, 0.9, plan)?.id, 'big');
      expect(areaAt([small], 'f1', 0.9, 0.9, plan), isNull);
      expect(areaAt(items, 'f2', 0.3, 0.3, plan)?.id, 'other');
    });

    test('подпись области — при приближении и если область не крошечная', () {
      const plan = Size(2000, 1000);
      expect(areaLabelVisible(_square, plan, 0.3, 0.3), isFalse,
          reason: 'не приближено');
      expect(areaLabelVisible(_square, plan, 0.6, 0.3), isTrue);
      const tiny = [(0.5, 0.5), (0.501, 0.5), (0.501, 0.501)];
      expect(areaLabelVisible(tiny, plan, 0.6, 0.3), isFalse);
    });
  });

  group('Номер помещения в тексте', () {
    String? code(String t) => TextIntake.roomNumberOf(t)?.code;

    test('со словом «кабинет», «комната», «room», «№»', () {
      expect(code('Не работает свет, кабинет 305'), '305');
      expect(code('Течёт кран в комнате 12а'), '12а');
      expect(code('Помещение № 7: сломан стул'), '7');
      expect(code('Leaking tap in room 305'), '305');
      expect(code('Жарко в номере 214'), '214');
    });

    test('с предлогом: «в 305-й», «в 305 кабинете», «in 305»', () {
      expect(code('Дует кондиционер в 305-й'), '305');
      expect(code('Шумит вентилятор в 305 кабинете'), '305');
      expect(code('Шумит вентилятор в 305'), '305');
      expect(code('Нет света в 12-й'), '12');
      expect(code('The light is off in 305'), '305');
    });

    test('этаж и время — не номер помещения', () {
      expect(code('Течёт вода на 3-м этаже'), isNull);
      expect(code('Сломан стул в 3 этаже'), isNull);
      expect(code('Этаж номер 3, течёт кран'), isNull);
      expect(code('Уборка в 10:00'), isNull);
      expect(code('Уборка в 2 раза чаще'), isNull);
      expect(code('Не работает розетка'), isNull);
    });

    test('разбор: номер выбирает помещение, даже без слов названия', () {
      final places = [
        Place(id: 'p305', objectId: 'bc', name: 'Open space', code: '305'),
        Place(id: 'p301', objectId: 'bc', name: 'Переговорная', code: '301'),
      ];
      final intake = TextIntake(places: places);
      final d = intake.parse('Эй, Хелпи, течёт кран в 305-й');
      expect(d.locationId, 'p305');
      expect(d.objectId, 'bc');
      expect(d.locationHint, contains('305'));
      // «кабинет 301» важнее совпавшего слова другого помещения
      expect(intake.parse('Кабинет 301, open space рядом шумит').locationId,
          'p301');
    });

    test('один номер в двух объектах: уточняют слова, иначе — не выбираем', () {
      final places = [
        Place(id: 'a', objectId: 'o1', name: 'Кухня', code: '101'),
        Place(id: 'b', objectId: 'o2', name: 'Серверная', code: '101'),
      ];
      final intake = TextIntake(places: places);
      expect(intake.parse('Перегрев в серверной, кабинет 101').locationId, 'b');
      expect(intake.parse('Не работает свет, кабинет 101').locationId, isNull);
    });

    test('номера нет в справочнике — обычный разбор по словам', () {
      final places = [Place(id: 'h', objectId: 'bc', name: 'Холл')];
      final d =
          TextIntake(places: places).parse('Мигает свет в холле, кабинет 999');
      expect(d.locationId, 'h');
    });
  });
}
