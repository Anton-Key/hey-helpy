import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/l10n_ext.dart';
import 'package:hey_helpy/features/directory/directory.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('название продукта и фраза активации берутся из переводов', () {
    expect(ru.appName, 'Эй, Helpy');
    expect(en.appName, 'Hey Helpy');
    expect(ru.wakePhrase, 'Эй, Хелпи');
    expect(en.wakePhrase, 'Hey, Helpy');
  });

  test('число заявок склоняется по правилам языка', () {
    expect(ru.requestsCount(1), '1 заявка');
    expect(ru.requestsCount(3), '3 заявки');
    expect(ru.requestsCount(5), '5 заявок');
    expect(ru.requestsCount(21), '21 заявка');
    expect(en.requestsCount(1), '1 work order');
    expect(en.requestsCount(2), '2 work orders');
  });

  test('коды из базы переводятся', () {
    expect(ru.status('on_review'), 'На проверке');
    expect(en.status('on_review'), 'In review');
    expect(en.priority('critical'), 'Critical');
    expect(en.objectType('warehouse'), 'Warehouse');
    expect(en.statusError(Exception('photo required')), en.errPhotoRequired);
  });

  test('слой: перевод → русский → основное название', () {
    final full = Layer.fromMap({'id': '1', 'name': 'Климат', 'name_i18n': {'ru': 'Климат', 'en': 'HVAC'}});
    final ruOnly = Layer.fromMap({'id': '2', 'name': 'Кровля', 'name_i18n': {'ru': 'Кровля'}});
    final none = Layer.fromMap({'id': '3', 'name': 'Лифты'}); // до миграции 0007
    expect(full.label('en'), 'HVAC');
    expect(full.label('ru'), 'Климат');
    expect(ruOnly.label('en'), 'Кровля');
    expect(none.label('en'), 'Лифты');
    expect(Layer.find([full, ruOnly], name: 'hvac')?.id, '1');
    expect(Layer.find([full, ruOnly], id: '2', name: 'HVAC')?.id, '2');
  });
}
