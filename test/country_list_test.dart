import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/regions/countries.dart';

void main() {
  test('справочник: коды уникальны, две заглавные латинские буквы', () {
    final codes = {for (final c in kCountries) c.code};
    expect(codes.length, kCountries.length);
    expect(kCountries.length, greaterThan(200));
    for (final c in kCountries) {
      expect(RegExp(r'^[A-Z]{2}$').hasMatch(c.code), isTrue, reason: c.code);
      expect(c.ru, isNotEmpty);
      expect(c.en, isNotEmpty);
    }
    for (final code in ['RS', 'RU', 'AE', 'TR', 'CI', 'CN']) {
      expect(countryByCode(code), isNotNull, reason: code);
    }
  });

  test('флаг и подпись', () {
    expect(countryFlag('RS'), '🇷🇸');
    expect(countryFlag('rs'), '🇷🇸');
    expect(countryFlag('R1'), '');
    expect(countryLabel('RS', 'ru'), '🇷🇸 Сербия');
    expect(countryLabel('RS', 'en', flag: false), 'Serbia');
    expect(countryLabel('ZZ', 'ru'), 'ZZ');
  });

  test('поиск по-русски, по-английски и по коду', () {
    expect(searchCountries('серб', 'ru').first.code, 'RS');
    expect(searchCountries('serb', 'ru').first.code, 'RS');
    expect(searchCountries('rs', 'ru').first.code, 'RS');
    expect(searchCountries('кот', 'ru').map((c) => c.code), contains('CI'));
    expect(searchCountries('Эмираты', 'ru'), isEmpty);
    expect(searchCountries('emirates', 'en').single.code, 'AE');
    expect(searchCountries('', 'ru').length, kCountries.length);
  });
}
