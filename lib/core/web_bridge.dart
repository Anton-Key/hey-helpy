import 'web_bridge_stub.dart' if (dart.library.js_interop) 'web_bridge_web.dart'
    as impl;

/// Связь веб-версии с отдельными страницами сайта (шаг 25: WebXR-демо
/// `web/ar/`). На телефоне (APK) ничего не делает.
class WebBridge {
  WebBridge._();

  /// Записать адрес базы и anon-ключ в `localStorage` (`hh.web.supabase`):
  /// страница `ar/` того же сайта читает их и сессию входа приложения.
  /// Anon-ключ и так есть в коде веб-версии; service-ключей тут нет.
  static void publishConfig(String url, String anonKey) =>
      impl.publishConfig(url, anonKey);

  /// Похоже ли, что «AR (демо)» заработает: браузер Chrome на Android и есть
  /// `navigator.xr`. Точную проверку (`immersive-ar`) делает сама страница.
  static bool get arLikely => impl.arLikely();

  /// Адрес страницы AR рядом с приложением: `<сайт>/ar/?location=…`.
  static Uri arPage({String? locationId, String? objectId}) =>
      impl.siteBase().resolve('ar/').replace(queryParameters: {
        if (locationId != null) 'location': locationId,
        if (objectId != null) 'object': objectId,
      });
}
