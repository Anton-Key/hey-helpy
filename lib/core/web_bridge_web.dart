import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

void publishConfig(String url, String anonKey) {
  try {
    web.window.localStorage.setItem(
        'hh.web.supabase', jsonEncode({'url': url, 'anonKey': anonKey}));
  } catch (_) {
    // Закрытое хранилище (приватный режим) — AR-страница попросит войти.
  }
}

bool arLikely() {
  final nav = web.window.navigator;
  final ua = nav.userAgent;
  final chrome = ua.contains('Chrome/') &&
      !RegExp(r'EdgA?/|OPR/|YaBrowser/|SamsungBrowser/|Firefox/').hasMatch(ua);
  return ua.contains('Android') && chrome && (nav as JSObject).has('xr');
}

/// Корень сайта (с учётом `--base-href /hey-helpy/`), без «#…».
Uri siteBase() {
  final href = web.document.baseURI;
  return Uri.parse(href).replace(fragment: '', query: '').removeFragment();
}
