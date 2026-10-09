import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Параметры в адресе веб-версии (например фильтр списка заявок), чтобы
/// ссылку можно было отправить коллеге. На телефоне ничего не делает.
///
/// Адрес вида `…/hey-helpy/#/?st=new&pri=critical` (роутер работает
/// с «#»); параметры до «#» (`?invite=…`) тоже читаются.
class AppUrl {
  AppUrl._();

  static Map<String, String> _initial = const {};

  /// Запомнить параметры адреса при запуске — до того, как роутер
  /// перенаправит на вход или заставку и адрес сменится. Вызывать в main().
  static void captureInitial() {
    if (!kIsWeb) return;
    _initial = parse(Uri.base);
  }

  /// Параметры из адреса: и до «#», и после.
  static Map<String, String> parse(Uri uri) {
    final q = <String, String>{...uri.queryParameters};
    final frag = uri.fragment;
    final i = frag.indexOf('?');
    if (i >= 0) q.addAll(Uri.splitQueryString(frag.substring(i + 1)));
    return q;
  }

  /// Забрать (один раз) параметры с ключами из [keys].
  static Map<String, String> takeInitial(Set<String> keys) {
    final out = {
      for (final e in _initial.entries)
        if (keys.contains(e.key)) e.key: e.value
    };
    _initial = {
      for (final e in _initial.entries)
        if (!keys.contains(e.key)) e.key: e.value
    };
    return out;
  }

  /// Заменить параметры в адресе, не открывая новую страницу и не
  /// добавляя запись в историю браузера.
  static void replaceQuery(Map<String, String> query) {
    if (!kIsWeb) return;
    SystemNavigator.routeInformationUpdated(
      uri: Uri(path: '/', queryParameters: query.isEmpty ? null : query),
      replace: true,
    );
  }
}
