/// Подложка карты — в одном месте: позже заменим на коммерческую или Яндекс
/// для РФ — поменять адреса и подписи здесь.
///
/// Основная — CARTO Positron (светлая, данные OpenStreetMap). С сентября 2026
/// CARTO отдаёт плитки только с ключом (бесплатный: carto.com/basemaps/apikey,
/// добавляется к адресу `?key=…`), без ключа на каждой плитке надпись
/// «API KEY REQUIRED». Ключ передаётся при сборке:
/// `--dart-define=MAP_TILE_KEY=…` (в GitHub — секрет `MAP_TILE_KEY`).
/// Ключа нет — временно стандартная подложка OpenStreetMap: годится для
/// демо и проверки, но не для массового приложения (правила tile.openstreetmap.org).
const mapTileKey = String.fromEnvironment('MAP_TILE_KEY');

bool get mapUsesCarto => mapTileKey.isNotEmpty;

String get mapTileUrl => mapUsesCarto
    ? 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png'
        '?key=${Uri.encodeQueryComponent(mapTileKey)}'
    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

List<String> get mapTileSubdomains =>
    mapUsesCarto ? const ['a', 'b', 'c', 'd'] : const [];

/// Подпись — обязательное условие использования данных OSM и плиток CARTO.
String get mapAttribution => mapUsesCarto
    ? 'OpenStreetMap contributors © CARTO'
    : 'OpenStreetMap contributors';

/// Наибольший зум, для которого у сервиса есть плитки (дальше — растягиваем).
int get mapTileMaxNativeZoom => mapUsesCarto ? 20 : 19;

/// Имя приложения в запросах плиток (User-Agent): по нему сервис плиток
/// отличает наше приложение от других.
const mapUserAgentPackage = 'app.heyhelpy.cmms';
