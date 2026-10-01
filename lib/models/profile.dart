import 'user_role.dart';

/// Профиль пользователя (таблица profiles).
class Profile {
  const Profile({
    required this.id,
    required this.role,
    this.companyId,
    this.fullName,
    this.phone,
    this.locale,
  });

  final String id;
  final UserRole role;
  final String? companyId;
  final String? fullName;
  final String? phone;

  /// Язык интерфейса (ru / en), выбранный пользователем. null — не выбирал.
  final String? locale;

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      role: UserRole.fromString(map['role'] as String?),
      companyId: map['company_id'] as String?,
      fullName: map['full_name'] as String?,
      phone: map['phone'] as String?,
      locale: map['locale'] as String?,
    );
  }

  /// Имя для показа; null, если не заполнено (подпись по умолчанию — из переводов).
  String? get displayName => (fullName == null || fullName!.isEmpty) ? null : fullName;
}
