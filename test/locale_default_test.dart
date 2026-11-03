import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/locale_controller.dart';

/// Шаг 33: английский — основной язык. Без сохранённого выбора (новый
/// пользователь, новое устройство) — en, даже если телефон по-русски.
void main() {
  test('без сохранённого выбора — английский', () {
    expect(LocaleController.initial(null), const Locale('en'));
  });

  test('сохранённый выбор сохраняется', () {
    expect(LocaleController.initial('ru'), const Locale('ru'));
    expect(LocaleController.initial('en'), const Locale('en'));
  });

  test('неизвестный язык — английский', () {
    expect(LocaleController.initial('de'), const Locale('en'));
  });
}
