/// Похожие названия (регионы, города) — защита от дублей и опечаток (шаг 16).
///
/// Нормализация как в базе (0015, `norm_name`: регистр, пробелы, «ё» → «е»)
/// плюс знаки препинания. Похожие — расстояние Левенштейна ≤ 2, у коротких
/// названий (меньше 5 букв) ≤ 1. Тесты — `test/region_name_match_test.dart`.
library;

/// «  ЕвРоПа. » → «европа»; «Ближний-Восток» → «ближний восток».
String normalizeName(String s) => s
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

/// То же, что `norm_name` в базе (без знаков препинания): точный дубль,
/// который база не пропустит (уникальный индекс).
String normalizeLikeDb(String s) =>
    s.toLowerCase().replaceAll('ё', 'е').trim().replaceAll(RegExp(r'\s+'), ' ');

/// Расстояние Левенштейна (вставка, удаление, замена — по 1).
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final x = a.runes.toList(), y = b.runes.toList();
  var prev = List<int>.generate(y.length + 1, (i) => i);
  for (var i = 1; i <= x.length; i++) {
    final cur = List<int>.filled(y.length + 1, 0)..[0] = i;
    for (var j = 1; j <= y.length; j++) {
      final cost = x[i - 1] == y[j - 1] ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost]
          .reduce((m, v) => v < m ? v : m);
    }
    prev = cur;
  }
  return prev[y.length];
}

/// Допустимое расстояние: у названий короче 5 букв — 1, иначе — 2.
int similarityLimit(String a, String b) {
  final n = [a.runes.length, b.runes.length].reduce((m, v) => v < m ? v : m);
  return n < 5 ? 1 : 2;
}

/// Похожи ли два названия (после нормализации).
bool isSimilarName(String a, String b) {
  final x = normalizeName(a), y = normalizeName(b);
  if (x.isEmpty || y.isEmpty) return false;
  if (x == y) return true;
  // Пробелы не считаем отличием: «Ближний Восток» ≈ «БлижнийВосток».
  final xs = x.replaceAll(' ', ''), ys = y.replaceAll(' ', '');
  if (xs == ys) return true;
  final limit = similarityLimit(xs, ys);
  if ((xs.length - ys.length).abs() > limit) return false;
  return levenshtein(xs, ys) <= limit;
}

/// Самое похожее из [items] на [name] (точное совпадение — первым), иначе null.
/// [except] — не сравнивать с этим элементом (переименование самого себя).
T? findSimilar<T>(String name, Iterable<T> items, String Function(T) nameOf,
    {T? except}) {
  final target = normalizeName(name).replaceAll(' ', '');
  T? best;
  var bestD = 1 << 30;
  for (final i in items) {
    if (except != null && identical(i, except)) continue;
    if (!isSimilarName(name, nameOf(i))) continue;
    final d = levenshtein(target, normalizeName(nameOf(i)).replaceAll(' ', ''));
    if (d < bestD) {
      best = i;
      bestD = d;
    }
  }
  return best;
}
