import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile.dart';

/// Тонкая обёртка над Supabase Auth + загрузка профиля пользователя.
class AuthRepository {
  AuthRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentSession != null;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {if (fullName != null && fullName.isNotEmpty) 'full_name': fullName},
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Загружает профиль текущего пользователя из таблицы profiles.
  Future<Profile?> fetchMyProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromMap(data);
  }
}
