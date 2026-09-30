import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/auth_repository.dart';
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
      _setStatus(SessionStatus.signedOut);
      return;
    }

    // Экран загрузки показываем только при первой загрузке,
    // чтобы повторное чтение профиля не «мигало» интерфейсом.
    if (_profile == null) _setStatus(SessionStatus.loading);

    try {
      final profile = await _auth.fetchMyProfile();
      if (seq != _loadSeq) return;
      _profile = profile;
      _setStatus(profile?.companyId == null
          ? SessionStatus.needsOnboarding
          : SessionStatus.ready);
    } catch (e) {
      if (seq != _loadSeq) return;
      debugPrint('SessionController: не удалось загрузить профиль: $e');
      _setStatus(SessionStatus.error);
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
