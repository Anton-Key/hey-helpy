import 'dart:math' as math;

import '../directory/directory.dart';
import 'voice_draft.dart';

/// Разбор текста заявки в поля черновика — локально, без сети и ИИ.
///
/// На вход — распознанный (или набранный) текст и справочники компании:
/// слои, помещения, объекты. На выходе — [VoiceDraft]: заголовок, описание,
/// слой, место и срочность. Всё, что не удалось определить, остаётся пустым —
/// пользователь выберет сам на экране подтверждения.
///
/// Словарь ключевых слов — ниже, в [layerRules], [highPriority] и
/// [lowPriority]; правила записи слов — в описании [layerRules].
class TextIntake {
  const TextIntake(
      {this.layers = const [],
      this.places = const [],
      this.objects = const []});

  final List<Layer> layers;
  final List<Place> places;
  final List<Obj> objects;

  static const titleMaxLength = 60;

  VoiceDraft parse(String text) {
    final transcript = text.trim();
    final clean = _tidy(stripWakePhrase(transcript));
    final tokens = _tokens(clean);
    final layer = _layer(tokens);
    final where = _where(clean, tokens);
    return VoiceDraft(
      transcript: transcript,
      title: _title(clean),
      description: clean.isEmpty ? null : _sentence(clean),
      layerId: (layer == null || layer.id.isEmpty) ? null : layer.id,
      layer: layer?.name,
      locationId: where.place?.id,
      objectId: where.place?.objectId ?? where.object?.id,
      locationHint: where.hint,
      priority: _priority(tokens),
    );
  }

  // ---------------------------------------------------------------------------
  // «Эй, Хелпи» в начале текста
  // ---------------------------------------------------------------------------

  /// Приветствие + имя («эй, хелпи», «hey helpy», «хей хелпи», «эй help») или
  /// одно имя, если его нельзя спутать с обычным словом («хелпи», «helpy»).
  static final _wake = RegExp(
      r'^[\s\p{P}]*(?:'
      r'(?:эй|ей|хей|хэй|hey|hay|hi|ok|okay|окей)[\s\p{P}]+'
      r'(?:хелпи|хэлпи|хелпе|хелп|helpy|helpie|helpi|help|happy|hippie|hippy|halpy)'
      r'|хелпи|хэлпи|helpy|helpie|helpi'
      r')(?![\p{L}\p{N}])[\s\p{P}]*',
      caseSensitive: false,
      unicode: true);

  /// Убирает фразу активации в начале текста.
  static String stripWakePhrase(String text) =>
      text.replaceFirst(_wake, '').trim();

  // ---------------------------------------------------------------------------
  // Заголовок и описание
  // ---------------------------------------------------------------------------

