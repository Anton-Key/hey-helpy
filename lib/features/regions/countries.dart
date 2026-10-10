/// Встроенный справочник стран ISO 3166-1 alpha-2 с названиями на русском
/// и английском (шаг 16). Страна объекта выбирается только из него — ввести
/// её текстом нельзя, поэтому опечаток не будет. В базе хранится только код
/// (`objects.country_code`, две заглавные латинские буквы — 0015).
/// Тесты — `test/country_list_test.dart`.
library;

class Country {
  const Country(this.code, this.ru, this.en);

  /// «RS».
  final String code;
  final String ru;
  final String en;

  /// Название на языке интерфейса (ru — по-русски, иначе по-английски).
  String name(String localeCode) => localeCode == 'ru' ? ru : en;

  /// Флаг-эмодзи из кода: две буквы → два «региональных индикатора».
  String get flag => countryFlag(code);
}

/// «RS» → 🇷🇸; не две латинские буквы — пустая строка.
String countryFlag(String code) {
  final c = code.trim().toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(c)) return '';
  return String.fromCharCodes(c.codeUnits.map((u) => 0x1F1E6 + u - 0x41));
}

/// Страна по коду (без учёта регистра); null — нет в справочнике.
Country? countryByCode(String? code) {
  if (code == null) return null;
  return _byCode[code.trim().toUpperCase()];
}

/// «🇷🇸 Сербия» / «🇷🇸 Serbia»; неизвестный код — сам код.
String countryLabel(String? code, String localeCode, {bool flag = true}) {
  final c = countryByCode(code);
  if (c == null) return code?.trim().toUpperCase() ?? '';
  return flag ? '${c.flag} ${c.name(localeCode)}' : c.name(localeCode);
}

String _norm(String s) => s.toLowerCase().replaceAll('ё', 'е').trim();

/// Поиск по русскому и английскому названию и по коду: «серб», «serb», «rs».
/// Пустой запрос — весь список. Порядок — по названию на языке интерфейса,
/// точное совпадение кода — первым.
List<Country> searchCountries(String query, String localeCode) {
  final q = _norm(query);
  final list = [
    for (final c in kCountries)
      if (q.isEmpty ||
          _norm(c.ru).contains(q) ||
          _norm(c.en).contains(q) ||
          c.code.toLowerCase() == q)
        c
  ];
  list.sort((a, b) {
    if (q.length == 2) {
      final ea = a.code.toLowerCase() == q, eb = b.code.toLowerCase() == q;
      if (ea != eb) return ea ? -1 : 1;
    }
    return _norm(a.name(localeCode)).compareTo(_norm(b.name(localeCode)));
  });
  return list;
}

final Map<String, Country> _byCode = {for (final c in kCountries) c.code: c};

/// Страны и территории ISO 3166-1 (кроме необитаемых).
final List<Country> kCountries = [
  for (final line in _raw.trim().split('\n'))
    if (line.trim().isNotEmpty) _parse(line),
];

Country _parse(String line) {
  final p = line.split('|');
  return Country(p[0].trim(), p[1].trim(), p[2].trim());
}

