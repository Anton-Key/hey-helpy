import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/regions/name_match.dart';
import 'package:hey_helpy/features/regions/region.dart';

void main() {
  test('normalizeName: регистр, пробелы, ё → е, знаки препинания', () {
    expect(normalizeName('  ЕвРоПа  '), 'европа');
    expect(normalizeName('Ближний   Восток'), 'ближний восток');
    expect(normalizeName('Ближний-Восток.'), 'ближний восток');
    expect(normalizeName('Ёлки'), normalizeName('елки'));
    expect(normalizeLikeDb(' европа '), normalizeLikeDb('ЕВРОПА'));
    // База знаки препинания не убирает — только приложение.
    expect(normalizeLikeDb('Европа.'), isNot(normalizeLikeDb('Европа')));
  });

  test('levenshtein', () {
    expect(levenshtein('европа', 'европа'), 0);
    expect(levenshtein('европа', 'европпа'), 1);
    expect(levenshtein('белград', 'белгад'), 1);
    expect(levenshtein('', 'абв'), 3);
    expect(levenshtein('кот', 'ток'), 2);
  });

  test('похожие: Европа ≈ Европпа ≈ «европа », но не Африка', () {
    expect(isSimilarName('Европа', 'Европпа'), isTrue);
    expect(isSimilarName('Европа', ' европа '), isTrue);
    expect(isSimilarName('Европа', 'Еврапа'), isTrue);
    expect(isSimilarName('Европа', 'Африка'), isFalse);
    expect(isSimilarName('Европа', 'Азия'), isFalse);
    expect(isSimilarName('Ближний Восток', 'БлижнийВосток'), isTrue);
    expect(isSimilarName('Белград', 'Белгад'), isTrue);
  });

  test('короткие названия (< 5 букв) — не больше 1 отличия', () {
    expect(isSimilarName('Азия', 'Азия'), isTrue);
    expect(isSimilarName('Азия', 'Азя'), isTrue);
    expect(isSimilarName('Азия', 'Ася-1'), isFalse);
    expect(isSimilarName('СНГ', 'СНГ.'), isTrue);
    expect(isSimilarName('СНГ', 'США'), isFalse);
    expect(similarityLimit('азия', 'европа'), 1);
    expect(similarityLimit('европа', 'африка'), 2);
  });

  test('findSimilar: ближайший, точное совпадение — первым', () {
    const regions = [
      Region(id: '1', name: 'Европа'),
      Region(id: '2', name: 'Африка'),
      Region(id: '3', name: 'Азия'),
    ];
    String n(Region r) => r.name;
    expect(findSimilar('Европпа', regions, n)?.id, '1');
    expect(findSimilar('ЕВРОПА', regions, n)?.id, '1');
    expect(findSimilar('Азия ', regions, n)?.id, '3');
    expect(findSimilar('Океания', regions, n), isNull);
    expect(findSimilar('Ася-1', regions, n), isNull);
  });
}