  /// Лишние пробелы и пробелы перед знаками препинания.
  static String _tidy(String s) => s
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'\s+([,.!?;:])'), r'$1')
      .trim();

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Текст целиком: с заглавной буквы и с точкой в конце.
  static String _sentence(String s) {
    final t = _capitalize(s);
    return RegExp(r'[.!?…]$').hasMatch(t) ? t : '$t.';
  }

  /// Первое предложение до [titleMaxLength] символов. Длинное — по частям
  /// через запятую, а если и первая часть длинная — по словам с «…».
  static String _title(String s) {
    if (s.isEmpty) return '';
    // Слишком короткое первое предложение («Срочно!») — вместе со следующим.
    final sentences = s.split(RegExp(r'(?<=[.!?…])\s+'));
    var first = sentences.first;
    for (var i = 1; i < sentences.length && first.split(' ').length < 3; i++) {
      first = '$first ${sentences[i]}';
    }
    first = first.replaceFirst(RegExp(r'[\s.!?…,;:]+$'), '');
    if (first.length > titleMaxLength) {
      final parts = first.split(RegExp(r'\s*[,;]\s*|\s+[—–-]\s+'));
      var acc = '';
      for (final p in parts) {
        final next = acc.isEmpty ? p : '$acc, $p';
        if (next.length > titleMaxLength) break;
        acc = next;
      }
      if (acc.isNotEmpty) {
        first = acc;
      } else {
        final cut = first.substring(0, titleMaxLength);
        final space = cut.lastIndexOf(' ');
        first =
            '${(space >= 20 ? cut.substring(0, space) : cut).replaceFirst(RegExp(r'[\s,;:]+$'), '')}…';
      }
    }
    return _capitalize(first);
  }

  // ---------------------------------------------------------------------------
  // Слова и ключевые фразы
  // ---------------------------------------------------------------------------

  static List<String> _tokens(String s) => s
      .toLowerCase()
      .replaceAll('ё', 'е')
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((w) => w.isNotEmpty)
      .toList();

  /// Есть ли ключевая фраза [kw] в словах [tokens]. Каждое слово фразы —
  /// начало слова в тексте («розетк» → «розетках»), со знаком `=` в конце —
  /// слово целиком («вода=» не совпадёт с «водитель»). Слова фразы идут подряд.
  static bool has(List<String> tokens, String kw) {
    final parts = kw.split(' ');
    for (var i = 0; i + parts.length <= tokens.length; i++) {
      var ok = true;
      for (var j = 0; j < parts.length && ok; j++) {
        final p = parts[j];
        final t = tokens[i + j];
        ok = p.endsWith('=')
            ? t == p.substring(0, p.length - 1)
            : t.startsWith(p);
      }
      if (ok) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Слой (вид работ)
  // ---------------------------------------------------------------------------

  /// Словарь видов работ — единственное место, где он хранится.
  ///
  /// [LayerRule.names] — названия слоя в базе (layers.name и переводы из
  /// name_i18n), по ним правило находит слой компании. Ключевые слова — в
  /// нижнем регистре, «ё» → «е»; это начала слов (основы), чтобы ловить все
  /// падежи; `=` в конце — слово целиком; пробел — слова подряд. Вес: 3 —
  /// прямо называет оборудование, 2 — характерная жалоба, 1 — слабый намёк.
  /// Побеждает слой с наибольшей суммой; при равенстве — тот, что выше.
  static const layerRules = [
    LayerRule(names: [
      'Климат',
      'HVAC'
    ], keywords: {
      'кондиц': 3, 'кондей': 3, 'кондер': 3, 'сплит': 3, 'вентилят': 3,
      'вентиляц': 3, 'вытяжк': 3, 'приточ': 3, 'отоплен': 3, 'отопит': 3,
      'батаре': 3, 'радиатор': 3, 'конденсат': 3, 'термостат': 3,
      'тепл завес': 3, 'завес': 2, 'фанкойл': 3, 'чиллер': 3, 'климат': 3,
      'внутрен блок': 3, 'наружн блок': 3, 'жарк': 2, 'жара=': 2,
      'холодно=': 2, 'мерзн': 2, 'замерз': 2, 'душно=': 2, 'духот': 2,
      'сквозняк': 2, 'дует=': 2, 'дуют=': 2, 'не охлажда': 2, 'не грее': 2,
      'температур': 1,
      // EN
      'air cond': 3, 'aircon': 3, 'conditioner': 3, 'ac=': 3, 'hvac': 3,
      'ventilat': 3, 'heating': 3, 'heater': 3, 'radiator': 3, 'condensat': 3,
      'thermostat': 3, 'fan=': 2, 'fans=': 2, 'hot=': 2, 'cold=': 2,
      'stuffy': 2, 'draft=': 2, 'draught': 2, 'temperature': 1,
    }),
    LayerRule(names: [
      'Электрика',
      'Electrical'
    ], keywords: {
      'свет': 2, 'освещ': 3, 'ламп': 3, 'розетк': 3, 'выключател': 3,
      'щит': 3, 'электр': 3, 'автомат': 2, 'выбил': 1, 'выбива': 1,
      'искрит': 3, 'искр': 2, 'мигает': 2, 'мигают': 2, 'мерцает': 2,
      'не горит': 2, 'не горят': 2, 'питани': 2, 'напряжени': 2, 'проводк': 3,
      'провод': 2, 'кабел': 1, 'удлинител': 2, 'темно=': 1,
      // EN
      'light': 2, 'lamp': 3, 'bulb': 3, 'socket': 3, 'outlet': 3,
      'power=': 2, 'electric': 3, 'switch': 2, 'breaker': 3, 'fuse': 3,
      'spark': 3, 'flicker': 2, 'wiring': 3, 'plug=': 2, 'dark=': 1,
    }),
    LayerRule(names: [
      'Сантехника',
      'Plumbing'
    ], keywords: {
      'протечк': 3, 'протека': 3, 'теч': 1, 'капа': 1, 'капл': 1, 'кран': 3,
      'смесител': 3, 'унитаз': 3, 'раковин': 3, 'засор': 3, 'канализ': 3,
      'труб': 2, 'вода=': 1, 'воды=': 1, 'воду=': 1, 'водой=': 1, 'воде=': 1,
      'водопровод': 3, 'водоснаб': 3, 'бачок=': 3, 'бачк': 3, 'слив': 2,
      'затопил': 3, 'затапл': 3, 'потоп': 3, 'лужа=': 1, 'душ=': 2,
      'бойлер': 2, 'сантех': 3,
      // EN
      'leak': 3, 'water': 1, 'tap=': 3, 'taps=': 3, 'faucet': 3,
      'toilet': 1, 'flush': 2, 'clog': 3, 'sink': 3, 'pipe': 2, 'drain': 2,
      'flood': 3, 'drip': 1, 'plumb': 3,
    }),
    LayerRule(names: [
      'Системы безопасности',
      'Security systems'
    ], keywords: {
      'камер': 3, 'видеонаблюд': 3, 'пропуск=': 3, 'пропуска=': 3,
      'пропуском=': 3, 'пропускн': 3, 'турникет': 3, 'сигнализ': 3,
      'пожар': 3, 'дым': 3, 'домофон': 3, 'скуд': 3, 'карт доступ': 3,
      'шлагбаум': 3, 'охран': 2, 'извещател': 3, 'спринклер': 3,
      'эвакуац': 2, 'замок=': 2, 'замка=': 2,
      // EN
      'camera': 3, 'cctv': 3, 'badge': 3, 'access card': 3, 'pass=': 2,
      'turnstile': 3, 'alarm': 3, 'fire=': 3, 'smoke': 3, 'intercom': 3,
      'barrier': 2, 'sprinkler': 3, 'lock=': 2, 'security': 2,
    }),
    LayerRule(names: [
      'Клининг',
      'Cleaning'
    ], keywords: {
      'уборк': 3, 'убрат': 2, 'уберит': 2, 'грязн': 2, 'грязь=': 2,
      'грязи=': 2, 'мусор': 3, 'пролил': 2, 'пролит': 2, 'разлил': 2,
      'разлит': 2, 'пыль=': 2, 'пыли=': 2, 'пыльн': 2, 'помыт': 2,
      'вымыт': 2, 'протерет': 2, 'клининг': 3, 'туалетн бумаг': 3,
      'салфет': 2, 'мыло=': 2, 'мыла=': 1,
      // EN
      'clean': 3, 'dirty': 2, 'dirt=': 2, 'trash': 3, 'garbage': 3,
      'rubbish': 3, 'bin=': 2, 'bins=': 2, 'spill': 2, 'mop': 2, 'dust': 2,
      'litter': 2, 'toilet paper': 3,
    }),
    LayerRule(names: [
      'Мебель',
      'Furniture'
    ], keywords: {
      'стул': 2, 'стол=': 2, 'стола=': 2, 'столе=': 2, 'столом=': 2,
      'столы=': 2, 'кресл': 2, 'шкаф': 2, 'полк': 2, 'полок=': 2, 'тумб': 2,
      'диван': 2, 'стеллаж': 2, 'мебел': 3, 'жалюзи': 2, 'ящик': 1,
      // EN
      'chair': 2, 'desk': 2, 'table': 2, 'cabinet': 2, 'shelf': 2,
      'shelves': 2, 'drawer': 1, 'sofa': 2, 'couch': 2, 'blind': 2,
      'furniture': 3,
    }),
  ];

  /// Слой с наибольшим весом ключевых слов. Если справочник слоёв загружен —
  /// только из слоёв компании; иначе — основное название из словаря.
  Layer? _layer(List<String> tokens) {
    Layer? best;
    var bestScore = 0;
    for (final rule in layerRules) {
      final Layer? layer;
      if (layers.isEmpty) {
        layer = Layer(id: '', name: rule.names.first);
      } else {
        layer = layers
            .where((l) => rule.names.any(l.matches))
            .cast<Layer?>()
            .firstWhere((_) => true, orElse: () => null);
        if (layer == null) continue;
      }
      var score = 0;
      rule.keywords.forEach((kw, w) {
        if (has(tokens, kw)) score += w;
      });
      if (score > bestScore) {
        best = layer;
        bestScore = score;
      }
    }
    if (best != null && best.id.isEmpty) return Layer(id: '', name: best.name);
    return best;
  }

  // ---------------------------------------------------------------------------
  // Срочность
  // ---------------------------------------------------------------------------

  /// «Не срочно» — проверяется первым: в нём есть «срочно».
  static const lowPriority = [
    'не срочн', 'несрочн', 'когда будет время', 'как будет время',
    'по возможности', 'не к спеху', 'когда нибудь', //
    'not urgent', 'no rush', 'when you have time', 'whenever you can',
    'low priority', 'no hurry',
  ];

  static const highPriority = [
    'срочн', 'авари', 'протечк', 'затопил', 'затапл', 'потоп', 'искр',
    'дым', 'запах гар', 'пахнет гар', 'гарь=', 'гарью=', 'пожар',
    'не работает совсем', 'совсем не работает', 'вообще не работает',
    'очень жарко', 'очень холодно', 'очень душно', 'немедленно', //
    'urgent', 'asap', 'emergency', 'flood', 'spark', 'smoke', 'burning',
    'fire=', 'not working at all', 'very hot', 'really hot', 'very cold',
    'really cold', 'immediately',
  ];

  /// low / normal / high — значения work_orders.priority.
  static String _priority(List<String> tokens) {
    if (lowPriority.any((k) => has(tokens, k))) return 'low';
    if (highPriority.any((k) => has(tokens, k))) return 'high';
    return 'normal';
  }

  // ---------------------------------------------------------------------------
  // Место: этаж, помещение, объект
  // ---------------------------------------------------------------------------

  static const _ordinalsRu = {
    'перв': 1,
    'втор': 2,
    'трет': 3,
    'четверт': 4,
    'пят': 5,
    'шест': 6,
    'седьм': 7,
    'восьм': 8,
    'девят': 9,
    'десят': 10,
  };
  static const _ordinalsEn = {
    'ground': 1,
    'first': 1,
    'second': 2,
    'third': 3,
    'fourth': 4,
    'fifth': 5,
    'sixth': 6,
    'seventh': 7,
    'eighth': 8,
    'ninth': 9,
    'tenth': 10,
  };

  static final _floorPatterns = <RegExp>[
    // «на 3-м этаже», «3 этаж», «3-й этаж»
    RegExp(r'(?:на\s+)?(\d{1,3})\s*(?:-?\s*(?:й|м|ом|ой|ем|ий))?\s+этаж\p{L}*',
        unicode: true),
    // «этаж 3», «этаж номер 3»
    RegExp(r'этаж\p{L}*\s+(?:номер\s+)?(\d{1,3})(?!\d)', unicode: true),
    // «на третьем этаже»
    RegExp(
        r'(?:на\s+)?(?<![\p{L}])(перв|втор|трет|четверт|пят|шест|седьм|восьм|девят|десят)\p{L}*\s+этаж\p{L}*',
        unicode: true),
    // «floor 3», «level 3»
    RegExp(r'(?:on\s+)?(?:floor|level)\s+(\d{1,3})(?!\d)'),
    // «3rd floor», «on the 3rd floor»
    RegExp(r'(?:on\s+(?:the\s+)?)?(\d{1,3})(?:st|nd|rd|th)?[\s-]+floor'),
    // «third floor», «third-floor»
    RegExp(
        r'(?:on\s+(?:the\s+)?)?\b(ground|first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth)[\s-]+floor'),
  ];

  /// Этаж из текста: номер и фраза, как её сказали («на третьем этаже»).
  static ({int number, String phrase})? floorOf(String text) {
    // toLowerCase и «ё» → «е» не меняют длину строки — индексы совпадают.
    final low = text.toLowerCase().replaceAll('ё', 'е');
    for (final re in _floorPatterns) {
      final m = re.firstMatch(low);
      if (m == null) continue;
      final g = m.group(1)!;
      final n = int.tryParse(g) ??
          _ordinalsRu[g] ??
          _ordinalsEn[g] ??
          _ordinalsRu.entries
              .firstWhere((e) => g.startsWith(e.key),
                  orElse: () => const MapEntry('', 0))
              .value;
      if (n <= 0) continue;
      return (number: n, phrase: text.substring(m.start, m.end).trim());
    }
    return null;
  }

  /// Основа слова для сравнения с названием помещения: без окончания,
  /// но не короче 4 букв («переговорная» → «переговор», «холл» → «холл»).
  static String _stem(String w) =>
      w.length <= 4 ? w : w.substring(0, math.max(4, w.length - 3));

  /// Значимые слова названия: без чисел и слова «этаж».
  static List<String> _nameWords(String name) => _tokens(name)
      .where((w) =>
          w.length >= 3 &&
          !RegExp(r'^\d+$').hasMatch(w) &&
          !w.startsWith('этаж') &&
          w != 'floor' &&
          w != 'level')
      .toList();

  /// Слова названия, найденные в тексте (по основам). Название из двух слов
  /// должно совпасть целиком («Open space» — не просто «open»), из трёх и
  /// больше — хотя бы наполовину; иначе — пустой список.
  static List<String> _matched(String name, List<String> tokens) {
    final found = <String>[];
    final words = _nameWords(name);
    for (final w in words) {
      final s = _stem(w);
      for (final t in tokens) {
        if (t.startsWith(s) && !found.contains(t)) {
          found.add(t);
          break;
        }
      }
    }
    final need = words.length <= 2 ? words.length : (words.length + 1) ~/ 2;
    return found.length >= need ? found : const [];
  }

  /// Общие слова о месте — попадают в подсказку, даже если такого
  /// помещения нет в справочнике.
  static const _placeWords = [
    'переговор',
    'туалет',
    'санузл',
    'кухн',
    'холл',
    'лифт',
    'лестниц',
    'коридор',
    'ресепшн',
    'ресепшен',
    'кабинет',
    'офис',
    'склад',
    'парковк',
    'подвал',
    'крыш',
    'вход',
    'щитов',
    'серверн',
    'столов',
    'опенспейс',
    'meeting room',
    'toilet',
    'restroom',
    'bathroom',
    'kitchen',
    'lobby',
    'hall=',
    'elevator',
    'lift=',
    'stairs',
    'corridor',
    'reception',
    'office',
    'warehouse',
    'parking',
    'basement',
    'roof',
    'entrance',
    'server room',
  ];

  ({Place? place, Obj? object, String? hint}) _where(
      String text, List<String> tokens) {
    final floor = floorOf(text);

    // Помещение: больше совпавших слов названия; этаж — уточняет.
    Place? place;
    var best = 0.0;
    var tie = false;
    var placeTokens = const <String>[];
    for (final p in places) {
      final m = _matched(p.name, tokens);
      if (m.isEmpty) continue;
      var score = m.length.toDouble();
      final pf = floorOf(p.name)?.number;
      if (floor != null && pf != null) {
        score += pf == floor.number ? 0.5 : -0.75;
      }
      if (score <= 0) continue;
      if (score > best) {
        place = p;
        best = score;
        tie = false;
        placeTokens = m;
      } else if (score == best) {
        tie = true;
      }
    }
    // Два одинаково подходящих помещения — пусть выберет пользователь.
    if (tie) place = null;

    Obj? object;
    if (place == null) {
      var bestObj = 0;
      for (final o in objects) {
        final n = _matched(o.name, tokens).length;
        if (n > bestObj) {
          object = o;
          bestObj = n;
        }
      }
    }

    final hintWords = <String>[...placeTokens];
    if (hintWords.isEmpty) {
      for (final kw in _placeWords) {
        final parts = kw.split(' ');
        for (var i = 0; i + parts.length <= tokens.length; i++) {
          final run = tokens.sublist(i, i + parts.length);
          if (has(run, kw)) {
            final phrase = run.join(' ');
            if (!hintWords.contains(phrase)) hintWords.add(phrase);
            break;
          }
        }
      }
    }
    final hint = [
      if (hintWords.isNotEmpty) hintWords.join(' '),
      if (floor != null) floor.phrase,
    ].join(', ');
    return (place: place, object: object, hint: hint.isEmpty ? null : hint);
  }
}

/// Правило словаря: слой и его ключевые слова с весами.
class LayerRule {
  const LayerRule({required this.names, required this.keywords});
  final List<String> names;
  final Map<String, int> keywords;
}