const _raw = '''
AD|Андорра|Andorra
AE|ОАЭ|United Arab Emirates
AF|Афганистан|Afghanistan
AG|Антигуа и Барбуда|Antigua and Barbuda
AI|Ангилья|Anguilla
AL|Албания|Albania
AM|Армения|Armenia
AO|Ангола|Angola
AR|Аргентина|Argentina
AS|Американское Самоа|American Samoa
AT|Австрия|Austria
AU|Австралия|Australia
AW|Аруба|Aruba
AX|Аландские острова|Åland Islands
AZ|Азербайджан|Azerbaijan
BA|Босния и Герцеговина|Bosnia and Herzegovina
BB|Барбадос|Barbados
BD|Бангладеш|Bangladesh
BE|Бельгия|Belgium
BF|Буркина-Фасо|Burkina Faso
BG|Болгария|Bulgaria
BH|Бахрейн|Bahrain
BI|Бурунди|Burundi
BJ|Бенин|Benin
BL|Сен-Бартелеми|Saint Barthélemy
BM|Бермуды|Bermuda
BN|Бруней|Brunei
BO|Боливия|Bolivia
BQ|Бонайре, Синт-Эстатиус и Саба|Caribbean Netherlands
BR|Бразилия|Brazil
BS|Багамы|Bahamas
BT|Бутан|Bhutan
BW|Ботсвана|Botswana
BY|Беларусь|Belarus
BZ|Белиз|Belize
CA|Канада|Canada
CC|Кокосовые острова|Cocos (Keeling) Islands
CD|ДР Конго|DR Congo
CF|ЦАР|Central African Republic
CG|Республика Конго|Republic of the Congo
CH|Швейцария|Switzerland
CI|Кот-д’Ивуар|Côte d’Ivoire
CK|Острова Кука|Cook Islands
CL|Чили|Chile
CM|Камерун|Cameroon
CN|Китай|China
CO|Колумбия|Colombia
CR|Коста-Рика|Costa Rica
CU|Куба|Cuba
CV|Кабо-Верде|Cape Verde
CW|Кюрасао|Curaçao
CX|Остров Рождества|Christmas Island
CY|Кипр|Cyprus
CZ|Чехия|Czechia
DE|Германия|Germany
DJ|Джибути|Djibouti
DK|Дания|Denmark
DM|Доминика|Dominica
DO|Доминиканская Республика|Dominican Republic
DZ|Алжир|Algeria
EC|Эквадор|Ecuador
EE|Эстония|Estonia
EG|Египет|Egypt
EH|Западная Сахара|Western Sahara
ER|Эритрея|Eritrea
ES|Испания|Spain
ET|Эфиопия|Ethiopia
FI|Финляндия|Finland
FJ|Фиджи|Fiji
FK|Фолклендские острова|Falkland Islands
FM|Микронезия|Micronesia
FO|Фарерские острова|Faroe Islands
FR|Франция|France
GA|Габон|Gabon
GB|Великобритания|United Kingdom
GD|Гренада|Grenada
GE|Грузия|Georgia
GF|Французская Гвиана|French Guiana
GG|Гернси|Guernsey
GH|Гана|Ghana
GI|Гибралтар|Gibraltar
GL|Гренландия|Greenland
GM|Гамбия|Gambia
GN|Гвинея|Guinea
GP|Гваделупа|Guadeloupe
GQ|Экваториальная Гвинея|Equatorial Guinea
GR|Греция|Greece
GT|Гватемала|Guatemala
GU|Гуам|Guam
GW|Гвинея-Бисау|Guinea-Bissau
GY|Гайана|Guyana
HK|Гонконг|Hong Kong
HN|Гондурас|Honduras
HR|Хорватия|Croatia
HT|Гаити|Haiti
HU|Венгрия|Hungary
ID|Индонезия|Indonesia
IE|Ирландия|Ireland
IL|Израиль|Israel
IM|Остров Мэн|Isle of Man
IN|Индия|India
IQ|Ирак|Iraq
IR|Иран|Iran
IS|Исландия|Iceland
IT|Италия|Italy
JE|Джерси|Jersey
JM|Ямайка|Jamaica
JO|Иордания|Jordan
JP|Япония|Japan
KE|Кения|Kenya
KG|Киргизия|Kyrgyzstan
KH|Камбоджа|Cambodia
KI|Кирибати|Kiribati
KM|Коморы|Comoros
KN|Сент-Китс и Невис|Saint Kitts and Nevis
KP|КНДР|North Korea
KR|Южная Корея|South Korea
KW|Кувейт|Kuwait
KY|Каймановы острова|Cayman Islands
KZ|Казахстан|Kazakhstan
LA|Лаос|Laos
LB|Ливан|Lebanon
LC|Сент-Люсия|Saint Lucia
LI|Лихтенштейн|Liechtenstein
LK|Шри-Ланка|Sri Lanka
LR|Либерия|Liberia
LS|Лесото|Lesotho
LT|Литва|Lithuania
LU|Люксембург|Luxembourg
LV|Латвия|Latvia
LY|Ливия|Libya
MA|Марокко|Morocco
MC|Монако|Monaco
MD|Молдова|Moldova
ME|Черногория|Montenegro
MF|Сен-Мартен|Saint Martin
MG|Мадагаскар|Madagascar
MH|Маршалловы Острова|Marshall Islands
MK|Северная Македония|North Macedonia
ML|Мали|Mali
MM|Мьянма|Myanmar
MN|Монголия|Mongolia
MO|Макао|Macao
MP|Северные Марианские острова|Northern Mariana Islands
MQ|Мартиника|Martinique
MR|Мавритания|Mauritania
MS|Монтсеррат|Montserrat
MT|Мальта|Malta
MU|Маврикий|Mauritius
MV|Мальдивы|Maldives
MW|Малави|Malawi
MX|Мексика|Mexico
MY|Малайзия|Malaysia
MZ|Мозамбик|Mozambique
NA|Намибия|Namibia
NC|Новая Каледония|New Caledonia
NE|Нигер|Niger
NF|Остров Норфолк|Norfolk Island
NG|Нигерия|Nigeria
NI|Никарагуа|Nicaragua
NL|Нидерланды|Netherlands
NO|Норвегия|Norway
NP|Непал|Nepal
NR|Науру|Nauru
NU|Ниуэ|Niue
NZ|Новая Зеландия|New Zealand
OM|Оман|Oman
PA|Панама|Panama
PE|Перу|Peru
PF|Французская Полинезия|French Polynesia
PG|Папуа — Новая Гвинея|Papua New Guinea
PH|Филиппины|Philippines
PK|Пакистан|Pakistan
PL|Польша|Poland
PM|Сен-Пьер и Микелон|Saint Pierre and Miquelon
PR|Пуэрто-Рико|Puerto Rico
PS|Палестина|Palestine
PT|Португалия|Portugal
PW|Палау|Palau
PY|Парагвай|Paraguay
QA|Катар|Qatar
RE|Реюньон|Réunion
RO|Румыния|Romania
RS|Сербия|Serbia
RU|Россия|Russia
RW|Руанда|Rwanda
SA|Саудовская Аравия|Saudi Arabia
SB|Соломоновы Острова|Solomon Islands
SC|Сейшельские Острова|Seychelles
SD|Судан|Sudan
SE|Швеция|Sweden
SG|Сингапур|Singapore
SH|Остров Святой Елены|Saint Helena
SI|Словения|Slovenia
SK|Словакия|Slovakia
SL|Сьерра-Леоне|Sierra Leone
SM|Сан-Марино|San Marino
SN|Сенегал|Senegal
SO|Сомали|Somalia
SR|Суринам|Suriname
SS|Южный Судан|South Sudan
ST|Сан-Томе и Принсипи|São Tomé and Príncipe
SV|Сальвадор|El Salvador
SX|Синт-Мартен|Sint Maarten
SY|Сирия|Syria
SZ|Эсватини|Eswatini
TC|Теркс и Кайкос|Turks and Caicos Islands
TD|Чад|Chad
TG|Того|Togo
TH|Таиланд|Thailand
TJ|Таджикистан|Tajikistan
TL|Восточный Тимор|Timor-Leste
TM|Туркменистан|Turkmenistan
TN|Тунис|Tunisia
TO|Тонга|Tonga
TR|Турция|Türkiye
TT|Тринидад и Тобаго|Trinidad and Tobago
TV|Тувалу|Tuvalu
TW|Тайвань|Taiwan
TZ|Танзания|Tanzania
UA|Украина|Ukraine
UG|Уганда|Uganda
US|США|United States
UY|Уругвай|Uruguay
UZ|Узбекистан|Uzbekistan
VA|Ватикан|Vatican City
VC|Сент-Винсент и Гренадины|Saint Vincent and the Grenadines
VE|Венесуэла|Venezuela
VG|Британские Виргинские острова|British Virgin Islands
VI|Виргинские острова (США)|U.S. Virgin Islands
VN|Вьетнам|Vietnam
VU|Вануату|Vanuatu
WF|Уоллис и Футуна|Wallis and Futuna
WS|Самоа|Samoa
XK|Косово|Kosovo
YE|Йемен|Yemen
YT|Майотта|Mayotte
ZA|ЮАР|South Africa
ZM|Замбия|Zambia
ZW|Зимбабве|Zimbabwe
''';
