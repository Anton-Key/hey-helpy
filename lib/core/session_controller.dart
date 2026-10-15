import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/auth_repository.dart';
import '../features/offline/offline_logic.dart' show isNetworkError;
import '../features/offline/offline_service.dart';
import '../models/profile.dart';

/// Где сейчас находится пользователь в жизненном цикле сессии.
enum SessionStatus {
  /// Идёт проверка сессии или загрузка профиля.
  loading,

  /// Пользователь не вошёл.
  signedOut,

  /// Вошёл, но не состоит ни в одной компании — нужен онбординг.
  needsOnboarding,

  /// Вошёл и привязан к компании — можно работать.
  ready,

  /// Не удалось загрузить профиль (например, нет сети).
  error,
}

/// Единый источник состояния сессии для роутера и экранов.
///
/// Слушает Supabase Auth, после входа загружает профиль и по нему
/// решает, нужен ли онбординг. Роутер подписан на этот объект
/// через refreshListenable и пересчитывает редиректы при каждом изменении.
class SessionController extends ChangeNotifier {
  SessionController({AuthRepository? auth}) : _auth = auth ?? AuthRepository() {
    _sub = _auth.onAuthStateChange.listen(_onAuthChange);
    _refresh();
  }

  final AuthRepository _auth;
  late final StreamSubscription<AuthState> _sub;

  SessionStatus _status = SessionStatus.loading;
  Profile? _profile;

  /// Защита от гонок: учитывается только результат последней загрузки.
  int _loadSeq = 0;

  SessionStatus get status => _status;
  Profile? get profile => _profile;

  /// Перечитать профиль. Вызывается после онбординга и смены роли.
  Future<void> reloadProfile() => _refresh();

  Future<void> signOut() => _auth.signOut();

  void _onAuthChange(AuthState state) {
    switch (state.event) {
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.signedOut:
      case AuthChangeEvent.userUpdated:
        _refresh();
      default:
        // tokenRefreshed и прочие события профиль не меняют.
        break;
    }
  }

  Future<void> _refresh() async {
    final seq = ++_loadSeq;

    if (!_auth.isSignedIn) {
      _profile = null;
      // Выход из аккаунта: данные и очередь на телефоне удаляются (шаг 27).
      unawaited(OfflineService.instance.detach());
      unawaited(SharedPreferences.getInstance()
          .then((p) => p.remove(_profileKey), onError: (_) => false));
      _setStatus(SessionStatus.signedOut);
      return;
    }

    // Экран загрузки показываем только при первой загрузке,
    // чтобы повторное чтение профиля не «мигало» интерфейсом.
    if (_profile == null) _setStatus(SessionStatus.loading);

    try {
      final row = await _auth.fetchMyProfileRow();
      final profile = row == null ? null : Profile.fromMap(row);
      if (seq != _loadSeq) return;
      _profile = profile;
      _setStatus(profile?.companyId == null
          ? SessionStatus.needsOnboarding
          : SessionStatus.ready);
      if (row != null && OfflineService.supported) {
        unawaited(_saveProfile(row));
        unawaited(OfflineService.instance.attach(row['id'] as String));
      }
    } catch (e) {
      if (seq != _loadSeq) return;
      debugPrint('SessionController: не удалось загрузить профиль: $e');
      // Без сети (шаг 27, APK): последний сохранённый профиль — можно
      // работать со своими заявками из телефона.
      final cached = isNetworkError(e) ? await _loadProfile() : null;
      if (seq != _loadSeq) return;
      if (cached != null && cached.companyId != null) {
        _profile = cached;
        _setStatus(SessionStatus.ready);
        unawaited(OfflineService.instance.attach(cached.id));
        OfflineService.instance.markOffline();
        return;
      }
      _setStatus(SessionStatus.error);
    }
  }

  static const _profileKey = 'offline_profile';

  Future<void> _saveProfile(Map<String, dynamic> row) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_profileKey, jsonEncode(row));
    } catch (_) {}
  }

  Future<Profile?> _loadProfile() async {
    if (!OfflineService.supported) return null;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_profileKey);
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      // Только профиль того, кто сейчас вошёл.
      if (m['id'] != _auth.currentUser?.id) return null;
      return Profile.fromMap(m);
    } catch (_) {
      return null;
    }
  }

  void _setStatus(SessionStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
