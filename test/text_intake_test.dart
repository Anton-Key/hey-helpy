import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/directory/directory.dart';
import 'package:hey_helpy/features/voice/text_intake.dart';
import 'package:hey_helpy/features/voice/voice_draft.dart';

// Справочники как у компании «Демо БЦ» (supabase/seed/demo.sql и слои 0007).
Layer _layer(String id, String ru, String en) =>
    Layer(id: id, name: ru, names: {'ru': ru, 'en': en});

final _layers = [
  _layer('hvac', 'Климат', 'HVAC'),
  _layer('elec', 'Электрика', 'Electrical'),
  _layer('plumb', 'Сантехника', 'Plumbing'),
  _layer('clean', 'Клининг', 'Cleaning'),
  _layer('sec', 'Системы безопасности', 'Security systems'),
  _layer('furn', 'Мебель', 'Furniture'),
  _layer('other', 'Другое', 'Other'),
];

Place _place(String id, String name) =>
    Place(id: id, objectId: 'bc', name: name, objectName: 'БЦ «Демо»');

final _places = [
  _place('meet', 'Переговорная, 3 этаж'),
  _place('elec', 'Электрощитовая, 1 этаж'),
  _place('open', 'Open space, 2 этаж'),
  _place('hall', 'Холл, 1 этаж'),
];

final _objects = [Obj(id: 'bc', name: 'БЦ «Демо»', type: 'office')];

const _intake = TextIntake();
final _demo = TextIntake(layers: _layers, places: _places, objects: _objects);

VoiceDraft parse(String text) => _demo.parse(text);

