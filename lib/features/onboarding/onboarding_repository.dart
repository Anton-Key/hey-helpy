import 'package:supabase_flutter/supabase_flutter.dart';

/// Ошибка онбординга с понятным пользователю текстом.
class OnboardingException implements Exception {
  OnboardingException(this.message);
  final String message;

  @override
  String toString() => message;
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

  static String _humanize(String raw) {
    const map = {
      'not authenticated': 'Войдите в аккаунт, чтобы продолжить.',
      'company name is required': 'Укажите название компании.',
      'user already belongs to a company': 'Вы уже состоите в компании.',
      'invite not found': 'Код приглашения не найден. Проверьте, что он введён полностью.',
      'invite already used': 'Этот код приглашения уже использован.',
      'invite expired': 'Срок действия приглашения истёк. Попросите новый код.',
      'user belongs to another company': 'Ваш аккаунт уже привязан к другой компании.',
      'forbidden: admin only': 'Менять роли может только администратор.',
      'cannot change own role': 'Нельзя изменить собственную роль.',
      'profile not found in your company': 'Пользователь не найден в вашей компании.',
    };
    for (final e in map.entries) {
      if (raw.contains(e.key)) return e.value;
    }
    return 'Не удалось выполнить действие. Попробуйте ещё раз.';
  }
}
