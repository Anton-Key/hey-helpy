import 'dart:async';

import 'package:http/http.dart' as http;

/// HTTP-клиент Supabase с пределом ожидания ответа (шаг 27).
///
/// Без него запрос при «зависшей» сети ждёт бесконечно — экран крутит
/// загрузку. Предел — до заголовков ответа: обычные запросы 25 с, загрузка
/// файлов в Storage 120 с (документ до 20 МБ на медленной сети), Edge Functions
/// 40 с (их ещё ограничивают сами клиенты: ИИ 16 с, `offline-sync` 30 с). `TimeoutException` приложение
/// считает ошибкой сети (`isNetworkError`): работает режим без сети и
/// показываются «Не получилось…» и «Повторить».
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  static const normal = Duration(seconds: 25);
  static const upload = Duration(seconds: 120);
  static const function = Duration(seconds: 40);

  /// Предел для запроса: загрузка файла — дольше.
  static Duration limitFor(String method, Uri url) {
    final isUpload = (method == 'POST' || method == 'PUT') &&
        url.path.contains('/storage/v1/object');
    if (isUpload) return upload;
    return url.path.contains('/functions/v1/') ? function : normal;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request).timeout(limitFor(request.method, request.url));

  @override
  void close() => _inner.close();
}
