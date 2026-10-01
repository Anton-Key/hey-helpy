import 'package:supabase_flutter/supabase_flutter.dart';

/// Причина ошибки онбординга. Текст для пользователя подбирает экран
/// на языке интерфейса (см. onboarding_screen.dart).
enum OnboardingError {
  notAuthenticated,
  companyNameRequired,
  alreadyInCompany,
  inviteNotFound,
  inviteUsed,
  inviteExpired,
  otherCompany,
  adminOnly,
  ownRole,
  profileNotFound,
  unknown,
}

class OnboardingException implements Exception {
  OnboardingException(this.error);
  final OnboardingError error;

  @override
  String toString() => 'OnboardingException($error)';
}

/// Онбординг и управление участниками компании.
///
/// Все изменения company_id и role идут только через серверные функции
/// (миграция 20260923000001_security_fixes.sql). Напрямую писать эти поля
/// в таблицу profiles клиент больше не может.
class OnboardingRepository {
  OnboardingRepository([SupabaseClient? client])
      : _c = client ?? Supabase.instance.client;

  final SupabaseClient _c;

  /// Создаёт компанию. Текущий пользователь становится её админом.
  Future<String> createCompany(String name) async {
    try {
      final id = await _c.rpc('create_company', params: {'p_name': name.trim()});
      return id as String;
    } on PostgrestException catch (e) {
      throw OnboardingException(_humanize(e.message));
    }
  }

  /// Вступление в компанию по коду приглашения подрядчика.
  /// Возвращает id созданной записи исполнителя.
  Future<String> acceptInvite(String token) async {
    try {
      final id = await _c.rpc('accept_invite', params: {'p_token': token.trim()});
      return id as String;
    } on PostgrestException catch (e) {
      throw OnboardingException(_humanize(e.message));
    }
  }

  /// Смена роли участника. Разрешено только админу своей компании.
  Future<void> setMemberRole(String profileId, String role) async {
    try {
      await _c.rpc('set_member_role', params: {
        'p_profile': profileId,
        'p_role': role,
      });
    } on PostgrestException catch (e) {
      throw OnboardingException(_humanize(e.message));
    }
  }

  /// Создаёт приглашение для исполнителя подрядчика и возвращает код.
  Future<String> createInvite(
    String contractorId, {
    Duration validFor = const Duration(days: 7),
  }) async {
    try {
      final row = await _c
          .from('invites')
          .insert({
            'contractor_id': contractorId,
            'expires_at': DateTime.now().add(validFor).toUtc().toIso8601String(),
          })
          .select('token')
          .single();
      return row['token'] as String;
    } on PostgrestException catch (e) {
      throw OnboardingException(_humanize(e.message));
    }
  }

  /// Сообщения серверных функций (миграция 0003) → причина ошибки.
  static OnboardingError _humanize(String raw) {
    const map = {
      'not authenticated': OnboardingError.notAuthenticated,
      'company name is required': OnboardingError.companyNameRequired,
      'user already belongs to a company': OnboardingError.alreadyInCompany,
      'invite not found': OnboardingError.inviteNotFound,
      'invite already used': OnboardingError.inviteUsed,
      'invite expired': OnboardingError.inviteExpired,
      'user belongs to another company': OnboardingError.otherCompany,
      'forbidden: admin only': OnboardingError.adminOnly,
      'cannot change own role': OnboardingError.ownRole,
      'profile not found in your company': OnboardingError.profileNotFound,
    };
    for (final e in map.entries) {
      if (raw.contains(e.key)) return e.value;
    }
    return OnboardingError.unknown;
  }
}
