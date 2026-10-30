import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Язык интерфейса.
///
/// При запуске берётся сохранённый на телефоне выбор, иначе английский —
/// основной язык продукта (шаг 33; язык устройства больше не берётся,
/// русский выбирается в настройках). После входа
/// язык из профиля (profiles.locale) имеет приоритет — так выбор
/// переезжает на другой телефон вместе с аккаунтом.
class LocaleController extends ChangeNotifier {
  LocaleController._(this._prefs, this._locale);

  static const supported = [Locale('ru'), Locale('en')];
  static const fallback = Locale('en');
  static const _prefsKey = 'locale';

  /// Названия языков пишутся на самом языке — так их находят в списке.
  static const nativeNames = {'ru': 'Русский', 'en': 'English'};

  final SharedPreferences? _prefs;
  Locale _locale;

  Locale get locale => _locale;
  String get code => _locale.languageCode;

  static Future<LocaleController> load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    return LocaleController._(prefs, initial(prefs?.getString(_prefsKey)));
  }

  /// Язык при запуске: сохранённый выбор, иначе [fallback] (английский).
  static Locale initial(String? saved) => _supportedOrNull(saved) ?? fallback;

  static Locale? _supportedOrNull(String? code) {
    if (code == null) return null;
    for (final l in supported) {
      if (l.languageCode == code) return l;
    }
    return null;
  }

  /// Язык из профиля после входа. Пустой или неизвестный — не трогаем.
  void applyFromProfile(String? code) {
    final l = _supportedOrNull(code);
    if (l == null || l == _locale) return;
    _set(l);
  }

  /// Выбор пользователя в профиле. Возвращает false, если на телефоне
  /// язык сменился, а в профиль записать не удалось (нет сети и т.п.).
  Future<bool> select(Locale l) async {
    if (_supportedOrNull(l.languageCode) == null) return false;
    _set(l);
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return true;
    try {
      await client.from('profiles').update({'locale': l.languageCode}).eq('id', uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _set(Locale l) {
    _locale = l;
    try {
      _prefs?.setString(_prefsKey, l.languageCode);
    } catch (_) {}
    notifyListeners();
  }
}

/// Доступ к [LocaleController] из любого экрана.
class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({super.key, required LocaleController controller, required super.child})
      : super(notifier: controller);

  static LocaleController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()!.notifier!;
}