void main() {
  group('Фразы из демо-истории', () {
    test('Шумит вентилятор в переговорной', () {
      final d = parse('Шумит вентилятор в переговорной');
      expect(d.layerId, 'hvac');
      expect(d.locationId, 'meet');
      expect(d.objectId, 'bc');
      expect(d.priority, 'normal');
      expect(d.title, 'Шумит вентилятор в переговорной');
      expect(d.description, 'Шумит вентилятор в переговорной.');
    });

    test('Нет питания на розетках в переговорной', () {
      final d = parse('нет питания на розетках в переговорной');
      expect(d.layerId, 'elec');
      expect(d.locationId, 'meet');
      expect(d.title, 'Нет питания на розетках в переговорной');
    });

    test('Мигает свет в холле', () {
      final d = parse('Мигает свет в холле');
      expect(d.layerId, 'elec');
      expect(d.locationId, 'hall');
      expect(d.locationHint, 'холле');
    });

    test('Капает конденсат над рабочим местом', () {
      final d = parse('Капает конденсат над рабочим местом');
      expect(d.layerId, 'hvac');
      expect(d.locationId, isNull);
      expect(d.priority, 'normal');
    });

    test('Выбивает автомат в электрощитовой', () {
      final d = parse('Выбивает автомат в электрощитовой');
      expect(d.layerId, 'elec');
      expect(d.locationId, 'elec');
    });

    test('Течёт вода из кондиционера на ресепшене', () {
      // Оборудование (кондиционер) весит больше, чем «течёт вода».
      final d = parse('Течёт вода из кондиционера на ресепшене');
      expect(d.layerId, 'hvac');
      expect(d.locationHint, 'ресепшене');
    });
  });

  group('«Эй, Хелпи» и оформление', () {
    test('фраза активации убирается, этаж и срочность', () {
      final d = parse(
          'Эй, Хелпи, в переговорной на третьем этаже не работает кондиционер, очень жарко');
      expect(d.transcript, startsWith('Эй, Хелпи'));
      expect(
          d.title, 'В переговорной на третьем этаже не работает кондиционер');
      expect(d.description,
          'В переговорной на третьем этаже не работает кондиционер, очень жарко.');
      expect(d.layerId, 'hvac');
      expect(d.locationId, 'meet');
      expect(d.locationHint, 'переговорной, на третьем этаже');
      expect(d.priority, 'high');
    });

    test('варианты написания фразы активации', () {
      for (final s in [
        'эй хелпи не горит свет',
        'Эй, Helpy, не горит свет',
        'Хей Хелпи не горит свет',
        'хэй, хелпи: не горит свет',
        'Hey Helpy, не горит свет',
        'Хелпи, не горит свет',
      ]) {
        expect(TextIntake.stripWakePhrase(s), 'не горит свет', reason: s);
      }
      // Обычные слова не трогаем.
      expect(TextIntake.stripWakePhrase('Эй, тут течёт кран'),
          'Эй, тут течёт кран');
    });

    test('длинный текст без точек — короткий заголовок с «…»', () {
      final d = parse(
          'в open space на втором этаже уже второй день очень сильно гудит и дребезжит что-то под фальшполом рядом с колонной');
      expect(d.title.length, lessThanOrEqualTo(TextIntake.titleMaxLength + 1));
      expect(d.title, endsWith('…'));
      expect(d.title, startsWith('В open space'));
      expect(d.locationId, 'open');
    });
  });

  group('Слои, срочность, место', () {
    test('без распознанного слоя — null', () {
      final d = parse('Посмотрите, пожалуйста, что-то странное в коридоре');
      expect(d.layerId, isNull);
      expect(d.layer, isNull);
      expect(d.locationHint, 'коридоре');
    });

    test('протечка — Сантехника, срочно', () {
      final d = parse('Протечка в туалете на 2-м этаже, затопило пол');
      expect(d.layerId, 'plumb');
      expect(d.priority, 'high');
      expect(d.locationHint, 'туалете, на 2-м этаже');
    });

    test('искрит розетка — срочно', () {
      final d = parse('Срочно! Искрит розетка у рабочего места');
      expect(d.layerId, 'elec');
      expect(d.priority, 'high');
      expect(d.title, 'Срочно! Искрит розетка у рабочего места');
    });

    test('не срочно — низкая срочность', () {
      final d = parse('Не срочно, когда будет время поменяйте лампу в холле');
      expect(d.priority, 'low');
      expect(d.layerId, 'elec');
      expect(d.locationId, 'hall');
    });

    test('турникет — Системы безопасности', () {
      final d = parse('Не работает турникет на входе, пропуск не читается');
      expect(d.layerId, 'sec');
      expect(d.locationHint, 'входе');
    });

    test('мусор — Клининг', () {
      final d = parse('Уберите мусор возле кухни');
      expect(d.layerId, 'clean');
    });

    test('сломан стул — Мебель', () {
      final d = parse('Сломался стул в переговорной');
      expect(d.layerId, 'furn');
      expect(d.locationId, 'meet');
    });

    test('холодно и батареи — Климат; «холодной воды» — Сантехника', () {
      expect(parse('Холодно, батареи еле тёплые').layerId, 'hvac');
      expect(parse('Нет холодной воды на кухне').layerId, 'plumb');
    });

    test('этаж: цифрой, словом, «этаж N»', () {
      expect(TextIntake.floorOf('на 3-м этаже')?.number, 3);
      expect(TextIntake.floorOf('пятый этаж')?.number, 5);
      expect(TextIntake.floorOf('этаж 12')?.number, 12);
      expect(TextIntake.floorOf('on the 4th floor')?.number, 4);
      expect(TextIntake.floorOf('third-floor meeting room')?.number, 3);
      expect(TextIntake.floorOf('floor 2')?.number, 2);
      expect(TextIntake.floorOf('просто текст'), isNull);
    });

    test('без справочника — слой по основному названию', () {
      final d = _intake.parse('Не работает кондиционер');
      expect(d.layer, 'Климат');
      expect(d.layerId, isNull);
    });
  });

  group('English', () {
    test('Hey Helpy + HVAC + floor + urgency', () {
      final d = parse(
          "Hey Helpy, the air conditioner in the meeting room on the third floor isn't working, it's really hot");
      // Первая часть длиннее 60 символов — обрезается по словам.
      expect(d.title,
          'The air conditioner in the meeting room on the third floor…');
      expect(d.layerId, 'hvac');
      expect(d.priority, 'high');
      expect(d.locationHint, 'meeting room, on the third floor');
    });

    test('lights flickering in the lobby', () {
      final d = parse('The lights are flickering in the lobby');
      expect(d.layerId, 'elec');
      expect(d.locationHint, 'lobby');
      expect(d.description, 'The lights are flickering in the lobby.');
    });

    test('leak — Plumbing, urgent', () {
      final d = parse('Urgent: water leak under the kitchen sink');
      expect(d.layerId, 'plumb');
      expect(d.priority, 'high');
    });

    test('not urgent, nothing recognised', () {
      final d = parse('Not urgent, please check the noise near the window');
      expect(d.layerId, isNull);
      expect(d.priority, 'low');
    });

    test('broken badge reader at the entrance', () {
      final d = parse('My badge does not open the turnstile at the entrance');
      expect(d.layerId, 'sec');
      expect(d.locationHint, 'entrance');
    });
  });

  group('Лифты', () {
    // В рабочей базе слой «Лифты» без переводов (name_i18n пустой).
    final withLifts = TextIntake(
        layers: [..._layers, const Layer(id: 'lift', name: 'Лифты')],
        places: _places,
        objects: _objects);

    test('в лифте застряла женщина — Лифты, срочно', () {
      final d = withLifts.parse('Эй, Хелпи, в лифте застряла женщина, срочно');
      expect(d.layerId, 'lift');
      expect(d.priority, 'high');
      expect(d.title, 'В лифте застряла женщина, срочно');
    });

    test('двери лифта не закрываются; elevator stuck', () {
      expect(withLifts.parse('Двери лифта не закрываются').layerId, 'lift');
      expect(
          withLifts.parse('The elevator is stuck on floor 2').layerId, 'lift');
    });

    test('в лифте не горит свет — Электрика', () {
      expect(withLifts.parse('В лифте не горит свет').layerId, 'elec');
    });

    test('нет слоя «Лифты» у компании — слой не выбран', () {
      expect(parse('В лифте застряла женщина').layerId, isNull);
    });

    test('без справочника — «Лифты»', () {
      expect(_intake.parse('Лифт застрял между этажами').layer, 'Лифты');
    });
  });
}
